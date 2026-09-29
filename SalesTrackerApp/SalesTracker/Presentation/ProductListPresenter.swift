//
//  ProductListPresenter.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

public struct ProductViewModel: Equatable, Sendable {
    public let product: Product
    public let name: String
    public let salesCount: String

    public init(product: Product, name: String, salesCount: String) {
        self.product = product
        self.name = name
        self.salesCount = salesCount
    }
}

public struct ProductListViewModel: Equatable, Sendable {
    public let products: [ProductViewModel]
    public let emptyMessage: String?

    public init(products: [ProductViewModel], emptyMessage: String?) {
        self.products = products
        self.emptyMessage = emptyMessage
    }
}

@MainActor
public protocol ProductListView {
    func display(_ viewModel: ProductListViewModel)
}

@MainActor
public final class ProductListPresenter {
    public static var title: String { SalesTrackerStrings.localized("PRODUCTS_TITLE") }

    private let listView: ProductListView
    private let loadingView: ResourceLoadingView
    private let errorView: ResourceErrorView

    public init(listView: ProductListView, loadingView: ResourceLoadingView, errorView: ResourceErrorView) {
        self.listView = listView
        self.loadingView = loadingView
        self.errorView = errorView
    }

    public func didStartLoading() {
        loadingView.display(ResourceLoadingViewModel(isLoading: true))
        errorView.display(.noError)
    }

    public func didFinishLoading(with summaries: [ProductSummary]) {
        listView.display(ProductListViewModel(
            products: summaries.map {
                ProductViewModel(
                    product: $0.product,
                    name: $0.product.name,
                    salesCount: SalesTrackerStrings.salesCount($0.salesCount)
                )
            },
            emptyMessage: summaries.isEmpty ? SalesTrackerStrings.localized("EMPTY_PRODUCTS_MESSAGE") : nil
        ))
        loadingView.display(ResourceLoadingViewModel(isLoading: false))
    }

    /// The list view is deliberately left alone: rows already on screen stay there, and the error
    /// goes somewhere the rows cannot cover it. A refresh that fails must not look like nothing
    /// happened.
    public func didFinishLoading(with error: Error) {
        errorView.display(.error(message: SalesTrackerStrings.localized("LOAD_FAILED_MESSAGE")))
        loadingView.display(ResourceLoadingViewModel(isLoading: false))
    }
}
