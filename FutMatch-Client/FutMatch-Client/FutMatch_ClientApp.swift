import SwiftUI
import CoreData
import Combine
import FirebaseAuth
import OnboardingFeature
import HomeFeature
import FMDesignSystem
import PersistenceFramework
import NetworkFramework
import SharedModels

/// App-wide navigation state
@MainActor
class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoggingOut: Bool = false
    @Published var logoutError: String?
    
    private let logoutUseCase: LogoutUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()

    /// Called after every logout (normal or forced) so the app target can purge local stores.
    var onDidLogout: (() -> Void)?

    init(logoutUseCase: LogoutUseCaseProtocol? = nil) {
        self.logoutUseCase = logoutUseCase ?? LogoutUseCase(authService: AuthService())
        isLoggedIn = KeychainManager.shared.isLoggedIn
        observeUnauthorizedResponses()
    }
    
    // MARK: - Session Expiry
    
    private func observeUnauthorizedResponses() {
        NotificationCenter.default
            .publisher(for: .apiUnauthorized)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isLoggedIn else { return }
                self.forceLogout()
            }
            .store(in: &cancellables)
    }
    
    /// Clears local session immediately without calling the logout API.
    /// Used when the server already invalidated the token (401).
    func forceLogout() {
        try? KeychainManager.shared.clearAuthData()
        onDidLogout?()
        isLoggedIn = false
    }
    
    func logout() {
        Task {
            await performLogout()
        }
    }
    
    private func performLogout() async {
        isLoggingOut = true
        logoutError = nil
        
        do {
            try await logoutUseCase.execute()
        } catch {
            logoutError = error.localizedDescription
            // Still logout locally even if API fails
            try? KeychainManager.shared.clearAuthData()
        }
        onDidLogout?()
        isLoggedIn = false
        isLoggingOut = false
    }
}

@main
struct FutMatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState = {
        let state = AppState()
        state.onDidLogout = {
            let context = PersistenceController.shared.container.viewContext
            // Clear cached matches on logout to avoid stale data for a different user
            let cachedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedMatchEntity")
            let deleteCached = NSBatchDeleteRequest(fetchRequest: cachedRequest)
            _ = try? context.execute(deleteCached)
            try? context.save()
        }
        return state
    }()
    @StateObject private var userSession: UserSession = {
        let context = PersistenceController.shared.container.viewContext
        return UserSession(cache: UserProfileCoreDataRepository(context: context))
    }()
    let persistenceController = PersistenceController.shared
    
    init() {
        // Clear Keychain on fresh install — iOS persists Keychain across uninstalls,
        // so we use UserDefaults (which IS wiped on uninstall) as a sentinel.
        clearKeychainIfFreshInstall()
        // Configure API base URL
        APIEnvironment.baseURL = Config.apiBaseURL
        // Register custom fonts
        FMFonts.registerFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(persistenceContainer: persistenceController.container)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .environmentObject(userSession)
        }
    }
}

// MARK: - Fresh Install Helper

/// UserDefaults is wiped on app uninstall; Keychain is not.
/// We use a sentinel key to detect the first launch after a fresh install
/// and clear any leftover auth tokens from a previous installation.
private func clearKeychainIfFreshInstall() {
    let sentinelKey = "com.futmatch.app.hasLaunchedBefore"
    guard !UserDefaults.standard.bool(forKey: sentinelKey) else { return }
    try? KeychainManager.shared.clearAuthData()
    UserDefaults.standard.set(true, forKey: sentinelKey)
}

/// Root view that handles navigation between Auth and Main flows
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userSession: UserSession
    @State private var isInterceptorReady = false
    let persistenceContainer: NSPersistentContainer
    
    var body: some View {
        Group {
            if appState.isLoggedIn {
                HomeContainerView(onLogout: {
                    userSession.clear()
                    appState.logout()
                })
                .task {
                    configureInterceptorIfNeeded()
                    await signInToFirebaseIfNeeded()
                    await userSession.fetchProfile()
                    await syncFCMTokenIfNeeded()
                }
            } else {
                makeLoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isLoggedIn)
    }
    
    /// Signs into Firebase Auth using the custom token provided by the backend.
    /// Required so Firestore rules with `request.auth != null` work correctly.
    private func signInToFirebaseIfNeeded() async {
        guard let token = KeychainManager.shared.firebaseToken, !token.isEmpty else { return }
        guard Auth.auth().currentUser == nil else { return }
        try? await Auth.auth().signIn(withCustomToken: token)
    }

    /// Syncs the stored FCM token with the server on every authenticated session start.
    /// Covers the case where Firebase fires the token delegate before the session is ready.
    private func syncFCMTokenIfNeeded() async {
        guard let token = KeychainManager.shared.fcmToken, !token.isEmpty else { return }
        let useCase = HomeDependencyFactory().makeUpdateFCMTokenUseCase()
        try? await useCase.execute(fcmToken: token)
    }

    /// Register auth interceptor and token refresh handler once.
    private func configureInterceptorIfNeeded() {
        guard !isInterceptorReady else { return }
        APIClient.shared.addInterceptor(AuthTokenInterceptor {
            try? KeychainManager.shared.retrieve(for: .accessToken)
        })
        APIClient.shared.unauthorizedHandler = {
            guard
                let userId = KeychainManager.shared.userId,
                let deviceId = try? KeychainManager.shared.retrieve(for: .deviceId),
                let refreshToken = try? KeychainManager.shared.retrieve(for: .refreshToken)
            else {
                throw APIError.invalidResponse
            }
            // Use a fresh APIClient without interceptors so the expired access token
            // is NOT attached to the refresh request via AuthTokenInterceptor.
            let refreshClient = APIClient()
            let response = try await AuthService(apiClient: refreshClient).refreshToken(userId: userId, deviceId: deviceId, refreshToken: refreshToken)
            let newAccessToken = response.data.authTokenResponse.accessToken
            try KeychainManager.shared.save(newAccessToken, for: .accessToken)
            if let newRefreshToken = response.data.authTokenResponse.refreshToken {
                try KeychainManager.shared.save(newRefreshToken, for: .refreshToken)
            }
            return newAccessToken
        }
        isInterceptorReady = true
    }
    
    @ViewBuilder
    private func makeLoginView() -> some View {
        // Create OnboardingViewModel with draft persistence
        let _ = OnboardingDependencyFactory(persistenceContainer: persistenceContainer)
        
        LoginView(
            onLoginSuccess: {
                appState.isLoggedIn = true
            }
        )
    }
}
