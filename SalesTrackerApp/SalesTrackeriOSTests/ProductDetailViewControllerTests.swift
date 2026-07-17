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
        let sut = makeSUT(product: product, sales: .success(sales), rates: [CurrencyRate(from: "EUR", to: "USD", rate: 2)])

        await waitUntil { sut.accessoryText(at: 1) == "$200.00" }

        XCTAssertEqual(sut.numberOfRenderedRows, 2)
        XCTAssertEqual(sut.accessoryText(at: 0), "$100.00")
        XCTAssertEqual(sut.accessoryText(at: 1), "$200.00", "Expected 100 EUR at a rate of 2 to be 200 USD")
    }

    /// Handing the amount back untouched when there is no rate would report - and sum - 500 BRL as
    /// 500 dollars: a plausible-looking number that reaches the user as money.
    func test_aSaleWithoutARate_isMarkedUnknownAndNeverPassedOffAsDollars() async {
        let product = makeProduct(name: "Bike")
        let sales = [makeSale(amount: 500, currency: "BRL", productId: product.id)]
        let sut = makeSUT(product: product, sales: .success(sales), rates: [CurrencyRate(from: "EUR", to: "USD", rate: 2)])

        await waitUntil { sut.accessoryText(at: 0) == "USD rate unavailable" }

        let usdText = sut.accessoryText(at: 0)
        XCTAssertNotEqual(usdText, "$500.00", "500 BRL is not 500 USD")
        XCTAssertFalse(usdText?.contains("500") ?? true, "Expected no dollar amount at all for a currency with no rate")
        XCTAssertTrue(sut.subtitleLabel.text?.contains("1") ?? false, "Expected the subtitle to report the unconverted sale")
    }

    /// The rates come from a free-tier middleware that cold-starts in about fourteen seconds. The
    /// sales are the user's data: waiting for the rates would leave the screen blank for that long.
    func test_showsTheSalesBeforeTheRatesArrive() async {
        let product = makeProduct(name: "Bike")
        let sales = [makeSale(amount: 100, currency: "EUR", productId: product.id)]
        let slowRates = LoadSignal<[CurrencyRate]?>()

        let sut = makeSUT(product: product, sales: .success(sales), loadRates: { await slowRates.value() })

        await waitUntil { sut.numberOfRenderedRows == 1 }

        XCTAssertEqual(sut.numberOfRenderedRows, 1, "Expected the sales on screen while the rates are still loading")
        XCTAssertEqual(sut.accessoryText(at: 0), "Converting…", "Expected the USD column to say it is still working, not that no rate exists")
        XCTAssertTrue(sut.messageLabel.isHidden, "Expected no error: the sales did load")

        slowRates.complete(with: [CurrencyRate(from: "EUR", to: "USD", rate: 2)])

        await waitUntil { sut.accessoryText(at: 0) == "$200.00" }
    }

    func test_whenTheRatesFail_theSalesStayOnScreenAndTheScreenSaysTheUSDColumnIsUnavailable() async {
        let product = makeProduct(name: "Bike")
        let sales = [
            makeSale(amount: 100, currency: "EUR", productId: product.id),
            makeSale(amount: 50, currency: "JPY", productId: product.id)
        ]
        let sut = makeSUT(product: product, sales: .success(sales), rates: nil)

        await waitUntil { sut.accessoryText(at: 0) == "USD rate unavailable" }

        XCTAssertEqual(sut.numberOfRenderedRows, 2, "Expected the sales to survive a failing rates request")
        XCTAssertTrue(sut.messageLabel.isHidden, "Expected no blocking error: the sales did load")
        XCTAssertFalse(sut.subtitleLabel.text?.isEmpty ?? true, "Expected the subtitle to explain the missing rates")
    }

    func test_displaysAMessageWhenThereAreNoSales() async {
        let sut = makeSUT(sales: .success([]), rates: [])

        await waitUntil { sut.messageLabel.isHidden == false }
        XCTAssertEqual(sut.numberOfRenderedRows, 0)
        XCTAssertFalse(sut.messageLabel.text?.isEmpty ?? true)
    }

    func test_displaysAMessageWhenTheSalesFailToLoad() async {
        let sut = makeSUT(sales: .failure(anyNSError()), rates: [])

        await waitUntil { sut.messageLabel.isHidden == false }
        XCTAssertFalse(sut.messageLabel.text?.isEmpty ?? true)
        XCTAssertEqual(sut.numberOfRenderedRows, 0)
    }

    /// Without this the screen is blank white for as long as the request takes - up to fourteen
    /// seconds - with no sign that anything is happening.
    func test_showsTheRefreshIndicatorWhileLoading() async {
        let sales = LoadSignal<Result<[Sale], Error>>()
        let sut = makeSUT(loadSales: { await sales.value() })
        let refreshControl = sut.replaceRefreshControlWithFake()

        sut.refresh()

        XCTAssertTrue(refreshControl.isRefreshing, "Expected the spinner while the sales are loading")

        sales.complete(with: .success([]))

        await waitUntil { !refreshControl.isRefreshing }
    }

    func test_pullToRefresh_loadsAgain() async {
        var loadCount = 0
        let sut = makeSUT(loadSales: { loadCount += 1; return .success([]) })
        await waitUntil { loadCount == 1 }

        sut.refreshControl?.simulatePullToRefresh()

        await waitUntil { loadCount == 2 }
    }

    /// The token lives for two minutes, so a screen the user left open and came back to is very
    /// likely showing data that a new request would now be refused.
    func test_reloadsWhenTheScreenIsShownAgain() async {
        var loadCount = 0
        let sut = makeSUT(loadSales: { loadCount += 1; return .success([]) })
        await waitUntil { loadCount == 1 }

        sut.viewWillAppear(false)

        await waitUntil { loadCount == 2 }
    }

    func test_titleIsTheProductName() {
        let sut = makeSUT(product: makeProduct(name: "Bike"))

        XCTAssertEqual(sut.title, "Bike")
    }

    // MARK: - Helpers

    /// `rates: nil` means the rates request failed - as opposed to `[]`, which means it came back
    /// with nothing to convert with.
    private func makeSUT(
        product: Product? = nil,
        sales: Result<[Sale], Error> = .success([]),
        rates: [CurrencyRate]? = [],
        loadSales: (() async -> Result<[Sale], Error>)? = nil,
        loadRates: (() async -> [CurrencyRate]?)? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ProductDetailViewController {
        let sut = ProductDetailViewController(product: product ?? makeProduct())

        sut.onLoad = loadSales ?? { sales }
        sut.onLoadRates = loadRates ?? { rates }

        trackForMemoryLeaks(sut, file: file, line: line)
        sut.loadViewIfNeeded()
        return sut
    }

}

private extension ProductDetailViewController {
    var messageLabel: UILabel { tableView.backgroundView as! UILabel }
    var subtitleLabel: UILabel { view(withIdentifier: AccessibilityIdentifier.subtitleLabel)! }
}
