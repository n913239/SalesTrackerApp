//
//  CurrencyRateMapper.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public enum CurrencyRateMapper {
    private struct RemoteRate: Decodable {
        let from: String
        let to: String
        let rate: Double
    }

    public enum Error: Swift.Error { case invalidData }

    public static func map(_ data: Data, from response: HTTPURLResponse) throws -> [CurrencyRate] {
        guard response.statusCode == 200,
              let items = try? JSONDecoder().decode([RemoteRate].self, from: data) else {
            throw Error.invalidData
        }

        return items.map {
            CurrencyRate(from: $0.from, to: $0.to, rate: decimal(from: $0.rate))
        }
    }

    /// Decoding a JSON number straight into `Decimal` still routes it through `Double` (1.18 ->
    /// 1.1799999999999999). Rebuilding from the double's shortest round-trip text recovers it.
    private static func decimal(from rate: Double) -> Decimal {
        Decimal(string: String(rate)) ?? Decimal(rate)
    }
}
