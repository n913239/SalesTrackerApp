//
//  URLSessionHTTPClient.swift
//  SalesTracker
//
//  Created by mike on 2026/9/28.
//

import Foundation

public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    struct UnexpectedValuesRepresentation: Error {}

    public init(session: URLSession) {
        self.session = session
    }

    public func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return try await perform(request)
    }

    public func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnexpectedValuesRepresentation()
        }
        return (data, httpResponse)
    }
}
