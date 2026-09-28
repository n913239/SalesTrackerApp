//
//  Product.swift
//  SalesTracker
//
//  Created by mike on 2026/9/28.
//

import Foundation

public struct Product: Equatable, Sendable {
    public let id: UUID
    public let name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
