import Foundation
import NetworkFramework
import Security

// MARK: - Profile DTOs (/profiles/me and /profiles/{userId})

struct ProfileMeResponse: Decodable {
    let data: ProfileMeDTO
}

struct ProfileMeDTO: Decodable {
    let id: String
    let name: String
    let lastName: String
    let country: String
    let playerPosition: PlayerPosition
    let profilePic: String?
    let level: PlayerLevel
    let averageScore: Int
    let stats: PlayerStatsDTO

    /// Builds the domain `User` from /profiles/me, optionally merging identity
    /// fields (gender, email, phone, birthDate…) from the legacy /user response.
    func toDomain(identity: UserDTO? = nil) -> User {
        User(
            id: id,
            name: name,
            lastName: lastName,
            email: identity?.email ?? "",
            phone: identity?.phone ?? "",
            status: UserStatus(rawValue: identity?.status ?? "") ?? .active,
            country: country,
            birthDate: identity.map { Date(timeIntervalSince1970: TimeInterval($0.birthDate) / 1000) } ?? Date(),
            gender: identity?.gender,
            playerPosition: playerPosition,
            profilePic: profilePic ?? "",
            level: level,
            userRole: identity?.userRole ?? .player,
            isEmailVerified: identity?.isEmailVerified ?? false,
            averageScore: averageScore,
            stats: stats.toDomain()
        )
    }
}

struct PlayerStatsDTO: Decodable {
    let matchesPlayed: Int
    let matchesWon: Int
    let mvpCount: Int
    let totalGoals: Int

    func toDomain() -> PlayerStats {
        PlayerStats(
            matchesPlayed: matchesPlayed,
            matchesWon: matchesWon,
            mvpCount: mvpCount,
            totalGoals: totalGoals
        )
    }
}

// MARK: - Legacy User DTO (GET /user — kept for edit-profile update endpoints)

struct UserProfileResponse: Decodable {
    let data: UserDTO
}

struct UserDTO: Decodable {
    let id: String
    let name: String
    let lastName: String
    let email: String
    let phone: String
    let status: String?
    let country: String
    let birthDate: Int64
    let gender: Gender
    let playerPosition: PlayerPosition
    let profilePicUrl: String?
    let level: PlayerLevel
    let userRole: UserRole
    let isEmailVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, lastName, email, phone, status, country, birthDate
        case gender, playerPosition, level, userRole, isEmailVerified
        case profilePicUrl = "profilePic"
    }
}

// MARK: - Profile Endpoint

public enum ProfileEndpoint: APIEndpoint {
    case me
    case publicProfile(userId: String)

    public var path: String {
        switch self {
        case .me:                           return "/profiles/me"
        case .publicProfile(let userId):    return "/profiles/\(userId)"
        }
    }

    public var method: HTTPMethod { .get }
}

// MARK: - User Endpoint (edit operations)

enum UserEndpoint: APIEndpoint {
    /// Legacy /user — still used to read identity fields (gender, email, phone)
    /// that /profiles/me omits.
    case profile
    case uploadProfilePic
    case updateName
    case updateCountry
    case updateGender
    case updatePosition

    var path: String {
        switch self {
        case .profile:          return "/user"
        case .uploadProfilePic: return "/user/profile-pic"
        case .updateName:       return "/user/profile/name"
        case .updateCountry:    return "/user/profile/country"
        case .updateGender:     return "/user/profile/gender"
        case .updatePosition:   return "/user/profile/position"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .profile:          return .get
        case .uploadProfilePic: return .post
        default:                return .patch
        }
    }
}

// MARK: - User Session

/// App-wide observable that holds the current user's profile.
/// Inject via `@EnvironmentObject` so all features can read user data.
@MainActor
public final class UserSession: ObservableObject {
    
    @Published public private(set) var currentUser: User?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: Error?
    /// Toggled true when a refresh fails but a cached profile is still shown —
    /// drives a transient error toast. The view resets it after display.
    @Published public var refreshFailed: Bool = false
    /// API-provided message for the refresh toast (nil → generic copy).
    @Published public private(set) var refreshErrorMessage: String?
    
    private let apiClient: APIClient
    private let cache: UserProfileCacheProtocol?

    public init(apiClient: APIClient = .shared, cache: UserProfileCacheProtocol? = nil) {
        self.apiClient = apiClient
        self.cache = cache
    }

    /// Fetch user profile using cache-then-refresh strategy.
    /// If a cached profile exists it is surfaced immediately (no spinner),
    /// then the API is hit in the background to keep data fresh.
    public func fetchProfile() async {
        // 1. Show cached data instantly — no spinner if cache hit
        if let cached = cache?.load() {
            currentUser = cached
        }

        // 2. Show loading indicator only when there is no cached data yet
        if currentUser == nil {
            isLoading = true
        }
        error = nil

        do {
            // /profiles/me carries stats + averageScore; /user carries identity
            // fields (gender, email, phone) that /profiles/me omits. Fetch both
            // concurrently and merge. /user is best-effort — if it fails we still
            // surface the profile data.
            async let profileTask: ProfileMeResponse = apiClient.request(endpoint: ProfileEndpoint.me)
            async let identityTask: UserProfileResponse? = try? await apiClient.request(endpoint: UserEndpoint.profile)

            let response = try await profileTask
            let identity = await identityTask?.data
            let user = response.data.toDomain(identity: identity)
            currentUser = user
            try? cache?.save(user)
        } catch {
            guard !(error is CancellationError) else {
                isLoading = false
                return
            }
            // Full-screen error only when we have no cached profile;
            // otherwise surface a transient toast over the cached content.
            if currentUser == nil {
                self.error = error
            } else {
                refreshErrorMessage = error.apiErrorMessage
                refreshFailed = true
            }
        }

        isLoading = false
    }

    /// Clear on logout — also removes the cached profile.
    public func clear() {
        currentUser = nil
        error = nil
        isLoading = false
        try? cache?.clear()
    }

    /// Get auth token from Keychain (used for loading authenticated images).
    public func getAuthToken() async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Profile Picture Upload

    /// Upload a profile picture and refresh the user profile.
    public func uploadProfilePic(imageData: Data) async throws {
        struct UploadResponse: Decodable {
            let data: String
        }
        let _: UploadResponse = try await apiClient.upload(
            endpoint: UserEndpoint.uploadProfilePic,
            fileData: imageData,
            fileName: "perfil.jpg",
            mimeType: "image/jpeg"
        )
        // Clear stale cache so fetchProfile doesn't restore old profilePic
        try? cache?.clear()
        await fetchProfile()
    }

    /// Update user profile fields (name, country, gender, position, etc.)
    public func updateProfile(
        firstName: String? = nil,
        lastName: String? = nil,
        countryISO: String? = nil,
        gender: Gender? = nil,
        playerPosition: PlayerPosition? = nil
    ) async throws {
        struct EmptyResponse: Decodable {
            let data: EmptyData?
        }
        struct EmptyData: Decodable {}

        // Update name if provided
        if let firstName = firstName, let lastName = lastName {
            struct UpdateNameRequest: Encodable {
                let name: String
                let lastName: String
            }
            let nameRequest = UpdateNameRequest(name: firstName, lastName: lastName)
            let _: EmptyResponse = try await apiClient.request(
                endpoint: UserEndpoint.updateName,
                body: nameRequest
            )
        }

        // Update country if provided
        if let countryISO = countryISO {
            struct UpdateCountryRequest: Encodable {
                let countryCode: String
            }
            let countryRequest = UpdateCountryRequest(countryCode: countryISO)
            let _: EmptyResponse = try await apiClient.request(
                endpoint: UserEndpoint.updateCountry,
                body: countryRequest
            )
        }

        // Update gender if provided
        if let gender = gender {
            struct UpdateGenderRequest: Encodable {
                let gender: Gender
            }
            let genderRequest = UpdateGenderRequest(gender: gender)
            let _: EmptyResponse = try await apiClient.request(
                endpoint: UserEndpoint.updateGender,
                body: genderRequest
            )
        }

        // Update position if provided
        if let playerPosition = playerPosition {
            struct UpdatePositionRequest: Encodable {
                let position: PlayerPosition
            }
            let positionRequest = UpdatePositionRequest(position: playerPosition)
            let _: EmptyResponse = try await apiClient.request(
                endpoint: UserEndpoint.updatePosition,
                body: positionRequest
            )
        }

        // Clear stale cache and refresh
        try? cache?.clear()
        await fetchProfile()
    }
}
