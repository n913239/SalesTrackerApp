//
//  SalesTrackerUIComposer.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/7/18.
//

import UIKit
import SalesTracker

@MainActor
enum SalesTrackerUIComposer {

    static func makeLogin(loginService: LoginService, onSuccess: @escaping () -> Void) -> LoginViewController {
        let viewController = LoginViewController()

        viewController.onLogin = { username, password in
            do {
                try await loginService.login(username: username, password: password)
                onSuccess()
                return nil
            } catch let error as LoginService.Error {
                return message(for: error)
            } catch {
                return SalesTrackerStrings.localized("LOGIN_CONNECTION_FAILED")
            }
        }

        return viewController
    }

    static func makeProductList(
        catalogue: @escaping () async throws -> ProductCatalogue,
        onSelect: @escaping (Product) -> Void
    ) -> ProductListViewController {
        let viewController = ProductListViewController()

        viewController.onLoad = {
            do {
                return .success(try await catalogue().summaries())
            } catch {
                return .failure(error)
            }
        }
        viewController.onSelect = onSelect

        return viewController
    }

    static func makeProductDetail(
        product: Product,
        catalogue: @escaping () async throws -> ProductCatalogue,
        rates: @escaping () async throws -> [CurrencyRate]
    ) -> ProductDetailViewController {
        let viewController = ProductDetailViewController(product: product)

        viewController.onLoad = {
            do {
                // The sales and the rates are loaded together, but a failing rates request only
                // costs the USD column. Awaiting the rates before showing anything - as the first
                // version did - left the whole screen empty whenever the middleware cold-started.
                async let sales = catalogue()
                async let loadedRates = rates()

                let salesOfProduct = try await sales.sales(of: product)
                let resolvedRates = try? await loadedRates

                return .success(ProductDetailViewController.Content(sales: salesOfProduct, rates: resolvedRates))
            } catch {
                return .failure(error)
            }
        }

        return viewController
    }

    // MARK: - Helpers

    private static func message(for error: LoginService.Error) -> String {
        switch error {
        case let .invalidCredentials(message):
            return message
        case .tokenNotStored:
            return SalesTrackerStrings.localized("LOGIN_TOKEN_NOT_STORED")
        case .connectivity:
            return SalesTrackerStrings.localized("LOGIN_CONNECTION_FAILED")
        @unknown default:
            return SalesTrackerStrings.localized("LOGIN_CONNECTION_FAILED")
        }
    }
}
