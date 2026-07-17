//
//  ProductDetailViewControllerTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

final class ProductDetailViewControllerTests: UILayerTestCase {

    func test_rendersEverySaleWithItsAmountInItsOwnCurrencyAndInUSD() async {
        let product = makeProduct(name: "Bike")
        let sales = [
            makeSale(amount: 100, currency: "USD", productId: product.id),
            makeSale(amount: 100, currency: "EUR", productId: product.id)
        ]
        let sut = makeSUT(product: product) {
            .success(.init(sales: sales, rates: [CurrencyRate(from: "EUR", to: "USD", rate: 2)]))
        }

        await waitUntil { sut.numberOfRenderedRows == 2 }

        XCTAssertEqual(sut.accessoryText(at: 0), "$100.00")
        XCTAssertEqual(sut.accessoryText(at: 1), "$200.00", "Expected 100 EUR at a rate of 2 to be 200 USD")
    }

    /// The bug that headlined the audit: the first version handed the amount back untouched when it
    /// could not find a rate, so 500 BRL was reported - and summed - as 500 dollars.
    func test_aSaleWithoutARate_isMarkedUnknownAndNeverPassedOffAsDollars() async {
        let product = makeProduct(name: "Bike")
        let sales = [makeSale(amount: 500, currency: "BRL", productId: product.id)]
        let sut = makeSUT(product: product) {
            .success(.init(sales: sales, rates: [CurrencyRate(from: "EUR", to: "USD", rate: 2)]))
        }

        await waitUntil { sut.numberOfRenderedRows == 1 }

        let usdText = sut.accessoryText(at: 0)
        XCTAssertNotEqual(usdText, "$500.00", "500 BRL is not 500 USD")
        XCTAssertFalse(usdText?.contains("500") ?? true, "Expected no dollar amount at all for a currency with no rate")
        XCTAssertTrue(sut.subtitleLabel.text?.contains("1") ?? false, "Expected the subtitle to report the unconverted sale")
    }

    /// The rates come from a free-tier middleware that cold-starts in about fourteen seconds. When it
    /// does not answer, the sales are still the user's data and must stay on screen.
    func test_whenTheRatesFail_theSalesAreStillShownAndTheScreenSaysTheUSDColumnIsUnavailable() async {
        let product = makeProduct(name: "Bike")
        let sales = [
            makeSale(amount: 100, currency: "EUR", productId: product.id),
            makeSale(amount: 50, currency: "JPY", productId: product.id)
        ]
        let sut = makeSUT(product: product) { .success(.init(sales: sales, rates: nil)) }

        await waitUntil { sut.numberOfRenderedRows == 2 }

        XCTAssertEqual(sut.numberOfRenderedRows, 2, "Expected the sales to survive a failing rates request")
        XCTAssertTrue(sut.messageLabel.isHidden, "Expected no blocking error: the sales did load")
        XCTAssertFalse(sut.subtitleLabel.text?.isEmpty ?? true, "Expected the subtitle to explain the missing rates")
    }

    func test_displaysAMessageWhenThereAreNoSales() async {
        let sut = makeSUT { .success(.init(sales: [], rates: [])) }

        await waitUntil { sut.messageLabel.isHidden == false }
        XCTAssertEqual(sut.numberOfRenderedRows, 0)
        XCTAssertFalse(sut.messageLabel.text?.isEmpty ?? true)
    }

    func test_displaysAMessageWhenTheSalesFailToLoad() async {
        let sut = makeSUT { .failure(self.anyNSError()) }

        await waitUntil { sut.messageLabel.isHidden == false }
        XCTAssertFalse(sut.messageLabel.text?.isEmpty ?? true)
        XCTAssertEqual(sut.numberOfRenderedRows, 0)
    }

    func test_pullToRefresh_loadsAgain() async {
        var loadCount = 0
        let sut = makeSUT { loadCount += 1; return .success(.init(sales: [], rates: [])) }
        await waitUntil { loadCount == 1 }

        sut.refreshControl?.simulatePullToRefresh()

        await waitUntil { loadCount == 2 }
    }

    /// The token lives for two minutes, so a screen the user left open and came back to is very
    /// likely showing data that a new request would now be refused.
    func test_reloadsWhenTheScreenIsShownAgain() async {
        var loadCount = 0
        let sut = makeSUT { loadCount += 1; return .success(.init(sales: [], rates: [])) }
        await waitUntil { loadCount == 1 }

        sut.viewWillAppear(false)

        await waitUntil { loadCount == 2 }
    }

    func test_titleIsTheProductName() {
        let sut = makeSUT(product: makeProduct(name: "Bike"))

        XCTAssertEqual(sut.title, "Bike")
    }

    // MARK: - Helpers

    private func makeSUT(
        product: Product? = nil,
        onLoad: @escaping () async -> Result<ProductDetailViewController.Content, Error> = { .success(.init(sales: [], rates: [])) },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ProductDetailViewController {
        let sut = ProductDetailViewController(product: product ?? makeProduct())
        sut.onLoad = onLoad
        trackForMemoryLeaks(sut, file: file, line: line)
        sut.loadViewIfNeeded()
        return sut
    }
}

private extension ProductDetailViewController {
    var messageLabel: UILabel { tableView.backgroundView as! UILabel }
    var subtitleLabel: UILabel { view(withIdentifier: AccessibilityIdentifier.subtitleLabel)! }
}
