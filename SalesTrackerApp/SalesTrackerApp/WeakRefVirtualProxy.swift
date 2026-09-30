//
//  WeakRefVirtualProxy.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/30.
//

import UIKit
import SalesTracker

/// Breaks the retain cycle between a presenter and the view controller it talks to: the adapter
/// owns the presenter, the presenter points back through this, and the screen is free to go
/// whenever the user leaves it.
final class WeakRefVirtualProxy<T: AnyObject> {
    private weak var object: T?

    init(_ object: T) {
        self.object = object
    }
}

extension WeakRefVirtualProxy: ResourceLoadingView where T: ResourceLoadingView {
    @MainActor
    func display(_ viewModel: ResourceLoadingViewModel) {
        object?.display(viewModel)
    }
}

extension WeakRefVirtualProxy: ResourceErrorView where T: ResourceErrorView {
    @MainActor
    func display(_ viewModel: ResourceErrorViewModel) {
        object?.display(viewModel)
    }
}

extension WeakRefVirtualProxy: ProductListView where T: ProductListView {
    @MainActor
    func display(_ viewModel: ProductListViewModel) {
        object?.display(viewModel)
    }
}

extension WeakRefVirtualProxy: ProductDetailView where T: ProductDetailView {
    @MainActor
    func display(_ viewModel: ProductDetailViewModel) {
        object?.display(viewModel)
    }
}
