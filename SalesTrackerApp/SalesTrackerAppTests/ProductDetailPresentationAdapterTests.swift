//
//  ProductDetailPresentationAdapterTests.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/30.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class ProductDetailPresentationAdapterTests: XCTestCase {

    func test_load_presentsTheSalesBeforeTheRates() async {
        let (sut, view, catalogue, rates, _) = makeSUT()
        await catalogue.completeWith(.success(catalogueWithOneEuroSale()))
        await rates.hangLoads()

        sut.load()
        await waitUntil("the sales reach the screen") { view.details.isEmpty == false }

        XCTAssertEqual(view.lastUSDColumn, [localized("USD_PENDING")], "The sales must not wait for the rates")
    }

    func test_load_presentsTheRatesWhenTheyArrive() async {
        let (sut, view, catalogue, rates, _) = makeSUT()
        await catalogue.completeWith(.success(catalogueWithOneEuroSale()))
        await rates.completeWith(.success([euroRate()]))

        sut.load()
        await waitUntil("the rates are applied") { view.lastUSDColumn == ["$118.00"] }

        XCTAssertEqual(view.lastUSDColumn, ["$118.00"])
    }

    func test_load_whenTheRatesArriveBeforeTheSales_presentsThemConvertedOnce() async {
        let (sut, view, catalogue, rates, _) = makeSUT()
        await catalogue.completeWith(.success(catalogueWithOneEuroSale()))
        await catalogue.hangLoads()
        await rates.completeWith(.success([euroRate()]))

        sut.load()
        await waitUntil("the sales request is in flight") { await catalogue.isHoldingALoad }
        await drainPendingWork()

        XCTAssertEqual(view.details.count, 0, "Rates alone have nothing to be applied to")

        await catalogue.releaseLoads()
        await waitUntil("the sales arrive") { view.details.isEmpty == false }
        await drainPendingWork()

        XCTAssertEqual(view.details.count, 1, "Expected one render, already converted")
        XCTAssertEqual(view.lastUSDColumn, ["$118.00"])
    }

    func test_load_whenTheRatesFail_stillPresentsTheSales_andReportsTheRatesFailure() async {
        let (sut, view, catalogue, rates, _) = makeSUT()
        await catalogue.completeWith(.success(catalogueWithOneEuroSale()))
        await rates.completeWith(.failure(anyNSError()))

        sut.load()
        await waitUntil("the rates failure is reflected") { view.lastUSDColumn == [localized("USD_UNAVAILABLE")] }

        XCTAssertEqual(view.lastUSDColumn, [localized("USD_UNAVAILABLE")])
        XCTAssertEqual(
            view.lastSubtitle,
            String(format: localized("PRODUCT_DETAIL_SUBTITLE_RATES_FAILED_FORMAT"), localized("PRODUCT_SALES_COUNT_ONE")),
            "The count must survive a failure of the rates request"
        )
    }

    func test_refresh_afterARatesFailure_goesBackToConverting() async {
        let (sut, view, catalogue, rates, _) = makeSUT()
        await catalogue.completeWith(.success(catalogueWithOneEuroSale()))
        await rates.completeWith(.failure(anyNSError()))
        sut.load()
        await waitUntil("the first load settles") { view.lastUSDColumn == [localized("USD_UNAVAILABLE")] }

        await rates.hangLoads()
        sut.refresh()
        await waitUntil("the sales come back while the rates are in flight") {
            view.lastUSDColumn == [localized("USD_PENDING")]
        }

        XCTAssertEqual(view.lastUSDColumn, [localized("USD_PENDING")], "A refresh must reset the rates to pending")
    }

    func test_load_doesNotInvalidateTheCache_butRefreshDoes() async {
        let (sut, view, _, _, cache) = makeSUT()

        sut.load()
        await waitUntil("the load settles") { view.loadingSequence.contains(false) }
        XCTAssertEqual(cache.invalidateCount, 0, "Opening a product must reuse the catalogue the list already loaded")

        sut.refresh()
        await waitUntil("the refresh settles") { cache.invalidateCount == 1 }
        XCTAssertEqual(cache.invalidateCount, 1)
    }

    func test_load_onSalesFailure_presentsTheError() async {
        let (sut, view, catalogue, _, _) = makeSUT()
        await catalogue.completeWith(.failure(anyNSError()))

        sut.load()
        await waitUntil("the failure is reported") {
            view.messages.contains { if case .errorMessage(.some) = $0 { true } else { false } }
        }

        XCTAssertEqual(view.details.count, 0)
        XCTAssertEqual(view.loadingSequence.last, false, "The spinner must not be left running")
    }

    func test_aNewRefresh_supersedesTheOneInFlight_andItsLateReplyIsDropped() async {
        let (sut, view, catalogue, rates, _) = makeSUT()
        await catalogue.completeWith(.success(catalogueWithOneEuroSale()))
        await rates.completeWith(.success([euroRate()]))
        await catalogue.hangLoads()

        sut.refresh()
        await waitUntil("the first refresh is in flight") { await catalogue.isHoldingALoad }
        sut.refresh()
        await catalogue.releaseLoads()
        await waitUntil("the surviving refresh settles") { view.lastUSDColumn == ["$118.00"] }
        await drainPendingWork()

        XCTAssertEqual(view.loadingSequence.last, false, "The spinner must not be left running")
    }

    func test_load_doesNotDeliverAResultAfterTheAdapterHasBeenDeallocated() async {
        let catalogue = CatalogueLoaderStub()
        let rates = RatesLoaderStub()
        await catalogue.completeWith(.success(catalogueWithOneEuroSale()))
        await catalogue.hangLoads()
        let view = DetailViewSpy()
        var sut: ProductDetailPresentationAdapter? = makeAdapter(catalogue: catalogue, rates: rates, cache: CacheSpy(), view: view)

        sut?.load()
        await waitUntil("the load is in flight") { await catalogue.isHoldingALoad }
        sut = nil
        await catalogue.releaseLoads()
        await drainPendingWork()

        XCTAssertEqual(view.details.count, 0, "A reply to a screen that is gone must change nothing")
    }

    // MARK: - Helpers

    private let product = makeProduct(named: "iPhone")

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (ProductDetailPresentationAdapter, DetailViewSpy, CatalogueLoaderStub, RatesLoaderStub, CacheSpy) {
        let catalogue = CatalogueLoaderStub()
        let rates = RatesLoaderStub()
        let cache = CacheSpy()
        let view = DetailViewSpy()
        let sut = makeAdapter(catalogue: catalogue, rates: rates, cache: cache, view: view)

        trackForMemoryLeaks(view, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        addTeardownBlock { [weak catalogue, weak rates] in
            await catalogue?.cancelPendingRequests()
            await rates?.cancelPendingRequests()
        }

        return (sut, view, catalogue, rates, cache)
    }

    private func makeAdapter(
        catalogue: CatalogueLoaderStub,
        rates: RatesLoaderStub,
        cache: CacheSpy,
        view: DetailViewSpy
    ) -> ProductDetailPresentationAdapter {
        let sut = ProductDetailPresentationAdapter(
            product: product,
            catalogueLoader: catalogue,
            catalogueCache: cache,
            ratesLoader: rates
        )
        sut.presenter = ProductDetailPresenter(
            detailView: WeakRefVirtualProxy(view),
            loadingView: WeakRefVirtualProxy(view),
            errorView: WeakRefVirtualProxy(view),
            formatter: SalesFormatter(timeZone: TimeZone(identifier: "UTC")!)
        )
        return sut
    }

    private func catalogueWithOneEuroSale() -> ProductCatalogue {
        ProductCatalogue(
            products: [product],
            sales: [makeSale(of: product, amount: "100.00", currency: "EUR")]
        )
    }

    private func euroRate() -> CurrencyRate {
        CurrencyRate(from: "EUR", to: "USD", rate: Decimal(string: "1.18")!)
    }
}
