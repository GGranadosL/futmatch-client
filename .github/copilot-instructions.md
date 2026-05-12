# FutMatch iOS - Copilot Instructions

## 🏗️ Architecture

This project follows **Clean Architecture** with **MVVM** pattern for SwiftUI.

### Layer Structure

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │    Views    │──│  ViewModels │──│   Coordinators  │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────┤
│                      Domain Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │  Use Cases  │──│   Entities  │──│   Repositories  │  │
│  │ (Interactors)│  │   (Models)  │  │   (Protocols)   │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────┤
│                       Data Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ Repositories│──│    DTOs     │──│   DataSources   │  │
│  │   (Impl)    │  │             │  │  (API/Local)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
Packages/
├── Core/
│   ├── NetworkFramework/      # API Client, Endpoints, Interceptors
│   ├── PersistenceFramework/  # CoreData, Keychain
│   └── FMDesignSystem/        # UI Components, Colors, Typography
│
├── Features/
│   ├── OnboardingFeature/     # Login, SignUp, Verification
│   ├── HomeFeature/           # Main tabs, Games list
│   └── [NewFeature]/          # Each feature is a Swift Package
│
└── Shared/
    └── Domain/                # Shared entities and use cases
```

## 🎯 Use Cases (Interactors)

**ALWAYS use Use Cases** to encapsulate business logic. ViewModels should NOT contain business logic directly.

### Use Case Template

```swift
// MARK: - Protocol
protocol LoginUseCaseProtocol {
    func execute(email: String, password: String) async throws -> User
}

// MARK: - Implementation
final class LoginUseCase: LoginUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol
    private let tokenStorage: TokenStorageProtocol
    
    init(
        authRepository: AuthRepositoryProtocol,
        tokenStorage: TokenStorageProtocol
    ) {
        self.authRepository = authRepository
        self.tokenStorage = tokenStorage
    }
    
    func execute(email: String, password: String) async throws -> User {
        let response = try await authRepository.login(email: email, password: password)
        try tokenStorage.save(token: response.token)
        return response.user
    }
}
```

### ViewModel Using Use Case

```swift
@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var state: ViewState<User> = .idle
    
    private let loginUseCase: LoginUseCaseProtocol
    
    init(loginUseCase: LoginUseCaseProtocol) {
        self.loginUseCase = loginUseCase
    }
    
    func login(email: String, password: String) async {
        state = .loading
        do {
            let user = try await loginUseCase.execute(email: email, password: password)
            state = .success(user)
        } catch {
            state = .failure(error)
        }
    }
}
```

## 💉 Dependency Injection

Use **Protocol-based DI** with a central container.

### DI Container

```swift
@MainActor
final class DIContainer {
    static let shared = DIContainer()
    
    // MARK: - Data Sources
    lazy var apiClient: APIClientProtocol = APIClient()
    lazy var keychainManager: KeychainManagerProtocol = KeychainManager()
    
    // MARK: - Repositories
    lazy var authRepository: AuthRepositoryProtocol = AuthRepository(
        apiClient: apiClient
    )
    
    // MARK: - Use Cases
    func makeLoginUseCase() -> LoginUseCaseProtocol {
        LoginUseCase(
            authRepository: authRepository,
            tokenStorage: keychainManager
        )
    }
    
    // MARK: - ViewModels
    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(loginUseCase: makeLoginUseCase())
    }
}
```

### Environment Injection (SwiftUI)

```swift
// Define environment key
private struct DIContainerKey: EnvironmentKey {
    static let defaultValue = DIContainer.shared
}

extension EnvironmentValues {
    var container: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

// Usage in View
struct LoginView: View {
    @Environment(\.container) private var container
    @StateObject private var viewModel: LoginViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: DIContainer.shared.makeLoginViewModel())
    }
}
```

## ✅ Best Practices

### 1. ViewModels

- Use `@MainActor` for all ViewModels
- Keep ViewModels **thin** - delegate to Use Cases
- Use `private(set)` for published properties
- Prefer `enum ViewState<T>` over multiple booleans

```swift
enum ViewState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
}
```

### 2. Views

- Keep Views **dumb** - only UI logic
- Extract reusable components to FMDesignSystem
- Use `.task` modifier for async operations
- Apply `.hideKeyboardOnTap()` on forms

```swift
struct MyView: View {
    @StateObject private var viewModel: MyViewModel
    
    var body: some View {
        content
            .task { await viewModel.loadData() }
            .hideKeyboardOnTap()
    }
}
```

### 3. Repositories

- Define protocols in Domain layer
- Implement in Data layer
- Handle DTO → Entity mapping

```swift
// Domain
protocol UserRepositoryProtocol {
    func getUser(id: String) async throws -> User
}

// Data
final class UserRepository: UserRepositoryProtocol {
    private let apiClient: APIClientProtocol
    
    func getUser(id: String) async throws -> User {
        let dto: UserDTO = try await apiClient.request(UserEndpoint.get(id: id))
        return dto.toDomain()
    }
}
```

### 4. Error Handling

- Create domain-specific errors
- Map API errors to domain errors
- Show user-friendly messages

```swift
enum AuthError: LocalizedError {
    case invalidCredentials
    case accountLocked
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Email o contraseña incorrectos"
        case .accountLocked: return "Cuenta bloqueada temporalmente"
        case .networkError: return "Error de conexión"
        }
    }
}
```

### 5. Networking

- Use `APIEndpoint` protocol for all endpoints
- Include `body` property for POST/PUT requests
- Log requests/responses in DEBUG mode

### 6. Code Cleanliness & Higher-Order Functions

- **Remove unused symbols**: Before adding new types, check existing usage. Delete unused models, parsers, and protocols
- **Search references first**: Use workspace search to verify no symbols are referenced before deletion
- **Prefer higher-order functions**: Use function composition and arrays of parsers for flexible, testable code
- **No examples in packages**: Keep demo code in documentation or separate repos, never inside Swift packages
- **Single responsibility**: If a type isn't consumed, remove it. Keep public APIs minimal and focused
- **Functional composition**: Use `compactMap`, `filter`, `first(where:)` over imperative loops when parsing/transforming data

### NetworkFramework: limpieza y parsers (convenios)

- Mantén el código del `NetworkFramework` limpio: elimina modelos y parsers que no se usan. Evita dejar tipos como `NestedAPIErrorResponse` o wrappers temporales si no hay puntos del código que los consuman.
- Prefiere un único modelo de error canónico (por ejemplo `APIErrorResponse`) en el módulo público. Si necesitas adaptadores para respuestas distintas, mantén esa lógica privada dentro del paquete.
- Usa higher-order functions para parsing de errores y manejo de respuestas (por ejemplo un array de parsers de tipo `[(Data, JSONDecoder) -> String?]`) para componer estrategias de parsing sin crear ramas complejas.
- No incluyas archivos de ejemplo dentro del paquete (evitar `Examples` o `APIClientExamples.swift` en `Packages/Core/NetworkFramework`). Los ejemplos deben vivir en documentación o en un repo/demo separado.
- Antes de eliminar un símbolo, busca referencias en el módulo para evitar romper la compilación; si es necesario, agrega una deprecación primero.

### 6. Localization

- Use `L10n` enum for all strings
- Support `en` and `es` locales
- Use `.xcstrings` format

### 7. Design System

- Use `FMColors` for all colors
- Use `FMTypography` for all fonts (Inter)
- Use `FM*` components (FMTextField, FMPrimaryButton, etc.)
- Primary color: `#3E5F90` (light) / `#6B9BD1` (dark)

## 🚫 Anti-Patterns to Avoid

1. ❌ Business logic in Views
2. ❌ Direct API calls from ViewModels
3. ❌ Hardcoded strings (use L10n)
4. ❌ Hardcoded colors (use FMColors)
5. ❌ Force unwrapping (`!`) without guard
6. ❌ Nested callbacks (use async/await)
7. ❌ God objects (split responsibilities)
8. ❌ Massive ViewModels (use Use Cases)
9. ❌ `print()` statements — use `#if DEBUG` logging or a Logger abstraction if needed
10. ❌ Literal strings in code — all user-facing strings via `L10n`, all identifiers (notification names, keychain keys, etc.) via typed constants or enums, never inline string literals

## 📱 iOS Version

- **Minimum deployment target: iOS 16.0**
- Use iOS 16 compatible APIs only
- `onChange(of:)` uses single parameter syntax

## 🧪 Testing

- Unit test Use Cases and Repositories
- Use protocols for easy mocking
- Name tests: `test_[method]_[scenario]_[expectedResult]`

```swift
func test_login_withValidCredentials_returnsUser() async throws {
    // Given
    let mockRepo = MockAuthRepository()
    mockRepo.loginResult = .success(User.mock)
    let useCase = LoginUseCase(authRepository: mockRepo)
    
    // When
    let user = try await useCase.execute(email: "test@test.com", password: "123456")
    
    // Then
    XCTAssertEqual(user.email, "test@test.com")
}
```

## 🔧 Code Style

- Use `// MARK: -` for section organization
- Document public APIs with `///`
- Prefer `guard` over nested `if`
- Use `final` for classes not meant to be subclassed
- Keep functions under 30 lines
- Keep files under 400 lines
