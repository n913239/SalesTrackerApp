//
//  KeychainTokenStoreTests.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import Security
import SalesTracker

final class KeychainTokenStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try? emptyTheKeychain()
    }

    override func tearDown() {
        try? emptyTheKeychain()
        super.tearDown()
    }

    func test_retrieve_deliversNilOnEmptyStore() {
        let sut = makeSUT()

        XCTAssertNil(sut.retrieve())
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

        XCTAssertEqual(sut.retrieve(), "second-token", "A second login must replace the token, not fail or duplicate it")
    }

    func test_retrieve_afterDelete_deliversNil() throws {
        let sut = makeSUT()
        try sut.save("a-token")

        try sut.delete()

        XCTAssertNil(sut.retrieve())
    }

    func test_delete_onEmptyStore_doesNotThrow() {
        let sut = makeSUT()

        XCTAssertNoThrow(try sut.delete())
    }

    func test_save_storesTheTokenSoItCannotLeaveTheDevice() throws {
        let sut = makeSUT()

        try sut.save("a-token")

        XCTAssertEqual(
            savedAccessibility(),
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String,
            "Without ThisDeviceOnly the token is included in iCloud and iTunes backups and can be restored onto another device"
        )
    }

    // MARK: - Helpers

    private let service = "com.salestracker.tests.token"
    private let account = "access-token"

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> KeychainTokenStore {
        let sut = KeychainTokenStore(service: service, account: account)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    /// Not through makeSUT: tracking a leak registers a teardown block, and doing that from
    /// tearDown itself is an API violation.
    private func emptyTheKeychain() throws {
        try KeychainTokenStore(service: service, account: account).delete()
    }

    private func savedAccessibility() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any] else { return nil }

        return attributes[kSecAttrAccessible as String] as? String
    }
}
