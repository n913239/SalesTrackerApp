# SalesTrackerApp

Purple Belt Challenge #4 (iOS side) — an app for sales managers tracking worldwide sales in multiple currencies: log in, browse every product with its sales count, and drill into a product to see each sale in its own currency **and** converted to USD at the current rate.

The USD rates come from the companion middleware — [`n913239/SalesMiddleware`](https://github.com/n913239/SalesMiddleware), deployed at `https://salesmiddleware.onrender.com/rates` — which resolves multi-step conversions (e.g. GBP→EUR→USD) into direct-to-USD rates.

## The rules the design hangs on

- **A missing rate is never guessed.** `CurrencyConverter.amountInUSD` returns `nil` when it has no rate for a currency; the row says the rate is unavailable and the summary reports how many sales went unconverted. Handing back the original figure would present 126,944 JPY as US$126,944 — a plausible-looking number that reaches the user as money.
- **The sales never wait for the rates.** The middleware runs on a free tier and cold-starts in ~14 seconds. The sales are the user's data and go on screen as soon as they arrive; the USD column shows *Converting…* until the rates land, and a failing rates request only costs that column.
- **A 401 is handled once, centrally.** The access token expires after 2 minutes, so expiry can surface on any screen and any request. `AuthenticatedHTTPClientDecorator` attaches the token and reports a 401; the composition root locks the app and shows the login screen again. The rates endpoint needs no token and uses the plain client — a 401 from a service that never authenticated the user must not sign them out.
- **Money is built from decimal text.** `JSONDecoder` routes `Decimal` through `Double` (1.18 arrives as 1.1799999999999999), and Swift `Decimal` literals do the same. The mappers rebuild each amount from its decimal string.
- **The token lives in the Keychain** with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so it persists across launches but never travels to iCloud/iTunes backups.

## Repository layout

The framework is organised by feature (`Domain` / `API` / `Presentation`), the same way the companion challenges are.

| Folder | Target | Purpose |
| --- | --- | --- |
| `SalesTracker/Domain/` | `SalesTracker` framework | Domain models, use cases and protocols: `Product`/`Sale`/`CurrencyRate`/`ProductSummary`, `CurrencyConverter`, `ProductCatalogue`, `TokenStore`/`KeychainTokenStore`, `LoginService` |
| `SalesTracker/API/` | `SalesTracker` framework | Networking + mapping: `HTTPClient` + `URLSessionHTTPClient`, `Endpoint`, `RemoteLoader`, the mappers, `AuthenticatedHTTPClientDecorator` |
| `SalesTracker/Presentation/` | `SalesTracker` framework | `SalesFormatter`, `SalesTrackerStrings` + `en.lproj`, and the two presenters |
| `SalesTrackerApp/` | `SalesTrackerApp` iOS app | `SceneDelegate` (injectable composition root), `SalesTrackerUIComposer`, and the Login / ProductList / ProductDetail view controllers |
| `SalesTrackerTests/` | unit | Framework tests (`Domain` / `API` folders): mappers, converter, catalogue, login, decorator, presenters |
| `SalesTrackerAppTests/` | app-hosted | `KeychainTokenStore` tests (the Keychain needs a host app's entitlements) |
| `SalesTrackeriOSTests/` | app-hosted | UI-layer tests for the three screens + `SceneDelegate` lock-out, driven through accessibility identifiers |
| `SalesTrackerAPIEndToEndTests/` | E2E | Real-network tests against the live backend and middleware. Excluded from CI; run on demand |

## Schemes & test plan

| Scheme (shared) | Purpose |
| --- | --- |
| `CI_iOS` | Drives CI via `CI_iOS.xctestplan` (random ordering, code coverage on production targets) |
| `SalesTrackerApp` | Build / run the app |
| `SalesTrackerAPIEndToEnd` | Run the live-network E2E tests locally |

`CI_iOS.xctestplan` runs `SalesTrackerTests` + `SalesTrackerAppTests` + `SalesTrackeriOSTests` (E2E intentionally excluded — a red CI has to mean the code is broken, not that someone else's server is), with `testExecutionOrdering: random` and coverage scoped to `SalesTracker` + `SalesTrackerApp`.

## CI / CD

**CI** (`.github/workflows/CI-iOS.yml`, GitHub Actions, `macos-15` / Xcode 16.4) builds and tests the `CI_iOS` scheme on an iPhone 16 simulator (iOS 18.5) with **ThreadSanitizer** and **code coverage** on every push & PR to `main`, uploading the `.xcresult` bundle as an artifact.

**CD** (`.github/workflows/CD.yml`) runs after a green CI-iOS via `workflow_run` (and on manual `workflow_dispatch`): it archives the app with `xcodebuild archive` and uploads the resulting `.xcarchive` as a build artifact. The archive is unsigned (`CODE_SIGNING_ALLOWED=NO`) — signing for a TestFlight upload needs an Apple Developer identity that isn't available to this challenge repo, so that final export leg is the one step left to wire up once credentials exist. The backend half of the challenge deploys continuously in parallel (Render redeploys the middleware on every push).

## Running locally

```bash
# CI test suite on a simulator
xcodebuild test -project SalesTrackerApp.xcodeproj -scheme CI_iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'

# Live-network end-to-end (backend + middleware; the middleware may cold-start for ~14s)
xcodebuild test -project SalesTrackerApp.xcodeproj -scheme SalesTrackerAPIEndToEnd \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

Test credentials: `tester` / `password` (tokens expire after 2 minutes, which makes the 401 → re-login flow easy to exercise). One measured quirk of the live login endpoint: a **wrong** password takes ~46 seconds to be rejected, while a correct one answers in under a second — which is why the login screen shows progress and blocks re-submission while a request is in flight.
