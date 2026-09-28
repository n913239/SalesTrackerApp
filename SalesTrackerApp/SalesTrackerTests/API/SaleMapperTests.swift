//
//  SaleMapperTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/28.
//

import XCTest
import SalesTracker

final class SaleMapperTests: XCTestCase {

    func test_map_throwsErrorOnNon200HTTPResponse() {
        let json = makeSalesJSON([])

        for code in [199, 201, 300, 400, 500] {
            XCTAssertThrowsError(
                try SaleMapper.map(json, from: response(code)),
                "Expected to throw for status code \(code)"
            )
        }
    }

    func test_map_deliversSalesOn200WithValidJSON() throws {
        let productId = UUID()
        let json = makeSalesJSON([
            [
                "currency_code": "BRL",
                "amount": "2299.00",
                "product_id": productId.uuidString,
                "date": "2030-01-02T11:00:00.000Z"
            ]
        ])

        let sales = try SaleMapper.map(json, from: response(200))

        XCTAssertEqual(sales, [
            Sale(
                currencyCode: "BRL",
                amount: Decimal(string: "2299.00")!,
                productId: productId,
                date: Date(timeIntervalSince1970: 1_893_582_000)
            )
        ])
    }

    func test_map_acceptsADateWithoutFractionalSeconds() throws {
        let json = makeSalesJSON([
            [
                "currency_code": "USD",
                "amount": "10.00",
                "product_id": UUID().uuidString,
                "date": "2030-01-02T11:00:00Z"
            ]
        ])

        let sales = try SaleMapper.map(json, from: response(200))

        XCTAssertEqual(sales.first?.date, Date(timeIntervalSince1970: 1_893_582_000))
    }

    func test_map_throwsErrorOnAnAmountThatIsNotANumber() {
        let json = makeSalesJSON([
            [
                "currency_code": "USD",
                "amount": "not a number",
                "product_id": UUID().uuidString,
                "date": "2030-01-02T11:00:00.000Z"
            ]
        ])

        XCTAssertThrowsError(try SaleMapper.map(json, from: response(200)))
    }

    func test_map_throwsErrorOnADateInAnUnsupportedFormat() {
        let json = makeSalesJSON([
            [
                "currency_code": "USD",
                "amount": "10.00",
                "product_id": UUID().uuidString,
                "date": "02/01/2030"
            ]
        ])

        XCTAssertThrowsError(try SaleMapper.map(json, from: response(200)))
    }

    // MARK: - Helpers

    private func makeSalesJSON(_ items: [[String: String]]) -> Data {
        try! JSONSerialization.data(withJSONObject: items)
    }

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any-url.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}
