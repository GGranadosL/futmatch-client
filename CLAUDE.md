# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

FutMatch is a native iOS app (Swift/SwiftUI) for creating, managing, and booking football (soccer) matches and reserving sports venues. It uses a modular SPM (Swift Package Manager) architecture.

## Build & Test Commands

```bash
# Build (from repo root)
xcodebuild build -scheme FutMatch-Client -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all tests
xcodebuild test -scheme FutMatch-Client -destination 'platform=iOS Simulator,name=iPhone 16'

# Run tests for a specific SPM package
cd Packages/Core/NetworkFramework && swift test
cd Packages/Features/OnboardingFeature && swift test

# Clean build
xcodebuild clean build -scheme FutMatch-Client
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
