//
//  SceneDelegate.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/7/17.
//

import UIKit
import SalesTracker

@MainActor
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private lazy var httpClient: HTTPClient = URLSessionHTTPClient(
        session: URLSession(configuration: .ephemeral)
    )
    private lazy var tokenStore: TokenStore = KeychainTokenStore()

    private var navigationController: UINavigationController?

    private lazy var authenticatedClient: HTTPClient = AuthenticatedHTTPClientDecorator(
        decoratee: httpClient,
        tokenStore: tokenStore,
        onUnauthorized: { [weak self] in
            Task { @MainActor in self?.lockApp() }
        }
    )

    override init() {
        super.init()
    }

    convenience init(httpClient: HTTPClient, tokenStore: TokenStore) {
        self.init()
        self.httpClient = httpClient
        self.tokenStore = tokenStore
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        configureWindow()
    }

    func configureWindow() {
        // A stored token means the session survived the last launch, so the list is shown straight
        // away. An expired one is caught by the first request, which sends the user back here.
        if tokenStore.retrieve() != nil {
            showProductList()
        } else {
            showLogin()
        }

        window?.makeKeyAndVisible()
    }

    // MARK: - Screens

    private func showLogin() {
        let loginService = LoginService(client: httpClient, tokenStore: tokenStore, url: Endpoint.login)

        let login = SalesTrackerUIComposer.makeLogin(loginService: loginService) { [weak self] in
            self?.showProductList()
        }

        navigationController = nil
        window?.rootViewController = UINavigationController(rootViewController: login)
    }

    private func showProductList() {
        let list = SalesTrackerUIComposer.makeProductList(
            catalogue: { [weak self] in try await self?.loadCatalogue() ?? ProductCatalogue(products: [], sales: []) },
            onSelect: { [weak self] product in self?.showProductDetail(for: product) }
        )

        let navigationController = UINavigationController(rootViewController: list)
        self.navigationController = navigationController
        window?.rootViewController = navigationController
    }

    private func showProductDetail(for product: Product) {
        let detail = SalesTrackerUIComposer.makeProductDetail(
            product: product,
            catalogue: { [weak self] in try await self?.loadCatalogue() ?? ProductCatalogue(products: [], sales: []) },
            rates: { [weak self] in try await self?.loadRates() ?? [] }
        )

        navigationController?.pushViewController(detail, animated: true)
    }

    /// A 401 can come back from any request on any screen, and the token only lives for two
    /// minutes. Handling it here - once - is what makes "lock the app and show the login screen
    /// again" true everywhere, rather than only on the one screen that happened to check.
    private func lockApp() {
        try? tokenStore.delete()
        showLogin()
    }

    // MARK: - Loading

    private func loadCatalogue() async throws -> ProductCatalogue {
        async let products = RemoteLoader(url: Endpoint.products, client: authenticatedClient, mapper: ProductMapper.map).load()
        async let sales = RemoteLoader(url: Endpoint.sales, client: authenticatedClient, mapper: SaleMapper.map).load()

        return ProductCatalogue(products: try await products, sales: try await sales)
    }

    private func loadRates() async throws -> [CurrencyRate] {
        // The rates endpoint needs no token, so it goes to the plain client: a 401 from it would
        // otherwise sign the user out of a service that never authenticated them.
        try await RemoteLoader(url: Endpoint.rates, client: httpClient, mapper: CurrencyRateMapper.map).load()
    }

}
