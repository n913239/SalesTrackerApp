//
//  LoginMapper.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public enum LoginMapper {
    private struct TokenResponse: Decodable { let access_token: String }
    private struct ErrorResponse: Decodable { let message: String }

    public enum Error: Swift.Error, Equatable {
        /// Carries the server's own message: it is the only thing that knows why the credentials
        /// were rejected.
        case invalidCredentials(message: String)
        case invalidData
    }

    public static func map(_ data: Data, from response: HTTPURLResponse) throws -> String {
        if response.statusCode == 401 {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
            throw Error.invalidCredentials(message: message ?? defaultInvalidCredentialsMessage)
        }

        guard response.statusCode == 200,
              let result = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw Error.invalidData
        }

        return result.access_token
    }

    private static var defaultInvalidCredentialsMessage: String {
        SalesTrackerStrings.localized("LOGIN_INVALID_CREDENTIALS")
    }
}
