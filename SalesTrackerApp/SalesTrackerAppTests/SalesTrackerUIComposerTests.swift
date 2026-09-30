//
//  SalesTrackerUIComposerTests.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/30.
//

import XCTest
import SalesTracker
@testable import SalesTrackerApp

@MainActor
final class SalesTrackerUIComposerTests: XCTestCase {

    func test_makeLogin_releasesTheScreenWhileALoginIsInFlight() async {
        let client = HTTPClientStub()
        let loginURL = URL(string: "https://a-backend.com/login")!
        await client.stub(loginURL, with: tokenJSON("a-token"))
        await client.hang(loginURL)

        var sut: LoginViewController? = SalesTrackerUIComposer.makeLogin(
            loginService: LoginService(client: client, tokenStore: TokenStoreSpy(), url: loginURL),
            onSuccess: {}
        )
        weak var weakSUT = sut

        sut?.simulateAppearance()
        sut?.onLogin?("tester", "password")
        await waitUntil("the login is in flight") { await client.isHoldingARequest }
        sut = nil
        await drainPendingWork()

        XCTAssertNil(weakSUT, "A login in flight must not keep the screen alive")
        await client.cancelPendingRequests()
    }

    func test_makeProductList_releasesTheScreenWhileALoadIsInFlight() async {
        let loader = CatalogueLoaderStub()
        await loader.hangLoads()

        var sut: ProductListViewController? = SalesTrackerUIComposer.makeProductList(
            catalogueLoader: loader,
            catalogueCache: CacheSpy(),
            onSelect: { _ in }
        )
        weak var weakSUT = sut

        sut?.simulateAppearance()
        await waitUntil("the load is in flight") { await loader.isHoldingALoad }
        sut = nil
        await drainPendingWork()

        XCTAssertNil(weakSUT, "A load in flight must not keep the screen alive")
        await loader.cancelPendingRequests()
    }

    func test_makeProductDetail_releasesTheScreenWhileALoadIsInFlight() async {
        let loader = CatalogueLoaderStub()
        let rates = RatesLoaderStub()
        await loader.hangLoads()
        await rates.hangLoads()

        var sut: ProductDetailViewController? = SalesTrackerUIComposer.makeProductDetail(
            product: makeProduct(named: "iPhone"),
            catalogueLoader: loader,
            catalogueCache: CacheSpy(),
            ratesLoader: rates
        )
        weak var weakSUT = sut

        sut?.simulateAppearance()
        await waitUntil("the load is in flight") { await loader.isHoldingALoad }
        sut = nil
        await drainPendingWork()

        XCTAssertNil(weakSUT, "A load in flight must not keep the screen alive")
        await loader.cancelPendingRequests()
        await rates.cancelPendingRequests()
    }
}
