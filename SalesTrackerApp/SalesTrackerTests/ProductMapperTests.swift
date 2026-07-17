//
//  ProductMapperTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class ProductMapperTests: XCTestCase {

    func test_map_throwsErrorOnNon200HTTPResponse() {
        let data = makeJSON([])
        for code in [199, 201, 300, 400, 500] {
            XCTAssertThrowsError(try ProductMapper.map(data, from: response(code)))
        }
    }

    func test_map_throwsErrorOn200WithInvalidJSON() {
        XCTAssertThrowsError(try ProductMapper.map(Data("bad".utf8), from: response(200)))
    }

    func test_map_deliversProductsOn200WithValidJSON() throws {
        let id = UUID()
        let json: [[String: Any]] = [["id": id.uuidString, "name": "iPhone"]]
        let result = try ProductMapper.map(makeJSON(json), from: response(200))

        XCTAssertEqual(result, [Product(id: id, name: "iPhone")])
    }

    // MARK: - Helpers

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func makeJSON(_ items: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: items)
    }
}
