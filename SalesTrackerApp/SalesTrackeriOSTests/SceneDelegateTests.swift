//
//  SceneDelegateTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

final class SceneDelegateTests: UILayerTestCase {

    func test_configureWindow_showsTheLoginScreenWithNoStoredToken() {
        let sut = makeSUT(token: nil)

        sut.configureWindow()

        XCTAssertTrue(rootViewController(of: sut) is LoginViewController)
    }

    func test_configureWindow_showsTheProductListWithAStoredToken() {
        let sut = makeSUT(token: "a-token")

        sut.configureWindow()

        XCTAssertTrue(rootViewController(of: sut) is ProductListViewController)
    }

    func test_configureWindow_makesTheWindowVisible() {
        let sut = makeSUT(token: nil)

        sut.configureWindow()

        XCTAssertFalse(sut.window?.isHidden ?? true)
    }

    /// The token expires after two minutes, so a 401 is the normal end of a session rather than an
    /// edge case. Whichever screen the request came from, the app has to drop the dead token and ask
    /// the user to sign in again.
    func test_anUnauthorizedResponse_deletesTheTokenAndReturnsToTheLoginScreen() async {
        let store = TokenStoreSpy(token: "an-expired-token")
        // An expired token is not a transport failure: the server answers, with a 401. Throwing here
        // instead would exercise a path the real client never takes.
        let client = HTTPClientStub(result: .success((Data(), response(withStatusCode: 401))))
        let sut = makeSUT(client: client, store: store)

        sut.configureWindow()
        XCTAssertTrue(rootViewController(of: sut) is ProductListViewController, "Precondition: the stored token opens the list")

        // The window in a test is not attached to a scene, so it never lays out its content on its
        // own. Loading the view is what a visible window does, and it is what sends the request that
        // comes back unauthorized.
        rootViewController(of: sut)?.loadViewIfNeeded()

        await waitUntil { rootViewController(of: sut) is LoginViewController }

        XCTAssertNil(store.retrieve(), "Expected the expired token to be deleted")
        XCTAssertTrue(rootViewController(of: sut) is LoginViewController)

        await drainPendingWork()
    }

    // MARK: - Helpers

    private func makeSUT(
        client: HTTPClient? = nil,
        store: TokenStore? = nil,
        token: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SceneDelegate {
        let sut = SceneDelegate(
            httpClient: client ?? HTTPClientStub(result: .failure(anyNSError())),
            tokenStore: store ?? TokenStoreSpy(token: token)
        )
        sut.window = UIWindow(frame: UIScreen.main.bounds)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func rootViewController(of sut: SceneDelegate) -> UIViewController? {
        (sut.window?.rootViewController as? UINavigationController)?.topViewController
    }

    private func response(withStatusCode code: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://any-url.com")!,
            statusCode: code,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private final class TokenStoreSpy: TokenStore, @unchecked Sendable {
        private let queue = DispatchQueue(label: "TokenStoreSpy")
        private var token: String?

        init(token: String?) { self.token = token }

        func save(_ token: String) throws { queue.sync { self.token = token } }
        func retrieve() -> String? { queue.sync { token } }
        func delete() throws { queue.sync { token = nil } }
    }

    private final class HTTPClientStub: HTTPClient, @unchecked Sendable {
        private let result: Result<(Data, HTTPURLResponse), Error>

        init(result: Result<(Data, HTTPURLResponse), Error>) { self.result = result }

        func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) { try result.get() }
        func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) { try result.get() }
    }
}
