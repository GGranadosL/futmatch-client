import SwiftUI
import CoreData
import Combine
import OSLog
import AuthenticationServices
import FirebaseAuth
import FirebaseAppCheck
import FirebaseMessaging
import GoogleSignIn
import OnboardingFeature
import PlayerFeature
import AdminFeature
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
        observeAppleCredentialRevocation()
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

    /// Fires when the user revokes FutMatch's access from Settings ▸ Apple ID ▸
    /// Sign in with Apple ▸ FutMatch ▸ Stop Using. Only ever posted for apps the
    /// user actually authorized with Apple, so it's safe to force-logout on
    /// unconditionally — a Google or password account will simply never see it.
    private func observeAppleCredentialRevocation() {
        NotificationCenter.default
            .publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)
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

        // Tear the session down *before* awaiting the network. /auth/signOut is a
        // full round trip, and `RootView.onLogout` already cleared `UserSession`
        // synchronously — so awaiting first left Home on screen for the whole call
        // with an empty profile behind it, rendering every `?? "—"` placeholder.
        // The sign-out request still authenticates: it reads the access token from
        // the Keychain, which `logoutUseCase` only clears once the call succeeds.
        onDidLogout?()
        isDemoMode = false
        isLoggedIn = false

        do {
            try await logoutUseCase.execute()
        } catch {
            logoutError = error.localizedDescription
            // Still logout locally even if API fails
            try? KeychainManager.shared.clearAuthData()
        }
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
    private let appGateRepository = AppGateRemoteConfigRepository()
    @StateObject private var appState: AppState = {
        let state = AppState()
        state.onDidLogout = {
            let context = PersistenceController.shared.container.viewContext
            // Clear both match caches on logout to avoid leaking data across accounts.
            // Wrapped in `perform` — viewContext may be mid-merge from a background
            // save (e.g. MatchCoreDataCacheRepository) at the exact moment logout
            // fires, and touching it outside its own queue corrupts its object set.
            context.perform {
                for entityName in ["CachedMatchEntity", "CachedReservedMatchEntity", "CachedAdminFieldEntity"] {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    let delete = NSBatchDeleteRequest(fetchRequest: request)
                    _ = try? context.execute(delete)
                }
                try? context.save()
            }
            // Clear both cache levels of FMImageCache so one account's photos
            // (avatars, field images) never linger on disk for the next login.
            FMImageCache.shared.clearAll()
            // Clear home cache so the next user doesn't see stale data
            UserDefaults.standard.removeObject(forKey: "home.cache.homeDataDTO")
            // Reset the notification badge's seen-ID set and the fetch-timestamp
            // safety net so the next user gets a fresh badge and an unthrottled fetch.
            PlayerDependencyFactory().clearNotificationState()
            // Drop persisted regional matches versions so the next account
            // re-fetches the full list instead of sending a stale sinceVersion.
            PlayerDependencyFactory().clearMatchVersions()
            // Stop receiving regional matches auto-refresh pushes for this device.
            Messaging.messaging().unsubscribe(fromTopic: MatchRegion.default.topic)
            // Drop the Google session too, so the next "Continue with Google"
            // shows the account picker instead of silently re-entering the
            // account that just signed out.
            GIDSignIn.sharedInstance.signOut()
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
        // Image cache: let the shared loader attach a bearer token to
        // authenticated Cloudinary URLs (own profile photo), resolve bare
        // field-image keys via the admin fields API, and purge stale disk
        // entries once at launch.
        Task {
            await FMImageLoader.shared.setAuthTokenProvider {
                try? KeychainManager.shared.retrieve(for: .accessToken)
            }
        }
        AdminDependencyFactory.registerImageDataFetcher()
        FMImageCache.shared.purgeDiskIfNeeded()
        // App Check: attach an attestation token to every backend request so the
        // server can verify the call comes from a genuine app instance. Gated by the
        // same flag as the provider factory — without a provider, token() would just
        // fail and waste the per-request timeout.
        // forcingRefresh is false so this reads the SDK's cached token: the SDK
        // already refreshes it before expiry (isTokenAutoRefreshEnabled in AppDelegate),
        // and forcing a refresh cost a network round-trip on *every* request, which
        // blew past the interceptor timeout on slow connections and sent the request
        // with no X-Firebase-AppCheck header at all.
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "AppCheck")
        let appCheckTokenProvider: () async throws -> String? = {
            do {
                return try await AppCheck.appCheck().token(forcingRefresh: false).token
            } catch {
                // Surfaces why requests go out without X-Firebase-AppCheck
                // (e.g. unregistered debug token, attestation failure). Logs the full
                // error — App Attest failures carry the real reason in userInfo, which
                // localizedDescription drops.
                logger.error("App Check token fetch failed: \(String(describing: error), privacy: .public)")
                return nil
            }
        }
        if Config.isAppCheckEnabled {
            APIClient.shared.addInterceptor(AppCheckInterceptor(tokenProvider: appCheckTokenProvider))
        }
        APIClient.shared.unauthorizedHandler = {
            guard let refreshToken = try? KeychainManager.shared.retrieve(for: .refreshToken) else {
                throw APIError.invalidResponse
            }
            let refreshClient = APIClient()
            if Config.isAppCheckEnabled {
                refreshClient.addInterceptor(AppCheckInterceptor(tokenProvider: appCheckTokenProvider))
            }
            let response = try await AuthService(apiClient: refreshClient).refreshToken(refreshToken: refreshToken)
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
            AppGateContainerView(viewModel: AppGateViewModel(repository: appGateRepository)) {
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
                    onAccountDeleted: {
                        // The account is already deleted server-side (tokens revoked) —
                        // wipe local session the same way a forced logout does, without
                        // calling /auth/signOut again.
                        userSession.clear()
                        appState.forceLogout()
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
        do {
            try await Auth.auth().signIn(withCustomToken: token)
        } catch {
            // Best-effort re-auth — a failure must not crash the app. If the
            // session is truly invalid, the auth interceptor will force a logout.
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "FirebaseAuth")
            logger.error("Firebase re-auth failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Syncs the FCM token with the server on every authenticated session start.
    /// Fetches the token directly from Firebase Messaging instead of trusting a value
    /// already cached in Keychain by the delegate callback — that callback only fires
    /// once per app install (when the token is first generated or later rotates), so on
    /// any subsequent login it may not have run yet, silently skipping the sync and
    /// leaving the device row without platform/fcm_token/app_version/os_version.
    private func syncFCMTokenIfNeeded() async {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "FCM")
        do {
            let token = try await Messaging.messaging().token()
            try? KeychainManager.shared.save(token, for: .fcmToken)
            let useCase = PlayerDependencyFactory().makeUpdateFCMTokenUseCase()
            try await useCase.execute(fcmToken: token)
        } catch {
            // Best-effort FCM token sync — Firebase/server errors must not
            // crash the app. The token will resync on the next session start.
            logger.error("FCM token sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }


    
    /// Only offered once each provider is actually configured; otherwise the
    /// button would open a sheet that can only fail. Google needs both client
    /// ids; Apple needs the backend endpoints deployed (`Config.isAppleSignInEnabled`).
    ///
    /// Not inlined into `makeLoginView()`: `@ViewBuilder` tries to interpret a
    /// bare `if let ... { <non-View statement> }` as a conditional view branch
    /// and fails to type-check, since assigning into a dictionary isn't a `View`.
    private func makeSocialProviders() -> [AuthProvider: any SocialAuthProviding] {
        var providers: [AuthProvider: any SocialAuthProviding] = [:]
        if GoogleSignInService.isConfigured {
            providers[.google] = GoogleSignInService()
        }
        if AppleSignInService.isConfigured {
            providers[.apple] = AppleSignInService()
        }
        return providers
    }

    @ViewBuilder
    private func makeLoginView() -> some View {
        let factory = OnboardingDependencyFactory(
            persistenceContainer: persistenceContainer,
            countryRepository: countryRepository,
            dialCodeRepository: dialCodeRepository
        )
        let socialProviders = makeSocialProviders()

        AuthLandingView(
            fetchCountriesUseCase: factory.makeFetchCountriesUseCase(),
            fetchDialCodesUseCase: factory.makeFetchDialCodesUseCase(),
            socialProviders: socialProviders,
            signInWithSocialUseCase: factory.makeSignInWithSocialUseCase(),
            makeRegisterSocialUserUseCase: { provider in
                guard let auth = socialProviders[provider] else { return nil }
                return factory.makeRegisterSocialUserUseCase(socialAuth: auth)
            },
            saveOnboardingDraftUseCase: factory.makeSaveOnboardingDraftUseCase(),
            getOnboardingDraftUseCase: factory.makeGetOnboardingDraftUseCase(),
            clearOnboardingDraftUseCase: factory.makeClearOnboardingDraftUseCase(),
            onLoginSuccess: { appState.isLoggedIn = true },
            firebaseSignIn: { token in
                try await Auth.auth().signIn(withCustomToken: token)
            }
        )
    }
}
