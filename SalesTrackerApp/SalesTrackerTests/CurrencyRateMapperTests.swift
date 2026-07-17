//
//  CurrencyRateMapperTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class CurrencyRateMapperTests: XCTestCase {

    func test_map_throwsErrorOnNon200HTTPResponse() {
        let data = makeJSON([])

        XCTAssertThrowsError(try CurrencyRateMapper.map(data, from: response(400)))
    }

    func test_map_throwsErrorOn200WithInvalidJSON() {
        let data = Data("not json".utf8)

        XCTAssertThrowsError(try CurrencyRateMapper.map(data, from: response(200)))
    }

    func test_map_deliversRatesOn200WithValidJSON() throws {
        let json: [[String: Any]] = [
            ["from": "EUR", "to": "USD", "rate": 1.18],
            ["from": "JPY", "to": "USD", "rate": 0.0092512]
        ]

        let result = try CurrencyRateMapper.map(makeJSON(json), from: response(200))

        XCTAssertEqual(result, [
            CurrencyRate(from: "EUR", to: "USD", rate: decimal("1.18")),
            CurrencyRate(from: "JPY", to: "USD", rate: decimal("0.0092512"))
        ])
    }

    func test_map_keepsTheFullPrecisionOfTheRate() throws {
        let json: [[String: Any]] = [["from": "JPY", "to": "USD", "rate": 0.009251200000000001]]

        let result = try CurrencyRateMapper.map(makeJSON(json), from: response(200))

        XCTAssertEqual(
            result.first?.rate,
            decimal("0.009251200000000001"),
            "A rounded rate silently changes every converted amount"
        )
    }

    // MARK: - Helpers

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func makeJSON(_ items: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: items)
    }

    /// Built from decimal text, not a literal, which would lose exactness through Double.
    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value)!
    }
}
