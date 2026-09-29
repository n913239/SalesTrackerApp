//
//  LoginMapper.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

public enum LoginMapper {
    private struct TokenResponse: Decodable { let access_token: String }
    private struct ErrorResponse: Decodable { let message: String }

    public enum Error: Swift.Error, Equatable {
        /// Carries the server's own message when there is one, and `nil` when there is not.
        /// Choosing the words a person reads is presentation work, so the API layer reports the
        /// absence and lets the presenter decide what to say instead.
        case invalidCredentials(message: String?)
        case invalidData
    }

    public static func map(_ data: Data, from response: HTTPURLResponse) throws -> String {
        if response.statusCode == 401 {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
            throw Error.invalidCredentials(message: message)
        }

        guard response.statusCode == 200,
              let result = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw Error.invalidData
        }

        return result.access_token
    }
}
