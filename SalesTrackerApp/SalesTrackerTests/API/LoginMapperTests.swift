//
//  LoginMapperTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

final class LoginMapperTests: XCTestCase {

    func test_map_on401_deliversTheServersOwnMessage() {
        let json = try! JSONSerialization.data(withJSONObject: ["message": "Wrong username or password"])

        XCTAssertThrowsError(try LoginMapper.map(json, from: response(401))) { error in
            XCTAssertEqual(error as? LoginMapper.Error, .invalidCredentials(message: "Wrong username or password"))
        }
    }

    func test_map_on401_withoutAMessage_deliversInvalidCredentialsWithNoMessage() {
        XCTAssertThrowsError(try LoginMapper.map(Data("{}".utf8), from: response(401))) { error in
            XCTAssertEqual(error as? LoginMapper.Error, .invalidCredentials(message: nil))
        }
    }

    func test_map_deliversTokenOn200() throws {
        let json = try JSONSerialization.data(withJSONObject: ["access_token": "a-token"])

        XCTAssertEqual(try LoginMapper.map(json, from: response(200)), "a-token")
    }

    func test_map_throwsInvalidDataOn200WithInvalidJSON() {
        XCTAssertThrowsError(try LoginMapper.map(Data("invalid json".utf8), from: response(200))) { error in
            XCTAssertEqual(error as? LoginMapper.Error, .invalidData)
        }
    }

    func test_map_throwsErrorOnNon200Non401() {
        for code in [199, 201, 300, 400, 500] {
            XCTAssertThrowsError(
                try LoginMapper.map(Data("{}".utf8), from: response(code)),
                "Expected to throw for status code \(code)"
            ) { error in
                XCTAssertEqual(error as? LoginMapper.Error, .invalidData)
            }
        }
    }

    // MARK: - Helpers

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any-url.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}
