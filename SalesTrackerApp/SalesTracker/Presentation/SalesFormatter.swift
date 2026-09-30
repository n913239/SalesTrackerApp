//
//  SalesFormatter.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

/// The locale is injected rather than read from the device, so the same sale reads the same way in
/// a test, on CI and in a screenshot. Fraction digits are pinned to two: left to the currency's
/// default, a JPY sale of 126,944.29 would lose its .29.
///
/// The time zone defaults to the device's: a sale made at 3:45 PM local time is what the person
/// holding the phone remembers, not the same instant rewritten in UTC. Tests and screenshots pin
/// it so the output does not move with the machine.
public struct SalesFormatter {
    private let currencyFormatter: NumberFormatter
    private let usdFormatter: NumberFormatter
    private let dateFormatter: DateFormatter

    public init(locale: Locale = Locale(identifier: "en_US"), timeZone: TimeZone = .current) {
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
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
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
