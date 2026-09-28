//
//  ProductCatalogue.swift
//  SalesTracker
//
//  Created by mike on 2026/9/28.
//

import Foundation

/// The products and the sales the app has for one session, in the two shapes the screens ask
/// for: a row per product for the list, and the sales of one product for the detail.
public struct ProductCatalogue: Equatable, Sendable {
    private let products: [Product]
    private let sales: [Sale]

    public init(products: [Product], sales: [Sale]) {
        self.products = products
        self.sales = sales
    }

    /// Ordered by name the way a person reads names, not by Unicode scalar.
    public func summaries() -> [ProductSummary] {
        var salesCountByProduct = [UUID: Int]()
        for sale in sales {
            salesCountByProduct[sale.productId, default: 0] += 1
        }

        return uniqueProducts()
            .map { ProductSummary(product: $0, salesCount: salesCountByProduct[$0.id] ?? 0) }
            .sorted { $0.product.name.localizedStandardCompare($1.product.name) == .orderedAscending }
    }

    public func sales(of product: Product) -> [Sale] {
        sales
            .filter { $0.productId == product.id }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Helpers

    private func uniqueProducts() -> [Product] {
        var seen = Set<UUID>()
        return products.filter { seen.insert($0.id).inserted }
    }
}
