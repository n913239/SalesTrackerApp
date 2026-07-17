//
//  SaleMapper.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
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

    /// The live feed sends fractional seconds, but one row without them must not fail the whole list.
    private static let dateFormatters: [ISO8601DateFormatter] = {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        return [withFractionalSeconds, withoutFractionalSeconds]
    }()

    public static func map(_ data: Data, from response: HTTPURLResponse) throws -> [Sale] {
        guard response.statusCode == 200,
              let items = try? JSONDecoder().decode([RemoteSale].self, from: data) else {
            throw Error.invalidData
        }

        return try items.map { item in
            guard let amount = Decimal(string: item.amount),
                  let date = date(from: item.date) else {
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

    private static func date(from string: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
