//
//  LoginService.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public final class LoginService {
    public enum Error: Swift.Error, Equatable {
        case invalidCredentials(message: String)
        case connectivity
        /// The credentials were accepted but the token could not be stored, so the next launch would
        /// silently ask for them again. Reporting it as connectivity would send the user to check a
        /// network that is working fine.
        case tokenNotStored
    }

    private struct Credentials: Encodable {
        let username: String
        let password: String
    }

    private let client: HTTPClient
    private let tokenStore: TokenStore
    private let url: URL

    public init(client: HTTPClient, tokenStore: TokenStore, url: URL) {
        self.client = client
        self.tokenStore = tokenStore
        self.url = url
    }

    public func login(username: String, password: String) async throws {
        let body: Data
        do {
            body = try JSONEncoder().encode(Credentials(username: username, password: password))
        } catch {
            throw Error.connectivity
        }

        let token: String
        do {
            let (data, response) = try await client.post(to: url, body: body, headers: [:])
            token = try LoginMapper.map(data, from: response)
        } catch let error as LoginMapper.Error {
            switch error {
            case let .invalidCredentials(message):
                throw Error.invalidCredentials(message: message)
            case .invalidData:
                throw Error.connectivity
            }
        } catch {
            throw Error.connectivity
        }

        do {
            try tokenStore.save(token)
        } catch {
            throw Error.tokenNotStored
        }
    }
}
