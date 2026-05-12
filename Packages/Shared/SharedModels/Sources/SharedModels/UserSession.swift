import Foundation
import NetworkFramework

// MARK: - User Profile Response (DTO)

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
    
    func toDomain() -> User {
        User(
            id: id,
            name: name,
            lastName: lastName,
            email: email,
            phone: phone,
            status: UserStatus(rawValue: status ?? "") ?? .active,
            country: country,
            birthDate: Date(timeIntervalSince1970: TimeInterval(birthDate) / 1000),
            gender: gender,
            playerPosition: playerPosition,
            profilePic: profilePicUrl ?? "",
            level: level,
            userRole: userRole,
            isEmailVerified: isEmailVerified ?? false
        )
    }
}

// MARK: - User Endpoint

enum UserEndpoint: APIEndpoint {
    case profile
    case uploadProfilePic
    
    var path: String {
        switch self {
        case .profile:
            return "/user"
        case .uploadProfilePic:
            return "/user/profile-pic"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .profile:
            return .get
        case .uploadProfilePic:
            return .post
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
            let response: UserProfileResponse = try await apiClient.request(endpoint: UserEndpoint.profile)
            let user = response.data.toDomain()
            currentUser = user
            try? cache?.save(user)
        } catch {
            self.error = error
            #if DEBUG
            print("❌ UserSession: \(error.localizedDescription)")
            #endif
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
}
