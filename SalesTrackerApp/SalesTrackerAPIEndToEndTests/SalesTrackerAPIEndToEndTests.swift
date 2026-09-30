//
//  SalesTrackerAPIEndToEndTests.swift
//  SalesTrackerAPIEndToEndTests
//
//  Created by mike on 2026/9/30.
//

import XCTest
import Synchronization
import SalesTracker

/// Runs against the live services, so it is a scheme of its own and is not part of CI: a red build
/// should mean the code broke, not that someone else's server was slow.
///
/// Run it by hand before submitting:
/// `xcodebuild test -project SalesTrackerApp/SalesTrackerApp.xcodeproj -scheme SalesTrackerAPIEndToEnd \
///   -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'`
final class SalesTrackerAPIEndToEndTests: XCTestCase {

    private let backendURL = URL(string: "https://ile-b2p4.essentialdeveloper.com")!
    private let middlewareURL = URL(string: "https://sales-middleware.n913239.workers.dev")!

    func test_login_withTheTestUser_storesAToken() async throws {
        let tokenStore = InMemoryTokenStore()
        let sut = LoginService(client: makeClient(), tokenStore: tokenStore, url: Endpoint.login.url(baseURL: backendURL))

        try await sut.login(username: "tester", password: "password")

        XCTAssertNotNil(tokenStore.retrieve())
    }

    func test_login_withWrongCredentials_deliversTheServersMessage() async throws {
        let sut = LoginService(
            client: makeClient(),
            tokenStore: InMemoryTokenStore(),
            url: Endpoint.login.url(baseURL: backendURL)
        )

        do {
            try await sut.login(username: "tester", password: "definitely-wrong")
            XCTFail("Expected to throw")
        } catch {
            guard case let .invalidCredentials(message) = error as? LoginService.Error else {
                return XCTFail("Expected invalid credentials, got \(error)")
            }
            XCTAssertNotNil(message, "Expected the server to say why")
        }
    }

    func test_loadingTheCatalogue_deliversProductsOrderedByNameWithTheirSales() async throws {
        let catalogue = try await loadCatalogue()
        let summaries = catalogue.summaries()

        XCTAssertFalse(summaries.isEmpty, "Expected the live backend to have products")
        XCTAssertEqual(
            summaries.map(\.product.name),
            summaries.map(\.product.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        )
        XCTAssertEqual(
            summaries.map(\.salesCount).reduce(0, +),
            summaries.reduce(0) { $0 + catalogue.sales(of: $1.product).count }
        )
    }

    func test_loadingTheCatalogue_withoutAToken_isRejected() async {
        let sut = RemoteProductCatalogueLoader(
            client: URLSessionHTTPClient(session: URLSession(configuration: .ephemeral)),
            productsURL: Endpoint.products.url(baseURL: backendURL),
            salesURL: Endpoint.sales.url(baseURL: backendURL)
        )

        do {
            _ = try await sut.load()
            XCTFail("Expected to throw")
        } catch {}
    }

    func test_loadingRates_deliversARateToUSDForEveryCurrencyThatIsSold() async throws {
        let catalogue = try await loadCatalogue()
        let rates = try await loadRates()

        let soldCurrencies = Set(
            catalogue.summaries().flatMap { catalogue.sales(of: $0.product).map(\.currencyCode) }
        )
        let convertible = Set(rates.filter { $0.to == "USD" }.map(\.from)).union(["USD"])

        XCTAssertTrue(
            soldCurrencies.isSubset(of: convertible),
            "No USD rate for: \(soldCurrencies.subtracting(convertible).sorted())"
        )
    }

    func test_theDetailOfAProduct_convertsEverySaleIntoUSD() async throws {
        let catalogue = try await loadCatalogue()
        let rates = try await loadRates()
        let converter = CurrencyConverter(rates: rates)

        let product = try XCTUnwrap(catalogue.summaries().first { $0.salesCount > 0 }?.product)
        let sales = catalogue.sales(of: product)

        let total = converter.totalInUSD(sales.map { (amount: $0.amount, currency: $0.currencyCode) })

        XCTAssertEqual(total.unconvertibleCount, 0, "Expected every sale of \(product.name) to convert")
        XCTAssertGreaterThan(total.amount, 0)
    }

    func test_theSalesOfAProduct_areOrderedMostRecentFirst() async throws {
        let catalogue = try await loadCatalogue()
        let product = try XCTUnwrap(catalogue.summaries().first { $0.salesCount > 1 }?.product)

        let dates = catalogue.sales(of: product).map(\.date)

        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    // MARK: - Helpers

    private func makeClient(timeout: TimeInterval = 30) -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        return URLSessionHTTPClient(session: URLSession(configuration: configuration))
    }

    private func loadCatalogue() async throws -> ProductCatalogue {
        let tokenStore = InMemoryTokenStore()
        let client = makeClient()

        try await LoginService(client: client, tokenStore: tokenStore, url: Endpoint.login.url(baseURL: backendURL))
            .login(username: "tester", password: "password")

        let authenticated = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenStore: tokenStore,
            onUnauthorized: {}
        )

        return try await RemoteProductCatalogueLoader(
            client: authenticated,
            productsURL: Endpoint.products.url(baseURL: backendURL),
            salesURL: Endpoint.sales.url(baseURL: backendURL)
        ).load()
    }

    private func loadRates() async throws -> [CurrencyRate] {
        try await RemoteLoader(
            url: Endpoint.rates.url(baseURL: middlewareURL),
            client: makeClient(),
            mapper: CurrencyRateMapper.map
        ).load()
    }
}

private final class InMemoryTokenStore: TokenStore {
    private let token = Mutex<String?>(nil)

    func save(_ token: String) throws { self.token.withLock { $0 = token } }
    func retrieve() -> String? { token.withLock { $0 } }
    func delete() throws { token.withLock { $0 = nil } }
}
