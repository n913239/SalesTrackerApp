//
//  TokenStore.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

public enum TokenStoreError: Error, Equatable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}

public protocol TokenStore: Sendable {
    func save(_ token: String) throws
    func retrieve() -> String?
    func delete() throws
}
