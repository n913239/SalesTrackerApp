//
//  Endpoint.swift
//  SalesTracker
//
//  Created by mike on 2026/9/28.
//

import Foundation

/// Knows the paths the API is laid out in, not the host it lives on. The base URL is injected by
/// the composition root, so the framework carries no environment of its own.
public enum Endpoint: Sendable {
    case login
    case products
    case sales
    case rates

    public func url(baseURL: URL) -> URL {
        baseURL.appendingPathComponent(path)
    }

    private var path: String {
        switch self {
        case .login: "login"
        case .products: "products"
        case .sales: "sales"
        case .rates: "rates"
        }
    }
}
