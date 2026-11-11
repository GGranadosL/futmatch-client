import Foundation

// MARK: - Envelopes

struct AdminUsersPageResponseDTO: Decodable {
    let data: AdminUsersPageDTO
}

struct AdminUsersPageDTO: Decodable {
    let items: [AdminUserDTO]
    let page: Int?
    let pageSize: Int?
    let total: Int?
}

struct AdminUserDetailResponseDTO: Decodable {
    let data: AdminUserDetailDTO
}

struct AdminUserPaymentsResponseDTO: Decodable {
    let data: AdminUserPaymentsPageDTO
}

struct AdminUserPaymentsPageDTO: Decodable {
    let items: [AdminUserPaymentDTO]
    let page: Int?
    let pageSize: Int?
    let total: Int?
}

struct AdminUserAccessResponseDTO: Decodable {
    let data: Bool?
}

// MARK: - User

struct AdminUserDTO: Decodable {
    let id: String
    let name: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let country: String?
    let gender: String?
    let profilePic: String?
    let role: String?
    let status: String?
    let isEmailVerified: Bool?
    let createdAt: Int64?

    /// Masks contact data on the way in: full values never leave this layer.
    func toDomain() -> AdminUserSummary {
        let fullName = [name, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return AdminUserSummary(
            id: id,
            fullName: fullName,
            maskedEmail: ContactMasking.maskEmail(email),
            countryCode: country,
            profilePicURL: profilePic.flatMap(URL.init(string:)),
            gender: gender,
            role: AdminUserRole(raw: role),
            status: AdminUserStatus(raw: status),
            isEmailVerified: isEmailVerified ?? false,
            createdAt: Date(epochMillis: createdAt)
        )
    }
}

struct AdminUserDetailDTO: Decodable {
    let id: String
    let name: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let country: String?
    let gender: String?
    let profilePic: String?
    let role: String?
    let status: String?
    let isEmailVerified: Bool?
    let createdAt: Int64?
    let security: SecurityDTO?
    let participation: ParticipationDTO?
    let devices: [AdminUserDeviceDTO]?

    struct SecurityDTO: Decodable {
        let activeSessionCount: Int?
        let failedLoginAttempts: Int?
        let lockedUntil: Int64?
    }

    struct ParticipationDTO: Decodable {
        let upcomingMatchesCount: Int?
        let completedMatchesCount: Int?
    }

    func toDomain() -> AdminUserDetail {
        let summary = AdminUserDTO(
            id: id, name: name, lastName: lastName, email: email, phone: phone, country: country,
            gender: gender, profilePic: profilePic, role: role, status: status,
            isEmailVerified: isEmailVerified, createdAt: createdAt
        ).toDomain()
        return AdminUserDetail(
            summary: summary,
            maskedPhone: ContactMasking.maskPhone(phone),
            activeSessionCount: security?.activeSessionCount,
            failedLoginAttempts: security?.failedLoginAttempts,
            lockedUntil: Date(epochMillis: security?.lockedUntil),
            upcomingMatchesCount: participation?.upcomingMatchesCount,
            completedMatchesCount: participation?.completedMatchesCount,
            devices: (devices ?? []).map { $0.toDomain() }
        )
    }
}

struct AdminUserDeviceDTO: Decodable {
    let id: String
    let platform: String?
    let deviceInfo: String?
    let appVersion: String?
    let osVersion: String?
    let isTrusted: Bool?
    let isActive: Bool?
    let lastUsedAt: Int64?

    func toDomain() -> AdminUserDevice {
        AdminUserDevice(
            id: id,
            platform: Self.platform(from: platform),
            name: deviceInfo?.nonBlank,
            appVersion: appVersion?.nonBlank,
            osVersion: osVersion?.nonBlank,
            isTrusted: isTrusted ?? false,
            isActive: isActive ?? false,
            lastUsedAt: Date(epochMillis: lastUsedAt)
        )
    }

    static func platform(from raw: String?) -> AdminUserDevice.Platform {
        guard let raw = raw?.nonBlank else { return .unknown }
        switch raw.uppercased() {
        case "IOS": return .ios
        case "ANDROID": return .android
        case "DESKTOP": return .desktop
        case "WEB": return .web
        default: return .other(raw)
        }
    }
}

// MARK: - Payment

struct AdminUserPaymentDTO: Decodable {
    let id: String
    let fieldName: String?
    let matchStartsAt: Int64?
    let amountInCents: Int64?
    let currency: String?
    let status: String?
    let paidAt: Int64?
    let refundedAt: Int64?
    let method: MethodDTO?

    struct MethodDTO: Decodable {
        let brand: String?
        let last4: String?
    }

    func toDomain() -> AdminUserPayment {
        let card: AdminUserPayment.Card? = method.flatMap { method in
            let brand = method.brand?.nonBlank
            let last4 = method.last4?.nonBlank
            guard brand != nil || last4 != nil else { return nil }
            return AdminUserPayment.Card(brand: brand, last4: last4)
        }
        return AdminUserPayment(
            id: id,
            fieldName: fieldName?.nonBlank,
            matchStartsAt: Date(epochMillis: matchStartsAt),
            amountInCents: amountInCents ?? 0,
            currency: currency?.nonBlank?.uppercased() ?? "",
            status: AdminPaymentStatus(raw: status),
            paidAt: Date(epochMillis: paidAt),
            refundedAt: Date(epochMillis: refundedAt),
            card: card
        )
    }
}

// MARK: - Access

struct UpdateAdminUserAccessRequestDTO: Encodable {
    let role: String?
    let status: String?

    init(change: AdminUserAccessChange) {
        role = change.role?.rawValue
        status = change.status?.rawValue
    }

    // Explicit so a nil field is omitted instead of sent as null.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(status, forKey: .status)
    }

    private enum CodingKeys: String, CodingKey { case role, status }
}

// MARK: - Helpers

extension Date {
    /// Epoch milliseconds → Date; `nil` for missing or non-positive values.
    init?(epochMillis: Int64?) {
        guard let epochMillis, epochMillis > 0 else { return nil }
        self.init(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
    }
}

private extension String {
    var nonBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
