//
//  ProductDetailViewControllerSnapshotTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class ProductDetailViewControllerSnapshotTests: XCTestCase {

    func test_PRODUCT_DETAIL_light() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: sales(), rates: .loaded(rates()))

        assert(snapshot: sut.snapshot(for: .iPhone(style: .light)), named: "PRODUCT_DETAIL_light")
    }

    func test_PRODUCT_DETAIL_dark() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: sales(), rates: .loaded(rates()))

        assert(snapshot: sut.snapshot(for: .iPhone(style: .dark)), named: "PRODUCT_DETAIL_dark")
    }

    func test_PRODUCT_DETAIL_CONVERTING_light() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: sales(), rates: .pending)

        assert(snapshot: sut.snapshot(for: .iPhone(style: .light)), named: "PRODUCT_DETAIL_CONVERTING_light")
    }

    func test_PRODUCT_DETAIL_RATES_FAILED_light() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: sales(), rates: .failed)

        assert(snapshot: sut.snapshot(for: .iPhone(style: .light)), named: "PRODUCT_DETAIL_RATES_FAILED_light")
    }

    func test_PRODUCT_DETAIL_XXXL() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: sales(), rates: .loaded(rates()))

        assert(
            snapshot: sut.snapshot(for: .iPhone(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)),
            named: "PRODUCT_DETAIL_XXXL"
        )
    }

    func test_PRODUCT_DETAIL_RATES_FAILED_XXXL() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: sales(), rates: .failed)

        assert(
            snapshot: sut.snapshot(for: .iPhone(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)),
            named: "PRODUCT_DETAIL_RATES_FAILED_XXXL"
        )
    }

    // MARK: - Helpers

    private func makeSUT() -> (ProductDetailViewController, ProductDetailPresenter) {
        let sut = ProductDetailViewController()
        sut.loadViewIfNeeded()
        let presenter = ProductDetailPresenter(
            detailView: sut,
            loadingView: sut,
            errorView: sut,
            formatter: SalesFormatter(timeZone: TimeZone(identifier: "UTC")!)
        )
        return (sut, presenter)
    }

    private func sales() -> [Sale] {
        let product = makeProduct(named: "iPhone")
        return [
            makeSale(of: product, amount: "2299.00", currency: "BRL", at: 1_893_582_000),
            makeSale(of: product, amount: "100.00", currency: "EUR", at: 1_893_495_600),
            makeSale(of: product, amount: "126944.29", currency: "JPY", at: 1_893_409_200)
        ]
    }

    private func rates() -> [CurrencyRate] {
        [
            CurrencyRate(from: "BRL", to: "USD", rate: Decimal(string: "0.18")!),
            CurrencyRate(from: "EUR", to: "USD", rate: Decimal(string: "1.18")!)
        ]
    }
}
