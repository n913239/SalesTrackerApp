//
//  LoginPresenterTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

@MainActor
final class LoginPresenterTests: XCTestCase {

    func test_init_doesNotSendMessagesToView() {
        let (_, view) = makeSUT()

        XCTAssertEqual(view.messages, [])
    }

    func test_didStartLogin_showsLoadingAndClearsThePreviousError() {
        let (sut, view) = makeSUT()

        sut.didStartLogin()

        XCTAssertEqual(view.messages, [.loading(true), .errorMessage(nil)])
    }

    func test_didFinishLogin_stopsLoading() {
        let (sut, view) = makeSUT()

        sut.didFinishLogin()

        XCTAssertEqual(view.messages, [.loading(false)])
    }

    func test_didFinishLoginWithInvalidCredentials_showsTheServersMessage() {
        let (sut, view) = makeSUT()

        sut.didFinishLogin(with: .invalidCredentials(message: "Wrong username or password"))

        XCTAssertEqual(view.messages, [.errorMessage("Wrong username or password"), .loading(false)])
    }

    func test_didFinishLoginWithInvalidCredentialsWithoutAMessage_showsTheDefaultMessage() {
        let (sut, view) = makeSUT()

        sut.didFinishLogin(with: .invalidCredentials(message: nil))

        XCTAssertEqual(view.messages, [.errorMessage(localized("LOGIN_INVALID_CREDENTIALS")), .loading(false)])
    }

    func test_didFinishLoginWithConnectivityError_showsTheConnectionMessage() {
        let (sut, view) = makeSUT()

        sut.didFinishLogin(with: .connectivity)

        XCTAssertEqual(view.messages, [.errorMessage(localized("LOGIN_CONNECTION_FAILED")), .loading(false)])
    }

    func test_didFinishLoginWithTokenNotStored_saysTheSessionWasNotSaved() {
        let (sut, view) = makeSUT()

        sut.didFinishLogin(with: .tokenNotStored)

        XCTAssertEqual(view.messages, [.errorMessage(localized("LOGIN_TOKEN_NOT_STORED")), .loading(false)])
    }

    func test_staticLabels_comeFromTheStringsTable() {
        XCTAssertEqual(LoginPresenter.title, localized("LOGIN_TITLE"))
        XCTAssertEqual(LoginPresenter.usernamePlaceholder, localized("LOGIN_USERNAME_PLACEHOLDER"))
        XCTAssertEqual(LoginPresenter.passwordPlaceholder, localized("LOGIN_PASSWORD_PLACEHOLDER"))
        XCTAssertEqual(LoginPresenter.loginButtonTitle, localized("LOGIN_BUTTON_TITLE"))
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (LoginPresenter, ViewSpy) {
        let view = ViewSpy()
        let sut = LoginPresenter(loadingView: view, errorView: view)
        trackForMemoryLeaks(view, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, view)
    }
}

@MainActor
final class ViewSpy: ResourceLoadingView, ResourceErrorView {
    enum Message: Equatable {
        case loading(Bool)
        case errorMessage(String?)
    }

    private(set) var messages: [Message] = []

    func display(_ viewModel: ResourceLoadingViewModel) {
        messages.append(.loading(viewModel.isLoading))
    }

    func display(_ viewModel: ResourceErrorViewModel) {
        messages.append(.errorMessage(viewModel.message))
    }
}
