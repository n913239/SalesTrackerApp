//
//  ResourceLoadingView.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

public struct ResourceLoadingViewModel: Equatable, Sendable {
    public let isLoading: Bool

    public init(isLoading: Bool) {
        self.isLoading = isLoading
    }
}

@MainActor
public protocol ResourceLoadingView {
    func display(_ viewModel: ResourceLoadingViewModel)
}
