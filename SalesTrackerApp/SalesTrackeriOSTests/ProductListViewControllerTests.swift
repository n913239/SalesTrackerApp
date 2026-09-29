//
//  ProductListViewControllerTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class ProductListViewControllerTests: XCTestCase {

    func test_refreshActions_requestARefresh() {
        var refreshCount = 0
        let sut = makeSUT(onRefresh: { refreshCount += 1 })

        XCTAssertEqual(refreshCount, 0, "Expected no refresh before the view appears")

        sut.simulateAppearance()
        XCTAssertEqual(refreshCount, 1, "Expected a refresh once the view appears")

        sut.refreshControl?.simulatePullToRefresh()
        XCTAssertEqual(refreshCount, 2, "Expected another refresh on the first pull")

        sut.refreshControl?.simulatePullToRefresh()
        XCTAssertEqual(refreshCount, 3, "Expected another refresh on the second pull")
    }

    func test_secondAppearance_doesNotRequestAnotherLoad() {
        var refreshCount = 0
        let sut = makeSUT(onRefresh: { refreshCount += 1 })
        sut.simulateAppearance()

        sut.simulateAppearance()

        XCTAssertEqual(refreshCount, 1, "Coming back from the detail must not reload the list")
    }

    func test_displayProducts_rendersEachRowWithItsNameAndSalesCount() {
        let sut = makeSUT()
        sut.simulateAppearance()

        sut.display(listViewModel(["iPad": "1 sale", "iPhone": "3 sales"]))

        XCTAssertEqual(sut.numberOfRenderedRows, 2)
        XCTAssertEqual(sut.title(at: 0), "iPad")
        XCTAssertEqual(sut.subtitle(at: 0), "1 sale")
        XCTAssertEqual(sut.title(at: 1), "iPhone")
        XCTAssertEqual(sut.subtitle(at: 1), "3 sales")
    }

    func test_displayNoProducts_showsTheEmptyMessage() {
        let sut = makeSUT()
        sut.simulateAppearance()

        sut.display(ProductListViewModel(products: [], emptyMessage: "No products yet."))

        XCTAssertEqual(sut.numberOfRenderedRows, 0)
        XCTAssertEqual(sut.emptyMessage, "No products yet.")
    }

    func test_displayProducts_hidesTheEmptyMessage() {
        let sut = makeSUT()
        sut.simulateAppearance()
        sut.display(ProductListViewModel(products: [], emptyMessage: "No products yet."))

        sut.display(listViewModel(["iPhone": "3 sales"]))

        XCTAssertNil(sut.emptyMessage)
    }

    func test_displayError_isVisibleAboveTheRows() {
        let sut = makeSUT()
        sut.simulateAppearance()
        sut.display(listViewModel(["iPad": "1 sale", "iPhone": "3 sales"]))

        sut.display(.error(message: "Couldn't load the data."))
        sut.view.layoutIfNeeded()

        XCTAssertTrue(sut.isShowingError, "Expected the error to be visible")
        XCTAssertEqual(sut.errorMessage, "Couldn't load the data.")
        XCTAssertGreaterThan(sut.tableView.tableHeaderView?.frame.height ?? 0, 0, "Expected the header to have height")
        XCTAssertEqual(sut.numberOfRenderedRows, 2, "Expected the rows to stay on screen")
    }

    func test_displayNoError_collapsesTheHeader() {
        let sut = makeSUT()
        sut.simulateAppearance()
        sut.display(.error(message: "Couldn't load the data."))

        sut.display(.noError)

        XCTAssertFalse(sut.isShowingError)
        XCTAssertNil(sut.tableView.tableHeaderView)
    }

    func test_displayLoading_drivesTheRefreshControl() {
        let sut = makeSUT()
        sut.simulateAppearance()

        sut.display(ResourceLoadingViewModel(isLoading: true))
        XCTAssertTrue(sut.refreshControl?.isRefreshing == true)

        sut.display(ResourceLoadingViewModel(isLoading: false))
        XCTAssertFalse(sut.refreshControl?.isRefreshing == true)
    }

    func test_selectingARow_notifiesTheSelectedProduct() {
        let iPhone = makeProduct(named: "iPhone")
        var selected: [Product] = []
        let sut = makeSUT(onSelect: { selected.append($0) })
        sut.simulateAppearance()
        sut.display(ProductListViewModel(
            products: [ProductViewModel(product: iPhone, name: "iPhone", salesCount: "3 sales")],
            emptyMessage: nil
        ))

        sut.simulateTapOnRow(0)

        XCTAssertEqual(selected, [iPhone])
    }

    // MARK: - Helpers

    private func makeSUT(
        onRefresh: @escaping () -> Void = {},
        onSelect: @escaping (Product) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ProductListViewController {
        let sut = ProductListViewController()
        sut.onRefresh = onRefresh
        sut.onSelect = onSelect
        sut.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func listViewModel(_ rows: [String: String]) -> ProductListViewModel {
        ProductListViewModel(
            products: rows.sorted { $0.key < $1.key }.map {
                ProductViewModel(product: makeProduct(named: $0.key), name: $0.key, salesCount: $0.value)
            },
            emptyMessage: nil
        )
    }
}
