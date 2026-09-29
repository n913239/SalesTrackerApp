//
//  LocalizationTestHelpers.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

/// Framework tests do not use `@testable`, so the only honest way to read a value is through the
/// framework's own bundle. A value that comes back equal to its key means the table never made it
/// into the bundle - fail loudly rather than assert key-against-key and pass.
func localized(
    _ key: String,
    table: String = "SalesTracker",
    file: StaticString = #filePath,
    line: UInt = #line
) -> String {
    let bundle = Bundle(for: LoginPresenter.self)
    let value = bundle.localizedString(forKey: key, value: nil, table: table)

    if value == key {
        XCTFail("Missing localized value for key \(key) in table \(table)", file: file, line: line)
    }

    return value
}
