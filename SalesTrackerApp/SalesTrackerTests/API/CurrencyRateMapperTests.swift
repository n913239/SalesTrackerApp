//
//  CurrencyRateMapperTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
//

import XCTest
import SalesTracker

final class CurrencyRateMapperTests: XCTestCase {

    func test_map_throwsErrorOnNon200HTTPResponse() {
        let json = makeRatesJSON([])

        for code in [199, 201, 300, 400, 500] {
            XCTAssertThrowsError(
                try CurrencyRateMapper.map(json, from: response(code)),
                "Expected to throw for status code \(code)"
            )
        }
    }

    func test_map_throwsErrorOn200WithInvalidJSON() {
        XCTAssertThrowsError(try CurrencyRateMapper.map(Data("invalid json".utf8), from: response(200)))
    }

    func test_map_deliversRatesOn200WithValidJSON() throws {
        let json = makeRatesJSON([
            ["from": "EUR", "to": "USD", "rate": 1.18],
            ["from": "BRL", "to": "USD", "rate": 0.18]
        ])

        let rates = try CurrencyRateMapper.map(json, from: response(200))

        XCTAssertEqual(rates, [
            CurrencyRate(from: "EUR", to: "USD", rate: Decimal(string: "1.18")!),
            CurrencyRate(from: "BRL", to: "USD", rate: Decimal(string: "0.18")!)
        ])
    }

    func test_map_keepsTheFullPrecisionOfTheRate() throws {
        let json = makeRatesJSON([["from": "EUR", "to": "USD", "rate": 1.18]])

        let rates = try CurrencyRateMapper.map(json, from: response(200))

        XCTAssertEqual(rates.first?.rate, Decimal(string: "1.18")!)
        XCTAssertNotEqual(rates.first?.rate, Decimal(1.18))
    }

    // MARK: - Helpers

    private func makeRatesJSON(_ items: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: items)
    }

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any-url.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}
