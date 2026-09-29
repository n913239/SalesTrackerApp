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

/// The rates are a third state, not a missing array: "not here yet" and "not coming" read
/// differently to a person, and flattening them into `[]` is what made a failed rates request look
/// like a product with no sales.
public enum CurrencyRatesOutcome: Equatable, Sendable {
    case pending
    case loaded([CurrencyRate])
    case failed
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

    public func didFinishLoading(with sales: [Sale], rates: CurrencyRatesOutcome) {
        detailView.display(ProductDetailViewModel(
            subtitle: subtitle(for: sales, rates: rates),
            sales: sales.map { row(for: $0, rates: rates) },
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

    private func row(for sale: Sale, rates: CurrencyRatesOutcome) -> SaleViewModel {
        let amount = formatter.amount(sale.amount, currency: sale.currencyCode)
        let date = formatter.date(sale.date)

        switch rates {
        case .pending:
            return SaleViewModel(
                amount: amount,
                date: date,
                amountInUSD: SalesTrackerStrings.localized("USD_PENDING"),
                isConverted: false
            )

        case .failed:
            return SaleViewModel(
                amount: amount,
                date: date,
                amountInUSD: SalesTrackerStrings.localized("USD_UNAVAILABLE"),
                isConverted: false
            )

        case let .loaded(rates):
            let converted = CurrencyConverter(rates: rates).amountInUSD(sale.amount, currency: sale.currencyCode)
            return SaleViewModel(
                amount: amount,
                date: date,
                amountInUSD: converted.map(formatter.usd) ?? SalesTrackerStrings.localized("USD_UNAVAILABLE"),
                isConverted: converted != nil
            )
        }
    }

    private func subtitle(for sales: [Sale], rates: CurrencyRatesOutcome) -> String {
        let count = SalesTrackerStrings.salesCount(sales.count)

        switch rates {
        case .pending:
            return String(format: SalesTrackerStrings.localized("PRODUCT_DETAIL_SUBTITLE_WITHOUT_RATES_FORMAT"), count)

        // The count survives the failure: the sales were loaded, and hiding how many there are
        // because a second, unrelated request failed is what made the screen look empty.
        case .failed:
            return String(format: SalesTrackerStrings.localized("PRODUCT_DETAIL_SUBTITLE_RATES_FAILED_FORMAT"), count)

        case let .loaded(rates):
            let total = CurrencyConverter(rates: rates)
                .totalInUSD(sales.map { (amount: $0.amount, currency: $0.currencyCode) })

            let converted = String(
                format: SalesTrackerStrings.localized("PRODUCT_DETAIL_SUBTITLE_FORMAT"),
                formatter.usd(total.amount),
                count
            )

            guard total.unconvertibleCount > 0 else { return converted }

            return String(
                format: SalesTrackerStrings.localized("PRODUCT_DETAIL_UNCONVERTIBLE_FORMAT"),
                converted,
                total.unconvertibleCount
            )
        }
    }
}
