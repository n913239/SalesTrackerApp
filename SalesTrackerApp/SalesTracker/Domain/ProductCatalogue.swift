//
//  ProductCatalogue.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

/// The list needs a name and a count, nothing more. Coupling it to the rates request - the
/// middleware cold-starts in about fourteen seconds - would keep the products off the screen.
public struct ProductCatalogue {
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
