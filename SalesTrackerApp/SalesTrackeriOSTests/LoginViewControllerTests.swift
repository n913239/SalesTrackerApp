//
//  LoginViewControllerTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

final class LoginViewControllerTests: UILayerTestCase {

    func test_loginButton_isDisabledUntilBothCredentialsAreEntered() {
        let sut = makeSUT()

        XCTAssertFalse(sut.loginButton.isEnabled, "Expected the button to be disabled with no credentials")

        sut.usernameField.simulateTyping("tester")
        XCTAssertFalse(sut.loginButton.isEnabled, "Expected the button to be disabled with no password")

        sut.passwordField.simulateTyping("password")
        XCTAssertTrue(sut.loginButton.isEnabled, "Expected the button to be enabled with both credentials")

        sut.usernameField.simulateTyping("")
        XCTAssertFalse(sut.loginButton.isEnabled, "Expected the button to be disabled again once the username is cleared")
    }

    func test_credentialFields_doNotLetTheKeyboardRewriteWhatIsTyped() {
        let sut = makeSUT()

        XCTAssertEqual(sut.usernameField.autocorrectionType, .no)
        XCTAssertEqual(sut.usernameField.autocapitalizationType, UITextAutocapitalizationType.none)
        XCTAssertTrue(sut.passwordField.isSecureTextEntry)
    }

    func test_login_passesTheTypedCredentials() async {
        var received = [(username: String, password: String)]()
        let sut = makeSUT { username, password in
            received.append((username, password))
            return nil
        }

        sut.usernameField.simulateTyping("tester")
        sut.passwordField.simulateTyping("password")
        sut.loginButton.simulateTap()

        await waitUntil { received.count == 1 }
        XCTAssertEqual(received.first?.username, "tester")
        XCTAssertEqual(received.first?.password, "password")
    }

    /// The live server takes about forty-six seconds to reject a wrong password. The screen has to
    /// say it is working, and it must not accept a second attempt while the first is in flight.
    func test_login_showsProgressAndBlocksInputWhileItIsInFlight() async {
        let inFlight = Signal()
        let sut = makeSUT { _, _ in
            await inFlight.wait()
            return nil
        }

        sut.usernameField.simulateTyping("tester")
        sut.passwordField.simulateTyping("password")
        sut.loginButton.simulateTap()

        await waitUntil { sut.activityIndicator.isAnimating }
        XCTAssertFalse(sut.loginButton.isEnabled, "Expected the button to be disabled while logging in")
        XCTAssertFalse(sut.usernameField.isEnabled, "Expected the username field to be disabled while logging in")
        XCTAssertFalse(sut.passwordField.isEnabled, "Expected the password field to be disabled while logging in")

        inFlight.complete()

        await waitUntil { !sut.activityIndicator.isAnimating }
        XCTAssertTrue(sut.loginButton.isEnabled, "Expected the button to be enabled again once the login finished")
        XCTAssertTrue(sut.usernameField.isEnabled, "Expected the username field to be enabled again")
    }

    func test_login_displaysTheErrorMessageOnFailure() async {
        let sut = makeSUT { _, _ in "Invalid credentials." }

        XCTAssertTrue(sut.errorLabel.isHidden, "Expected no error before logging in")

        sut.usernameField.simulateTyping("tester")
        sut.passwordField.simulateTyping("wrong")
        sut.loginButton.simulateTap()

        await waitUntil { !sut.errorLabel.isHidden }
        XCTAssertEqual(sut.errorLabel.text, "Invalid credentials.")
    }

    func test_login_hidesAPreviousErrorOnSuccess() async {
        var message: String? = "Invalid credentials."
        let sut = makeSUT { _, _ in message }

        sut.usernameField.simulateTyping("tester")
        sut.passwordField.simulateTyping("wrong")
        sut.loginButton.simulateTap()
        await waitUntil { !sut.errorLabel.isHidden }

        message = nil
        sut.passwordField.simulateTyping("password")
        sut.loginButton.simulateTap()

        await waitUntil { sut.errorLabel.isHidden }
        XCTAssertNil(sut.errorLabel.text)
    }

    // MARK: - Helpers

    private func makeSUT(
        onLogin: @escaping (String, String) async -> String? = { _, _ in nil },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LoginViewController {
        let sut = LoginViewController()
        sut.onLogin = onLogin
        trackForMemoryLeaks(sut, file: file, line: line)
        sut.loadViewIfNeeded()
        return sut
    }

    /// Holds the login open so the test can look at the screen while the request is still running.
    ///
    /// The lock is not decoration: `onLogin` is a nonisolated async closure, so it runs off the main
    /// actor while `complete()` is called on it. Without the lock the waiting side can read a stale
    /// `isComplete`, park a continuation nobody will ever resume, and hang the test.
    private final class Signal: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Never>?
        private var isComplete = false

        func wait() async {
            await withCheckedContinuation { continuation in
                lock.lock()
                if isComplete {
                    lock.unlock()
                    continuation.resume()
                } else {
                    self.continuation = continuation
                    lock.unlock()
                }
            }
        }

        func complete() {
            lock.lock()
            isComplete = true
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()

            continuation?.resume()
        }
    }
}

private extension LoginViewController {
    var usernameField: UITextField { view(withIdentifier: AccessibilityIdentifier.username)! }
    var passwordField: UITextField { view(withIdentifier: AccessibilityIdentifier.password)! }
    var loginButton: UIButton { view(withIdentifier: AccessibilityIdentifier.loginButton)! }
    var errorLabel: UILabel { view(withIdentifier: AccessibilityIdentifier.errorLabel)! }
    var activityIndicator: UIActivityIndicatorView { view.firstDescendant { $0 is UIActivityIndicatorView } as! UIActivityIndicatorView }
}
