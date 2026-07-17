//
//  LoginMapperTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

final class LoginMapperTests: XCTestCase {

    func test_map_on401_deliversTheServersOwnMessage() {
        let data = try! JSONSerialization.data(withJSONObject: ["message": "Invalid credentials."])

        XCTAssertThrowsError(try LoginMapper.map(data, from: response(401))) { error in
            XCTAssertEqual(error as? LoginMapper.Error, .invalidCredentials(message: "Invalid credentials."))
        }
    }

    func test_map_on401_withoutAMessage_stillReportsInvalidCredentials() {
        let data = Data("{}".utf8)

        XCTAssertThrowsError(try LoginMapper.map(data, from: response(401))) { error in
            guard case .invalidCredentials = error as? LoginMapper.Error else {
                return XCTFail("Expected invalidCredentials, got \(error) instead")
            }
        }
    }

    func test_map_deliversTokenOn200() throws {
        let data = try! JSONSerialization.data(withJSONObject: ["access_token": "abc123"])

        let token = try LoginMapper.map(data, from: response(200))

        XCTAssertEqual(token, "abc123")
    }

    func test_map_throwsInvalidDataOn200WithInvalidJSON() {
        let data = Data("not json".utf8)

        XCTAssertThrowsError(try LoginMapper.map(data, from: response(200))) { error in
            XCTAssertEqual(error as? LoginMapper.Error, .invalidData)
        }
    }

    func test_map_throwsErrorOnNon200Non401() {
        let data = Data("{}".utf8)

        XCTAssertThrowsError(try LoginMapper.map(data, from: response(500))) { error in
            XCTAssertEqual(error as? LoginMapper.Error, .invalidData)
        }
    }

    // MARK: - Helpers

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}
