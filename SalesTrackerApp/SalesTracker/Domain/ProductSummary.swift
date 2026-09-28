//
//  ProductSummary.swift
//  SalesTracker
//
//  Created by mike on 2026/9/28.
//

import Foundation

public struct ProductSummary: Equatable, Sendable {
    public let product: Product
    public let salesCount: Int

    public init(product: Product, salesCount: Int) {
        self.product = product
        self.salesCount = salesCount
    }
}
