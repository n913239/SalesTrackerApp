//
//  URLSessionHTTPClientTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
//

import XCTest
import Synchronization
import SalesTracker

@MainActor
final class URLSessionHTTPClientTests: XCTestCase {

    override func tearDown() {
        URLProtocolStub.removeStub()
        super.tearDown()
    }

    func test_getFromURL_failsOnRequestError() async {
        URLProtocolStub.stub(data: nil, response: nil, error: anyNSError())
        let sut = makeSUT()

        do {
            _ = try await sut.get(from: anyURL(), headers: [:])
            XCTFail("Expected to throw")
        } catch {}
    }

    func test_getFromURL_failsOnAllInvalidRepresentationCases() async {
        let invalidCases: [(Data?, URLResponse?, Error?)] = [
            // A protocol that delivers neither a response nor an error is not a representable
            // case here: `data(for:)` returns `(Data, URLResponse)` or throws, so the only way
            // to produce one would be a stub that breaks the URL Loading System's own contract.
            (nil, nonHTTPURLResponse(), nil),
            (anyData(), nonHTTPURLResponse(), nil),
            (anyData(), nil, anyNSError()),
            (nil, nonHTTPURLResponse(), anyNSError()),
            (nil, anyHTTPURLResponse(), anyNSError()),
            (anyData(), nonHTTPURLResponse(), anyNSError()),
            (anyData(), anyHTTPURLResponse(), anyNSError())
        ]

        for (data, response, error) in invalidCases {
            URLProtocolStub.stub(data: data, response: response, error: error)

            do {
                _ = try await makeSUT().get(from: anyURL(), headers: [:])
                XCTFail("Expected to throw for data: \(String(describing: data)), response: \(String(describing: response)), error: \(String(describing: error))")
            } catch {}
        }
    }

    func test_getFromURL_succeedsOnHTTPURLResponseWithData() async throws {
        let expectedData = anyData()
        URLProtocolStub.stub(data: expectedData, response: anyHTTPURLResponse(), error: nil)

        let (data, response) = try await makeSUT().get(from: anyURL(), headers: [:])

        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_getFromURL_succeedsWithEmptyDataOnHTTPURLResponseWithNilData() async throws {
        URLProtocolStub.stub(data: nil, response: anyHTTPURLResponse(), error: nil)

        let (data, response) = try await makeSUT().get(from: anyURL(), headers: [:])

        XCTAssertEqual(data, Data())
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_getFromURL_sendsTheGivenHeaders() async throws {
        let observed = Mutex<URLRequest?>(nil)
        URLProtocolStub.stub(data: anyData(), response: anyHTTPURLResponse(), error: nil) { request in
            observed.withLock { $0 = request }
        }

        _ = try await makeSUT().get(from: anyURL(), headers: ["Authorization": "Bearer a-token"])

        let request = observed.withLock { $0 }
        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer a-token")
    }

    func test_cancelGetFromURLTask_cancelsURLRequest() async {
        URLProtocolStub.stubHangingRequest()
        let sut = makeSUT()

        let task = Task { try await sut.get(from: anyURL(), headers: [:]) }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .cancelled)
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let sut = URLSessionHTTPClient(session: URLSession(configuration: configuration))
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func anyURL() -> URL { URL(string: "https://any-url.com")! }
    private func anyData() -> Data { Data("any data".utf8) }
    private func anyNSError() -> NSError { NSError(domain: "any error", code: 0) }

    private func anyHTTPURLResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private func nonHTTPURLResponse() -> URLResponse {
        URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
}

private final class URLProtocolStub: URLProtocol {
    private struct Stub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
        let hangs: Bool
        let onStartLoading: (@Sendable (URLRequest) -> Void)?
    }

    private static let stubbed = Mutex<Stub?>(nil)

    static func stub(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        onStartLoading: (@Sendable (URLRequest) -> Void)? = nil
    ) {
        stubbed.withLock { $0 = Stub(data: data, response: response, error: error, hangs: false, onStartLoading: onStartLoading) }
    }

    static func stubHangingRequest() {
        stubbed.withLock { $0 = Stub(data: nil, response: nil, error: nil, hangs: true, onStartLoading: nil) }
    }

    static func removeStub() {
        stubbed.withLock { $0 = nil }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = URLProtocolStub.stubbed.withLock({ $0 }) else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        stub.onStartLoading?(request)

        guard !stub.hangs else { return }

        // The URL Loading System requires a response before any data; sending them the other way
        // round traps inside URLSession rather than surfacing as an error.
        if let response = stub.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
