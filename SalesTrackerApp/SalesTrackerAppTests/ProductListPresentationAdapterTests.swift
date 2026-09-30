//
//  ProductListPresentationAdapterTests.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/30.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class ProductListPresentationAdapterTests: XCTestCase {

    func test_refresh_presentsLoadingThenTheSummaries() async {
        let (sut, view, loader, _) = makeSUT()
        await loader.completeWith(.success(makeCatalogue(productNames: ["iPad", "iPhone"])))

        sut.refresh()
        await waitUntil("the load finishes") { view.renderedRows.isEmpty == false }

        XCTAssertEqual(view.loadingSequence, [true, false])
        XCTAssertEqual(view.renderedRows, ["iPad", "iPhone"])
    }

    func test_refresh_invalidatesTheCacheBeforeLoading() async {
        let log = EventLog()
        let (sut, view, _, cache) = makeSUT(log: log)

        sut.refresh()
        await waitUntil("the load finishes") { view.loadingSequence.contains(false) }

        XCTAssertEqual(cache.invalidateCount, 1)
        XCTAssertEqual(log.all, ["invalidate", "load"], "A pull must throw the cache away before asking again")
    }

    func test_refresh_onFailure_presentsTheError() async {
        let (sut, view, loader, _) = makeSUT()
        await loader.completeWith(.failure(anyNSError()))

        sut.refresh()
        await waitUntil("the load finishes") { view.loadingSequence.contains(false) }

        XCTAssertEqual(view.messages.filter { if case .list = $0 { true } else { false } }, [], "A failure must not touch the rows")
        XCTAssertNotNil(view.messages.last(where: { if case .errorMessage(.some) = $0 { true } else { false } }))
    }

    func test_aNewRefresh_supersedesTheOneInFlight_andItsLateReplyIsDropped() async {
        let (sut, view, loader, _) = makeSUT()
        await loader.completeWith(.success(makeCatalogue(productNames: ["iPhone"])))
        await loader.hangLoads()

        sut.refresh()
        await waitUntil("the first load is in flight") { await loader.isHoldingALoad }
        sut.refresh()
        await loader.releaseLoads()
        await waitUntil("the surviving load finishes") { view.renderedRows.isEmpty == false }
        await drainPendingWork()

        XCTAssertEqual(view.renderedRows, ["iPhone"])
        XCTAssertEqual(view.loadingSequence.last, false, "The spinner must not be left running")
    }

    func test_refresh_doesNotHoldTheAdapterThroughTheLoad() async {
        let loader = CatalogueLoaderStub()
        await loader.hangLoads()
        var sut: ProductListPresentationAdapter? = makeAdapter(loader: loader, cache: CacheSpy(), view: ListViewSpy())
        weak var weakSUT = sut

        sut?.refresh()
        await waitUntil("the load is in flight") { await loader.isHoldingALoad }
        sut = nil
        await drainPendingWork()

        XCTAssertNil(weakSUT, "A load in flight must not keep the screen alive")
    }

    func test_refresh_doesNotDeliverAResultAfterTheAdapterHasBeenDeallocated() async {
        let loader = CatalogueLoaderStub()
        await loader.completeWith(.success(makeCatalogue(productNames: ["iPhone"])))
        await loader.hangLoads()
        let view = ListViewSpy()
        var sut: ProductListPresentationAdapter? = makeAdapter(loader: loader, cache: CacheSpy(), view: view)

        sut?.refresh()
        await waitUntil("the load is in flight") { await loader.isHoldingALoad }
        sut = nil
        await loader.releaseLoads()
        await drainPendingWork()

        XCTAssertEqual(view.renderedRows, [], "A reply to a screen that is gone must change nothing")
    }

    func test_deinit_cancelsTheLoadInFlight() async {
        let loader = CatalogueLoaderStub()
        await loader.hangLoads()
        var sut: ProductListPresentationAdapter? = makeAdapter(loader: loader, cache: CacheSpy(), view: ListViewSpy())

        sut?.refresh()
        await waitUntil("the load is in flight") { await loader.isHoldingALoad }
        sut = nil
        await drainPendingWork()

        XCTAssertEqual(loader.cancellations.count, 1)
    }

    // MARK: - Helpers

    private func makeSUT(
        log: EventLog = EventLog(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (ProductListPresentationAdapter, ListViewSpy, CatalogueLoaderStub, CacheSpy) {
        let loader = CatalogueLoaderStub(log: log)
        let cache = CacheSpy(log: log)
        let view = ListViewSpy()
        let sut = makeAdapter(loader: loader, cache: cache, view: view)

        trackForMemoryLeaks(view, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        addTeardownBlock { [weak loader] in await loader?.cancelPendingRequests() }

        return (sut, view, loader, cache)
    }

    private func makeAdapter(
        loader: CatalogueLoaderStub,
        cache: CacheSpy,
        view: ListViewSpy
    ) -> ProductListPresentationAdapter {
        let sut = ProductListPresentationAdapter(catalogueLoader: loader, catalogueCache: cache)
        sut.presenter = ProductListPresenter(
            listView: WeakRefVirtualProxy(view),
            loadingView: WeakRefVirtualProxy(view),
            errorView: WeakRefVirtualProxy(view)
        )
        return sut
    }
}
