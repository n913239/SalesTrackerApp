//
//  Endpoint.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public enum Endpoint {
    private static let baseURL = "https://ile-b2p4.essentialdeveloper.com"
    private static let middlewareURL = "https://salesmiddleware.onrender.com"

    public static var login: URL { URL(string: "\(baseURL)/login")! }
    public static var products: URL { URL(string: "\(baseURL)/products")! }
    public static var sales: URL { URL(string: "\(baseURL)/sales")! }
    public static var rates: URL { URL(string: "\(middlewareURL)/rates")! }
}
