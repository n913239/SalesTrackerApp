//
//  ProductDetailViewControllerTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class ProductDetailViewControllerTests: XCTestCase {

    func test_viewIsAppearing_requestsALoad() {
        var loadCount = 0
        let sut = makeSUT(onLoad: { loadCount += 1 })

        XCTAssertEqual(loadCount, 0, "Expected no load before the view appears")

        sut.simulateAppearance()

        XCTAssertEqual(loadCount, 1)
    }

    func test_secondAppearance_doesNotRequestAnotherLoad() {
        var loadCount = 0
        let sut = makeSUT(onLoad: { loadCount += 1 })
        sut.simulateAppearance()

        sut.simulateAppearance()

        XCTAssertEqual(loadCount, 1)
    }

    func test_pullToRefresh_requestsARefresh() {
        var refreshCount = 0
        let sut = makeSUT(onRefresh: { refreshCount += 1 })
        sut.simulateAppearance()

        sut.refreshControl?.simulatePullToRefresh()

        XCTAssertEqual(refreshCount, 1)
    }

    func test_displayDetail_rendersEachSaleWithItsAmountDateAndUSD() {
        let sut = makeSUT()
        sut.simulateAppearance()

        sut.display(ProductDetailViewModel(
            subtitle: "any subtitle",
            sales: [
                SaleViewModel(amount: "€100.00", date: "Jan 2, 2030 at 11:00 AM", amountInUSD: "$118.00", isConverted: true),
                SaleViewModel(amount: "¥126,944.29", date: "Jan 1, 2030 at 9:30 AM", amountInUSD: "No USD rate", isConverted: false)
            ],
            emptyMessage: nil
        ))

        XCTAssertEqual(sut.numberOfRenderedRows, 2)
        XCTAssertEqual(sut.title(at: 0), "€100.00")
        XCTAssertEqual(sut.subtitle(at: 0), "Jan 2, 2030 at 11:00 AM")
        XCTAssertEqual(sut.accessoryText(at: 0), "$118.00")
        XCTAssertEqual(sut.title(at: 1), "¥126,944.29")
        XCTAssertEqual(sut.subtitle(at: 1), "Jan 1, 2030 at 9:30 AM")
        XCTAssertEqual(sut.accessoryText(at: 1), "No USD rate")
    }

    func test_displayDetail_atAnAccessibilityTextSize_movesTheUSDUnderTheDate() {
        let sut = makeSUT(contentSizeCategory: .accessibilityExtraExtraExtraLarge)
        sut.simulateAppearance()

        sut.display(ProductDetailViewModel(
            subtitle: "any subtitle",
            sales: [
                SaleViewModel(amount: "€100.00", date: "Jan 2, 2030 at 11:00 AM", amountInUSD: "$118.00", isConverted: true)
            ],
            emptyMessage: nil
        ))

        XCTAssertEqual(sut.title(at: 0), "€100.00")
        XCTAssertEqual(sut.stackedSubtitle(at: 0), "Jan 2, 2030 at 11:00 AM\n$118.00")
        XCTAssertNil(sut.accessoryText(at: 0), "Expected no USD column beside the amount")
    }

    func test_displayDetail_showsTheSubtitle() {
        let sut = makeSUT()
        sut.simulateAppearance()

        sut.display(detailViewModel(subtitle: "$168.00 from 2 sales"))

        XCTAssertEqual(sut.subtitleText, "$168.00 from 2 sales")
    }

    func test_displayDetail_dimsTheRowsThatAreNotConverted() {
        let sut = makeSUT()
        sut.simulateAppearance()

        sut.display(ProductDetailViewModel(
            subtitle: "any subtitle",
            sales: [
                SaleViewModel(amount: "€100.00", date: "a date", amountInUSD: "$118.00", isConverted: true),
                SaleViewModel(amount: "¥1.00", date: "a date", amountInUSD: "No USD rate", isConverted: false)
            ],
            emptyMessage: nil
        ))

        XCTAssertTrue(sut.isConverted(at: 0))
        XCTAssertFalse(sut.isConverted(at: 1))
    }

    func test_displayNoSales_showsTheEmptyMessage() {
        let sut = makeSUT()
        sut.simulateAppearance()

        sut.display(ProductDetailViewModel(subtitle: "any subtitle", sales: [], emptyMessage: "No sales yet."))

        XCTAssertEqual(sut.numberOfRenderedRows, 0)
        XCTAssertEqual(sut.emptyMessage, "No sales yet.")
    }

    func test_displayError_keepsTheRowsAndTheSubtitleOnScreen() {
        let sut = makeSUT()
        sut.simulateAppearance()
        sut.display(detailViewModel(subtitle: "$168.00 from 2 sales"))

        sut.display(.error(message: "Couldn't load the data."))
        sut.view.layoutIfNeeded()

        XCTAssertTrue(sut.isShowingError)
        XCTAssertEqual(sut.errorMessage, "Couldn't load the data.")
        XCTAssertEqual(sut.subtitleText, "$168.00 from 2 sales", "Expected the summary to survive a failed refresh")
        XCTAssertEqual(sut.numberOfRenderedRows, 2, "Expected the rows to survive a failed refresh")
    }

    func test_rows_cannotBeSelected() {
        let sut = makeSUT()
        sut.simulateAppearance()

        XCTAssertFalse(sut.tableView.allowsSelection)
    }

    func test_displayLoading_drivesTheRefreshControl() {
        let sut = makeSUT()
        sut.simulateAppearance()

        sut.display(ResourceLoadingViewModel(isLoading: true))
        XCTAssertTrue(sut.refreshControl?.isRefreshing == true)

        sut.display(ResourceLoadingViewModel(isLoading: false))
        XCTAssertFalse(sut.refreshControl?.isRefreshing == true)
    }

    // MARK: - Helpers

    private func makeSUT(
        onLoad: @escaping () -> Void = {},
        onRefresh: @escaping () -> Void = {},
        contentSizeCategory: UIContentSizeCategory = .large,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ProductDetailViewController {
        let sut = ProductDetailViewController()
        sut.onLoad = onLoad
        sut.onRefresh = onRefresh
        sut.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        sut.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func detailViewModel(subtitle: String) -> ProductDetailViewModel {
        ProductDetailViewModel(
            subtitle: subtitle,
            sales: [
                SaleViewModel(amount: "€100.00", date: "a date", amountInUSD: "$118.00", isConverted: true),
                SaleViewModel(amount: "$50.00", date: "a date", amountInUSD: "$50.00", isConverted: true)
            ],
            emptyMessage: nil
        )
    }
}

private extension ProductDetailViewController {
    var subtitleText: String? {
        (view(withIdentifier: AccessibilityIdentifier.subtitleLabel) as UILabel?)?.text
    }

    func stackedSubtitle(at row: Int) -> String? {
        (cell(at: row)?.contentConfiguration as? UIListContentConfiguration)?.secondaryAttributedText?.string
    }
}
