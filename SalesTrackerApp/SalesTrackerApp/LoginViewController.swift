//
//  LoginViewController.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/29.
//

import UIKit
import SalesTracker

/// Holds no state and decides nothing: it reports what the user typed and renders what it is
/// told. Every word on it comes from the presenter, and the request it triggers belongs to
/// whoever set `onLogin`.
public final class LoginViewController: UIViewController, ResourceLoadingView, ResourceErrorView {

    enum AccessibilityIdentifier {
        static let username = "login.username"
        static let password = "login.password"
        static let button = "login.button"
        static let errorLabel = "login.errorLabel"
    }

    public var onLogin: ((_ username: String, _ password: String) -> Void)?

    private let usernameField: UITextField = {
        let field = UITextField()
        field.placeholder = LoginPresenter.usernamePlaceholder
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.textContentType = .username
        field.accessibilityIdentifier = AccessibilityIdentifier.username
        return field
    }()

    private let passwordField: UITextField = {
        let field = UITextField()
        field.placeholder = LoginPresenter.passwordPlaceholder
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.isSecureTextEntry = true
        field.textContentType = .password
        field.accessibilityIdentifier = AccessibilityIdentifier.password
        return field
    }()

    private let loginButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = LoginPresenter.loginButtonTitle
        let button = UIButton(configuration: configuration)
        button.isEnabled = false
        button.accessibilityIdentifier = AccessibilityIdentifier.button
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

    private var isLoading = false

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = LoginPresenter.title

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

    // MARK: - ResourceLoadingView

    public func display(_ viewModel: ResourceLoadingViewModel) {
        isLoading = viewModel.isLoading

        usernameField.isEnabled = !isLoading
        passwordField.isEnabled = !isLoading
        updateLoginButton()

        isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    // MARK: - ResourceErrorView

    public func display(_ viewModel: ResourceErrorViewModel) {
        errorLabel.text = viewModel.message
        errorLabel.isHidden = viewModel.message == nil
    }

    // MARK: - Actions

    @objc private func credentialsChanged() {
        updateLoginButton()
    }

    @objc private func loginTapped() {
        onLogin?(username, password)
    }

    // MARK: - Helpers

    private func updateLoginButton() {
        loginButton.isEnabled = !isLoading && !username.isEmpty && !password.isEmpty
    }

    private var username: String { usernameField.text ?? "" }
    private var password: String { passwordField.text ?? "" }
}
