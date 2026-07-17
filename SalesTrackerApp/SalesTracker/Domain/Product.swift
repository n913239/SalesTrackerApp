//
//  Product.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public struct Product: Equatable {
    public let id: UUID
    public let name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
