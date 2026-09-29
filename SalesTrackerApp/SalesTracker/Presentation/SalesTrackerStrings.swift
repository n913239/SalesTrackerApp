//
//  SalesTrackerStrings.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

/// Internal on purpose: the words a screen shows are the presenters' business, and a client that
/// could reach past them for a raw key would be free to show something no presenter ever decided.
enum SalesTrackerStrings {
    static func localized(_ key: String) -> String {
        NSLocalizedString(
            key,
            tableName: "SalesTracker",
            bundle: Bundle(for: SalesTrackerBundleToken.self),
            comment: ""
        )
    }

    /// Shared by the list and the detail, and singular at one: "1 sales" is not English.
    static func salesCount(_ count: Int) -> String {
        count == 1
        ? localized("PRODUCT_SALES_COUNT_ONE")
        : String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), count)
    }
}

/// Locates the framework's own bundle, which is not the main bundle once the app embeds it.
final class SalesTrackerBundleToken {}
