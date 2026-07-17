//
//  ProductSummary.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public struct ProductSummary: Equatable {
    public let product: Product
    public let salesCount: Int

    public init(product: Product, salesCount: Int) {
        self.product = product
        self.salesCount = salesCount
    }
}
