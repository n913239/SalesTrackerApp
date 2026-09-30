//
//  SceneDelegate.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/28.
//

import UIKit
import SalesTracker

/// The composition root. It knows which host the app talks to and which screen comes after which,
/// and it builds the objects that do the work - but it never does any of that work itself.
@MainActor
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    /// The only place in the app that names a host. Everything below takes a URL it is given.
    private let backendURL = URL(string: "https://ile-b2p4.essentialdeveloper.com")!
    private let middlewareURL = URL(string: "https://sales-middleware.n913239.workers.dev")!

    private lazy var httpClient: HTTPClient = URLSessionHTTPClient(
        session: URLSession(configuration: .ephemeral)
    )
    private lazy var tokenStore: TokenStore = KeychainTokenStore()

    private lazy var authenticatedClient: HTTPClient = AuthenticatedHTTPClientDecorator(
        decoratee: httpClient,
        tokenStore: tokenStore,
        onUnauthorized: { [weak self] in self?.lockApp() }
    )

    private var navigationController: UINavigationController?

    /// Scoped to a login session: the list builds it, the detail shares it, and a 401 throws the
    /// whole thing away with the token.
    private var catalogueLoader: CachingProductCatalogueLoader?

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
        // Expiry is not checked here: the first request made with an expired token locks the app.
        if tokenStore.retrieve() != nil {
            showProductList()
        } else {
            showLogin()
        }

        window?.makeKeyAndVisible()
    }

    // MARK: - Screens

    private func showLogin() {
        let login = SalesTrackerUIComposer.makeLogin(
            loginService: LoginService(
                client: httpClient,
                tokenStore: tokenStore,
                url: Endpoint.login.url(baseURL: backendURL)
            ),
            onSuccess: { [weak self] in self?.showProductList() }
        )

        navigationController = nil
        catalogueLoader = nil
        window?.rootViewController = UINavigationController(rootViewController: login)
    }

    private func showProductList() {
        let catalogueLoader = CachingProductCatalogueLoader(
            decoratee: RemoteProductCatalogueLoader(
                client: authenticatedClient,
                productsURL: Endpoint.products.url(baseURL: backendURL),
                salesURL: Endpoint.sales.url(baseURL: backendURL)
            )
        )
        self.catalogueLoader = catalogueLoader

        let list = SalesTrackerUIComposer.makeProductList(
            catalogueLoader: catalogueLoader,
            catalogueCache: catalogueLoader,
            onSelect: { [weak self] product in self?.showProductDetail(for: product) }
        )

        let navigationController = UINavigationController(rootViewController: list)
        self.navigationController = navigationController
        window?.rootViewController = navigationController
    }

    /// A 401 can come back from any request on any screen, because the token can expire at any
    /// time. Handling it here - once - is what makes "lock the app and show the login screen
    /// again" true everywhere, rather than only on the screen that happened to check.
    private func lockApp() {
        // Two requests can come back unauthorized at the same time; the second one finds the
        // token already gone and leaves the login screen the first one built alone.
        guard tokenStore.retrieve() != nil else { return }

        // The session is over either way: a token that cannot be deleted must not keep the user
        // looking at a screen whose data will never refresh.
        try? tokenStore.delete()
        showLogin()
    }

    private func showProductDetail(for product: Product) {
        guard let catalogueLoader else { return }

        let detail = SalesTrackerUIComposer.makeProductDetail(
            product: product,
            catalogueLoader: catalogueLoader,
            catalogueCache: catalogueLoader,
            // The rates endpoint needs no token, so it goes to the plain client: a 401 from it
            // would otherwise sign the user out of a service that never authenticated them.
            ratesLoader: RemoteLoader(
                url: Endpoint.rates.url(baseURL: middlewareURL),
                client: httpClient,
                mapper: CurrencyRateMapper.map
            )
        )

        navigationController?.pushViewController(detail, animated: true)
    }
}
