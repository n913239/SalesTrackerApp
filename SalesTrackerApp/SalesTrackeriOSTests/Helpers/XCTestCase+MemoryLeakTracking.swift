//
//  XCTestCase+MemoryLeakTracking.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/28.
//

import XCTest

extension XCTestCase {
    @MainActor
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { @MainActor [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}
