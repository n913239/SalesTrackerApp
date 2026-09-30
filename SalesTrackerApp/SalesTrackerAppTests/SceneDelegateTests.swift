//
//  SceneDelegateTests.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/30.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class SceneDelegateTests: XCTestCase {

    func test_configureWindow_showsTheLoginScreenWithNoStoredToken() async {
        let (sut, _) = makeSUT(storedToken: nil)

        sut.configureWindow()

        XCTAssertNotNil(sut.topViewController as? LoginViewController)
    }

    func test_configureWindow_showsTheProductListWithAStoredToken() async {
        let (sut, _) = makeSUT(storedToken: "a-token")

        sut.configureWindow()

        XCTAssertNotNil(sut.topViewController as? ProductListViewController)
    }

    func test_configureWindow_makesTheWindowVisible() async {
        let (sut, _) = makeSUT(storedToken: nil)
        let window = UIWindowSpy()
        sut.window = window

        sut.configureWindow()

        XCTAssertEqual(window.makeKeyAndVisibleCallCount, 1)
    }

    func test_theCatalogueRequests_goToTheBackendURL() async {
        let (sut, client) = makeSUT(storedToken: "a-token")
        await client.stub(productsURL, with: emptyJSONArray())
        await client.stub(salesURL, with: emptyJSONArray())

        sut.configureWindow()
        sut.topViewController?.simulateAppearance()
        await waitUntil("both catalogue requests go out") {
            let products = await client.requests(to: productsURL)
            let sales = await client.requests(to: salesURL)
            return products == 1 && sales == 1
        }

        let products = await client.requests(to: productsURL)
        let sales = await client.requests(to: salesURL)
        XCTAssertEqual(products, 1)
        XCTAssertEqual(sales, 1)
    }

    func test_anUnauthorizedResponse_deletesTheTokenAndReturnsToTheLoginScreen() async {
        let tokenStore = TokenStoreSpy(token: "a-token")
        let (sut, client) = makeSUT(tokenStore: tokenStore)
        await client.stub(productsURL, with: emptyJSONArray(), statusCode: 401)
        await client.stub(salesURL, with: emptyJSONArray(), statusCode: 401)

        sut.configureWindow()
        sut.topViewController?.simulateAppearance()
        await waitUntil("the app locks") { sut.topViewController is LoginViewController }

        XCTAssertNil(tokenStore.retrieve())
        XCTAssertNotNil(sut.topViewController as? LoginViewController)
    }

    func test_twoUnauthorizedResponses_lockTheAppOnce() async {
        let (sut, client) = makeSUT(tokenStore: TokenStoreSpy(token: "a-token"))
        await client.stub(productsURL, with: emptyJSONArray(), statusCode: 401)
        await client.stub(salesURL, with: emptyJSONArray(), statusCode: 401)

        sut.configureWindow()
        sut.topViewController?.simulateAppearance()
        await waitUntil("the app locks") { sut.topViewController is LoginViewController }
        let firstLogin = sut.topViewController
        await drainPendingWork()

        XCTAssertTrue(sut.topViewController === firstLogin, "Both 401s must not build two login screens")
    }

    func test_anUnauthorizedResponse_whenTheTokenCannotBeDeleted_stillReturnsToTheLoginScreen() async {
        let tokenStore = TokenStoreSpy(token: "a-token", deleteError: anyNSError())
        let (sut, client) = makeSUT(tokenStore: tokenStore)
        await client.stub(productsURL, with: emptyJSONArray(), statusCode: 401)
        await client.stub(salesURL, with: emptyJSONArray(), statusCode: 401)

        sut.configureWindow()
        sut.topViewController?.simulateAppearance()
        await waitUntil("the app locks") { sut.topViewController is LoginViewController }

        XCTAssertGreaterThanOrEqual(tokenStore.deleteCount, 1, "Expected the app to try to clear the session")
        XCTAssertNotNil(sut.topViewController as? LoginViewController)
    }

    func test_theRatesRequest_carriesNoAuthorizationHeader() async {
        let (sut, client) = makeSUT(tokenStore: TokenStoreSpy(token: "a-token"))
        await stubACatalogueWithOneProduct(on: client)
        await client.stub(ratesURL, with: emptyJSONArray())

        sut.configureWindow()
        sut.topViewController?.simulateAppearance()
        await waitUntil("the list has a row") { (sut.topViewController as? ProductListViewController)?.numberOfRenderedRows == 1 }
        (sut.topViewController as? ProductListViewController)?.simulateTapOnRow(0)
        await waitUntil("the detail is pushed") { sut.topViewController is ProductDetailViewController }
        sut.topViewController?.simulateAppearance()
        await waitUntil("the rates request goes out") { await client.requests(to: ratesURL) == 1 }

        let headers = await client.headers(for: ratesURL)
        XCTAssertNil(headers?["Authorization"], "The rates service never authenticated the user")
    }

    func test_selectingAProduct_doesNotRequestTheCatalogueAgain() async {
        let (sut, client) = makeSUT(tokenStore: TokenStoreSpy(token: "a-token"))
        await stubACatalogueWithOneProduct(on: client)
        await client.stub(ratesURL, with: emptyJSONArray())

        sut.configureWindow()
        sut.topViewController?.simulateAppearance()
        await waitUntil("the list has a row") { (sut.topViewController as? ProductListViewController)?.numberOfRenderedRows == 1 }
        (sut.topViewController as? ProductListViewController)?.simulateTapOnRow(0)
        await waitUntil("the detail is pushed") { sut.topViewController is ProductDetailViewController }
        sut.topViewController?.simulateAppearance()
        await waitUntil("the rates request goes out") { await client.requests(to: ratesURL) == 1 }
        await drainPendingWork()

        let sales = await client.requests(to: salesURL)
        XCTAssertEqual(sales, 1, "Opening a product must reuse the catalogue the list already loaded")
    }

    func test_pullingToRefreshTheList_requestsTheCatalogueAgain() async {
        let (sut, client) = makeSUT(tokenStore: TokenStoreSpy(token: "a-token"))
        await stubACatalogueWithOneProduct(on: client)

        sut.configureWindow()
        let list = sut.topViewController as? ProductListViewController
        list?.simulateAppearance()
        await waitUntil("the list has a row") { list?.numberOfRenderedRows == 1 }

        list?.refreshControl?.simulatePullToRefresh()
        await waitUntil("the catalogue is asked for again") { await client.requests(to: productsURL) == 2 }

        let products = await client.requests(to: productsURL)
        let sales = await client.requests(to: salesURL)
        XCTAssertEqual(products, 2)
        XCTAssertEqual(sales, 2)
    }

    // MARK: - Helpers

    private var productsURL: URL { URL(string: "https://ile-b2p4.essentialdeveloper.com/products")! }
    private var salesURL: URL { URL(string: "https://ile-b2p4.essentialdeveloper.com/sales")! }
    private var ratesURL: URL { URL(string: "https://sales-middleware.n913239.workers.dev/rates")! }

    private func makeSUT(
        storedToken: String? = nil,
        tokenStore: TokenStoreSpy? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (SceneDelegate, HTTPClientStub) {
        let client = HTTPClientStub()
        let sut = SceneDelegate(httpClient: client, tokenStore: tokenStore ?? TokenStoreSpy(token: storedToken))
        sut.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        trackForMemoryLeaks(sut, file: file, line: line)
        addTeardownBlock { [weak client] in await client?.cancelPendingRequests() }

        return (sut, client)
    }

    private func emptyJSONArray() -> Data { Data("[]".utf8) }

    private func stubACatalogueWithOneProduct(on client: HTTPClientStub) async {
        let id = UUID()
        await client.stub(productsURL, with: try! JSONSerialization.data(withJSONObject: [
            ["id": id.uuidString, "name": "iPhone"]
        ]))
        await client.stub(salesURL, with: try! JSONSerialization.data(withJSONObject: [
            ["currency_code": "EUR", "amount": "100.00", "product_id": id.uuidString, "date": "2030-01-02T11:00:00Z"]
        ]))
    }
}

extension SceneDelegate {
    var topViewController: UIViewController? {
        (window?.rootViewController as? UINavigationController)?.topViewController
    }
}

final class UIWindowSpy: UIWindow {
    private(set) var makeKeyAndVisibleCallCount = 0

    override func makeKeyAndVisible() {
        makeKeyAndVisibleCallCount += 1
    }
}
