# SalesTrackerApp

An iOS app that signs a user in, lists the products a shop sells with how many sales each has, and
shows one product's sales in their own currency and converted to USD.

## Design rules

1. **Never guess an exchange rate.** A sale in a currency with no rate is shown as such, not
   converted at 1:1. Inventing money that reaches the user as real is worse than saying nothing.
2. **The sales do not wait for the rates.** They are separate requests to separate services; the
   sales go on screen as soon as they arrive, with the USD column still converting.
3. **A 401 is handled once, centrally.** The token can expire at any time, so a 401 can surface
   on any screen and any request. `SceneDelegate` clears the session and returns to the login screen.
4. **Money is built from decimal text, never from a binary double.** `1.18` as a `Double` is
   `1.1799999999999999`, and a cent lost per row is a cent lost. Sale amounts are parsed from their
   text; rates arrive as JSON numbers and are rebuilt from their shortest round-trip text.
5. **The token lives in the Keychain**, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so it
   is not in iCloud or an iTunes backup and cannot be restored onto another device.
6. **The catalogue is loaded once and shared** by the list and the detail. Opening a product costs
   no catalogue request - only `/rates`, fetched fresh each time so the USD amounts are current. A
   pull to refresh sets the cached catalogue aside and asks again; if that refresh fails, the
   catalogue it was replacing stays, so the rows still on screen still open.

## Why this shape

**A presenter per screen, and nothing else decides what the screen says.** Every string, every
state, every "1 sale" versus "3 sales" comes from a presenter and a strings table. The view
controllers keep only the view models they were last handed and decide nothing beyond enabling the
login button once both fields have text - they implement the view protocols and report taps.
That is what makes the wording testable without a simulator and translatable without touching the
app target.

**A presentation adapter per screen, and it is the only thing that starts work.** In the app
target, `Task` appears in exactly three files: `LoginPresentationAdapter`,
`ProductListPresentationAdapter`, `ProductDetailPresentationAdapter`. Each owns its task, cancels
the one it supersedes, and drops a reply that arrives after the screen is gone. Concurrency is one
small, tested layer rather than something every view controller does its own way. The framework
holds one more, inside `CachingProductCatalogueLoader`: the single shared load that concurrent
callers join.

**`WeakRefVirtualProxy` between presenter and view controller.** The view controller holds the
adapter, the adapter holds the presenter, and the presenter points back through a weak proxy - so
a request in flight never keeps a screen the user has left alive, and nothing leaks.

**The detail presenter is stateless.** It is handed the sales and a `CurrencyRatesOutcome`
(`.pending` / `.loaded` / `.failed`) and draws one frame from them. Which of the two requests has
arrived is sequencing, and sequencing belongs with whoever owns the requests - the adapter. A
presenter that remembered what it drew last would have to be reset, and forgetting to reset it is
how a refresh after a failure keeps showing the failure.

**The catalogue cache is a decorator, not a flag inside the loader.** `CachingProductCatalogueLoader`
conforms to the same `ProductCatalogueLoader` its decoratee does, so nothing above it knows a cache
exists. Loading and invalidating are separate (`load()` / `invalidate()`), which is what lets a
pull to refresh mean "ask again" without a second kind of load. A refresh that fails hands back the
catalogue it was replacing, and a caller that joined that refresh gets the same catalogue rather
than the error.

**Base URLs live only in `SceneDelegate`.** `Endpoint` knows paths, not hosts, and takes the base
URL it is given. The framework carries no environment of its own, and the one place that names a
host is the one place that composes the app.

**`SceneDelegate` composes and never starts.** It builds loaders, decorators and screens, and
hands them to each other. It contains no `await`, no `async let`, no `Task` and no `.load()`.

## Use cases

| The user | What happens | Requests |
|---|---|---|
| Opens the app with no stored token | Login screen | none |
| Opens the app with a stored token | Product list, loading | `/products` + `/sales` (in parallel) |
| Signs in | Product list replaces the login screen, loading | `/products` + `/sales` |
| Signs in with a rejected password | The server's own message on the login screen | `/login` |
| Pulls to refresh the list | Cache invalidated, list reloaded; on failure the error appears above the rows, which stay and still open from the kept catalogue | `/products` + `/sales` |
| Taps a product | Detail, sales on screen with USD converting, then converted | `/rates` only - the catalogue is cached (or joined while a refresh is in flight; if that refresh fails the detail opens from the catalogue it was replacing) |
| Pulls to refresh the detail | Cache invalidated; the catalogue and the rates are loaded together, as on opening; if the catalogue fails, the rows and the summary stay | `/products` + `/sales` + `/rates` |
| Hits an expired token anywhere | Token deleted, login screen, cache dropped with the session | the failing request |

## Caching rules

| Case | Behaviour |
|---|---|
| Hit | The cached catalogue is returned; no request |
| Miss | The decoratee is asked and the result cached |
| In flight | A second caller joins the load already running; the decoratee is asked once. If the load it joined was a refresh and that refresh fails, the joiner gets the catalogue the refresh was replacing, not the error |
| Failure | Nothing new is cached, so the next caller retries. A refresh that fails puts back the catalogue it was replacing, so the rows still on screen still open |
| Invalidate | The cached catalogue is set aside, not dropped, until a refresh brings a new one; a load already running is disowned so its late reply cannot overwrite the refresh the user asked for |
| End of session | A 401 drops the whole cache with the token; the next sign-in builds a new one |

## Layout

| Path | Contents | Lifetime |
|---|---|---|
| `SalesTracker/Domain` | `Product`, `Sale`, `CurrencyRate`, `ProductCatalogue`, `ProductSummary`, `CurrencyConverter`, `LoginService`, `TokenStore`, `ProductCatalogueLoader`, `ProductCatalogueCache`, `CurrencyRatesLoader` | value types and protocols; `LoginService` is a class built for each login screen |
| `SalesTracker/Domain/Infrastructure` | `KeychainTokenStore` | one per scene (a `lazy var` on `SceneDelegate`) |
| `SalesTracker/API` | `HTTPClient`, `Endpoint`, `RemoteLoader`, the four mappers, `AuthenticatedHTTPClientDecorator`, `RemoteProductCatalogueLoader`, `CachingProductCatalogueLoader` | stateless, except `CachingProductCatalogueLoader`, which holds the catalogue for one login session; it and the `RemoteProductCatalogueLoader` it wraps are built for each session |
| `SalesTracker/API/Infrastructure` | `URLSessionHTTPClient` | one per scene |
| `SalesTracker/Presentation` | the three presenters, the view protocols, `SalesFormatter`, `SalesTrackerStrings`, `en.lproj/SalesTracker.strings` | per screen |
| `SalesTrackerApp` | the three view controllers, the three presentation adapters, `WeakRefVirtualProxy`, `SalesTrackerUIComposer`, `UITableView+HeaderSizing`, `SceneDelegate` | per screen; `SceneDelegate` per scene |

Nothing in `SalesTracker` imports `UIKit`, and nothing in `Presentation` knows a network exists.
`Domain` holds the value types and the loader protocols, plus `LoginService`, which posts through the
`HTTPClient` protocol and reads the reply with `LoginMapper`.

## Schemes and tests

| Scheme | What it runs |
|---|---|
| `CI_iOS` | `SalesTrackerTests` (111), `SalesTrackerAppTests` (48), `SalesTrackeriOSTests` (43) - **202 tests**, random order, code coverage |
| `SalesTrackerAPIEndToEnd` | 7 tests against the live backend and the live middleware. **Not part of CI** - a red build should mean the code broke, not that someone else's server was slow |
| `SalesTrackerApp` | the app |
| `SalesTracker` | the framework |

`SalesTrackeriOSTests` includes 16 snapshot tests covering the three screens in light, dark and the
largest Dynamic Type size. The comparison allows up to 1% of pixels to differ, with no per-pixel
colour tolerance: a pixel either matches exactly or counts against the 1%.

## Running it locally

```bash
# the CI scheme and test plan, the way CI runs them
xcodebuild clean build test \
  -project SalesTrackerApp/SalesTrackerApp.xcodeproj \
  -scheme CI_iOS -testPlan CI_iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -enableThreadSanitizer YES -enableCodeCoverage YES

# the end-to-end tests, by hand, before submitting
xcodebuild test \
  -project SalesTrackerApp/SalesTrackerApp.xcodeproj \
  -scheme SalesTrackerAPIEndToEnd \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -parallel-testing-enabled NO
```

Built with Xcode 16.4 against iOS 18.5. The whole project compiles under
`SWIFT_STRICT_CONCURRENCY = complete`, so the compiler - not a convention - is what keeps the app
to one concurrency model.

## CI and CD

- **CI** runs `CI_iOS` on every push and pull request to `main`, with Thread Sanitizer and code
  coverage on, and uploads the `.xcresult`.
- **CD** runs after a green CI and archives the app (unsigned) as a workflow artifact.

## Services

| Service | URL |
|---|---|
| Backend (`/login`, `/products`, `/sales`) | `https://ile-b2p4.essentialdeveloper.com` |
| Rates middleware (`/rates`, `/health`) | `https://sales-middleware.n913239.workers.dev` |

The rates request carries no `Authorization` header: the middleware never authenticates the user,
and a 401 from it must not sign them out of the backend.

Test account `tester` / `password`. **Its token expires after two minutes**, which is the quickest
way to see the app lock itself and return to the login screen.
