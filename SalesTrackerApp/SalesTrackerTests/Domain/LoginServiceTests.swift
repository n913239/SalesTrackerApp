//
//  LoginServiceTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class LoginServiceTests: XCTestCase {

    func test_login_postsTheCredentialsToTheLoginURL() async throws {
        let url = URL(string: "https://any-url.com/login")!
        let (sut, client, _) = makeSUT(url: url)
        client.stub(statusCode: 200, data: tokenJSON("a-token"))

        try await sut.login(username: "tester", password: "password")

        XCTAssertEqual(client.postedURLs, [url])
        XCTAssertEqual(client.postedBodies.first.flatMap(decodeCredentials), ["tester", "password"])
    }

    func test_login_storesTheReceivedToken() async throws {
        let (sut, client, store) = makeSUT()
        client.stub(statusCode: 200, data: tokenJSON("a-token"))

        try await sut.login(username: "tester", password: "password")

        XCTAssertEqual(store.savedTokens, ["a-token"])
    }

    func test_login_on401_deliversTheServersOwnMessage() async {
        let (sut, client, store) = makeSUT()
        client.stub(statusCode: 401, data: messageJSON("Invalid credentials."))

        await expect(sut, toThrow: .invalidCredentials(message: "Invalid credentials."))

        XCTAssertEqual(store.savedTokens, [], "A rejected login must not store anything")
    }

    func test_login_onClientError_deliversConnectivityError() async {
        let (sut, client, _) = makeSUT()
        client.stubError()

        await expect(sut, toThrow: .connectivity)
    }

    func test_login_onInvalidResponseData_deliversConnectivityError() async {
        let (sut, client, _) = makeSUT()
        client.stub(statusCode: 200, data: Data("not json".utf8))

        await expect(sut, toThrow: .connectivity)
    }

    func test_login_whenTheTokenCannotBeStored_reportsThatRatherThanAConnectionFailure() async {
        let (sut, client, store) = makeSUT()
        client.stub(statusCode: 200, data: tokenJSON("a-token"))
        store.failOnSave = true

        await expect(sut, toThrow: .tokenNotStored)
    }

    // MARK: - Helpers

    private func makeSUT(
        url: URL = URL(string: "https://any-url.com/login")!,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (LoginService, HTTPClientSpy, TokenStoreSpy) {
        let client = HTTPClientSpy()
        let store = TokenStoreSpy()
        let sut = LoginService(client: client, tokenStore: store, url: url)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client, store)
    }

    private func expect(
        _ sut: LoginService,
        toThrow expected: LoginService.Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await sut.login(username: "tester", password: "password")
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? LoginService.Error, expected, file: file, line: line)
        }
    }

    private func tokenJSON(_ token: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["access_token": token])
    }

    private func messageJSON(_ message: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["message": message])
    }

    private func decodeCredentials(_ body: Data) -> [String]? {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
              let username = json["username"], let password = json["password"] else { return nil }
        return [username, password]
    }

    private final class HTTPClientSpy: HTTPClient, @unchecked Sendable {
        private let queue = DispatchQueue(label: "HTTPClientSpy")
        private var _postedURLs = [URL]()
        private var _postedBodies = [Data]()
        private var _statusCode = 200
        private var _data = Data()
        private var _shouldFail = false

        var postedURLs: [URL] { queue.sync { _postedURLs } }
        var postedBodies: [Data] { queue.sync { _postedBodies } }

        func stub(statusCode: Int, data: Data) {
            queue.sync {
                _statusCode = statusCode
                _data = data
                _shouldFail = false
            }
        }

        func stubError() {
            queue.sync { _shouldFail = true }
        }

        func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
            throw NSError(domain: "unused", code: 0)
        }

        func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
            let (statusCode, data, shouldFail): (Int, Data, Bool) = queue.sync {
                _postedURLs.append(url)
                _postedBodies.append(body)
                return (_statusCode, _data, _shouldFail)
            }

            if shouldFail { throw NSError(domain: "offline", code: 0) }

            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
    }

    private final class TokenStoreSpy: TokenStore, @unchecked Sendable {
        private let queue = DispatchQueue(label: "TokenStoreSpy")
        private var _savedTokens = [String]()

        var failOnSave = false
        var savedTokens: [String] { queue.sync { _savedTokens } }

        func save(_ token: String) throws {
            if failOnSave { throw TokenStoreError.saveFailed(-1) }
            queue.sync { _savedTokens.append(token) }
        }

        func retrieve() -> String? {
            queue.sync { _savedTokens.last }
        }

        func delete() throws {
            queue.sync { _savedTokens.removeAll() }
        }
    }
}
