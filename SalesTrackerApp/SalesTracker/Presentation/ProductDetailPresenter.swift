//
//  ProductDetailPresenter.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public struct SaleViewModel: Equatable {
    public let amount: String
    public let date: String
    /// `nil` when there is no rate for that currency. The view shows that it is unknown; it never
    /// falls back to the amount in the sale's own currency dressed up as dollars.
    public let amountInUSD: String?

    public init(amount: String, date: String, amountInUSD: String?) {
        self.amount = amount
        self.date = date
        self.amountInUSD = amountInUSD
    }
}

public struct ProductDetailViewModel: Equatable {
    public let title: String
    public let subtitle: String
    public let sales: [SaleViewModel]

    public init(title: String, subtitle: String, sales: [SaleViewModel]) {
        self.title = title
        self.subtitle = subtitle
        self.sales = sales
    }
}

public struct ProductDetailPresenter {
    private let formatter: SalesFormatter

    public init(formatter: SalesFormatter = SalesFormatter()) {
        self.formatter = formatter
    }

    /// `converter` is `nil` while the rates have not arrived - the middleware cold-starts in about
    /// fourteen seconds, and the sales are the user's data: they go on screen straight away. Without
    /// rates there is no honest total to show, so the subtitle reports the count alone.
    public func viewModel(
        for product: Product,
        sales: [Sale],
        converter: CurrencyConverter?
    ) -> ProductDetailViewModel {
        ProductDetailViewModel(
            title: product.name,
            subtitle: subtitle(for: sales, converter: converter),
            sales: sales.map { sale in
                SaleViewModel(
                    amount: formatter.amount(sale.amount, currency: sale.currencyCode),
                    date: formatter.date(sale.date),
                    amountInUSD: converter?.amountInUSD(sale.amount, currency: sale.currencyCode).map(formatter.usd)
                )
            }
        )
    }

    // MARK: - Helpers

    private func subtitle(for sales: [Sale], converter: CurrencyConverter?) -> String {
        let count = SalesTrackerStrings.salesCount(sales.count)

        guard let converter else {
            return String(format: SalesTrackerStrings.localized("PRODUCT_DETAIL_SUBTITLE_WITHOUT_RATES_FORMAT"), count)
        }

        return subtitle(
            total: converter.totalInUSD(sales.map { (amount: $0.amount, currency: $0.currencyCode) }),
            salesCount: count
        )
    }

    private func subtitle(total: CurrencyConverter.Total, salesCount: String) -> String {
        var subtitle = String(
            format: SalesTrackerStrings.localized("PRODUCT_DETAIL_SUBTITLE_FORMAT"),
            formatter.usd(total.amount),
            salesCount
        )

        if total.unconvertibleCount > 0 {
            let missing = String(
                format: SalesTrackerStrings.localized("PRODUCT_DETAIL_UNCONVERTIBLE_FORMAT"),
                total.unconvertibleCount
            )
            subtitle += " · " + missing
        }

        return subtitle
    }
}
