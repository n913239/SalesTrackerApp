//
//  ProductListViewControllerSnapshotTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class ProductListViewControllerSnapshotTests: XCTestCase {

    func test_PRODUCT_LIST_light() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: summaries())

        assert(snapshot: sut.snapshot(for: .iPhone(style: .light)), named: "PRODUCT_LIST_light")
    }

    func test_PRODUCT_LIST_dark() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: summaries())

        assert(snapshot: sut.snapshot(for: .iPhone(style: .dark)), named: "PRODUCT_LIST_dark")
    }

    func test_PRODUCT_LIST_EMPTY_light() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: [])

        assert(snapshot: sut.snapshot(for: .iPhone(style: .light)), named: "PRODUCT_LIST_EMPTY_light")
    }

    func test_PRODUCT_LIST_ERROR_WITH_ROWS_light() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: summaries())
        presenter.didFinishLoading(with: anyNSError())

        assert(snapshot: sut.snapshot(for: .iPhone(style: .light)), named: "PRODUCT_LIST_ERROR_WITH_ROWS_light")
    }

    func test_PRODUCT_LIST_XXXL() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: summaries())

        assert(
            snapshot: sut.snapshot(for: .iPhone(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)),
            named: "PRODUCT_LIST_XXXL"
        )
    }

    func test_PRODUCT_LIST_ERROR_WITH_ROWS_XXXL() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLoading(with: summaries())
        presenter.didFinishLoading(with: anyNSError())

        assert(
            snapshot: sut.snapshot(for: .iPhone(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)),
            named: "PRODUCT_LIST_ERROR_WITH_ROWS_XXXL"
        )
    }

    // MARK: - Helpers

    private func makeSUT() -> (ProductListViewController, ProductListPresenter) {
        let sut = ProductListViewController()
        sut.loadViewIfNeeded()
        return (sut, ProductListPresenter(listView: sut, loadingView: sut, errorView: sut))
    }

    private func summaries() -> [ProductSummary] {
        [
            ProductSummary(product: makeProduct(named: "Apple Watch"), salesCount: 1),
            ProductSummary(product: makeProduct(named: "iPad"), salesCount: 0),
            ProductSummary(product: makeProduct(named: "iPhone"), salesCount: 3)
        ]
    }
}
