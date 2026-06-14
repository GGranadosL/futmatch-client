import SwiftUI
import CoreData
import Combine
import OSLog
import FirebaseAuth
import FirebaseAppCheck
import FirebaseMessaging
import OnboardingFeature
import PlayerFeature
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
    /// `true` mientras el usuario explora la app con datos de demo (sin sesión real persistida).
    @Published var isDemoMode: Bool = false

    private let logoutUseCase: LogoutUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()

    /// Called after every logout (normal or forced) so the app target can purge local stores.
    var onDidLogout: (() -> Void)?

    init(logoutUseCase: LogoutUseCaseProtocol? = nil) {
        self.logoutUseCase = logoutUseCase ?? LogoutUseCase(authService: AuthService())
        isLoggedIn = KeychainManager.shared.isLoggedIn
        observeUnauthorizedResponses()
    }

    // MARK: - Demo Mode

    /// Activa el modo demo usando el token de la sesión almacenada en Keychain.
    /// No hace login real — solo muestra endpoints /demo/*.
    func enterDemoMode() {
        isDemoMode = true
        isLoggedIn = true
    }

    /// Sale del modo demo y regresa a la pantalla de login.
    /// No llama al API de logout ni borra el Keychain.
    func exitDemoMode() {
        isDemoMode = false
        isLoggedIn = false
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
        isDemoMode = false
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
        isDemoMode = false
        isLoggedIn = false
        isLoggingOut = false
    }
}

@main
struct FutMatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// Shared Remote Config repository — single instance so cache is reused across features.
    private let countryRepository = CountryRemoteConfigRepository()
    /// Shared dial-code Remote Config repository — single instance so cache is reused across features.
    private let dialCodeRepository = DialCodeRemoteConfigRepository()
    @StateObject private var appState: AppState = {
        let state = AppState()
        state.onDidLogout = {
            let context = PersistenceController.shared.container.viewContext
            // Clear both match caches on logout to avoid leaking data across accounts
            for entityName in ["CachedMatchEntity", "CachedReservedMatchEntity", "CachedAdminFieldEntity"] {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let delete = NSBatchDeleteRequest(fetchRequest: request)
                _ = try? context.execute(delete)
            }
            try? context.save()
            // Clear home cache so the next user doesn't see stale data
            UserDefaults.standard.removeObject(forKey: "home.cache.homeDataDTO")
            // Reset notification seen-count so the next user gets a fresh badge
            UserDefaults.standard.removeObject(forKey: "notifications.seenUnreadCount")
            // Drop persisted regional matches versions so the next account
            // re-fetches the full list instead of sending a stale sinceVersion.
            PlayerDependencyFactory().clearMatchVersions()
            // Stop receiving regional matches auto-refresh pushes for this device.
            Messaging.messaging().unsubscribe(fromTopic: MatchRegion.default.topic)
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
        // Auth interceptor and refresh handler configured at launch so they are
        // ready for any request, including profile-pic upload right after registration.
        APIClient.shared.addInterceptor(AuthTokenInterceptor {
            try? KeychainManager.shared.retrieve(for: .accessToken)
        })
        // App Check: attach an attestation token to every backend request so the
        // server can verify the call comes from a genuine app instance. Gated by the
        // same flag as the provider factory — without a provider, token() would just
        // fail and waste the per-request timeout.
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "AppCheck")
        let appCheckTokenProvider: () async throws -> String? = {
            do {
                return try await AppCheck.appCheck().token(forcingRefresh: false).token
            } catch {
                // Surfaces why requests go out without X-Firebase-AppCheck
                // (e.g. unregistered debug token, attestation failure).
                logger.error("App Check token fetch failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        if Config.isAppCheckEnabled {
            APIClient.shared.addInterceptor(AppCheckInterceptor(tokenProvider: appCheckTokenProvider))
        }
        APIClient.shared.unauthorizedHandler = {
            guard
                let userId = KeychainManager.shared.userId,
                let deviceId = try? KeychainManager.shared.retrieve(for: .deviceId),
                let refreshToken = try? KeychainManager.shared.retrieve(for: .refreshToken)
            else {
                throw APIError.invalidResponse
            }
            let refreshClient = APIClient()
            if Config.isAppCheckEnabled {
                refreshClient.addInterceptor(AppCheckInterceptor(tokenProvider: appCheckTokenProvider))
            }
            let response = try await AuthService(apiClient: refreshClient).refreshToken(userId: userId, deviceId: deviceId, refreshToken: refreshToken)
            let newAccessToken = response.data.authTokenResponse.accessToken
            try KeychainManager.shared.save(newAccessToken, for: .accessToken)
            if let newRefreshToken = response.data.authTokenResponse.refreshToken {
                try KeychainManager.shared.save(newRefreshToken, for: .refreshToken)
            }
            return newAccessToken
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(persistenceContainer: persistenceController.container,
                     countryRepository: countryRepository,
                     dialCodeRepository: dialCodeRepository,
                     onRequestNotificationPermission: {
                         appDelegate.requestNotificationAuthorization()
                     },
                     onAuthenticatedStart: {
                         appDelegate.subscribeToMatchUpdates()
                     })
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
    let persistenceContainer: NSPersistentContainer
    let countryRepository: any CountryRepositoryProtocol
    let dialCodeRepository: any DialCodeRepositoryProtocol
    var onRequestNotificationPermission: (() -> Void)?
    /// Invoked once an authenticated (non-demo) session is ready — subscribes to
    /// the regional matches push topic.
    var onAuthenticatedStart: (() -> Void)?
    
    var body: some View {
        Group {
            if appState.isLoggedIn {
                HomeContainerView(
                    onLogout: {
                        if appState.isDemoMode {
                            appState.exitDemoMode()
                        } else {
                            userSession.clear()
                            appState.logout()
                        }
                    },
                    isDemoMode: appState.isDemoMode,
                    countryRepository: countryRepository,
                    managedObjectContext: persistenceContainer.viewContext
                )
                .task {
                    // Profile is fetched in every mode — the bearer token is valid
                    // in demo and we need `profilePicURL`, name, level, etc. for the UI.
                    await userSession.fetchProfile()
                    // Request notification permission now that the user is logged in.
                    // The APNs token was already requested silently at launch.
                    onRequestNotificationPermission?()
                    // Firebase Auth and FCM are skipped in demo mode.
                    guard !appState.isDemoMode else { return }
                    // Re-authenticate with Firebase on app relaunch if the user already
                    // had a session (Firebase Auth state is not persisted across cold starts
                    // when using custom tokens — only on-login sign-in covers new logins).
                    await reAuthFirebaseIfNeeded()
                    await syncFCMTokenIfNeeded()
                    // Subscribe to the regional matches topic for auto-refresh pushes.
                    onAuthenticatedStart?()
                }
            } else {
                makeLoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isLoggedIn)
    }
    
    /// Signs into Firebase with the stored custom token on app relaunch.
    /// Custom-token sessions are not persisted by Firebase across cold starts,
    /// so we need to re-authenticate every time the app is opened with an active session.
    private func reAuthFirebaseIfNeeded() async {
        guard Auth.auth().currentUser == nil else {
            return
        }
        guard let token = KeychainManager.shared.firebaseToken, !token.isEmpty else {
            return
        }
        try! await Auth.auth().signIn(withCustomToken: token)
    }

    /// Syncs the stored FCM token with the server on every authenticated session start.
    /// Covers the case where Firebase fires the token delegate before the session is ready.
    private func syncFCMTokenIfNeeded() async {
        guard let token = KeychainManager.shared.fcmToken, !token.isEmpty else {
            return
        }
        let useCase = PlayerDependencyFactory().makeUpdateFCMTokenUseCase()
        try! await useCase.execute(fcmToken: token)
    }


    
    @ViewBuilder
    private func makeLoginView() -> some View {
        let factory = OnboardingDependencyFactory(
            persistenceContainer: persistenceContainer,
            countryRepository: countryRepository,
            dialCodeRepository: dialCodeRepository
        )
        LoginView(
            fetchCountriesUseCase: factory.makeFetchCountriesUseCase(),
            fetchDialCodesUseCase: factory.makeFetchDialCodesUseCase(),
            onLoginSuccess: { appState.isLoggedIn = true },
            firebaseSignIn: { token in
                try await Auth.auth().signIn(withCustomToken: token)
            }
        )
    }
}
