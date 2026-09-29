//
//  ProductDetailPresenter.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

public struct SaleViewModel: Equatable, Sendable {
    public let amount: String
    public let date: String
    public let amountInUSD: String
    public let isConverted: Bool

    public init(amount: String, date: String, amountInUSD: String, isConverted: Bool) {
        self.amount = amount
        self.date = date
        self.amountInUSD = amountInUSD
        self.isConverted = isConverted
    }
}

public struct ProductDetailViewModel: Equatable, Sendable {
    public let subtitle: String
    public let sales: [SaleViewModel]
    public let emptyMessage: String?

    public init(subtitle: String, sales: [SaleViewModel], emptyMessage: String?) {
        self.subtitle = subtitle
        self.sales = sales
        self.emptyMessage = emptyMessage
    }
}

@MainActor
public protocol ProductDetailView {
    func display(_ viewModel: ProductDetailViewModel)
}

/// Stateless on purpose: it is handed everything it needs to draw one frame, and nothing it draws
/// depends on what it drew before. Deciding which of the two requests has arrived is sequencing,
/// and sequencing lives in the adapter that owns the requests.
@MainActor
public final class ProductDetailPresenter {
    private let detailView: ProductDetailView
    private let loadingView: ResourceLoadingView
    private let errorView: ResourceErrorView
    private let formatter: SalesFormatter

    public init(
        detailView: ProductDetailView,
        loadingView: ResourceLoadingView,
        errorView: ResourceErrorView,
        formatter: SalesFormatter
    ) {
        self.detailView = detailView
        self.loadingView = loadingView
        self.errorView = errorView
        self.formatter = formatter
    }

    public func didStartLoading() {
        loadingView.display(ResourceLoadingViewModel(isLoading: true))
        errorView.display(.noError)
    }

    public func didFinishLoading(with sales: [Sale], rates: [CurrencyRate]) {
        let converter = CurrencyConverter(rates: rates)

        detailView.display(ProductDetailViewModel(
            subtitle: subtitle(for: sales, converter: converter),
            sales: sales.map { row(for: $0, converter: converter) },
            emptyMessage: sales.isEmpty ? SalesTrackerStrings.localized("EMPTY_SALES_MESSAGE") : nil
        ))
        loadingView.display(ResourceLoadingViewModel(isLoading: false))
    }

    /// The rows and the summary stay exactly as they are: a failed refresh is news, not a reason
    /// to empty a screen the user was reading.
    public func didFinishLoading(with error: Error) {
        errorView.display(.error(message: SalesTrackerStrings.localized("LOAD_FAILED_MESSAGE")))
        loadingView.display(ResourceLoadingViewModel(isLoading: false))
    }

    // MARK: - Helpers

    private func row(for sale: Sale, converter: CurrencyConverter) -> SaleViewModel {
        let converted = converter.amountInUSD(sale.amount, currency: sale.currencyCode)

        return SaleViewModel(
            amount: formatter.amount(sale.amount, currency: sale.currencyCode),
            date: formatter.date(sale.date),
            amountInUSD: converted.map(formatter.usd) ?? SalesTrackerStrings.localized("USD_UNAVAILABLE"),
            isConverted: converted != nil
        )
    }

    private func subtitle(for sales: [Sale], converter: CurrencyConverter) -> String {
        let total = converter.totalInUSD(sales.map { (amount: $0.amount, currency: $0.currencyCode) })

        let converted = String(
            format: SalesTrackerStrings.localized("PRODUCT_DETAIL_SUBTITLE_FORMAT"),
            formatter.usd(total.amount),
            SalesTrackerStrings.salesCount(sales.count)
        )

        guard total.unconvertibleCount > 0 else { return converted }

        return String(
            format: SalesTrackerStrings.localized("PRODUCT_DETAIL_UNCONVERTIBLE_FORMAT"),
            converted,
            total.unconvertibleCount
        )
    }
}
