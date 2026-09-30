//
//  LoginPresenter.swift
//  SalesTracker
//
//  Created by mike on 2026/9/29.
//

import Foundation

@MainActor
public final class LoginPresenter {
    public static var title: String { SalesTrackerStrings.localized("LOGIN_TITLE") }
    public static var usernamePlaceholder: String { SalesTrackerStrings.localized("LOGIN_USERNAME_PLACEHOLDER") }
    public static var passwordPlaceholder: String { SalesTrackerStrings.localized("LOGIN_PASSWORD_PLACEHOLDER") }
    public static var loginButtonTitle: String { SalesTrackerStrings.localized("LOGIN_BUTTON_TITLE") }

    private let loadingView: ResourceLoadingView
    private let errorView: ResourceErrorView

    public init(loadingView: ResourceLoadingView, errorView: ResourceErrorView) {
        self.loadingView = loadingView
        self.errorView = errorView
    }

    public func didStartLogin() {
        loadingView.display(ResourceLoadingViewModel(isLoading: true))
        errorView.display(.noError)
    }

    public func didFinishLogin() {
        loadingView.display(ResourceLoadingViewModel(isLoading: false))
    }

    public func didFinishLogin(with error: LoginService.Error) {
        errorView.display(.error(message: message(for: error)))
        loadingView.display(ResourceLoadingViewModel(isLoading: false))
    }

    // MARK: - Helpers

    private func message(for error: LoginService.Error) -> String {
        switch error {
        case let .invalidCredentials(message):
            message ?? SalesTrackerStrings.localized("LOGIN_INVALID_CREDENTIALS")
        case .connectivity:
            SalesTrackerStrings.localized("LOGIN_CONNECTION_FAILED")
        case .tokenNotStored:
            SalesTrackerStrings.localized("LOGIN_TOKEN_NOT_STORED")
        }
    }
}
