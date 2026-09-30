//
//  SalesTrackerUIComposer.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/30.
//

import UIKit
import SalesTracker

/// Builds each screen out of its parts and wires the closures between them. It starts nothing and
/// decides nothing: no request, no navigation, no text of its own.
@MainActor
enum SalesTrackerUIComposer {

    static func makeLogin(
        loginService: LoginService,
        onSuccess: @escaping () -> Void
    ) -> LoginViewController {
        let viewController = LoginViewController()

        let adapter = LoginPresentationAdapter(loginService: loginService, onSuccess: onSuccess)
        adapter.presenter = LoginPresenter(
            loadingView: WeakRefVirtualProxy(viewController),
            errorView: WeakRefVirtualProxy(viewController)
        )

        // The closure holds the adapter, the adapter holds the presenter, and the presenter
        // points back through a weak proxy - so nothing here outlives the screen, and nothing
        // here dies before it either.
        viewController.onLogin = { username, password in
            adapter.login(username: username, password: password)
        }

        return viewController
    }

    static func makeProductList(
        catalogueLoader: ProductCatalogueLoader,
        catalogueCache: ProductCatalogueCache,
        onSelect: @escaping (Product) -> Void
    ) -> ProductListViewController {
        let viewController = ProductListViewController()

        let adapter = ProductListPresentationAdapter(
            catalogueLoader: catalogueLoader,
            catalogueCache: catalogueCache
        )
        adapter.presenter = ProductListPresenter(
            listView: WeakRefVirtualProxy(viewController),
            loadingView: WeakRefVirtualProxy(viewController),
            errorView: WeakRefVirtualProxy(viewController)
        )

        viewController.onRefresh = { adapter.refresh() }
        viewController.onSelect = onSelect

        return viewController
    }

    static func makeProductDetail(
        product: Product,
        catalogueLoader: ProductCatalogueLoader,
        catalogueCache: ProductCatalogueCache,
        ratesLoader: CurrencyRatesLoader
    ) -> ProductDetailViewController {
        let viewController = ProductDetailViewController()
        viewController.title = product.name

        let adapter = ProductDetailPresentationAdapter(
            product: product,
            catalogueLoader: catalogueLoader,
            catalogueCache: catalogueCache,
            ratesLoader: ratesLoader
        )
        adapter.presenter = ProductDetailPresenter(
            detailView: WeakRefVirtualProxy(viewController),
            loadingView: WeakRefVirtualProxy(viewController),
            errorView: WeakRefVirtualProxy(viewController),
            formatter: SalesFormatter()
        )

        viewController.onLoad = { adapter.load() }
        viewController.onRefresh = { adapter.refresh() }

        return viewController
    }
}
