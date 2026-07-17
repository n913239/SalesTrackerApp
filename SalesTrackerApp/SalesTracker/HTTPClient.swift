//
//  HTTPClient.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

/// Declared here, not on the decorator that raises it, so RemoteLoader can rethrow it by type
/// rather than flatten it into .connectivity.
public enum HTTPClientError: Error, Equatable {
    case unauthorized
}

public protocol HTTPClient {
    func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse)
    func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse)
}
