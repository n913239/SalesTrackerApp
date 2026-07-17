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

    public func viewModel(
        for product: Product,
        sales: [Sale],
        converter: CurrencyConverter
    ) -> ProductDetailViewModel {
        let total = converter.totalInUSD(sales.map { (amount: $0.amount, currency: $0.currencyCode) })

        return ProductDetailViewModel(
            title: product.name,
            subtitle: subtitle(total: total, salesCount: sales.count),
            sales: sales.map { sale in
                SaleViewModel(
                    amount: formatter.amount(sale.amount, currency: sale.currencyCode),
                    date: formatter.date(sale.date),
                    amountInUSD: converter.amountInUSD(sale.amount, currency: sale.currencyCode).map(formatter.usd)
                )
            }
        )
    }

    // MARK: - Helpers

    private func subtitle(total: CurrencyConverter.Total, salesCount: Int) -> String {
        let sales = SalesTrackerStrings.salesCount(salesCount)
        var subtitle = String(
            format: SalesTrackerStrings.localized("PRODUCT_DETAIL_SUBTITLE_FORMAT"),
            formatter.usd(total.amount),
            sales
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
