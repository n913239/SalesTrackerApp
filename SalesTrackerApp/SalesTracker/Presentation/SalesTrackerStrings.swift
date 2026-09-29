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
}

/// Locates the framework's own bundle, which is not the main bundle once the app embeds it.
final class SalesTrackerBundleToken {}
