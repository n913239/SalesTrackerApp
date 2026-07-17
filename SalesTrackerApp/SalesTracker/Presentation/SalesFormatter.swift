//
//  SalesFormatter.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

/// The locale, calendar and time zone are injected rather than read from the device, so the same
/// sale reads the same way in a test, on CI and in a screenshot. Fraction digits are pinned to two:
/// left to the default, a sale of 999.99 rounds to 1,000 and the cents disappear.
public struct SalesFormatter {
    private let currencyFormatter: NumberFormatter
    private let usdFormatter: NumberFormatter
    private let dateFormatter: DateFormatter

    public init(
        locale: Locale = Locale(identifier: "en_US"),
        timeZone: TimeZone = TimeZone(identifier: "UTC") ?? .current
    ) {
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

        dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h a"
    }

    public func amount(_ amount: Decimal, currency: String) -> String {
        currencyFormatter.currencyCode = currency
        return currencyFormatter.string(from: amount as NSDecimalNumber) ?? "\(currency) \(amount)"
    }

    public func usd(_ amount: Decimal) -> String {
        usdFormatter.string(from: amount as NSDecimalNumber) ?? "US$\(amount)"
    }

    public func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
