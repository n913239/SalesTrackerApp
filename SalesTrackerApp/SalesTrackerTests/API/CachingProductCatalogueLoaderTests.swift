//
//  CachingProductCatalogueLoaderTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

final class CachingProductCatalogueLoaderTests: XCTestCase {

    func test_init_doesNotLoad() async {
        let (_, decoratee) = makeSUT()

        let callCount = await decoratee.loadCallCount
        XCTAssertEqual(callCount, 0)
    }

    func test_load_deliversTheDecorateesCatalogue() async throws {
        let (sut, decoratee) = makeSUT()
        let catalogue = makeCatalogue(productNamed: "iPhone")
        await decoratee.completeWith(.success(catalogue))

        let received = try await sut.load()

        XCTAssertEqual(received.summaries(), catalogue.summaries())
    }

    func test_loadTwice_onlyLoadsFromTheDecorateeOnce() async throws {
        let (sut, decoratee) = makeSUT()

        _ = try await sut.load()
        _ = try await sut.load()

        let callCount = await decoratee.loadCallCount
        XCTAssertEqual(callCount, 1)
    }

    func test_concurrentLoads_shareOneDecorateeLoad() async throws {
        let (sut, decoratee) = makeSUT()
        let catalogue = makeCatalogue(productNamed: "iPhone")
        await decoratee.completeWith(.success(catalogue))
        await decoratee.hangTheNextLoad()

        async let results: [[ProductSummary]] = withThrowingTaskGroup(of: [ProductSummary].self) { group in
            for _ in 0..<5 {
                group.addTask { try await sut.load().summaries() }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        await waitUntilTheDecorateeIsLoading(decoratee)
        await decoratee.releaseTheHungLoad()

        let summaries = try await results
        let callCount = await decoratee.loadCallCount
        XCTAssertEqual(callCount, 1, "Five callers should share one load")
        XCTAssertEqual(summaries.count, 5)
        XCTAssertTrue(summaries.allSatisfy { $0 == catalogue.summaries() })
    }

    func test_load_deliversTheDecorateesError() async {
        let (sut, decoratee) = makeSUT()
        await decoratee.completeWith(.failure(anyNSError()))

        do {
            _ = try await sut.load()
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as NSError, anyNSError())
        }
    }

    func test_loadAfterAFailure_retriesTheDecoratee() async throws {
        let (sut, decoratee) = makeSUT()
        await decoratee.completeWith(.failure(anyNSError()))
        _ = try? await sut.load()

        await decoratee.completeWith(.success(makeCatalogue(productNamed: "iPhone")))
        _ = try await sut.load()

        let callCount = await decoratee.loadCallCount
        XCTAssertEqual(callCount, 2, "A failure must not be cached")
    }

    func test_invalidateOnAnEmptyCache_doesNothing() async {
        let (sut, decoratee) = makeSUT()

        await sut.invalidate()

        let callCount = await decoratee.loadCallCount
        XCTAssertEqual(callCount, 0)
    }

    func test_loadAfterInvalidate_loadsFromTheDecorateeAgain() async throws {
        let (sut, decoratee) = makeSUT()
        _ = try await sut.load()

        await sut.invalidate()
        _ = try await sut.load()

        let callCount = await decoratee.loadCallCount
        XCTAssertEqual(callCount, 2)
    }

    func test_aLoadThatFinishesAfterInvalidate_doesNotRefillTheCache() async throws {
        let (sut, decoratee) = makeSUT()
        await decoratee.hangTheNextLoad()

        let hungLoad = Task { try await sut.load() }
        await waitUntilTheDecorateeIsLoading(decoratee)
        await sut.invalidate()
        await decoratee.releaseTheHungLoad()
        _ = try await hungLoad.value

        _ = try await sut.load()

        let callCount = await decoratee.loadCallCount
        XCTAssertEqual(callCount, 2, "The reply that arrived after invalidate must not be cached")
    }

    func test_aRefreshThatFails_reportsItButKeepsTheCatalogueItWasReplacing() async throws {
        let (sut, decoratee) = makeSUT()
        let catalogue = makeCatalogue(productNamed: "iPhone")
        await decoratee.completeWith(.success(catalogue))
        _ = try await sut.load()

        await sut.invalidate()
        await decoratee.completeWith(.failure(anyNSError()))
        do {
            _ = try await sut.load()
            XCTFail("Expected the refresh to report its failure")
        } catch {}

        let received = try await sut.load()

        XCTAssertEqual(received.summaries(), catalogue.summaries())
        let callCount = await decoratee.loadCallCount
        XCTAssertEqual(callCount, 2, "The rows still on screen must open from the cache, not from the network that just failed")
    }

    // MARK: - Helpers

    private func makeSUT() -> (CachingProductCatalogueLoader, LoaderSpy) {
        let decoratee = LoaderSpy()
        return (CachingProductCatalogueLoader(decoratee: decoratee), decoratee)
    }

    private func makeCatalogue(productNamed name: String) -> ProductCatalogue {
        ProductCatalogue(products: [Product(id: UUID(), name: name)], sales: [])
    }

    private func anyNSError() -> NSError { NSError(domain: "any error", code: 0) }

    private func waitUntilTheDecorateeIsLoading(
        _ decoratee: LoaderSpy,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<1000 {
            if await decoratee.isHanging { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for the decoratee to start loading", file: file, line: line)
    }
}

actor LoaderSpy: ProductCatalogueLoader {
    private(set) var loadCallCount = 0
    private(set) var isHanging = false

    private var result: Result<ProductCatalogue, Error> = .success(ProductCatalogue(products: [], sales: []))
    private var hangTheNext = false
    private var hungLoad: CheckedContinuation<Void, Never>?

    func completeWith(_ result: Result<ProductCatalogue, Error>) {
        self.result = result
    }

    func hangTheNextLoad() {
        hangTheNext = true
    }

    func releaseTheHungLoad() {
        hangTheNext = false
        isHanging = false
        hungLoad?.resume()
        hungLoad = nil
    }

    func load() async throws -> ProductCatalogue {
        loadCallCount += 1

        if hangTheNext {
            hangTheNext = false
            isHanging = true
            await withCheckedContinuation { hungLoad = $0 }
        }

        return try result.get()
    }
}
