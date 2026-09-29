//
//  SalesFormatterTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

final class SalesFormatterTests: XCTestCase {

    func test_amount_usesTheSymbolOfTheSaleCurrency() {
        let sut = SalesFormatter()

        XCTAssertEqual(sut.amount(decimal("2299.00"), currency: "BRL"), "R$2,299.00")
        XCTAssertEqual(sut.amount(decimal("126944.29"), currency: "JPY"), "¥126,944.29")
        XCTAssertEqual(sut.amount(decimal("100.00"), currency: "EUR"), "€100.00")
    }

    func test_amount_keepsTheCents() {
        let sut = SalesFormatter()

        XCTAssertEqual(sut.amount(decimal("999.99"), currency: "USD"), "$999.99")
    }

    func test_usd_formatsAsDollars() {
        let sut = SalesFormatter()

        XCTAssertEqual(sut.usd(decimal("323.28")), "$323.28")
    }

    func test_date_showsTheMinutes() {
        let sut = SalesFormatter(timeZone: TimeZone(identifier: "UTC")!)

        XCTAssertEqual(sut.date(Date(timeIntervalSince1970: 1_721_490_327)), "Jul 20, 2024 at 3:45 PM")
    }

    func test_date_usesTheInjectedTimeZone() {
        let sut = SalesFormatter(timeZone: TimeZone(identifier: "Asia/Taipei")!)

        XCTAssertEqual(sut.date(Date(timeIntervalSince1970: 1_721_490_327)), "Jul 20, 2024 at 11:45 PM")
    }

    func test_init_defaultsToTheCurrentTimeZone() {
        let date = Date(timeIntervalSince1970: 1_721_490_327)

        XCTAssertEqual(SalesFormatter().date(date), SalesFormatter(timeZone: .current).date(date))
    }

    // MARK: - Helpers

    private func decimal(_ string: String) -> Decimal {
        Decimal(string: string)!
    }
}
