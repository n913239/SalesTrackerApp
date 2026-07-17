//
//  RemoteLoader.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public final class RemoteLoader<Resource> {
    public typealias Mapper = (Data, HTTPURLResponse) throws -> Resource

    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
    }

    private let url: URL
    private let client: HTTPClient
    private let mapper: Mapper

    public init(url: URL, client: HTTPClient, mapper: @escaping Mapper) {
        self.url = url
        self.client = client
        self.mapper = mapper
    }

    public func load() async throws -> Resource {
        let data: Data
        let response: HTTPURLResponse

        do {
            (data, response) = try await client.get(from: url, headers: [:])
        } catch let error as HTTPClientError {
            // Rethrown by type so an expired token reaches the caller instead of becoming .connectivity.
            throw error
        } catch {
            throw Error.connectivity
        }

        do {
            return try mapper(data, response)
        } catch {
            throw Error.invalidData
        }
    }
}
