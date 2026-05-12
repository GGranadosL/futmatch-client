import Foundation
import SharedModels

public struct RegisterStartRequest: Codable {
    public let name: String
    public let lastName: String
    public let email: String
    public let password: String
    public let phone: String
    public let country: String
    public let birthDate: Int64 // timestamp in milliseconds
    public let gender: Gender
    public let playerPosition: PlayerPosition
    public let profilePic: String?
    public let level: PlayerLevel
    public let userRole: UserRole
    
    public init(
        name: String,
        lastName: String,
        email: String,
        password: String,
        phone: String,
        country: String,
        birthDate: Int64,
        gender: Gender,
        playerPosition: PlayerPosition,
        profilePic: String? = nil,
        level: PlayerLevel,
        userRole: UserRole = .player
    ) {
        self.name = name
        self.lastName = lastName
        self.email = email
        self.password = password
        self.phone = phone
        self.country = country
        self.birthDate = birthDate
        self.gender = gender
        self.playerPosition = playerPosition
        self.profilePic = profilePic
        self.level = level
        self.userRole = userRole
    }
}

// MARK: - Register Complete Request
public struct RegisterCompleteRequest: Codable {
    public let email: String
    public let verificationCode: String
    
    public init(email: String, verificationCode: String) {
        self.email = email
        self.verificationCode = verificationCode
    }
}
