//
//  LoginViewController.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/7/18.
//

import UIKit

public final class LoginViewController: UIViewController {

    enum AccessibilityIdentifier {
        static let username = "login-username-field"
        static let password = "login-password-field"
        static let loginButton = "login-button"
        static let errorLabel = "login-error-label"
    }

    /// Returns an error message to display, or nil when the login succeeded.
    public var onLogin: ((_ username: String, _ password: String) async -> String?)?

    private let usernameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Username"
        field.borderStyle = .roundedRect
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.textContentType = .username
        field.accessibilityIdentifier = AccessibilityIdentifier.username
        return field
    }()

    private let passwordField: UITextField = {
        let field = UITextField()
        field.placeholder = "Password"
        field.borderStyle = .roundedRect
        field.isSecureTextEntry = true
        field.textContentType = .password
        field.accessibilityIdentifier = AccessibilityIdentifier.password
        return field
    }()

    private let loginButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Log in"
        let button = UIButton(configuration: configuration)
        button.isEnabled = false
        button.accessibilityIdentifier = AccessibilityIdentifier.loginButton
        return button
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .systemRed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.accessibilityIdentifier = AccessibilityIdentifier.errorLabel
        return label
    }()

    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Sales Tracker"

        usernameField.addTarget(self, action: #selector(credentialsChanged), for: .editingChanged)
        passwordField.addTarget(self, action: #selector(credentialsChanged), for: .editingChanged)
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [usernameField, passwordField, loginButton, activityIndicator, errorLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Actions

    @objc private func credentialsChanged() {
        loginButton.isEnabled = !username.isEmpty && !password.isEmpty
    }

    @objc private func loginTapped() {
        Task { await login() }
    }

    private func login() async {
        setBusy(true)

        let message = await onLogin?(username, password)

        setBusy(false)
        display(error: message)
    }

    private func setBusy(_ isBusy: Bool) {
        loginButton.isEnabled = !isBusy && !username.isEmpty && !password.isEmpty
        usernameField.isEnabled = !isBusy
        passwordField.isEnabled = !isBusy
        isBusy ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    private func display(error message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
    }

    // MARK: - Helpers

    private var username: String {
        usernameField.text ?? ""
    }

    private var password: String {
        passwordField.text ?? ""
    }
}
