//
//  ProductMapperTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
//

import XCTest
import SalesTracker

final class ProductMapperTests: XCTestCase {

    func test_map_throwsErrorOnNon200HTTPResponse() throws {
        let json = makeProductsJSON([])

        for code in [199, 201, 300, 400, 500] {
            XCTAssertThrowsError(
                try ProductMapper.map(json, from: response(code)),
                "Expected to throw for status code \(code)"
            )
        }
    }

    func test_map_throwsErrorOn200WithInvalidJSON() {
        XCTAssertThrowsError(try ProductMapper.map(Data("invalid json".utf8), from: response(200)))
    }

    func test_map_deliversProductsOn200WithValidJSON() throws {
        let first = UUID()
        let second = UUID()
        let json = makeProductsJSON([
            ["id": first.uuidString, "name": "iPhone"],
            ["id": second.uuidString, "name": "iPad"]
        ])

        let products = try ProductMapper.map(json, from: response(200))

        XCTAssertEqual(products, [Product(id: first, name: "iPhone"), Product(id: second, name: "iPad")])
    }

    // MARK: - Helpers

    private func makeProductsJSON(_ items: [[String: String]]) -> Data {
        try! JSONSerialization.data(withJSONObject: items)
    }

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any-url.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}
