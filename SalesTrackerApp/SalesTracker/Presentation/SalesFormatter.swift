//
//  SalesFormatter.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

/// The locale is injected rather than read from the device, so the same sale reads the same way in
/// a test, on CI and in a screenshot. Fraction digits are pinned to two: left to the default, a
/// sale of 999.99 rounds to 1,000 and the cents disappear.
public struct SalesFormatter {
    private let currencyFormatter: NumberFormatter
    private let usdFormatter: NumberFormatter

    public init(locale: Locale = Locale(identifier: "en_US")) {
        currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.locale = locale
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2

        usdFormatter = NumberFormatter()
        usdFormatter.numberStyle = .currency
        usdFormatter.locale = locale
        usdFormatter.currencyCode = "USD"
        usdFormatter.minimumFractionDigits = 2
        usdFormatter.maximumFractionDigits = 2
    }

    public func amount(_ amount: Decimal, currency: String) -> String {
        currencyFormatter.currencyCode = currency
        return currencyFormatter.string(from: amount as NSDecimalNumber) ?? "\(currency) \(amount)"
    }

    public func usd(_ amount: Decimal) -> String {
        usdFormatter.string(from: amount as NSDecimalNumber) ?? "US$\(amount)"
    }
}
