//
//  SaleMapper.swift
//  SalesTracker
//
//  Created by mike on 2026/9/28.
//

import Foundation

public enum SaleMapper {
    private struct RemoteSale: Decodable {
        let currency_code: String
        let amount: String
        let product_id: UUID
        let date: String
    }

    public enum Error: Swift.Error { case invalidData }

    @Sendable public static func map(_ data: Data, from response: HTTPURLResponse) throws -> [Sale] {
        guard response.statusCode == 200,
              let items = try? JSONDecoder().decode([RemoteSale].self, from: data) else {
            throw Error.invalidData
        }

        // Built per response rather than held in a static: a shared formatter would be mutable
        // state crossing isolation domains, and two allocations per response cost nothing next
        // to decoding the response itself.
        let formatters = makeDateFormatters()

        return try items.map { item in
            // Built from the decimal text, never from a binary double: 1.18 as a Double is
            // 1.1799999999999999, and money that drifts by a cent per row is money lost.
            guard let amount = Decimal(string: item.amount),
                  let date = date(from: item.date, using: formatters) else {
                throw Error.invalidData
            }
            return Sale(
                currencyCode: item.currency_code,
                amount: amount,
                productId: item.product_id,
                date: date
            )
        }
    }

    /// The live feed sends fractional seconds, but one row without them must not fail the whole list.
    private static func makeDateFormatters() -> [ISO8601DateFormatter] {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        return [withFractionalSeconds, withoutFractionalSeconds]
    }

    private static func date(from string: String, using formatters: [ISO8601DateFormatter]) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
