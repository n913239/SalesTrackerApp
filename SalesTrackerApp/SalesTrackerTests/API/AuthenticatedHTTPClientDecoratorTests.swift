//
//  AuthenticatedHTTPClientDecoratorTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class AuthenticatedHTTPClientDecoratorTests: XCTestCase {

    func test_get_attachesTheStoredTokenAsTheAuthorizationHeader() async throws {
        let (sut, client, _) = makeSUT(token: "a-token")

        _ = try await sut.get(from: anyURL(), headers: [:])

        XCTAssertEqual(client.requestedHeaders, [["Authorization": "a-token"]])
    }

    func test_post_attachesTheStoredTokenAsTheAuthorizationHeader() async throws {
        let (sut, client, _) = makeSUT(token: "a-token")

        _ = try await sut.post(to: anyURL(), body: Data(), headers: ["Content-Type": "application/json"])

        XCTAssertEqual(client.requestedHeaders, [[
            "Content-Type": "application/json",
            "Authorization": "a-token"
        ]])
    }

    func test_get_withoutAStoredToken_sendsNoAuthorizationHeader() async throws {
        let (sut, client, _) = makeSUT(token: nil)

        _ = try await sut.get(from: anyURL(), headers: [:])

        XCTAssertEqual(client.requestedHeaders, [[:]])
    }

    func test_get_on401_reportsUnauthorizedAndThrows() async {
        let (sut, client, unauthorizedCount) = makeSUT(token: "expired-token")
        client.stub(statusCode: 401)

        do {
            _ = try await sut.get(from: anyURL(), headers: [:])
            XCTFail("Expected unauthorized")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .unauthorized)
        }

        XCTAssertEqual(unauthorizedCount.value, 1)
    }

    func test_post_on401_reportsUnauthorizedAndThrows() async {
        let (sut, client, unauthorizedCount) = makeSUT(token: "expired-token")
        client.stub(statusCode: 401)

        do {
            _ = try await sut.post(to: anyURL(), body: Data(), headers: [:])
            XCTFail("Expected unauthorized")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .unauthorized)
        }

        XCTAssertEqual(unauthorizedCount.value, 1)
    }

    func test_get_onSuccess_doesNotReportUnauthorized() async throws {
        let (sut, client, unauthorizedCount) = makeSUT(token: "a-token")
        client.stub(statusCode: 200)

        _ = try await sut.get(from: anyURL(), headers: [:])

        XCTAssertEqual(unauthorizedCount.value, 0)
    }

    // MARK: - Helpers

    private func makeSUT(
        token: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (AuthenticatedHTTPClientDecorator, HTTPClientSpy, Counter) {
        let client = HTTPClientSpy()
        let store = TokenStoreStub(token: token)
        let counter = Counter()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenStore: store,
            onUnauthorized: { counter.increment() }
        )
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client, counter)
    }

    private func anyURL() -> URL {
        URL(string: "https://any-url.com")!
    }

    private final class HTTPClientSpy: HTTPClient, @unchecked Sendable {
        private let queue = DispatchQueue(label: "HTTPClientSpy")
        private var _requestedHeaders = [[String: String]]()
        private var _statusCode = 200

        var requestedHeaders: [[String: String]] {
            queue.sync { _requestedHeaders }
        }

        func stub(statusCode: Int) {
            queue.sync { _statusCode = statusCode }
        }

        func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
            respond(to: url, headers: headers)
        }

        func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
            respond(to: url, headers: headers)
        }

        private func respond(to url: URL, headers: [String: String]) -> (Data, HTTPURLResponse) {
            let statusCode: Int = queue.sync {
                _requestedHeaders.append(headers)
                return _statusCode
            }
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
    }

    private struct TokenStoreStub: TokenStore {
        let token: String?

        func save(_ token: String) throws {}
        func retrieve() -> String? { token }
        func delete() throws {}
    }

    private final class Counter: @unchecked Sendable {
        private let queue = DispatchQueue(label: "Counter")
        private var _value = 0

        var value: Int { queue.sync { _value } }
        func increment() { queue.sync { _value += 1 } }
    }
}
