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

    // MARK: - Helpers

    private var productsURL: URL { URL(string: "https://ile-b2p4.essentialdeveloper.com/products")! }
    private var salesURL: URL { URL(string: "https://ile-b2p4.essentialdeveloper.com/sales")! }
    private var ratesURL: URL { URL(string: "https://sales-middleware.n913239.workers.dev/rates")! }

    private func makeSUT(
        storedToken: String?,
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

    private func emptyJSONArray() -> Data { Data("[]".utf8) }
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
