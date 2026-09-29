//
//  KeychainTokenStoreTests.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import Security
import SalesTracker

final class KeychainTokenStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try? makeSUT().delete()
    }

    override func tearDown() {
        try? makeSUT().delete()
        super.tearDown()
    }

    func test_retrieve_deliversNilOnEmptyStore() {
        XCTAssertNil(makeSUT().retrieve())
    }

    func test_retrieve_deliversTheSavedToken() throws {
        let sut = makeSUT()

        try sut.save("a-token")

        XCTAssertEqual(sut.retrieve(), "a-token")
    }

    func test_save_overwritesAPreviouslySavedToken() throws {
        let sut = makeSUT()

        try sut.save("first-token")
        try sut.save("second-token")

        XCTAssertEqual(sut.retrieve(), "second-token")
    }

    func test_retrieve_afterDelete_deliversNil() throws {
        let sut = makeSUT()
        try sut.save("a-token")

        try sut.delete()

        XCTAssertNil(sut.retrieve())
    }

    func test_delete_onEmptyStore_doesNotThrow() {
        XCTAssertNoThrow(try makeSUT().delete())
    }

    func test_save_storesTheTokenSoItCannotLeaveTheDevice() throws {
        try makeSUT().save("a-token")

        XCTAssertEqual(storedAccessibility() as String?, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> KeychainTokenStore {
        KeychainTokenStore(service: testService, account: testAccount)
    }

    private var testService: String { "com.salestracker.tests.token" }
    private var testAccount: String { "test-access-token" }

    private func storedAccessibility() -> CFString? {
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testService,
            kSecAttrAccount as String: testAccount,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any] else { return nil }

        return attributes[kSecAttrAccessible as String] as! CFString?
    }
}
