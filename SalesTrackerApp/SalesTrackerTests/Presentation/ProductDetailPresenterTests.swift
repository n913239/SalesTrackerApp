//
//  ProductDetailPresenterTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class ProductDetailPresenterTests: XCTestCase {

    func test_viewModel_showsTheProductNameTheTotalAndTheSalesCount() {
        let sut = ProductDetailPresenter()
        let product = Product(id: UUID(), name: "Vision Pro")

        let viewModel = sut.viewModel(
            for: product,
            sales: [sale(amount: "100.00", currency: "EUR"), sale(amount: "50.00", currency: "USD")],
            converter: CurrencyConverter(rates: [rate("EUR", "1.18")])
        )

        XCTAssertEqual(viewModel.title, "Vision Pro")
        XCTAssertEqual(viewModel.subtitle, "($168.00 from 2 sales)")
    }

    func test_viewModel_saysOneSaleRatherThanOneSales() {
        let sut = ProductDetailPresenter()

        let viewModel = sut.viewModel(
            for: Product(id: UUID(), name: "AirTag"),
            sales: [sale(amount: "100.00", currency: "USD")],
            converter: CurrencyConverter(rates: [])
        )

        XCTAssertEqual(viewModel.subtitle, "($100.00 from 1 sale)")
    }

    func test_viewModel_keepsTheCentsOfEveryAmount() {
        let sut = ProductDetailPresenter()

        let viewModel = sut.viewModel(
            for: Product(id: UUID(), name: "iMac"),
            sales: [sale(amount: "999.99", currency: "USD")],
            converter: CurrencyConverter(rates: [])
        )

        XCTAssertEqual(viewModel.sales.first?.amount, "$999.99", "Rounding to whole dollars quietly changes the number")
        XCTAssertEqual(viewModel.sales.first?.amountInUSD, "$999.99")
        XCTAssertEqual(viewModel.subtitle, "($999.99 from 1 sale)")
    }

    func test_viewModel_showsEachSaleInItsOwnCurrencyAndInUSD() {
        let sut = ProductDetailPresenter()

        let viewModel = sut.viewModel(
            for: Product(id: UUID(), name: "iPhone"),
            sales: [sale(amount: "2299.00", currency: "BRL", date: date("2030-01-02T11:00:00Z"))],
            converter: CurrencyConverter(rates: [rate("BRL", "0.14061824")])
        )

        XCTAssertEqual(viewModel.sales.first?.amount, "R$2,299.00")
        XCTAssertEqual(viewModel.sales.first?.amountInUSD, "$323.28")
        XCTAssertEqual(viewModel.sales.first?.date, "Jan 2, 2030 at 11 AM")
    }

    func test_viewModel_withoutARate_reportsTheAmountAsUnknownRatherThanGuessingIt() {
        let sut = ProductDetailPresenter()

        let viewModel = sut.viewModel(
            for: Product(id: UUID(), name: "MacBook Pro"),
            sales: [sale(amount: "126944.29", currency: "JPY")],
            converter: CurrencyConverter(rates: [])
        )

        XCTAssertNil(
            viewModel.sales.first?.amountInUSD,
            "Showing 126,944 yen as US$126,944 overstates the sale by a factor of a hundred"
        )
        XCTAssertEqual(viewModel.sales.first?.amount, "¥126,944.29")
    }

    func test_viewModel_excludesTheUnconvertibleSalesFromTheTotalAndSaysHowMany() {
        let sut = ProductDetailPresenter()

        let viewModel = sut.viewModel(
            for: Product(id: UUID(), name: "Mac mini"),
            sales: [
                sale(amount: "100.00", currency: "EUR"),
                sale(amount: "126944.29", currency: "JPY"),
                sale(amount: "1000.00", currency: "ZAR")
            ],
            converter: CurrencyConverter(rates: [rate("EUR", "1.18")])
        )

        XCTAssertEqual(viewModel.subtitle, "($118.00 from 3 sales) · 2 without a USD rate")
    }

    // MARK: - Helpers

    private func sale(
        amount: String,
        currency: String,
        date: Date = Date()
    ) -> Sale {
        Sale(
            currencyCode: currency,
            amount: Decimal(string: amount)!,
            productId: UUID(),
            date: date
        )
    }

    private func rate(_ currency: String, _ value: String) -> CurrencyRate {
        CurrencyRate(from: currency, to: "USD", rate: Decimal(string: value)!)
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }
}
