//
//  TokenStore.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation
import Security

public enum TokenStoreError: Error, Equatable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}

public protocol TokenStore {
    func save(_ token: String) throws
    func retrieve() -> String?
    func delete() throws
}

public final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String

    public init(service: String = "com.salestracker.token", account: String = "access-token") {
        self.service = service
        self.account = account
    }

    public func save(_ token: String) throws {
        let data = Data(token.utf8)

        let updateStatus = SecItemUpdate(
            query() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecSuccess { return }

        guard updateStatus == errSecItemNotFound else {
            throw TokenStoreError.saveFailed(updateStatus)
        }

        var attributes = query()
        attributes[kSecValueData as String] = data
        // ThisDeviceOnly keeps the token out of iCloud and iTunes backups, so it cannot be
        // restored onto another device. The default accessibility does not.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw TokenStoreError.saveFailed(addStatus)
        }
    }

    public func retrieve() -> String? {
        var lookup = query()
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func delete() throws {
        let status = SecItemDelete(query() as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.deleteFailed(status)
        }
    }

    // MARK: - Helpers

    private func query() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
