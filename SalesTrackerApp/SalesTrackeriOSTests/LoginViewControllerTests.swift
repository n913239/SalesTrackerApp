//
//  LoginViewControllerTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class LoginViewControllerTests: XCTestCase {

    func test_loginButton_isDisabledUntilBothCredentialsAreEntered() {
        let sut = makeSUT()

        XCTAssertFalse(sut.loginButton.isEnabled, "Expected the button to start disabled")

        sut.usernameField.simulateTyping("tester")
        XCTAssertFalse(sut.loginButton.isEnabled, "Expected the button to stay disabled with no password")

        sut.passwordField.simulateTyping("password")
        XCTAssertTrue(sut.loginButton.isEnabled, "Expected the button to be enabled once both are entered")

        sut.usernameField.simulateTyping("")
        XCTAssertFalse(sut.loginButton.isEnabled, "Expected the button to disable again when a field is cleared")
    }

    func test_credentialFields_doNotLetTheKeyboardRewriteWhatIsTyped() {
        let sut = makeSUT()

        XCTAssertEqual(sut.usernameField.autocorrectionType, .no)
        XCTAssertEqual(sut.usernameField.autocapitalizationType, .none)
        XCTAssertEqual(sut.passwordField.autocorrectionType, .no)
        XCTAssertEqual(sut.passwordField.autocapitalizationType, .none)
        XCTAssertTrue(sut.passwordField.isSecureTextEntry)
    }

    func test_tappingLogin_handsOverTheTypedCredentials() {
        var received: [(username: String, password: String)] = []
        let sut = makeSUT { received.append((username: $0, password: $1)) }

        sut.usernameField.simulateTyping("tester")
        sut.passwordField.simulateTyping("password")
        sut.loginButton.simulateTap()

        XCTAssertEqual(received.map(\.username), ["tester"])
        XCTAssertEqual(received.map(\.password), ["password"])
    }

    func test_displayLoading_disablesTheInputsAndSpins() {
        let sut = makeSUT()
        sut.usernameField.simulateTyping("tester")
        sut.passwordField.simulateTyping("password")

        sut.display(ResourceLoadingViewModel(isLoading: true))

        XCTAssertFalse(sut.usernameField.isEnabled)
        XCTAssertFalse(sut.passwordField.isEnabled)
        XCTAssertFalse(sut.loginButton.isEnabled, "Expected no second login while one is in flight")
        XCTAssertTrue(sut.activityIndicator.isAnimating)
    }

    func test_displayLoadingFalse_enablesTheInputsAgain() {
        let sut = makeSUT()
        sut.usernameField.simulateTyping("tester")
        sut.passwordField.simulateTyping("password")
        sut.display(ResourceLoadingViewModel(isLoading: true))

        sut.display(ResourceLoadingViewModel(isLoading: false))

        XCTAssertTrue(sut.usernameField.isEnabled)
        XCTAssertTrue(sut.passwordField.isEnabled)
        XCTAssertTrue(sut.loginButton.isEnabled)
        XCTAssertFalse(sut.activityIndicator.isAnimating)
    }

    func test_displayError_showsTheMessage_andNoErrorHidesIt() {
        let sut = makeSUT()

        sut.display(.error(message: "a message"))

        XCTAssertTrue(sut.isShowingError)
        XCTAssertEqual(sut.errorMessage, "a message")

        sut.display(.noError)

        XCTAssertFalse(sut.isShowingError)
    }

    func test_labels_comeFromTheStringsTable() {
        let sut = makeSUT()

        XCTAssertEqual(sut.title, LoginPresenter.title)
        XCTAssertEqual(sut.usernameField.placeholder, LoginPresenter.usernamePlaceholder)
        XCTAssertEqual(sut.passwordField.placeholder, LoginPresenter.passwordPlaceholder)
        XCTAssertEqual(sut.loginButton.configuration?.title, LoginPresenter.loginButtonTitle)
    }

    // MARK: - Helpers

    private func makeSUT(
        onLogin: @escaping (String, String) -> Void = { _, _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LoginViewController {
        let sut = LoginViewController()
        sut.onLogin = onLogin
        trackForMemoryLeaks(sut, file: file, line: line)
        sut.simulateAppearance()
        return sut
    }
}

private extension LoginViewController {
    var usernameField: UITextField { view(withIdentifier: AccessibilityIdentifier.username)! }
    var passwordField: UITextField { view(withIdentifier: AccessibilityIdentifier.password)! }
    var loginButton: UIButton { view(withIdentifier: AccessibilityIdentifier.button)! }
    var activityIndicator: UIActivityIndicatorView {
        view.firstDescendant { $0 is UIActivityIndicatorView } as! UIActivityIndicatorView
    }
}
