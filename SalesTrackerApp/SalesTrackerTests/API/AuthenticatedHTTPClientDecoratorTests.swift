//
//  AuthenticatedHTTPClientDecoratorTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import Synchronization
import SalesTracker

final class AuthenticatedHTTPClientDecoratorTests: XCTestCase {

    func test_get_attachesTheStoredTokenAsTheAuthorizationHeader() async throws {
        let decoratee = HTTPClientSpy()
        let (sut, _) = makeSUT(decoratee: decoratee, storedToken: "a-token")

        _ = try await sut.get(from: anyURL(), headers: ["Accept": "application/json"])

        let headers = await decoratee.sentHeaders
        XCTAssertEqual(headers, [["Accept": "application/json", "Authorization": "a-token"]])
    }

    func test_post_attachesTheStoredTokenAsTheAuthorizationHeader() async throws {
        let decoratee = HTTPClientSpy()
        let (sut, _) = makeSUT(decoratee: decoratee, storedToken: "a-token")

        _ = try await sut.post(to: anyURL(), body: Data(), headers: [:])

        let headers = await decoratee.sentHeaders
        XCTAssertEqual(headers, [["Authorization": "a-token"]])
    }

    func test_get_withoutAStoredToken_sendsNoAuthorizationHeader() async throws {
        let decoratee = HTTPClientSpy()
        let (sut, _) = makeSUT(decoratee: decoratee, storedToken: nil)

        _ = try await sut.get(from: anyURL(), headers: [:])

        let headers = await decoratee.sentHeaders
        XCTAssertEqual(headers, [[:]])
    }

    func test_get_on401_reportsUnauthorizedAndThrows() async {
        let decoratee = HTTPClientSpy()
        await decoratee.completeWith(statusCode: 401)
        let (sut, unauthorized) = makeSUT(decoratee: decoratee, storedToken: "a-token")

        do {
            _ = try await sut.get(from: anyURL(), headers: [:])
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .unauthorized)
            XCTAssertEqual(unauthorized.count, 1)
        }
    }

    func test_post_on401_reportsUnauthorizedAndThrows() async {
        let decoratee = HTTPClientSpy()
        await decoratee.completeWith(statusCode: 401)
        let (sut, unauthorized) = makeSUT(decoratee: decoratee, storedToken: "a-token")

        do {
            _ = try await sut.post(to: anyURL(), body: Data(), headers: [:])
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .unauthorized)
            XCTAssertEqual(unauthorized.count, 1)
        }
    }

    func test_get_onSuccess_doesNotReportUnauthorized() async throws {
        let decoratee = HTTPClientSpy()
        let (sut, unauthorized) = makeSUT(decoratee: decoratee, storedToken: "a-token")

        _ = try await sut.get(from: anyURL(), headers: [:])

        XCTAssertEqual(unauthorized.count, 0)
    }

    // MARK: - Helpers

    private func makeSUT(
        decoratee: HTTPClientSpy,
        storedToken: String?
    ) -> (AuthenticatedHTTPClientDecorator, UnauthorizedSpy) {
        let tokenStore = TokenStoreSpy()
        if let storedToken { try? tokenStore.save(storedToken) }

        let unauthorized = UnauthorizedSpy()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: decoratee,
            tokenStore: tokenStore,
            onUnauthorized: { unauthorized.record() }
        )
        return (sut, unauthorized)
    }

    private func anyURL() -> URL { URL(string: "https://any-url.com")! }
}

/// `Mutex` is non-copyable, so the counter travels as a reference rather than inside a tuple.
private final class UnauthorizedSpy: Sendable {
    private let calls = Mutex(0)

    var count: Int { calls.withLock { $0 } }

    func record() { calls.withLock { $0 += 1 } }
}

private actor HTTPClientSpy: HTTPClient {
    private(set) var sentHeaders: [[String: String]] = []
    private var statusCode = 200

    func completeWith(statusCode: Int) {
        self.statusCode = statusCode
    }

    func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        sentHeaders.append(headers)
        return (Data(), HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }

    func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        sentHeaders.append(headers)
        return (Data(), HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }
}
