//
//  ResourceErrorView.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

public struct ResourceErrorViewModel: Equatable, Sendable {
    public let message: String?

    public init(message: String?) {
        self.message = message
    }

    public static var noError: ResourceErrorViewModel {
        ResourceErrorViewModel(message: nil)
    }

    public static func error(message: String) -> ResourceErrorViewModel {
        ResourceErrorViewModel(message: message)
    }
}

@MainActor
public protocol ResourceErrorView {
    func display(_ viewModel: ResourceErrorViewModel)
}
