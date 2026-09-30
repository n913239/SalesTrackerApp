//
//  LoginPresentationAdapterTests.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/30.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class LoginPresentationAdapterTests: XCTestCase {

    func test_login_presentsLoadingBeforeTheResult() async {
        let (sut, view, client) = await makeSUT()
        await client.hang(loginURL)

        sut.login(username: "tester", password: "password")

        XCTAssertEqual(view.messages, [.loading(true), .errorMessage(nil)], "Expected loading without waiting for the reply")
    }

    func test_login_onSuccess_finishesAndReportsSuccess() async {
        var successCount = 0
        let (sut, view, _) = await makeSUT(onSuccess: { successCount += 1 })

        sut.login(username: "tester", password: "password")
        await waitUntil("the login finishes") { view.messages.contains(.loading(false)) }

        XCTAssertEqual(view.messages, [.loading(true), .errorMessage(nil), .loading(false)])
        XCTAssertEqual(successCount, 1)
    }

    func test_login_onFailure_presentsTheError() async {
        let (sut, view, client) = await makeSUT()
        await client.stub(loginURL, with: Data(#"{"message":"Wrong username or password"}"#.utf8), statusCode: 401)

        sut.login(username: "tester", password: "wrong")
        await waitUntil("the login finishes") { view.messages.contains(.loading(false)) }

        XCTAssertEqual(view.messages, [
            .loading(true),
            .errorMessage(nil),
            .errorMessage("Wrong username or password"),
            .loading(false)
        ])
    }

    func test_aSecondLogin_supersedesTheOneInFlight_andItsLateReplyIsDropped() async {
        var successCount = 0
        let (sut, view, client) = await makeSUT(onSuccess: { successCount += 1 })
        await client.hang(loginURL)

        sut.login(username: "tester", password: "first")
        await waitUntil("the first request is in flight") { await client.isHoldingARequest }
        sut.login(username: "tester", password: "second")

        await client.release(loginURL)
        await waitUntil("the second login finishes") { view.messages.contains(.loading(false)) }
        await drainPendingWork()

        XCTAssertEqual(successCount, 1, "The superseded login must not report success as well")
        XCTAssertEqual(view.messages.last, .loading(false), "The spinner must not be left running")
    }

    func test_deinit_cancelsTheLoginInFlight() async {
        let client = HTTPClientStub()
        await client.hang(loginURL)
        var sut: LoginPresentationAdapter? = makeAdapter(client: client, view: LoginViewSpy())

        sut?.login(username: "tester", password: "password")
        await waitUntil("the request is in flight") { await client.isHoldingARequest }
        sut = nil
        await drainPendingWork()

        XCTAssertEqual(client.cancellations.count, 1, "Letting go of the screen must cancel the request it started")
    }

    func test_login_doesNotDeliverAResultAfterTheAdapterHasBeenDeallocated() async {
        let client = HTTPClientStub()
        await client.stub(loginURL, with: tokenJSON("a-token"))
        await client.hang(loginURL)
        let view = LoginViewSpy()
        var sut: LoginPresentationAdapter? = makeAdapter(client: client, view: view)

        sut?.login(username: "tester", password: "password")
        await waitUntil("the request is in flight") { await client.isHoldingARequest }
        sut = nil
        await client.release(loginURL)
        await drainPendingWork()

        XCTAssertEqual(view.messages, [.loading(true), .errorMessage(nil)], "A reply to a screen that is gone must change nothing")
    }

    // MARK: - Helpers

    private var loginURL: URL { URL(string: "https://a-backend.com/login")! }

    private func makeSUT(
        onSuccess: @escaping () -> Void = {},
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> (LoginPresentationAdapter, LoginViewSpy, HTTPClientStub) {
        let client = HTTPClientStub()
        let view = LoginViewSpy()
        let sut = makeAdapter(client: client, view: view, onSuccess: onSuccess)

        await client.stub(loginURL, with: tokenJSON("a-token"))

        trackForMemoryLeaks(view, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        addTeardownBlock { [weak client] in await client?.cancelPendingRequests() }

        return (sut, view, client)
    }

    private func makeAdapter(
        client: HTTPClientStub,
        view: LoginViewSpy,
        onSuccess: @escaping () -> Void = {}
    ) -> LoginPresentationAdapter {
        let sut = LoginPresentationAdapter(
            loginService: LoginService(client: client, tokenStore: TokenStoreSpy(), url: loginURL),
            onSuccess: onSuccess
        )
        sut.presenter = LoginPresenter(
            loadingView: WeakRefVirtualProxy(view),
            errorView: WeakRefVirtualProxy(view)
        )
        return sut
    }
}
