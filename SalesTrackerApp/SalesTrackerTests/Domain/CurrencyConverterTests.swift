//
//  CurrencyConverterTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
//

import XCTest
import SalesTracker

final class CurrencyConverterTests: XCTestCase {

    func test_amountInUSD_convertsUsingTheRateForThatCurrency() {
        let sut = CurrencyConverter(rates: [rate(from: "EUR", "1.18"), rate(from: "BRL", "0.18")])

        XCTAssertEqual(sut.amountInUSD(decimal("100.00"), currency: "EUR"), decimal("118.00"))
        XCTAssertEqual(sut.amountInUSD(decimal("2299.00"), currency: "BRL"), decimal("413.82"))
    }

    func test_amountInUSD_treatsUSDAsUnchanged() {
        let sut = CurrencyConverter(rates: [])

        XCTAssertEqual(sut.amountInUSD(decimal("42.50"), currency: "USD"), decimal("42.50"))
    }

    func test_amountInUSD_deliversNilWhenThereIsNoRateForThatCurrency() {
        let sut = CurrencyConverter(rates: [rate(from: "EUR", "1.18")])

        XCTAssertNil(sut.amountInUSD(decimal("126944.29"), currency: "JPY"))
    }

    func test_amountInUSD_deliversNilWhenNoRatesLoaded() {
        let sut = CurrencyConverter(rates: [])

        XCTAssertNil(sut.amountInUSD(decimal("100.00"), currency: "EUR"))
    }

    func test_amountInUSD_ignoresRatesThatDoNotConvertToUSD() {
        let sut = CurrencyConverter(rates: [CurrencyRate(from: "EUR", to: "GBP", rate: decimal("0.85"))])

        XCTAssertNil(sut.amountInUSD(decimal("100.00"), currency: "EUR"))
    }

    func test_totalInUSD_sumsTheConvertibleAmountsAndReportsTheRest() {
        let sut = CurrencyConverter(rates: [rate(from: "EUR", "1.18")])

        let total = sut.totalInUSD([
            (decimal("100.00"), "EUR"),
            (decimal("50.00"), "USD"),
            (decimal("126944.29"), "JPY")
        ])

        XCTAssertEqual(total, CurrencyConverter.Total(amount: decimal("168.00"), unconvertibleCount: 1))
    }

    func test_totalInUSD_ofNothingIsZero() {
        let sut = CurrencyConverter(rates: [])

        XCTAssertEqual(sut.totalInUSD([]), CurrencyConverter.Total(amount: 0, unconvertibleCount: 0))
    }

    // MARK: - Helpers

    private func decimal(_ string: String) -> Decimal {
        Decimal(string: string)!
    }

    private func rate(from currency: String, _ value: String) -> CurrencyRate {
        CurrencyRate(from: currency, to: "USD", rate: decimal(value))
    }
}
