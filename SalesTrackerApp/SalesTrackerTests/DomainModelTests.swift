//
//  DomainModelTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class DomainModelTests: XCTestCase {

    func test_product_holdsProperties() {
        let id = UUID()
        let product = Product(id: id, name: "iPhone")

        XCTAssertEqual(product.id, id)
        XCTAssertEqual(product.name, "iPhone")
    }

    func test_sale_holdsProperties() {
        let id = UUID()
        let date = Date()
        let sale = Sale(currencyCode: "EUR", amount: 999.99, productId: id, date: date)

        XCTAssertEqual(sale.currencyCode, "EUR")
        XCTAssertEqual(sale.amount, 999.99)
        XCTAssertEqual(sale.productId, id)
        XCTAssertEqual(sale.date, date)
    }

    func test_currencyRate_holdsProperties() {
        let rate = CurrencyRate(from: "EUR", to: "USD", rate: 1.18)

        XCTAssertEqual(rate.from, "EUR")
        XCTAssertEqual(rate.to, "USD")
        XCTAssertEqual(rate.rate, 1.18)
    }
}
