//
//  EndpointTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
//

import XCTest
import SalesTracker

final class EndpointTests: XCTestCase {

    func test_login_appendsTheLoginPathToTheBaseURL() {
        XCTAssertEqual(Endpoint.login.url(baseURL: baseURL()).absoluteString, "https://any-host.com/login")
    }

    func test_products_appendsTheProductsPathToTheBaseURL() {
        XCTAssertEqual(Endpoint.products.url(baseURL: baseURL()).absoluteString, "https://any-host.com/products")
    }

    func test_sales_appendsTheSalesPathToTheBaseURL() {
        XCTAssertEqual(Endpoint.sales.url(baseURL: baseURL()).absoluteString, "https://any-host.com/sales")
    }

    func test_rates_appendsTheRatesPathToTheBaseURL() {
        XCTAssertEqual(Endpoint.rates.url(baseURL: baseURL()).absoluteString, "https://any-host.com/rates")
    }

    // MARK: - Helpers

    private func baseURL() -> URL {
        URL(string: "https://any-host.com")!
    }
}
