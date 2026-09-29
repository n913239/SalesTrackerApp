//
//  ProductListPresenterTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

@MainActor
final class ProductListPresenterTests: XCTestCase {

    func test_init_doesNotSendMessagesToView() {
        let (_, view) = makeSUT()

        XCTAssertEqual(view.messages, [])
    }

    func test_didStartLoading_showsLoadingAndClearsThePreviousError() {
        let (sut, view) = makeSUT()

        sut.didStartLoading()

        XCTAssertEqual(view.messages, [.loading(true), .errorMessage(nil)])
    }

    func test_didFinishLoadingWithSummaries_displaysEachProductWithItsSalesCount() {
        let (sut, view) = makeSUT()
        let iPhone = Product(id: UUID(), name: "iPhone")
        let iPad = Product(id: UUID(), name: "iPad")

        sut.didFinishLoading(with: [
            ProductSummary(product: iPad, salesCount: 0),
            ProductSummary(product: iPhone, salesCount: 3)
        ])

        XCTAssertEqual(view.renderedProducts.map(\.name), ["iPad", "iPhone"])
        XCTAssertEqual(view.renderedProducts.map(\.salesCount), [
            String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), 0),
            String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), 3)
        ])
        XCTAssertEqual(view.renderedProducts.map(\.product), [iPad, iPhone])
    }

    func test_didFinishLoadingWithOneSale_saysOneSaleRatherThanOneSales() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(with: [ProductSummary(product: Product(id: UUID(), name: "iPhone"), salesCount: 1)])

        XCTAssertEqual(view.renderedProducts.map(\.salesCount), [localized("PRODUCT_SALES_COUNT_ONE")])
    }

    func test_didFinishLoadingWithNoSummaries_displaysTheEmptyMessage() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(with: [])

        XCTAssertEqual(view.renderedProducts, [])
        XCTAssertEqual(view.renderedEmptyMessage, localized("EMPTY_PRODUCTS_MESSAGE"))
    }

    func test_didFinishLoadingWithSummaries_stopsLoading() {
        let (sut, view) = makeSUT()

        sut.didFinishLoading(with: [ProductSummary(product: Product(id: UUID(), name: "iPhone"), salesCount: 1)])

        XCTAssertEqual(view.messages.last, .loading(false))
        XCTAssertNil(view.renderedEmptyMessage)
    }

    func test_didFinishLoadingWithError_showsTheMessageStopsLoadingAndLeavesTheListAlone() {
        let (sut, view) = makeSUT()
        sut.didFinishLoading(with: [ProductSummary(product: Product(id: UUID(), name: "iPhone"), salesCount: 1)])
        view.clearMessages()

        sut.didFinishLoading(with: anyNSError())

        XCTAssertEqual(view.messages, [
            .errorMessage(localized("LOAD_FAILED_MESSAGE")),
            .loading(false)
        ], "A failed refresh must not touch the rows already on screen")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (ProductListPresenter, ListViewSpy) {
        let view = ListViewSpy()
        let sut = ProductListPresenter(listView: view, loadingView: view, errorView: view)
        trackForMemoryLeaks(view, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, view)
    }

    private func anyNSError() -> NSError { NSError(domain: "any error", code: 0) }
}

@MainActor
final class ListViewSpy: ProductListView, ResourceLoadingView, ResourceErrorView {
    enum Message: Equatable {
        case loading(Bool)
        case errorMessage(String?)
        case list(ProductListViewModel)
    }

    private(set) var messages: [Message] = []

    var renderedProducts: [ProductViewModel] {
        messages.compactMap { if case let .list(viewModel) = $0 { viewModel.products } else { nil } }.last ?? []
    }

    var renderedEmptyMessage: String? {
        messages.compactMap { if case let .list(viewModel) = $0 { viewModel.emptyMessage } else { nil } }.last ?? nil
    }

    func clearMessages() { messages.removeAll() }

    func display(_ viewModel: ProductListViewModel) { messages.append(.list(viewModel)) }
    func display(_ viewModel: ResourceLoadingViewModel) { messages.append(.loading(viewModel.isLoading)) }
    func display(_ viewModel: ResourceErrorViewModel) { messages.append(.errorMessage(viewModel.message)) }
}
