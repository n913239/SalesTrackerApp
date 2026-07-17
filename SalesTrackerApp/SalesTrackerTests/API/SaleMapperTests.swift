//
//  SaleMapperTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class SaleMapperTests: XCTestCase {

    func test_map_throwsErrorOnNon200HTTPResponse() {
        let data = makeJSON([])
        for code in [199, 201, 400, 500] {
            XCTAssertThrowsError(try SaleMapper.map(data, from: response(code)))
        }
    }

    func test_map_deliversSalesOn200WithValidJSON() throws {
        let id = UUID()
        let json: [[String: Any]] = [[
            "currency_code": "EUR",
            "amount": "999.99",
            "product_id": id.uuidString,
            "date": "2024-07-20T15:45:27.366Z"
        ]]
        let result = try SaleMapper.map(makeJSON(json), from: response(200))

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.currencyCode, "EUR")
        XCTAssertEqual(result.first?.amount, 999.99)
        XCTAssertEqual(result.first?.productId, id)
    }

    // MARK: - Helpers

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func makeJSON(_ items: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: items)
    }
}
