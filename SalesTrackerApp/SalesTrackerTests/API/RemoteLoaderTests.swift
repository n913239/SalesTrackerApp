//
//  RemoteLoaderTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
//

import XCTest
import SalesTracker

@MainActor
final class RemoteLoaderTests: XCTestCase {

    func test_load_requestsTheGivenURL() async throws {
        let url = URL(string: "https://a-given-url.com")!
        let client = HTTPClientSpy()
        let sut = makeSUT(url: url, client: client) { _, _ in "any" }

        _ = try await sut.load()

        let requestedURLs = await client.requestedURLs
        XCTAssertEqual(requestedURLs, [url])
    }

    func test_load_deliversWhatTheMapperReturns() async throws {
        let client = HTTPClientSpy()
        let sut = makeSUT(client: client) { _, _ in "mapped resource" }

        let resource = try await sut.load()

        XCTAssertEqual(resource, "mapped resource")
    }

    func test_load_onClientFailure_throwsConnectivity() async {
        let client = HTTPClientSpy()
        await client.completeWith(error: anyNSError())
        let sut = makeSUT(client: client) { _, _ in "any" }

        do {
            _ = try await sut.load()
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? RemoteLoader<String>.Error, .connectivity)
        }
    }

    func test_load_onUnauthorized_rethrowsItInsteadOfMaskingItAsConnectivity() async {
        let client = HTTPClientSpy()
        await client.completeWith(error: HTTPClientError.unauthorized)
        let sut = makeSUT(client: client) { _, _ in "any" }

        do {
            _ = try await sut.load()
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .unauthorized)
        }
    }

    func test_load_onMapperFailure_throwsInvalidData() async {
        let client = HTTPClientSpy()
        let sut = makeSUT(client: client) { _, _ in throw anyNSError() }

        do {
            _ = try await sut.load()
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? RemoteLoader<String>.Error, .invalidData)
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        url: URL = URL(string: "https://any-url.com")!,
        client: HTTPClientSpy,
        mapper: @escaping RemoteLoader<String>.Mapper,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> RemoteLoader<String> {
        let sut = RemoteLoader(url: url, client: client, mapper: mapper)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}

private func anyNSError() -> NSError { NSError(domain: "any error", code: 0) }

actor HTTPClientSpy: HTTPClient {
    private(set) var requestedURLs: [URL] = []
    private(set) var sentHeaders: [[String: String]] = []
    private var error: Error?

    func completeWith(error: Error) {
        self.error = error
    }

    func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        requestedURLs.append(url)
        sentHeaders.append(headers)
        if let error { throw error }
        return (Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        requestedURLs.append(url)
        sentHeaders.append(headers)
        if let error { throw error }
        return (Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
