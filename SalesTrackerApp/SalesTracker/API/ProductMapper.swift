//
//  ProductMapper.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public enum ProductMapper {
    private struct RemoteProduct: Decodable {
        let id: UUID
        let name: String
    }

    public enum Error: Swift.Error { case invalidData }

    public static func map(_ data: Data, from response: HTTPURLResponse) throws -> [Product] {
        guard response.statusCode == 200,
              let items = try? JSONDecoder().decode([RemoteProduct].self, from: data) else {
            throw Error.invalidData
        }
        return items.map { Product(id: $0.id, name: $0.name) }
    }
}
