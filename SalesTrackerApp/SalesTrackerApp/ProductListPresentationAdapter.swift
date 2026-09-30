//
//  ProductListPresentationAdapter.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/30.
//

import Foundation
import SalesTracker

/// Owns the load the list needs. A pull invalidates the cached catalogue first, so a refresh
/// really does reach the server rather than redrawing what is already on screen.
@MainActor
final class ProductListPresentationAdapter {
    var presenter: ProductListPresenter?

    private let catalogueLoader: ProductCatalogueLoader
    private let catalogueCache: ProductCatalogueCache
    private var task: Task<Void, Never>?

    init(catalogueLoader: ProductCatalogueLoader, catalogueCache: ProductCatalogueCache) {
        self.catalogueLoader = catalogueLoader
        self.catalogueCache = catalogueCache
    }

    deinit {
        task?.cancel()
    }

    func refresh() {
        task?.cancel()

        presenter?.didStartLoading()

        let catalogueLoader = self.catalogueLoader
        let catalogueCache = self.catalogueCache

        task = Task { [weak self] in
            await catalogueCache.invalidate()

            do {
                let catalogue = try await catalogueLoader.load()
                guard !Task.isCancelled else { return }
                self?.presenter?.didFinishLoading(with: catalogue.summaries())
            } catch {
                guard !Task.isCancelled else { return }
                self?.presenter?.didFinishLoading(with: error)
            }
        }
    }
}
