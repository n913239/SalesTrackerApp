//
//  ProductCatalogueLoader.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

/// The catalogue the list and the detail both read from.
public protocol ProductCatalogueLoader: Sendable {
    func load() async throws -> ProductCatalogue
}

/// Separated from loading (CQS): a pull to refresh invalidates the cached catalogue, and the
/// next `load()` decides on its own what to do about that.
public protocol ProductCatalogueCache: Sendable {
    func invalidate() async
}

public protocol CurrencyRatesLoader: Sendable {
    func load() async throws -> [CurrencyRate]
}
