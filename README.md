# FutMatch

FutMatch is a native iOS app for organizing football (soccer) matches and booking sports venues. Players discover and join nearby matches, pay their share in-app, and get real-time updates on who's playing; organizers create matches, manage venues, and supervise games from an admin experience.

Built with **Swift** and **SwiftUI** on a modular **Swift Package Manager** architecture.

---

## Features

- **Match discovery & booking** — browse nearby matches, view details, and reserve a spot with in-app payment.
- **In-app payments** — secure checkout via Stripe `PaymentSheet` with transparent, backend-driven pricing.
- **Real-time player lists** — live roster updates powered by Firestore.
- **Player profiles** — profiles, stats, and account management.
- **Push notifications** — match reminders and updates via Firebase Cloud Messaging.
- **Admin experience** — create and manage matches, venues, and locations; supervise live matches; cancel with reasons.
- **Localization** — full English and Spanish support.
- **Offline-friendly caching** — CoreData-backed caches keep the app responsive and reduce network churn.

---

## Architecture

The app follows a **feature-based, modular SPM architecture**. Each feature is an independent Swift package with a clean, layered structure.

```
Packages/
├── Core/
│   ├── NetworkFramework/     # HTTP client, request interceptors, token refresh
│   ├── PersistenceFramework/ # Keychain + CoreData stack
│   └── FMDesignSystem/       # Shared UI components, theme, typography
├── Features/
│   ├── OnboardingFeature/    # Auth: login, registration, password reset
│   ├── PlayerFeature/        # Matches, profile, payments (player-facing)
│   └── AdminFeature/         # Match/venue/location management & supervision
└── Shared/
    ├── SharedModels/         # DTOs and API response types
    └── Domain/               # Shared domain models
```

Every feature package uses a consistent layered structure:

```
Sources/[FeatureName]/
├── Domain/          # Repository & UseCase protocols (abstractions)
│   ├── Repositories/
│   └── UseCases/
├── Data/            # Concrete repositories, DTOs, CoreData persistence
├── ViewModels/      # @ObservableObject state holders
├── Views/           # SwiftUI views
├── DI/              # Per-feature DependencyFactory
└── Services/        # API service layer (owned by repositories)
```

### Core principles

- **Unidirectional data flow:** `View → ViewModel → UseCase → Repository → Data Source`. Business logic never lives in views.
- **Dependency injection everywhere:** every dependency is injected as a protocol. Concrete types are instantiated **only** inside each feature's `DependencyFactory` — no hidden singletons in business logic.
- **Value types by default:** `struct` for models, use cases, and helpers; `class` reserved for `ObservableObject` view models and identity-bearing services.
- **Design system first:** shared components (`FMTextField`, `FMToast`, `FMSkeleton`, `FMStickyActionBar`, …) keep the UI consistent and localizable.

### State management

- **App-level:** `AppState` (auth/session lifecycle) and `UserSession` (cached profile) are injected as environment objects at the root.
- **Feature-level:** `@StateObject` view models with `@Published` properties; Combine for reactive updates.
- **Caching:** CoreData repositories cache match and profile data; caches are cleared on logout.
- **Real-time:** Firestore provides live player-list updates for active matches.

### Networking

`APIClient` (in `NetworkFramework`) is the central HTTP client. A `RequestInterceptor` chain attaches bearer tokens and transparently handles token refresh on `401`. On an unrecoverable `401`, an `.apiUnauthorized` notification triggers a forced logout. Tokens are stored securely via the Keychain.

---

## Tech Stack

| Area | Technology |
|------|-----------|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Architecture | Modular SPM · Clean layered (UseCase + Repository) |
| Auth / Realtime / Push | Firebase (Auth, Firestore, FCM, Analytics) |
| Payments | Stripe iOS SDK (`PaymentSheet`) |
| Animations | Lottie |
| Keyboard handling | IQKeyboardManagerSwift |
| Persistence | CoreData · Keychain |

---

## Getting Started

### Requirements

- macOS with **Xcode 16+**
- iOS **16+** deployment target (PersistenceFramework targets iOS 14)
- A valid `GoogleService-Info.plist` added to the app target (required for Firebase to initialize)

### Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd futmatch-client
   ```
2. Add your `GoogleService-Info.plist` to the `FutMatch-Client/FutMatch-Client/` app target.
3. Open the project:
   ```bash
   open FutMatch-Client/FutMatch-Client.xcodeproj
   ```
4. Swift Package Manager dependencies resolve automatically on first build.

### Build

```bash
xcodebuild build \
  -scheme FutMatch-Client \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -project FutMatch-Client/FutMatch-Client.xcodeproj
```

---

## Testing

Tests focus on **business logic** — use cases, view model state transitions, and domain transformations — using protocol-based mocks. Framework and third-party behavior (networking, Stripe, Firebase, CoreData internals) is intentionally not unit-tested.

Run all tests:

```bash
xcodebuild test \
  -scheme FutMatch-Client \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -project FutMatch-Client/FutMatch-Client.xcodeproj
```

Run tests for a single package:

```bash
cd Packages/Core/NetworkFramework && swift test
cd Packages/Features/OnboardingFeature && swift test
```

---

## Localization

All user-facing text is localized (English and Spanish) — no hardcoded string literals. Strings live in `Localizable.xcstrings` inside each feature's `Resources` folder and are referenced through generated `L10n` accessors.

---

## Project Layout

```
futmatch-client/
├── FutMatch-Client/          # Xcode app target (entry point, assets, config)
│   ├── FutMatch-Client.xcodeproj
│   ├── FutMatch-ClientTests/
│   └── FutMatch-ClientUITests/
├── Packages/                 # Modular SPM packages (Core, Features, Shared)
└── CLAUDE.md                 # Engineering standards & contributor guidance
```

The app entry point is `FutMatch_ClientApp.swift`. `AppDelegate` configures Firebase, FCM, and keyboard handling; `RootView` switches between the login and main experiences based on auth state.

---

## Contributing

Engineering standards (architecture rules, DI expectations, testing scope, UI/UX patterns, and localization requirements) are documented in [`CLAUDE.md`](CLAUDE.md). Please review it before contributing.
