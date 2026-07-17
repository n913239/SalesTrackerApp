//
//  CurrencyConverter.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

/// `amountInUSD` returns `nil` rather than guess: without a rate, presenting 126,944 JPY as
/// US$126,944 would invent money that reaches the user as real.
public struct CurrencyConverter {
    public struct Total: Equatable {
        public let amount: Decimal
        public let unconvertibleCount: Int

        public init(amount: Decimal, unconvertibleCount: Int) {
            self.amount = amount
            self.unconvertibleCount = unconvertibleCount
        }
    }

    private static let usd = "USD"

    private let ratesToUSD: [String: Decimal]

    public init(rates: [CurrencyRate]) {
        var ratesToUSD = [String: Decimal]()
        for rate in rates where rate.to == Self.usd {
            ratesToUSD[rate.from] = rate.rate
        }
        self.ratesToUSD = ratesToUSD
    }

    public func amountInUSD(_ amount: Decimal, currency: String) -> Decimal? {
        guard currency != Self.usd else { return amount }
        guard let rate = ratesToUSD[currency] else { return nil }
        return amount * rate
    }

    public func totalInUSD(_ amounts: [(amount: Decimal, currency: String)]) -> Total {
        var total = Decimal.zero
        var unconvertibleCount = 0

        for entry in amounts {
            if let converted = amountInUSD(entry.amount, currency: entry.currency) {
                total += converted
            } else {
                unconvertibleCount += 1
            }
        }

        return Total(amount: total, unconvertibleCount: unconvertibleCount)
    }
}
