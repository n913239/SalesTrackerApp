//
//  RemoteProductCatalogueLoader.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

/// One catalogue out of two endpoints. The two requests are independent, so they go out together
/// and the screen waits for the slower one rather than for their sum.
public final class RemoteProductCatalogueLoader: ProductCatalogueLoader {
    private let client: HTTPClient
    private let productsURL: URL
    private let salesURL: URL

    public init(client: HTTPClient, productsURL: URL, salesURL: URL) {
        self.client = client
        self.productsURL = productsURL
        self.salesURL = salesURL
    }

    public func load() async throws -> ProductCatalogue {
        async let products = RemoteLoader(url: productsURL, client: client, mapper: ProductMapper.map).load()
        async let sales = RemoteLoader(url: salesURL, client: client, mapper: SaleMapper.map).load()

        return ProductCatalogue(products: try await products, sales: try await sales)
    }
}
