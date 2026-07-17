//
//  CurrencyRate.swift
//  SalesTracker
//
//  Created by mike on 2026/7/18.
//

import Foundation

public struct CurrencyRate: Equatable {
    public let from: String
    public let to: String
    public let rate: Decimal

    public init(from: String, to: String, rate: Decimal) {
        self.from = from
        self.to = to
        self.rate = rate
    }
}
