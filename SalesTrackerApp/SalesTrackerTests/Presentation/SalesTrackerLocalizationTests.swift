//
//  SalesTrackerLocalizationTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

final class SalesTrackerLocalizationTests: XCTestCase {

    func test_localizedStrings_haveKeysAndValuesForAllSupportedLocalizations() {
        let table = "SalesTracker"
        let bundle = Bundle(for: LoginPresenter.self)
        let localizationBundles = allLocalizationBundles(in: bundle, file: #filePath, line: #line)
        let keys = allLocalizedStringKeys(in: localizationBundles, table: table)

        for (localizationBundle, localization) in localizationBundles {
            for key in keys {
                let value = localizationBundle.localizedString(forKey: key, value: nil, table: table)

                if value == key {
                    XCTFail("Missing \(localization) localized string for key: '\(key)' in table: '\(table)'")
                }
            }
        }
    }

    // MARK: - Helpers

    private typealias LocalizedBundle = (bundle: Bundle, localization: String)

    private func allLocalizationBundles(in bundle: Bundle, file: StaticString, line: UInt) -> [LocalizedBundle] {
        bundle.localizations.compactMap { localization in
            guard let path = bundle.path(forResource: localization, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else {
                XCTFail("Couldn't find bundle for localization: \(localization)", file: file, line: line)
                return nil
            }

            return (localizedBundle, localization)
        }
    }

    private func allLocalizedStringKeys(in bundles: [LocalizedBundle], table: String) -> Set<String> {
        bundles.reduce([]) { acc, current in
            guard let path = current.bundle.path(forResource: table, ofType: "strings"),
                  let strings = NSDictionary(contentsOfFile: path),
                  let keys = strings.allKeys as? [String] else {
                XCTFail("Couldn't load localized strings for localization: \(current.localization)")
                return acc
            }

            return acc.union(Set(keys))
        }
    }
}
