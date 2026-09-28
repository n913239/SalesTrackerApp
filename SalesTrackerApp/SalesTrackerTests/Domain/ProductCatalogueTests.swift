//
//  ProductCatalogueTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
//

import XCTest
import SalesTracker

final class ProductCatalogueTests: XCTestCase {

    func test_summaries_countsTheSalesOfEachProduct() {
        let iPhone = product(named: "iPhone")
        let iPad = product(named: "iPad")
        let sut = ProductCatalogue(
            products: [iPhone, iPad],
            sales: [sale(of: iPhone), sale(of: iPhone), sale(of: iPad)]
        )

        XCTAssertEqual(sut.summaries(), [
            ProductSummary(product: iPad, salesCount: 1),
            ProductSummary(product: iPhone, salesCount: 2)
        ])
    }

    func test_summaries_includesAProductWithNoSales() {
        let unsold = product(named: "Apple Watch")
        let sut = ProductCatalogue(products: [unsold], sales: [])

        XCTAssertEqual(sut.summaries(), [ProductSummary(product: unsold, salesCount: 0)])
    }

    func test_summaries_ordersByNameAsAPersonReadsIt() {
        let names = ["iPhone 10", "iPhone 9", "Apple Watch"]
        let products = names.map { product(named: $0) }
        let sut = ProductCatalogue(products: products, sales: [])

        XCTAssertEqual(sut.summaries().map(\.product.name), ["Apple Watch", "iPhone 9", "iPhone 10"])
    }

    func test_summaries_deliversOneRowPerUniqueProduct() {
        let iPhone = product(named: "iPhone")
        let sut = ProductCatalogue(products: [iPhone, iPhone], sales: [])

        XCTAssertEqual(sut.summaries(), [ProductSummary(product: iPhone, salesCount: 0)])
    }

    func test_salesOfProduct_deliversOnlyThatProductsSalesMostRecentFirst() {
        let iPhone = product(named: "iPhone")
        let iPad = product(named: "iPad")
        let older = sale(of: iPhone, at: 100)
        let newer = sale(of: iPhone, at: 200)
        let other = sale(of: iPad, at: 300)
        let sut = ProductCatalogue(products: [iPhone, iPad], sales: [older, other, newer])

        XCTAssertEqual(sut.sales(of: iPhone), [newer, older])
    }

    func test_salesOfProduct_withoutSales_deliversEmpty() {
        let unsold = product(named: "Apple Watch")
        let sut = ProductCatalogue(products: [unsold], sales: [])

        XCTAssertEqual(sut.sales(of: unsold), [])
    }

    // MARK: - Helpers

    private func product(named name: String) -> Product {
        Product(id: UUID(), name: name)
    }

    private func sale(of product: Product, at timestamp: TimeInterval = 0) -> Sale {
        Sale(
            currencyCode: "USD",
            amount: Decimal(string: "10.00")!,
            productId: product.id,
            date: Date(timeIntervalSince1970: timestamp)
        )
    }
}
