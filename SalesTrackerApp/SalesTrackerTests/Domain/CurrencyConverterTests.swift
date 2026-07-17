//
//  CurrencyConverterTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class CurrencyConverterTests: XCTestCase {

    func test_amountInUSD_convertsUsingTheRateForThatCurrency() {
        let sut = CurrencyConverter(rates: [
            rate(from: "JPY", value: "0.0092512"),
            rate(from: "EUR", value: "1.18")
        ])

        XCTAssertEqual(sut.amountInUSD(decimal("1000"), currency: "JPY"), decimal("9.2512"))
        XCTAssertEqual(sut.amountInUSD(decimal("100"), currency: "EUR"), decimal("118"))
    }

    func test_amountInUSD_treatsUSDAsUnchanged() {
        let sut = CurrencyConverter(rates: [])

        XCTAssertEqual(sut.amountInUSD(decimal("1480.79"), currency: "USD"), decimal("1480.79"))
    }

    func test_amountInUSD_deliversNilWhenThereIsNoRateForThatCurrency() {
        let sut = CurrencyConverter(rates: [rate(from: "EUR", value: "1.18")])

        XCTAssertNil(
            sut.amountInUSD(decimal("126944.29"), currency: "JPY"),
            "Without a rate the amount is unknown - returning the yen figure as dollars would invent money"
        )
    }

    func test_amountInUSD_deliversNilWhenNoRatesLoaded() {
        let sut = CurrencyConverter(rates: [])

        XCTAssertNil(sut.amountInUSD(decimal("1480.79"), currency: "JPY"))
    }

    func test_amountInUSD_ignoresRatesThatDoNotConvertToUSD() {
        let sut = CurrencyConverter(rates: [
            CurrencyRate(from: "CAD", to: "JPY", rate: decimal("80")),
            CurrencyRate(from: "EUR", to: "USD", rate: decimal("1.18"))
        ])

        XCTAssertNil(
            sut.amountInUSD(decimal("100"), currency: "CAD"),
            "A CAD-to-JPY rate must never be used to produce a dollar amount"
        )
        XCTAssertEqual(sut.amountInUSD(decimal("100"), currency: "EUR"), decimal("118"))
    }

    func test_totalInUSD_sumsTheConvertibleAmountsAndReportsTheRest() {
        let sut = CurrencyConverter(rates: [
            rate(from: "EUR", value: "1.18"),
            rate(from: "GBP", value: "1.3216")
        ])

        let total = sut.totalInUSD([
            (amount: decimal("100"), currency: "EUR"),
            (amount: decimal("100"), currency: "GBP"),
            (amount: decimal("50"), currency: "USD"),
            (amount: decimal("1000"), currency: "JPY")
        ])

        XCTAssertEqual(total.amount, decimal("300.16"), "118 + 132.16 + 50")
        XCTAssertEqual(total.unconvertibleCount, 1, "The yen sale has no rate, so it is reported rather than guessed")
    }

    func test_totalInUSD_ofNothingIsZero() {
        let sut = CurrencyConverter(rates: [])

        let total = sut.totalInUSD([])

        XCTAssertEqual(total.amount, 0)
        XCTAssertEqual(total.unconvertibleCount, 0)
    }

    // MARK: - Helpers

    private func rate(from currency: String, value: String) -> CurrencyRate {
        CurrencyRate(from: currency, to: "USD", rate: decimal(value))
    }

    /// Built from decimal text, not a literal, which would lose exactness through Double.
    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value)!
    }
}
