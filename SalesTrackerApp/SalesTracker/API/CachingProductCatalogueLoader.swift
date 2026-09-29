//
//  CachingProductCatalogueLoader.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

/// One catalogue per session, shared by the list and the detail.
///
/// - hit: a cached catalogue is returned without touching the network.
/// - miss: the decoratee is asked, and the result is cached.
/// - in flight: a second caller joins the load already running instead of starting another.
/// - failure: nothing is cached, so the next caller retries.
/// - invalidate: the cache is emptied, and a load already running is disowned so its late reply
///   cannot refill what the user just asked to be thrown away.
public actor CachingProductCatalogueLoader: ProductCatalogueLoader, ProductCatalogueCache {
    private let decoratee: ProductCatalogueLoader
    private var cached: ProductCatalogue?
    private var loadInProgress: Task<ProductCatalogue, Error>?
    private var generation = 0

    public init(decoratee: ProductCatalogueLoader) {
        self.decoratee = decoratee
    }

    public func load() async throws -> ProductCatalogue {
        if let cached { return cached }
        if let loadInProgress { return try await loadInProgress.value }

        let decoratee = self.decoratee
        let task = Task { try await decoratee.load() }
        let generationAtStart = generation
        loadInProgress = task

        do {
            let catalogue = try await task.value
            guard generation == generationAtStart else { return catalogue }
            cached = catalogue
            loadInProgress = nil
            return catalogue
        } catch {
            if generation == generationAtStart { loadInProgress = nil }
            throw error
        }
    }

    public func invalidate() {
        cached = nil
        loadInProgress = nil
        generation += 1
    }
}
