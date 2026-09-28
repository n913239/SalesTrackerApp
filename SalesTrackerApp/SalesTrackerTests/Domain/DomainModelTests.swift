//
//  DomainModelTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
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
        let amount = Decimal(string: "999.99")!

        let sale = Sale(currencyCode: "EUR", amount: amount, productId: id, date: date)

        XCTAssertEqual(sale.currencyCode, "EUR")
        XCTAssertEqual(sale.amount, amount)
        XCTAssertEqual(sale.productId, id)
        XCTAssertEqual(sale.date, date)
    }

    func test_currencyRate_holdsProperties() {
        let rate = Decimal(string: "1.18")!

        let currencyRate = CurrencyRate(from: "EUR", to: "USD", rate: rate)

        XCTAssertEqual(currencyRate.from, "EUR")
        XCTAssertEqual(currencyRate.to, "USD")
        XCTAssertEqual(currencyRate.rate, rate)
    }
}
