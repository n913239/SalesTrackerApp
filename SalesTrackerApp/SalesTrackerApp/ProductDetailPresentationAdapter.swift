//
//  ProductDetailPresentationAdapter.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/30.
//

import Foundation
import SalesTracker

/// Owns both requests the detail needs and the order they arrive in.
///
/// The sales go on screen as soon as they land, with the USD column still converting; the rates
/// fill it in when they arrive, or mark it unavailable when they do not. Waiting for both would
/// hold an empty screen hostage to the slower of two unrelated services.
@MainActor
final class ProductDetailPresentationAdapter {
    var presenter: ProductDetailPresenter?

    private enum Leg: Sendable {
        case sales([Sale])
        case salesFailed
        case rates([CurrencyRate])
        case ratesFailed
    }

    enum LoadError: Error {
        case catalogueUnavailable
    }

    private let product: Product
    private let catalogueLoader: ProductCatalogueLoader
    private let catalogueCache: ProductCatalogueCache
    private let ratesLoader: CurrencyRatesLoader

    private var sales: [Sale]?
    private var rates: CurrencyRatesOutcome = .pending
    private var task: Task<Void, Never>?

    init(
        product: Product,
        catalogueLoader: ProductCatalogueLoader,
        catalogueCache: ProductCatalogueCache,
        ratesLoader: CurrencyRatesLoader
    ) {
        self.product = product
        self.catalogueLoader = catalogueLoader
        self.catalogueCache = catalogueCache
        self.ratesLoader = ratesLoader
    }

    deinit {
        task?.cancel()
    }

    /// The catalogue was already loaded for the list, so opening a product reads the cache.
    func load() {
        start(invalidatingCache: false)
    }

    /// A pull is the user asking for the current truth, so the cache goes first.
    func refresh() {
        start(invalidatingCache: true)
    }

    private func start(invalidatingCache: Bool) {
        task?.cancel()

        sales = nil
        rates = .pending
        presenter?.didStartLoading()

        let product = self.product
        let catalogueLoader = self.catalogueLoader
        let catalogueCache = self.catalogueCache
        let ratesLoader = self.ratesLoader

        task = Task { [weak self] in
            if invalidatingCache {
                await catalogueCache.invalidate()
            }

            await withTaskGroup(of: Leg.self) { group in
                group.addTask {
                    do { return .sales(try await catalogueLoader.load().sales(of: product)) }
                    catch { return .salesFailed }
                }

                group.addTask {
                    do { return .rates(try await ratesLoader.load()) }
                    catch { return .ratesFailed }
                }

                for await leg in group {
                    guard !Task.isCancelled else { return }
                    self?.handle(leg)
                }
            }
        }
    }

    private func handle(_ leg: Leg) {
        switch leg {
        case let .sales(sales):
            self.sales = sales
            present()

        case .salesFailed:
            presenter?.didFinishLoading(with: LoadError.catalogueUnavailable)

        case let .rates(rates):
            self.rates = .loaded(rates)
            present()

        case .ratesFailed:
            self.rates = .failed
            present()
        }
    }

    /// Nothing is drawn until the sales are known: the rates alone have nothing to be applied to.
    private func present() {
        guard let sales else { return }
        presenter?.didFinishLoading(with: sales, rates: rates)
    }
}
