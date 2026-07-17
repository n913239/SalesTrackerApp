//
//  ProductCatalogueTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class ProductCatalogueTests: XCTestCase {

    func test_summaries_countsTheSalesOfEachProduct() {
        let mac = makeProduct(name: "Mac mini")
        let ipad = makeProduct(name: "iPad Pro")
        let sut = ProductCatalogue(
            products: [mac, ipad],
            sales: [sale(of: mac), sale(of: mac), sale(of: ipad)]
        )

        XCTAssertEqual(sut.summaries(), [
            ProductSummary(product: ipad, salesCount: 1),
            ProductSummary(product: mac, salesCount: 2)
        ])
    }

    func test_summaries_includesAProductWithNoSales() {
        let airtag = makeProduct(name: "AirTag")
        let sut = ProductCatalogue(products: [airtag], sales: [])

        XCTAssertEqual(sut.summaries(), [ProductSummary(product: airtag, salesCount: 0)])
    }

    func test_summaries_ordersByNameAsAPersonReadsIt() {
        let names = ["iPhone", "Apple TV 4K", "iMac", "AirTag", "Vision Pro"]
        let products = names.map { makeProduct(name: $0) }
        let sut = ProductCatalogue(products: products, sales: [])

        XCTAssertEqual(
            sut.summaries().map(\.product.name),
            ["AirTag", "Apple TV 4K", "iMac", "iPhone", "Vision Pro"],
            "Sorting by Unicode scalar would put every lowercase name after every uppercase one"
        )
    }

    func test_summaries_deliversOneRowPerUniqueProduct() {
        let mac = makeProduct(name: "Mac mini")
        let sut = ProductCatalogue(products: [mac, mac], sales: [sale(of: mac)])

        XCTAssertEqual(sut.summaries(), [ProductSummary(product: mac, salesCount: 1)])
    }

    func test_salesOfProduct_deliversOnlyThatProductsSalesMostRecentFirst() {
        let mac = makeProduct(name: "Mac mini")
        let ipad = makeProduct(name: "iPad Pro")

        let older = sale(of: mac, date: date("2024-01-01T10:00:00Z"))
        let newer = sale(of: mac, date: date("2024-06-01T10:00:00Z"))
        let other = sale(of: ipad, date: date("2024-03-01T10:00:00Z"))

        let sut = ProductCatalogue(products: [mac, ipad], sales: [older, other, newer])

        XCTAssertEqual(sut.sales(of: mac), [newer, older])
    }

    func test_salesOfProduct_withoutSales_deliversEmpty() {
        let airtag = makeProduct(name: "AirTag")
        let sut = ProductCatalogue(products: [airtag], sales: [])

        XCTAssertEqual(sut.sales(of: airtag), [])
    }

    // MARK: - Helpers

    private func makeProduct(name: String) -> Product {
        Product(id: UUID(), name: name)
    }

    private func sale(
        of product: Product,
        amount: String = "100.00",
        currency: String = "USD",
        date: Date = Date()
    ) -> Sale {
        Sale(
            currencyCode: currency,
            amount: Decimal(string: amount)!,
            productId: product.id,
            date: date
        )
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }
}
