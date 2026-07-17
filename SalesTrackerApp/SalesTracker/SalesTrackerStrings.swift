//
//  SalesTrackerStrings.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public enum SalesTrackerStrings {
    public static func localized(_ key: String) -> String {
        NSLocalizedString(
            key,
            tableName: "SalesTracker",
            bundle: Bundle(for: SalesTrackerBundleToken.self),
            comment: ""
        )
    }

    /// Shared by the list and the detail, and singular at one: "1 sales" is not English.
    public static func salesCount(_ count: Int) -> String {
        count == 1
        ? localized("PRODUCT_SALES_COUNT_ONE")
        : String(format: localized("PRODUCT_SALES_COUNT_FORMAT"), count)
    }
}

/// Locates the framework's own bundle, which is not the main bundle once the app embeds it.
final class SalesTrackerBundleToken {}
