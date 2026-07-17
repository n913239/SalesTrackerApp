//
//  SalesTrackerAPIEndToEndTests.swift
//  SalesTrackerAPIEndToEndTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

/// Hits the live backend and the live middleware. Excluded from the CI test plan: a red CI has to
/// mean the code is broken, not that someone else's server is. Run before shipping a change to the
/// networking, mapping or conversion layers.
final class SalesTrackerAPIEndToEndTests: XCTestCase {

    func test_login_withTheTestUser_storesAToken() async throws {
        let store = InMemoryTokenStore()
        let sut = LoginService(client: makeClient(), tokenStore: store, url: Endpoint.login)

        try await sut.login(username: "tester", password: "password")

        XCTAssertFalse(store.retrieve()?.isEmpty ?? true, "Expected a token to be stored")
    }

    func test_login_withWrongCredentials_deliversTheServersMessage() async {
        let sut = LoginService(client: makeClient(), tokenStore: InMemoryTokenStore(), url: Endpoint.login)

        do {
            try await sut.login(username: "tester", password: "wrong-password")
            XCTFail("Expected the login to be rejected")
        } catch let error as LoginService.Error {
            guard case let .invalidCredentials(message) = error else {
                return XCTFail("Expected invalidCredentials, got \(error) instead")
            }
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Expected invalidCredentials, got \(error) instead")
        }
    }

    func test_loadingProductsAndSales_buildsACatalogue() async throws {
        let client = try await authenticatedClient()

        async let products = RemoteLoader(url: Endpoint.products, client: client, mapper: ProductMapper.map).load()
        async let sales = RemoteLoader(url: Endpoint.sales, client: client, mapper: SaleMapper.map).load()

        let catalogue = ProductCatalogue(products: try await products, sales: try await sales)
        let summaries = catalogue.summaries()

        XCTAssertFalse(summaries.isEmpty, "Expected the live feed to contain products")
        XCTAssertEqual(
            summaries.map(\.product.name),
            summaries.map(\.product.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            "Expected the products to be ordered by name"
        )
        XCTAssertGreaterThan(summaries.reduce(0) { $0 + $1.salesCount }, 0, "Expected the live feed to contain sales")
    }

    func test_loadingProductsAndSales_withoutAToken_isRejected() async {
        let client = AuthenticatedHTTPClientDecorator(
            decoratee: makeClient(),
            tokenStore: InMemoryTokenStore(),
            onUnauthorized: {}
        )

        do {
            _ = try await RemoteLoader(url: Endpoint.products, client: client, mapper: ProductMapper.map).load()
            XCTFail("Expected the request to be rejected without a token")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .unauthorized)
        }
    }

    func test_loadingRates_deliversARateToUSDForEveryCurrencyThatIsSold() async throws {
        let client = try await authenticatedClient()

        let rates = try await RemoteLoader(url: Endpoint.rates, client: makeClient(), mapper: CurrencyRateMapper.map).load()
        let sales = try await RemoteLoader(url: Endpoint.sales, client: client, mapper: SaleMapper.map).load()

        let converter = CurrencyConverter(rates: rates)
        let currencies = Set(sales.map(\.currencyCode))

        for currency in currencies {
            XCTAssertNotNil(
                converter.amountInUSD(100, currency: currency),
                "The middleware must resolve \(currency) to USD - only EUR converts directly, so the rest depend on its multi-hop conversion"
            )
        }
    }

    func test_theDetailOfAProduct_convertsEverySaleIntoUSD() async throws {
        let client = try await authenticatedClient()

        async let loadedProducts = RemoteLoader(url: Endpoint.products, client: client, mapper: ProductMapper.map).load()
        async let loadedSales = RemoteLoader(url: Endpoint.sales, client: client, mapper: SaleMapper.map).load()
        async let loadedRates = RemoteLoader(url: Endpoint.rates, client: makeClient(), mapper: CurrencyRateMapper.map).load()

        let catalogue = ProductCatalogue(products: try await loadedProducts, sales: try await loadedSales)
        let converter = CurrencyConverter(rates: try await loadedRates)

        let product = try XCTUnwrap(catalogue.summaries().first?.product)
        let sales = catalogue.sales(of: product)

        let viewModel = ProductDetailPresenter().viewModel(for: product, sales: sales, converter: converter)

        XCTAssertEqual(viewModel.title, product.name)
        XCTAssertEqual(viewModel.sales.count, sales.count)
        XCTAssertTrue(
            viewModel.sales.allSatisfy { $0.amountInUSD != nil },
            "Every currency in the live feed has a rate, so no sale should be left without a USD amount"
        )
        XCTAssertFalse(
            viewModel.subtitle.contains("without a USD rate"),
            "Expected every sale to be converted"
        )
    }

    func test_theSalesOfAProduct_areOrderedMostRecentFirst() async throws {
        let client = try await authenticatedClient()

        async let loadedProducts = RemoteLoader(url: Endpoint.products, client: client, mapper: ProductMapper.map).load()
        async let loadedSales = RemoteLoader(url: Endpoint.sales, client: client, mapper: SaleMapper.map).load()

        let catalogue = ProductCatalogue(products: try await loadedProducts, sales: try await loadedSales)
        let product = try XCTUnwrap(catalogue.summaries().first?.product)

        let dates = catalogue.sales(of: product).map(\.date)

        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    // MARK: - Helpers

    private func makeClient(file: StaticString = #filePath, line: UInt = #line) -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        // Two slow paths, both measured against the live services: the middleware runs on a free
        // tier and cold-starts in about fourteen seconds, and the login endpoint takes about
        // forty-six seconds to reject a wrong password - a correct one answers in under a second.
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 90
        return URLSessionHTTPClient(session: URLSession(configuration: configuration))
    }

    private func authenticatedClient() async throws -> HTTPClient {
        let store = InMemoryTokenStore()
        let client = makeClient()

        try await LoginService(client: client, tokenStore: store, url: Endpoint.login)
            .login(username: "tester", password: "password")

        return AuthenticatedHTTPClientDecorator(decoratee: client, tokenStore: store, onUnauthorized: {})
    }

    private final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
        private let queue = DispatchQueue(label: "InMemoryTokenStore")
        private var token: String?

        func save(_ token: String) throws { queue.sync { self.token = token } }
        func retrieve() -> String? { queue.sync { token } }
        func delete() throws { queue.sync { token = nil } }
    }
}
