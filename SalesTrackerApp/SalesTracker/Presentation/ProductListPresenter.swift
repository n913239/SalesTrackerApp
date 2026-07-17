//
//  ProductListPresenter.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public struct ProductViewModel: Equatable {
    public let name: String
    public let salesCount: String

    public init(name: String, salesCount: String) {
        self.name = name
        self.salesCount = salesCount
    }
}

public struct ProductListPresenter {
    public init() {}

    public static var title: String {
        SalesTrackerStrings.localized("PRODUCTS_TITLE")
    }

    public func viewModels(for summaries: [ProductSummary]) -> [ProductViewModel] {
        summaries.map {
            ProductViewModel(
                name: $0.product.name,
                salesCount: SalesTrackerStrings.salesCount($0.salesCount)
            )
        }
    }
}
