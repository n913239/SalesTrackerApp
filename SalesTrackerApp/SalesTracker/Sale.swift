//
//  Sale.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public struct Sale: Equatable {
    public let currencyCode: String
    public let amount: Decimal
    public let productId: UUID
    public let date: Date

    public init(currencyCode: String, amount: Decimal, productId: UUID, date: Date) {
        self.currencyCode = currencyCode
        self.amount = amount
        self.productId = productId
        self.date = date
    }
}
