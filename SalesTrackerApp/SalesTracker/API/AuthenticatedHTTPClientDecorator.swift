//
//  AuthenticatedHTTPClientDecorator.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

/// Attaches the access token to every request and reports a 401 once, centrally.
///
/// The token can expire at any time, so a 401 can surface on any screen and on any request.
/// Checking for it at a single call site would leave every other screen showing stale or empty data
/// with no explanation.
public final class AuthenticatedHTTPClientDecorator: HTTPClient {
    private let decoratee: HTTPClient
    private let tokenStore: TokenStore

    /// Isolated to the main actor so the caller can update UI state directly: the decorator hops
    /// with a structured await instead of every call site spawning its own Task to get there.
    private let onUnauthorized: @MainActor @Sendable () -> Void

    public init(
        decoratee: HTTPClient,
        tokenStore: TokenStore,
        onUnauthorized: @escaping @MainActor @Sendable () -> Void
    ) {
        self.decoratee = decoratee
        self.tokenStore = tokenStore
        self.onUnauthorized = onUnauthorized
    }

    public func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        try await authenticating {
            try await decoratee.get(from: url, headers: headers.merging(authorization()) { _, new in new })
        }
    }

    public func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        try await authenticating {
            try await decoratee.post(to: url, body: body, headers: headers.merging(authorization()) { _, new in new })
        }
    }

    // MARK: - Helpers

    private func authorization() -> [String: String] {
        guard let token = tokenStore.retrieve() else { return [:] }
        return ["Authorization": token]
    }

    private func authenticating(
        _ request: () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await request()

        guard response.statusCode != 401 else {
            await onUnauthorized()
            throw HTTPClientError.unauthorized
        }

        return (data, response)
    }
}
