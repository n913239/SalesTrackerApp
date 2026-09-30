//
//  SalesTrackerAcceptanceTests.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/30.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

/// Assembled from `SceneDelegate` with every real object in place; only the transport and the
/// Keychain are stood in for. These check that the requirements are met on screen, not that a
/// particular number of requests went out - that belongs with the composition root.
@MainActor
final class SalesTrackerAcceptanceTests: XCTestCase {

    func test_login_withValidCredentials_showsTheProductList() async {
        let (sut, client) = makeSUT()
        await client.stub(loginURL, with: tokenJSON("a-token"))
        await stubACatalogue(on: client)

        sut.configureWindow()
        let login = sut.topViewController as? LoginViewController
        login?.simulateAppearance()
        login?.onLogin?("tester", "password")
        await waitUntil("the list replaces the login screen") { sut.topViewController is ProductListViewController }

        XCTAssertNotNil(sut.topViewController as? ProductListViewController)
    }

    func test_login_withRejectedCredentials_showsTheServersMessage() async {
        let (sut, client) = makeSUT()
        await client.stub(loginURL, with: Data(#"{"message":"Wrong username or password"}"#.utf8), statusCode: 401)

        sut.configureWindow()
        let login = sut.topViewController as? LoginViewController
        login?.simulateAppearance()
        login?.onLogin?("tester", "wrong")
        await waitUntil("the message reaches the screen") { login?.isShowingError == true }

        XCTAssertEqual(login?.errorMessage, "Wrong username or password")
        XCTAssertNotNil(sut.topViewController as? LoginViewController, "A rejected login must not move on")
    }

    func test_productList_showsEveryProductWithItsSalesCount_orderedByName() async {
        let (sut, client) = makeSUT(storedToken: "a-token")
        await stubACatalogue(on: client)

        let list = try! await showTheList(sut, client)

        XCTAssertEqual(list.numberOfRenderedRows, 2)
        XCTAssertEqual(list.title(at: 0), "Apple Watch")
        XCTAssertEqual(list.subtitle(at: 0), String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), 0))
        XCTAssertEqual(list.title(at: 1), "iPhone")
        XCTAssertEqual(list.subtitle(at: 1), localized("PRODUCT_SALES_COUNT_ONE"))
    }

    func test_refreshingAListThatHasRows_whenItFails_showsTheErrorAboveTheRows() async {
        let (sut, client) = makeSUT(storedToken: "a-token")
        await stubACatalogue(on: client)
        let list = try! await showTheList(sut, client)

        await client.stub(productsURL, withError: anyNSError())
        await client.stub(salesURL, withError: anyNSError())
        list.refreshControl?.simulatePullToRefresh()
        await waitUntil("the failure reaches the screen") { list.isShowingError }

        XCTAssertTrue(list.isShowingError, "A refresh that fails must say so")
        XCTAssertEqual(list.numberOfRenderedRows, 2, "The rows the user was reading must stay")
    }

    func test_selectingAProduct_showsItsSalesInTheirOwnCurrencyAndInUSD() async {
        let (sut, client) = makeSUT(storedToken: "a-token")
        await stubACatalogue(on: client)
        await client.stub(ratesURL, with: try! JSONSerialization.data(withJSONObject: [
            ["from": "EUR", "to": "USD", "rate": 1.18]
        ]))

        let detail = try! await showTheDetail(sut, client)
        // The sales are on screen before the rates are: waiting for the converted column is
        // waiting for the second render, not for a duration.
        await waitUntil("the rates are applied") { detail.accessoryText(at: 0) == "$118.00" }

        XCTAssertEqual(detail.numberOfRenderedRows, 1)
        XCTAssertEqual(detail.title(at: 0), "€100.00")
        XCTAssertEqual(detail.accessoryText(at: 0), "$118.00")
        XCTAssertEqual(
            detail.subtitleText,
            String(
                format: localized("PRODUCT_DETAIL_SUBTITLE_FORMAT"),
                "$118.00",
                localized("PRODUCT_SALES_COUNT_ONE")
            )
        )
    }

    func test_productDetail_whenTheRatesFail_keepsTheSalesAndTheCount() async {
        let (sut, client) = makeSUT(storedToken: "a-token")
        await stubACatalogue(on: client)
        await client.stub(ratesURL, withError: anyNSError())

        let detail = try! await showTheDetail(sut, client)
        await waitUntil("the rates failure is reflected") {
            detail.accessoryText(at: 0) == localized("USD_UNAVAILABLE")
        }

        XCTAssertEqual(detail.numberOfRenderedRows, 1, "A failed rates request must not cost the user the sales")
        XCTAssertEqual(
            detail.subtitleText,
            String(format: localized("PRODUCT_DETAIL_SUBTITLE_RATES_FAILED_FORMAT"), localized("PRODUCT_SALES_COUNT_ONE")),
            "The count must survive a failed rates request"
        )
    }

    func test_aRefreshThatComesBackUnauthorized_returnsToTheLoginScreen() async {
        let (sut, client) = makeSUT(storedToken: "a-token")
        await stubACatalogue(on: client)
        let list = try! await showTheList(sut, client)

        await client.stub(productsURL, with: emptyJSONArray(), statusCode: 401)
        await client.stub(salesURL, with: emptyJSONArray(), statusCode: 401)
        list.refreshControl?.simulatePullToRefresh()
        await waitUntil("the app locks") { sut.topViewController is LoginViewController }

        XCTAssertNotNil(sut.topViewController as? LoginViewController)
    }

    // MARK: - Helpers

    private var loginURL: URL { URL(string: "https://ile-b2p4.essentialdeveloper.com/login")! }
    private var productsURL: URL { URL(string: "https://ile-b2p4.essentialdeveloper.com/products")! }
    private var salesURL: URL { URL(string: "https://ile-b2p4.essentialdeveloper.com/sales")! }
    private var ratesURL: URL { URL(string: "https://sales-middleware.n913239.workers.dev/rates")! }

    private func makeSUT(
        storedToken: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (SceneDelegate, HTTPClientStub) {
        let client = HTTPClientStub()
        let sut = SceneDelegate(httpClient: client, tokenStore: TokenStoreSpy(token: storedToken))
        sut.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        trackForMemoryLeaks(sut, file: file, line: line)
        addTeardownBlock { [weak client] in await client?.cancelPendingRequests() }

        return (sut, client)
    }

    private func showTheList(_ sut: SceneDelegate, _ client: HTTPClientStub) async throws -> ProductListViewController {
        sut.configureWindow()
        sut.topViewController?.simulateAppearance()
        await waitUntil("the list has rows") { (sut.topViewController as? ProductListViewController)?.numberOfRenderedRows == 2 }
        return try XCTUnwrap(sut.topViewController as? ProductListViewController)
    }

    private func showTheDetail(_ sut: SceneDelegate, _ client: HTTPClientStub) async throws -> ProductDetailViewController {
        let list = try await showTheList(sut, client)
        list.simulateTapOnRow(1)
        await waitUntil("the detail is pushed") { sut.topViewController is ProductDetailViewController }
        sut.topViewController?.simulateAppearance()
        let detail = try XCTUnwrap(sut.topViewController as? ProductDetailViewController)
        await waitUntil("the sales reach the screen") { detail.numberOfRenderedRows == 1 }
        return detail
    }

    private func emptyJSONArray() -> Data { Data("[]".utf8) }

    private func stubACatalogue(on client: HTTPClientStub) async {
        let iPhone = UUID()
        let appleWatch = UUID()
        await client.stub(productsURL, with: try! JSONSerialization.data(withJSONObject: [
            ["id": iPhone.uuidString, "name": "iPhone"],
            ["id": appleWatch.uuidString, "name": "Apple Watch"]
        ]))
        await client.stub(salesURL, with: try! JSONSerialization.data(withJSONObject: [
            ["currency_code": "EUR", "amount": "100.00", "product_id": iPhone.uuidString, "date": "2030-01-02T11:00:00Z"]
        ]))
    }
}

private extension ProductDetailViewController {
    var subtitleText: String? {
        (view(withIdentifier: "productDetail.subtitleLabel") as UILabel?)?.text
    }
}
