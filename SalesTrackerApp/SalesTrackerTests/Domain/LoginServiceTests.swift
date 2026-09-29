//
//  LoginServiceTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import Synchronization
import SalesTracker

final class LoginServiceTests: XCTestCase {

    func test_login_postsTheCredentialsToTheLoginURL() async throws {
        let url = URL(string: "https://a-backend.com/login")!
        let client = HTTPClientSpy()
        await client.completeWith(token: "a-token")
        let sut = LoginService(client: client, tokenStore: TokenStoreSpy(), url: url)

        try await sut.login(username: "tester", password: "password")

        let requests = await client.postedRequests
        XCTAssertEqual(requests.map(\.url), [url])
        XCTAssertEqual(
            requests.first.flatMap { try? JSONSerialization.jsonObject(with: $0.body) as? [String: String] },
            ["username": "tester", "password": "password"]
        )
    }

    func test_login_storesTheReceivedToken() async throws {
        let client = HTTPClientSpy()
        await client.completeWith(token: "a-token")
        let tokenStore = TokenStoreSpy()
        let sut = LoginService(client: client, tokenStore: tokenStore, url: anyURL())

        try await sut.login(username: "tester", password: "password")

        XCTAssertEqual(tokenStore.savedTokens, ["a-token"])
    }

    func test_login_on401_deliversTheServersOwnMessage() async {
        let client = HTTPClientSpy()
        await client.completeWith(
            data: try! JSONSerialization.data(withJSONObject: ["message": "Wrong username or password"]),
            statusCode: 401
        )
        let sut = LoginService(client: client, tokenStore: TokenStoreSpy(), url: anyURL())

        do {
            try await sut.login(username: "tester", password: "wrong")
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? LoginService.Error, .invalidCredentials(message: "Wrong username or password"))
        }
    }

    func test_login_onClientError_deliversConnectivityError() async {
        let client = HTTPClientSpy()
        await client.completeWith(error: NSError(domain: "any error", code: 0))
        let sut = LoginService(client: client, tokenStore: TokenStoreSpy(), url: anyURL())

        do {
            try await sut.login(username: "tester", password: "password")
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? LoginService.Error, .connectivity)
        }
    }

    func test_login_onInvalidResponseData_deliversConnectivityError() async {
        let client = HTTPClientSpy()
        await client.completeWith(data: Data("invalid json".utf8), statusCode: 200)
        let sut = LoginService(client: client, tokenStore: TokenStoreSpy(), url: anyURL())

        do {
            try await sut.login(username: "tester", password: "password")
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? LoginService.Error, .connectivity)
        }
    }

    func test_login_whenTheTokenCannotBeStored_reportsThatRatherThanAConnectionFailure() async {
        let client = HTTPClientSpy()
        await client.completeWith(token: "a-token")
        let tokenStore = TokenStoreSpy(saveError: TokenStoreError.saveFailed(-25299))
        let sut = LoginService(client: client, tokenStore: tokenStore, url: anyURL())

        do {
            try await sut.login(username: "tester", password: "password")
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? LoginService.Error, .tokenNotStored)
        }
    }

    // MARK: - Helpers

    private func anyURL() -> URL { URL(string: "https://any-url.com")! }
}

private actor HTTPClientSpy: HTTPClient {
    struct PostedRequest {
        let url: URL
        let body: Data
    }

    private(set) var postedRequests: [PostedRequest] = []
    private var data = Data()
    private var statusCode = 200
    private var error: Error?

    func completeWith(token: String) {
        data = try! JSONSerialization.data(withJSONObject: ["access_token": token])
        statusCode = 200
    }

    func completeWith(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func completeWith(error: Error) {
        self.error = error
    }

    func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        throw NSError(domain: "not used", code: 0)
    }

    func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        postedRequests.append(PostedRequest(url: url, body: body))
        if let error { throw error }
        return (data, HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }
}

final class TokenStoreSpy: TokenStore {
    private struct State {
        var tokens: [String] = []
        var deleteCount = 0
    }

    private let state = Mutex(State())
    private let saveError: Error?
    private let deleteError: Error?

    init(saveError: Error? = nil, deleteError: Error? = nil) {
        self.saveError = saveError
        self.deleteError = deleteError
    }

    var savedTokens: [String] { state.withLock { $0.tokens } }
    var deleteCount: Int { state.withLock { $0.deleteCount } }

    func save(_ token: String) throws {
        if let saveError { throw saveError }
        state.withLock { $0.tokens.append(token) }
    }

    func retrieve() -> String? {
        state.withLock { $0.tokens.last }
    }

    func delete() throws {
        state.withLock { $0.deleteCount += 1 }
        if let deleteError { throw deleteError }
        state.withLock { $0.tokens.removeAll() }
    }
}
