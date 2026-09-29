//
//  UILayerTestCase.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import Foundation
import SalesTracker

func makeProduct(named name: String = "iPhone") -> Product {
    Product(id: UUID(), name: name)
}

func makeSale(
    of product: Product = makeProduct(),
    amount: String = "100.00",
    currency: String = "EUR",
    at timestamp: TimeInterval = 1_893_582_000
) -> Sale {
    Sale(
        currencyCode: currency,
        amount: Decimal(string: amount)!,
        productId: product.id,
        date: Date(timeIntervalSince1970: timestamp)
    )
}

func anyNSError() -> NSError {
    NSError(domain: "any error", code: 0)
}
