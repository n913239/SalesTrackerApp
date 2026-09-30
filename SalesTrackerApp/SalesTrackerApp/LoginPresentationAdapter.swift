//
//  LoginPresentationAdapter.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/30.
//

import Foundation
import SalesTracker

/// Owns the one Task a login needs. The view controller reports a tap, the presenter decides what
/// the screen says, and the work in between lives here: adapters are the only place in the app
/// target allowed to start anything.
@MainActor
final class LoginPresentationAdapter {
    var presenter: LoginPresenter?

    private let loginService: LoginService
    private let onSuccess: () -> Void
    private var task: Task<Void, Never>?

    init(loginService: LoginService, onSuccess: @escaping () -> Void) {
        self.loginService = loginService
        self.onSuccess = onSuccess
    }

    deinit {
        task?.cancel()
    }

    func login(username: String, password: String) {
        // A second attempt supersedes the first, so a slow reply to abandoned credentials can
        // never overwrite the newer one.
        task?.cancel()

        presenter?.didStartLogin()

        let loginService = self.loginService

        task = Task { [weak self] in
            do {
                try await loginService.login(username: username, password: password)
                guard !Task.isCancelled else { return }
                self?.presenter?.didFinishLogin()
                self?.onSuccess()
            } catch {
                guard !Task.isCancelled else { return }
                self?.presenter?.didFinishLogin(with: error as? LoginService.Error ?? .connectivity)
            }
        }
    }
}
