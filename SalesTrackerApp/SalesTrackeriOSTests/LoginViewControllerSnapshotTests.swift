//
//  LoginViewControllerSnapshotTests.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class LoginViewControllerSnapshotTests: XCTestCase {

    func test_LOGIN_EMPTY_light() {
        let (sut, _) = makeSUT()

        assert(snapshot: sut.snapshot(for: .iPhone(style: .light)), named: "LOGIN_EMPTY_light")
    }

    func test_LOGIN_ERROR_dark() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLogin(with: .invalidCredentials(message: nil))

        assert(snapshot: sut.snapshot(for: .iPhone(style: .dark)), named: "LOGIN_ERROR_dark")
    }

    func test_LOGIN_ERROR_XXXL() {
        let (sut, presenter) = makeSUT()

        presenter.didFinishLogin(with: .invalidCredentials(message: nil))

        assert(
            snapshot: sut.snapshot(for: .iPhone(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)),
            named: "LOGIN_ERROR_XXXL"
        )
    }

    func test_LOGIN_LOADING_light() {
        let (sut, presenter) = makeSUT()

        presenter.didStartLogin()

        assert(snapshot: sut.snapshot(for: .iPhone(style: .light)), named: "LOGIN_LOADING_light")
    }

    // MARK: - Helpers

    private func makeSUT() -> (LoginViewController, LoginPresenter) {
        let sut = LoginViewController()
        sut.loadViewIfNeeded()
        return (sut, LoginPresenter(loadingView: sut, errorView: sut))
    }
}
