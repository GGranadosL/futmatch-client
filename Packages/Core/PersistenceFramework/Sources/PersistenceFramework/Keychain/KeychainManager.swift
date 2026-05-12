import Foundation
import Security

// MARK: - Keychain Keys
public enum KeychainKey: String {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case userId = "user_id"
    case deviceId = "device_id"
    case firebaseToken = "firebase_token"
    case fcmToken = "fcm_token"
}

public class KeychainManager {
    public static let shared = KeychainManager()
    
    private let service = "com.futmatch.app"
    
    public init() {}
    
    // MARK: - Save
    public func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.saveFailed
        }

        // Delete query uses only identifying attributes (kSecValueData must NOT be included)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }
    
    /// Save using KeychainKey enum
    public func save(_ value: String, for key: KeychainKey) throws {
        try save(value, forKey: key.rawValue)
    }
    
    // MARK: - Retrieve
    public func retrieve(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        
        return value
    }
    
    /// Retrieve using KeychainKey enum
    public func retrieve(for key: KeychainKey) throws -> String? {
        try retrieve(forKey: key.rawValue)
    }
    
    // MARK: - Delete
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed
        }
    }
    
    /// Delete using KeychainKey enum
    public func delete(for key: KeychainKey) throws {
        try delete(forKey: key.rawValue)
    }

    // MARK: - Codable

    /// Save any Codable value to Keychain as JSON (base64-encoded).
    public func saveCodable<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        let string = data.base64EncodedString()
        try save(string, forKey: key)
    }

    /// Load a Codable value previously saved with `saveCodable(_:forKey:)`. Returns nil if not found.
    public func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let string = try retrieve(forKey: key) else { return nil }
        guard let data = Data(base64Encoded: string) else { throw KeychainError.decodingFailed }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Auth Tokens
    
    /// Save authentication tokens after login/register
    public func saveAuthTokens(accessToken: String, refreshToken: String, userId: String, deviceId: String, firebaseToken: String? = nil) throws {
        try save(accessToken, for: .accessToken)
        try save(refreshToken, for: .refreshToken)
        try save(userId, for: .userId)
        try save(deviceId, for: .deviceId)
        if let firebaseToken = firebaseToken {
            try save(firebaseToken, for: .firebaseToken)
        }
    }
    
    /// Clear all authentication data (logout).
    /// Note: deviceId is intentionally preserved — it identifies the physical device
    /// so the server can skip MFA on the next login from the same device.
    public func clearAuthData() throws {
        try delete(for: .accessToken)
        try delete(for: .refreshToken)
        try delete(for: .userId)
        try delete(for: .firebaseToken)
        try? delete(for: .fcmToken)
    }
    
    /// Check if user is logged in (has valid access token)
    public var isLoggedIn: Bool {
        guard let token = try? retrieve(for: .accessToken), !token.isEmpty else {
            return false
        }
        return true
    }
    
    /// Get current access token
    public var accessToken: String? {
        try? retrieve(for: .accessToken)
    }
    
    /// Get current refresh token
    public var refreshToken: String? {
        try? retrieve(for: .refreshToken)
    }
    
    /// Get current user ID
    public var userId: String? {
        try? retrieve(for: .userId)
    }
    
    /// Get current Firebase token
    public var firebaseToken: String? {
        try? retrieve(for: .firebaseToken)
    }

    /// Get current FCM device token
    public var fcmToken: String? {
        try? retrieve(for: .fcmToken)
    }
}

public enum KeychainError: LocalizedError {
    case saveFailed
    case retrieveFailed
    case deleteFailed
    case decodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "No se pudo guardar en Keychain"
        case .retrieveFailed:
            return "No se pudo recuperar de Keychain"
        case .deleteFailed:
            return "No se pudo eliminar de Keychain"
        case .decodingFailed:
            return "Error decodificando datos del Keychain"
        }
    }
}
