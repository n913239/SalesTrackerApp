//
//  ProductListViewControllerTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

final class ProductListViewControllerTests: UILayerTestCase {

    func test_loadsProductsWhenTheViewAppears() async {
        var loadCount = 0
        let sut = makeSUT { loadCount += 1; return .success([]) }

        await waitUntil { loadCount == 1 }
        XCTAssertEqual(loadCount, 1)
        XCTAssertEqual(sut.numberOfRenderedRows, 0)
    }

    func test_pullToRefresh_loadsAgain() async {
        var loadCount = 0
        let sut = makeSUT { loadCount += 1; return .success([]) }
        await waitUntil { loadCount == 1 }

        sut.refreshControl?.simulatePullToRefresh()

        await waitUntil { loadCount == 2 }
        XCTAssertEqual(loadCount, 2)
    }

    /// A load the user did not start by pulling still has to show that the screen is working.
    func test_showsTheRefreshIndicatorWhileLoading() async {
        let summaries = LoadSignal<Result<[ProductSummary], Error>>()
        let sut = makeSUT { await summaries.value() }
        let refreshControl = sut.replaceRefreshControlWithFake()

        sut.refresh()

        XCTAssertTrue(refreshControl.isRefreshing, "Expected the spinner while the products are loading")

        summaries.complete(with: .success([]))

        await waitUntil { !refreshControl.isRefreshing }
    }

    func test_rendersTheProductsAndTheirSalesCount() async {
        let summaries = [
            ProductSummary(product: makeProduct(name: "Bike"), salesCount: 3),
            ProductSummary(product: makeProduct(name: "Car"), salesCount: 1)
        ]
        let sut = makeSUT { .success(summaries) }

        await waitUntil { sut.numberOfRenderedRows == 2 }

        XCTAssertEqual(sut.title(at: 0), "Bike")
        XCTAssertEqual(sut.subtitle(at: 0), "3 sales")
        XCTAssertEqual(sut.title(at: 1), "Car")
        XCTAssertEqual(sut.subtitle(at: 1), "1 sale", "Expected the singular form, not \"1 sales\"")
    }

    func test_displaysAMessageWhenThereAreNoProducts() async {
        let sut = makeSUT { .success([]) }

        await waitUntil { sut.messageLabel.isHidden == false }
        XCTAssertFalse(sut.messageLabel.text?.isEmpty ?? true)
        XCTAssertEqual(sut.numberOfRenderedRows, 0)
    }

    func test_displaysAMessageWhenTheLoadFails() async {
        let sut = makeSUT { .failure(self.anyNSError()) }

        await waitUntil { sut.messageLabel.isHidden == false }
        XCTAssertFalse(sut.messageLabel.text?.isEmpty ?? true)
    }

    func test_hidesTheErrorMessageOnASuccessfulReload() async {
        var result: Result<[ProductSummary], Error> = .failure(anyNSError())
        let sut = makeSUT { result }
        await waitUntil { sut.messageLabel.isHidden == false }

        result = .success([ProductSummary(product: makeProduct(name: "Bike"), salesCount: 1)])
        sut.refreshControl?.simulatePullToRefresh()

        await waitUntil { sut.numberOfRenderedRows == 1 }
        XCTAssertTrue(sut.messageLabel.isHidden, "Expected the error message to go away once the reload succeeded")
    }

    func test_selectingARow_notifiesTheSelectedProduct() async {
        let bike = makeProduct(name: "Bike")
        let car = makeProduct(name: "Car")
        var selected = [Product]()

        let sut = makeSUT(
            onLoad: { .success([ProductSummary(product: bike, salesCount: 0), ProductSummary(product: car, salesCount: 0)]) },
            onSelect: { selected.append($0) }
        )
        await waitUntil { sut.numberOfRenderedRows == 2 }

        sut.simulateTapOnRow(1)

        XCTAssertEqual(selected, [car])
    }

    // MARK: - Helpers

    private func makeSUT(
        onLoad: @escaping () async -> Result<[ProductSummary], Error> = { .success([]) },
        onSelect: @escaping (Product) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ProductListViewController {
        let sut = ProductListViewController()
        sut.onLoad = onLoad
        sut.onSelect = onSelect
        trackForMemoryLeaks(sut, file: file, line: line)
        sut.loadViewIfNeeded()
        return sut
    }
}

private extension ProductListViewController {
    var messageLabel: UILabel { tableView.backgroundView as! UILabel }
}
