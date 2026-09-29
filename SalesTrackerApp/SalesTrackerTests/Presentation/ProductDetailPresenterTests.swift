//
//  ProductDetailPresenterTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

@MainActor
final class ProductDetailPresenterTests: XCTestCase {

    func test_init_doesNotSendMessagesToView() {
        let (_, view) = makeSUT()

        XCTAssertEqual(view.messages, [])
    }

    func test_didFinishLoading_withLoadedRates_showsEachSaleInItsOwnCurrencyAndInUSD() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(with: [sale(amount: "100.00", currency: "EUR")], rates: .loaded([rate("EUR", "1.18")]))

        XCTAssertEqual(view.renderedSales, [
            SaleViewModel(amount: "€100.00", date: "Jan 2, 2030 at 11:00 AM", amountInUSD: "$118.00", isConverted: true)
        ])
    }

    func test_didFinishLoading_withLoadedRates_showsTheTotalAndTheCount() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(
            with: [sale(amount: "100.00", currency: "EUR"), sale(amount: "50.00", currency: "USD")],
            rates: .loaded([rate("EUR", "1.18")])
        )

        XCTAssertEqual(view.renderedSubtitle, String(
            format: localized("PRODUCT_DETAIL_SUBTITLE_FORMAT"),
            "$168.00",
            String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), 2)
        ))
    }

    func test_didFinishLoading_withoutARate_reportsTheAmountAsUnavailableRatherThanGuessingIt() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(
            with: [sale(amount: "100.00", currency: "EUR"), sale(amount: "126944.29", currency: "JPY")],
            rates: .loaded([rate("EUR", "1.18")])
        )

        XCTAssertEqual(view.renderedSales.map(\.amountInUSD), ["$118.00", localized("USD_UNAVAILABLE")])
        XCTAssertEqual(view.renderedSales.map(\.isConverted), [true, false])
        XCTAssertEqual(view.renderedSubtitle, String(
            format: localized("PRODUCT_DETAIL_UNCONVERTIBLE_FORMAT"),
            String(
                format: localized("PRODUCT_DETAIL_SUBTITLE_FORMAT"),
                "$118.00",
                String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), 2)
            ),
            1
        ))
    }

    func test_didFinishLoadingWithNoSales_displaysTheEmptyMessage() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(with: [], rates: .loaded([]))

        XCTAssertEqual(view.renderedSales, [])
        XCTAssertEqual(view.renderedEmptyMessage, localized("EMPTY_SALES_MESSAGE"))
    }

    func test_didFinishLoadingWithError_showsTheMessageStopsLoadingAndLeavesTheRowsAlone() {
        let (sut, view) = makeSUT()
        sut.didFinishLoading(with: [sale(amount: "100.00", currency: "EUR")], rates: .loaded([rate("EUR", "1.18")]))
        view.clearMessages()

        sut.didFinishLoading(with: anyNSError())

        XCTAssertEqual(view.messages, [
            .errorMessage(localized("LOAD_FAILED_MESSAGE")),
            .loading(false)
        ], "A failed refresh must not touch the rows already on screen")
    }

    func test_didFinishLoading_withPendingRates_saysEachRowIsStillConverting() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(with: [sale(amount: "100.00", currency: "EUR")], rates: .pending)

        XCTAssertEqual(view.renderedSales.map(\.amountInUSD), [localized("USD_PENDING")])
        XCTAssertEqual(view.renderedSales.map(\.isConverted), [false])
    }

    func test_didFinishLoading_withPendingRates_reportsTheCountAlone() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(
            with: [sale(amount: "100.00", currency: "EUR"), sale(amount: "50.00", currency: "USD")],
            rates: .pending
        )

        XCTAssertEqual(view.renderedSubtitle, String(
            format: localized("PRODUCT_DETAIL_SUBTITLE_WITHOUT_RATES_FORMAT"),
            String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), 2)
        ))
    }

    func test_didFinishLoading_withFailedRates_keepsTheCountInTheSubtitle() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(
            with: [sale(amount: "100.00", currency: "EUR"), sale(amount: "50.00", currency: "USD")],
            rates: .failed
        )

        XCTAssertEqual(view.renderedSales.map(\.amountInUSD), [localized("USD_UNAVAILABLE"), localized("USD_UNAVAILABLE")])
        XCTAssertEqual(view.renderedSubtitle, String(
            format: localized("PRODUCT_DETAIL_SUBTITLE_RATES_FAILED_FORMAT"),
            String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), 2)
        ))
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (ProductDetailPresenter, DetailViewSpy) {
        let view = DetailViewSpy()
        let sut = ProductDetailPresenter(
            detailView: view,
            loadingView: view,
            errorView: view,
            formatter: SalesFormatter(timeZone: TimeZone(identifier: "UTC")!)
        )
        trackForMemoryLeaks(view, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, view)
    }

    private func sale(amount: String, currency: String) -> Sale {
        Sale(
            currencyCode: currency,
            amount: Decimal(string: amount)!,
            productId: UUID(),
            date: Date(timeIntervalSince1970: 1_893_582_000)
        )
    }

    private func rate(_ currency: String, _ value: String) -> CurrencyRate {
        CurrencyRate(from: currency, to: "USD", rate: Decimal(string: value)!)
    }

    private func anyNSError() -> NSError { NSError(domain: "any error", code: 0) }
}

@MainActor
final class DetailViewSpy: ProductDetailView, ResourceLoadingView, ResourceErrorView {
    enum Message: Equatable {
        case loading(Bool)
        case errorMessage(String?)
        case detail(ProductDetailViewModel)
    }

    private(set) var messages: [Message] = []

    private var lastDetail: ProductDetailViewModel? {
        messages.compactMap { if case let .detail(viewModel) = $0 { viewModel } else { nil } }.last
    }

    var renderedSales: [SaleViewModel] { lastDetail?.sales ?? [] }
    var renderedSubtitle: String? { lastDetail?.subtitle }
    var renderedEmptyMessage: String? { lastDetail?.emptyMessage }

    func clearMessages() { messages.removeAll() }

    func display(_ viewModel: ProductDetailViewModel) { messages.append(.detail(viewModel)) }
    func display(_ viewModel: ResourceLoadingViewModel) { messages.append(.loading(viewModel.isLoading)) }
    func display(_ viewModel: ResourceErrorViewModel) { messages.append(.errorMessage(viewModel.message)) }
}
