# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

FutMatch is a native iOS app (Swift/SwiftUI) for creating, managing, and booking football (soccer) matches and reserving sports venues. It uses a modular SPM (Swift Package Manager) architecture.

## Build & Test Commands

```bash
# Build (from repo root)
xcodebuild build -scheme FutMatch-Client -destination 'platform=iOS Simulator,name=iPhone 17' -project FutMatch-Client/FutMatch-Client.xcodeproj

# Run all tests
xcodebuild test -scheme FutMatch-Client -destination 'platform=iOS Simulator,name=iPhone 17' -project FutMatch-Client/FutMatch-Client.xcodeproj

# Run tests for a specific SPM package
cd Packages/Core/NetworkFramework && swift test
cd Packages/Features/OnboardingFeature && swift test

# Clean build
xcodebuild clean build -scheme FutMatch-Client -project FutMatch-Client/FutMatch-Client.xcodeproj
```

The main Xcode project is at `FutMatch-Client/FutMatch-Client.xcodeproj`. There is no lint config currently in place.

## Architecture

The app uses a **feature-based SPM modular architecture** under `Packages/`:

```
Packages/
├── Core/
│   ├── NetworkFramework/     # HTTP client, interceptors, token refresh
│   ├── PersistenceFramework/ # Keychain, CoreData stack
│   └── FMDesignSystem/       # Shared UI components, theme, fonts
├── Features/
│   ├── OnboardingFeature/    # Auth: login, registration, password reset
│   └── HomeFeature/          # Main app: matches, profile, payments
└── Shared/
    └── SharedModels/         # DTOs and API response types shared across features
```

Each feature package follows a consistent **layered structure**:

```
Sources/[FeatureName]/
├── Domain/
│   ├── Repositories/   # Abstract protocols
│   └── UseCases/       # Business logic protocols
├── Data/
│   ├── Repositories/   # Concrete implementations
│   ├── DTOs/           # API request/response models
│   └── Persistence/    # CoreData entity models
├── ViewModels/         # @ObservableObject / @StateObject state holders
├── Views/              # SwiftUI views
├── DI/                 # Dependency injection factory (one per feature)
└── Services/           # API service layer
```

## Dependency Injection

Each feature has a single **DependencyFactory** (e.g., `OnboardingDependencyFactory`, `HomeDependencyFactory`) that wires together the repositories, use cases, and view models. Factories are instantiated at the app level and passed down via SwiftUI `.environmentObject()` or direct injection.

## Networking

`APIClient` (in `NetworkFramework`) is the central HTTP client. It uses a `RequestInterceptor` chain — `AuthTokenInterceptor` attaches the bearer token and handles 401 responses by attempting token refresh. On unrecoverable 401, it posts `.apiUnauthorized` notification, which `AppState` observes to force logout.

Token storage and retrieval goes through `KeychainManager.shared`.

## State Management

- **App-level:** `AppState` (login/logout, unauthorized handling) and `UserSession` (cached user profile) are environment objects injected at the root.
- **Feature-level:** `@StateObject` view models with `@Published` properties; Combine used for reactive updates.
- **CoreData cache:** `MatchCoreDataCacheRepository` caches match data; `UserProfileCoreDataRepository` caches user profile. Both are cleared on logout.
- **Firestore:** `FirestoreMatchPlayersRepository` provides real-time player list updates for active matches.

## App Entry Point & Launch Flow

1. `FutMatch_ClientApp.swift` — SwiftUI `@main`, sets up `AppState`, `PersistenceController`, and injects `HomeDependencyFactory`/`OnboardingDependencyFactory`.
2. `AppDelegate.swift` — Configures Firebase, FCM, and `IQKeyboardManagerSwift`.
3. `RootView` reads `AppState.isLoggedIn` to decide between `LoginView` and `HomeContainerView`.
4. On login: tokens → Keychain → Firebase custom token auth → FCM token sync → `isLoggedIn = true`.
5. On logout: `LogoutUseCase` calls backend, clears Keychain, wipes CoreData caches, resets `AppState`/`UserSession`.

## External Integrations

- **Firebase** (v12+): Auth (custom token), Firestore (real-time), FCM (push notifications), Analytics.
- **Stripe** (`stripe-ios-spm` v24+): `PaymentSheet` for in-app match booking payments.
- **IQKeyboardManagerSwift**: Keyboard avoidance (CocoaPods, not SPM).
- **GoogleService-Info.plist** must be present in the app target for Firebase to initialize.

## Localization

OnboardingFeature supports English and Spanish via generated `L10n.swift` (using SwiftGen or similar). String keys live in `.strings` files inside the feature package's resources.

## Minimum Deployment Target

- `PersistenceFramework`: iOS 14
- All feature packages: iOS 16

---

## Engineering Standards

These rules are non-negotiable. Apply them to every file you create or modify.

### 1. `struct` over `class`

Use `struct` by default. Only use `class` when identity semantics, inheritance, or a framework requirement demand it.

| Use `struct` | Use `class` |
|---|---|
| DTOs, domain models, value types | `ObservableObject` ViewModels (`@StateObject` requires reference type) |
| Endpoints, formatters, helper types | Singleton services (`APIClient`, `KeychainManager`) |
| Repository/UseCase implementations that hold no mutable state | Objects shared across multiple owners |
| `NotificationItem`, `MatchItem`, `NotificationSection`, etc. | `AppState`, `UserSession` (reference semantics needed) |

If a type holds only injected dependencies (protocols) and no mutable state, it is almost certainly a `struct`.

### 2. Mandatory UseCase + Repository Architecture

Every piece of business logic must go through this chain — no exceptions:

```
View → ViewModel → UseCase (protocol) → Repository (protocol) → Data Source
```

- **UseCases** live in `Domain/UseCases/`. One public `execute(...)` method. No direct dependency on `APIClient`, CoreData, or any concrete type.
- **Repositories** live in `Domain/Repositories/` (protocol) and `Data/Repositories/` (concrete). They translate between data sources and domain models.
- **ViewModels** depend only on UseCase protocols, never on Services or APIClient directly.
- **Services** (`MatchService`, `NotificationService`, etc.) are an intermediate layer owned by repository implementations — they must not be injected directly into ViewModels.

### 3. ⚠️ Zero Uninjected Dependencies — CRITICAL

**Every dependency must be injected.** There must be no hidden coupling.

❌ **Never do this:**
```swift
// Inside any init, method, or property
let client = APIClient.shared          // accessing a singleton directly
let service = MatchService()           // constructing a concrete type inline
let factory = HomeDependencyFactory()  // creating a factory inside a view or VM
KeychainManager.shared.retrieve(...)   // reaching for a singleton inside business logic
```

✅ **Always do this:**
```swift
// Inject via init
struct FetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol {
    private let repository: MatchRepositoryProtocol
    init(repository: MatchRepositoryProtocol) { self.repository = repository }
}

// Wire everything in DependencyFactory — that is the only place allowed to touch concrete types
func makeFetchMatchDetailUseCase() -> FetchMatchDetailUseCaseProtocol {
    FetchMatchDetailUseCase(repository: makeMatchRepository())
}
```

Rules:
- Every dependency a type needs must appear in its `init` as a protocol parameter.
- `DependencyFactory` is the **only** place where concrete types are instantiated.
- Views must never create ViewModels, Services, or Factories inline. Use `.environmentObject()` or pass via `init`.
- If you catch yourself writing `SomeConcrete()` inside a ViewModel, UseCase, or Repository — stop. Inject it instead.

### 4. Unit Tests — Business Logic Only

Generate tests that validate **business rules**, not implementation details or third-party behavior.

**Test targets:** UseCases, ViewModels, domain model transformations, grouping/formatting logic.

**What to test:**
- A UseCase returns the correct domain model given a mock repository response
- A ViewModel transitions to the right state (`.loaded`, `.empty`, `.failed`) based on UseCase output
- Date grouping logic (`groupByDate`) produces the correct section titles
- Price/time formatters return the expected strings
- Error paths (UseCase throws → ViewModel sets `.failed`)

**What NOT to test:**
- `APIClient` network calls — that's framework code
- Stripe or Firebase SDK behavior — that's third-party code
- CoreData or Keychain internals
- SwiftUI view rendering
- Trivial getters/setters with no logic

**Test structure:**
```swift
// Use mocks via protocol conformance — never subclassing
final class MockMatchRepository: MatchRepositoryProtocol {
    var stubbedMatches: [MatchItem] = []
    var fetchCallCount = 0
    func fetchMatches(lat: Double?, lon: Double?) async throws -> [MatchItem] {
        fetchCallCount += 1
        return stubbedMatches
    }
}

final class FetchMatchesUseCaseTests: XCTestCase {
    func test_execute_returnsMappedMatches() async throws {
        let repo = MockMatchRepository()
        repo.stubbedMatches = [.stub()]
        let sut = FetchMatchesUseCase(repository: repo)
        let result = try await sut.execute(lat: nil, lon: nil)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(repo.fetchCallCount, 1)
    }
}
```

Each test file lives in `Tests/[FeatureName]Tests/` inside the relevant SPM package.

### 5. Text Fields — Always Use `FMTextField`

**Never** use a raw SwiftUI `TextField` with manual `.padding()`, `.background()`, `.cornerRadius()`, and `.overlay(stroke(...))`. Always use `FMTextField` from `FMDesignSystem`:

```swift
// ❌ Never do this
TextField("Dirección", text: $viewModel.address)
    .padding(12)
    .background(FMColors.surfaceContainerLowest)
    .cornerRadius(8)
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(FMColors.outlineVariant, lineWidth: 1))

// ✅ Always do this
FMTextField(
    label: "Dirección",
    text: $viewModel.address,
    autocapitalization: .sentences
)
```

`FMTextField` supports: `label`, `placeholder`, `keyboardType`, `autocapitalization`, `errorMessage`, `trailingIcon`, `onTrailingIconTap`.

For `Double` bindings (lat/lon), create a `Binding<String>` in the view:
```swift
private var latitudeBinding: Binding<String> {
    Binding(
        get: { viewModel.latitude == 0 ? "" : String(format: "%.6f", viewModel.latitude) },
        set: { if let d = Double($0) { viewModel.latitude = d } }
    )
}
```

### 6. Loading States — Skeleton Placeholders, Not Spinners

All list screens must show card-matched skeleton placeholders when loading with no cached data. **Never** use a bare `ProgressView()` as the sole loading state for a list.

- Skeleton structs live in `Views/Components/[Screen]Skeleton.swift`
- Use `FMSkeleton(cornerRadius:)` from `FMDesignSystem`, matching the card's proportions (same heights/widths as the real card)
- Show skeleton only when **both** `isLoading == true` AND `items.isEmpty`; if there is cached data, show it while the network refreshes silently

```swift
// ✅ Correct pattern
if isLoading && items.isEmpty {
    skeletonList          // FMSkeleton placeholders, .disabled(true)
} else if !isLoading && items.isEmpty {
    FMEmptyStateCard(...) // nothing to show
} else {
    realList              // cached or fresh data; network refresh is silent
}
```

Examples: `AdminFieldCardSkeleton`, `AdminLocationCardSkeleton`.

### 7. ⚠️ CoreData — Every Context Access Goes Through `perform` — CRITICAL

`NSManagedObjectContext` is **not thread-safe**. A context (including the main-queue `viewContext`) may only be touched from inside its own `perform` / `performAndWait` block. Repository methods are `async` or called from `Task { }` / `.task { }`, which run on background threads — so **every** `fetch`, `insert`, `delete`, `setValue`, `value(forKey:)`, `hasChanges`, and `save()` must be wrapped.

Skipping this corrupts the context's internal object set and crashes with errors like:
- `*** -[__NSCFSet addObject:]: attempt to insert nil`
- `*** Collection <__NSCFSet: …> was mutated while being enumerated`

These look like unrelated random crashes but are **all the same bug**: off-queue context access. Do not chase the symptom (batch-delete vs individual-delete, `representedClassName`, etc.) — wrap the access.

❌ **Never do this:**
```swift
func saveItems(_ items: [Item]) throws {
    let existing = try context.fetch(request)   // off-queue → crash
    existing.forEach { context.delete($0) }
    try context.save()
}
```

✅ **Always do this:**
```swift
// async method (network precedes the cache write):
try await context.perform {
    let existing = try self.context.fetch(request)
    existing.forEach { self.context.delete($0) }
    try self.context.save()
}

// sync method that returns a value:
func loadItems() -> [Item] {
    context.performAndWait {
        let results = (try? context.fetch(request)) ?? []
        return results.compactMap { map($0) }
    }
}
```

Reference implementations: `LocationRepository`, `AdminFieldsCoreDataCacheRepository`, `MatchCoreDataCacheRepository`, `UserProfileCoreDataRepository`, `OnboardingRepository`. `performAndWait` is reentrant — safe to call whether or not you're already on the context's queue.
