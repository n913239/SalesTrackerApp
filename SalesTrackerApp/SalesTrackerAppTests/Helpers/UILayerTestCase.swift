//
//  UILayerTestCase.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/30.
//

import XCTest
import Synchronization
import SalesTracker

// MARK: - Test data

func makeProduct(named name: String = "iPhone") -> Product {
    Product(id: UUID(), name: name)
}

func makeSale(
    of product: Product = makeProduct(),
    amount: String = "100.00",
    currency: String = "EUR",
    at timestamp: TimeInterval = 1_893_582_000
) -> Sale {
    Sale(
        currencyCode: currency,
        amount: Decimal(string: amount)!,
        productId: product.id,
        date: Date(timeIntervalSince1970: timestamp)
    )
}

func anyNSError() -> NSError {
    NSError(domain: "any error", code: 0)
}

// MARK: - Waiting on observable state

extension XCTestCase {
    /// Waits for something the test can see, never for a duration. `async let` changes when things
    /// happen without changing what happens, so sleeping would only make the test slower and
    /// flakier - and a timeout that fails loudly beats one that hangs the suite.
    @MainActor
    func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() { return }
            await Task.yield()
        }

        XCTFail("Timed out waiting until \(description)", file: file, line: line)
    }

    /// Lets everything already scheduled run to completion, for the cases where the assertion is
    /// that nothing further happened.
    @MainActor
    func drainPendingWork(turns: Int = 20) async {
        for _ in 0..<turns { await Task.yield() }
    }
}

// MARK: - Doubles

/// `Mutex` is non-copyable, so counters that a non-isolated cancellation handler has to reach
/// travel as a reference.
final class CancellationSpy: Sendable {
    private let calls = Mutex(0)

    var count: Int { calls.withLock { $0 } }

    func record() { calls.withLock { $0 += 1 } }
}

/// Routes by URL so one stub can stand in for the whole backend, and can hold any request in
/// flight so a test can assert what the screen looks like while it is still waiting.
actor HTTPClientStub: HTTPClient {
    struct Response {
        let data: Data
        let statusCode: Int
    }

    nonisolated let cancellations = CancellationSpy()

    private var responses: [URL: Result<Response, Error>] = [:]
    private var hangingURLs: Set<URL> = []
    private var requestedURLs: [URL] = []
    private var sentHeaders: [URL: [String: String]] = [:]

    private var pending: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var cancelledBeforeStored: Set<UUID> = []

    // MARK: Stubbing

    func stub(_ url: URL, with data: Data, statusCode: Int = 200) {
        responses[url] = .success(Response(data: data, statusCode: statusCode))
    }

    func stub(_ url: URL, withError error: Error) {
        responses[url] = .failure(error)
    }

    func hang(_ url: URL) {
        hangingURLs.insert(url)
    }

    func release(_ url: URL) {
        hangingURLs.remove(url)
        let waiting = pending
        pending.removeAll()
        waiting.values.forEach { $0.resume() }
    }

    func cancelPendingRequests() {
        let waiting = pending
        pending.removeAll()
        waiting.values.forEach { $0.resume(throwing: CancellationError()) }
    }

    // MARK: Recording

    /// Whether a request is actually being held right now. Tests wait on this instead of assuming
    /// the request has reached the stub - a wait that is always true is not a wait.
    var isHoldingARequest: Bool { !pending.isEmpty }

    func requests(to url: URL) -> Int {
        requestedURLs.filter { $0 == url }.count
    }

    func headers(for url: URL) -> [String: String]? {
        sentHeaders[url]
    }

    // MARK: HTTPClient

    func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        try await perform(url, headers: headers)
    }

    func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        try await perform(url, headers: headers)
    }

    // MARK: Helpers

    private func perform(_ url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        requestedURLs.append(url)
        sentHeaders[url] = headers

        if hangingURLs.contains(url) {
            try await hold()
        }

        guard let result = responses[url] else {
            throw NSError(domain: "no stub for \(url)", code: 0)
        }

        let response = try result.get()

        // A transport reports what came back, including a 401. Turning that into
        // `HTTPClientError.unauthorized` is the decorator's job, and a stub that did it here
        // would hide whether the decorator is wired in at all.
        return (
            response.data,
            HTTPURLResponse(url: url, statusCode: response.statusCode, httpVersion: nil, headerFields: nil)!
        )
    }

    private func hold() async throws {
        let id = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                store(id, continuation)
            }
        } onCancel: {
            cancellations.record()
            Task { await self.cancel(id) }
        }
    }

    private func store(_ id: UUID, _ continuation: CheckedContinuation<Void, Error>) {
        if cancelledBeforeStored.remove(id) != nil {
            continuation.resume(throwing: CancellationError())
        } else {
            pending[id] = continuation
        }
    }

    private func cancel(_ id: UUID) {
        if let continuation = pending.removeValue(forKey: id) {
            continuation.resume(throwing: CancellationError())
        } else {
            cancelledBeforeStored.insert(id)
        }
    }
}

final class TokenStoreSpy: TokenStore {
    private struct State {
        var token: String?
        var deleteCount = 0
    }

    private let state: Mutex<State>
    private let saveError: Error?
    private let deleteError: Error?

    init(token: String? = nil, saveError: Error? = nil, deleteError: Error? = nil) {
        self.state = Mutex(State(token: token))
        self.saveError = saveError
        self.deleteError = deleteError
    }

    var savedToken: String? { state.withLock { $0.token } }
    var deleteCount: Int { state.withLock { $0.deleteCount } }

    func save(_ token: String) throws {
        if let saveError { throw saveError }
        state.withLock { $0.token = token }
    }

    func retrieve() -> String? {
        state.withLock { $0.token }
    }

    func delete() throws {
        state.withLock { $0.deleteCount += 1 }
        if let deleteError { throw deleteError }
        state.withLock { $0.token = nil }
    }
}

@MainActor
final class LoginViewSpy: ResourceLoadingView, ResourceErrorView {
    enum Message: Equatable {
        case loading(Bool)
        case errorMessage(String?)
    }

    private(set) var messages: [Message] = []

    func display(_ viewModel: ResourceLoadingViewModel) { messages.append(.loading(viewModel.isLoading)) }
    func display(_ viewModel: ResourceErrorViewModel) { messages.append(.errorMessage(viewModel.message)) }
}

func tokenJSON(_ token: String) -> Data {
    try! JSONSerialization.data(withJSONObject: ["access_token": token])
}
