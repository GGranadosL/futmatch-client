import Foundation

// MARK: - Enums

public enum AdminUserRole: String, CaseIterable, Equatable, Sendable {
    case administrator = "ADMIN"
    case organizer = "ORGANIZER"
    case player = "PLAYER"
    case unknown = "UNKNOWN"

    /// Roles an admin can filter by and assign, in display order.
    public static let selectable: [AdminUserRole] = [.administrator, .organizer, .player]

    init(raw: String?) {
        self = raw.flatMap { AdminUserRole(rawValue: $0.uppercased()) } ?? .unknown
    }
}

public enum AdminUserStatus: String, CaseIterable, Equatable, Sendable {
    case active = "ACTIVE"
    case blocked = "BLOCKED"
    case suspended = "SUSPENDED"
    case unknown = "UNKNOWN"

    public static let selectable: [AdminUserStatus] = [.active, .blocked, .suspended]

    init(raw: String?) {
        self = raw.flatMap { AdminUserStatus(rawValue: $0.uppercased()) } ?? .unknown
    }
}

public enum AdminPaymentStatus: Equatable, Sendable {
    case created, authorized, succeeded, failed, canceled, refunded, unknown

    init(raw: String?) {
        switch raw?.uppercased() {
        case "CREATED", "REQUIRES_PAYMENT_METHOD", "REQUIRES_CONFIRMATION", "PROCESSING": self = .created
        case "AUTHORIZED", "REQUIRES_CAPTURE": self = .authorized
        case "SUCCEEDED", "PAID", "CAPTURED": self = .succeeded
        case "FAILED": self = .failed
        case "CANCELED", "CANCELLED": self = .canceled
        case "REFUNDED": self = .refunded
        default: self = .unknown
        }
    }
}

// MARK: - Users

/// One row of the admin users list. Contact data is already masked.
public struct AdminUserSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let fullName: String
    public let maskedEmail: String?
    public let countryCode: String?
    public let profilePicURL: URL?
    public let gender: String?
    public let role: AdminUserRole
    public let status: AdminUserStatus
    public let isEmailVerified: Bool
    /// `nil` when the backend didn't send a usable timestamp.
    public let createdAt: Date?

    public init(
        id: String, fullName: String, maskedEmail: String?, countryCode: String?,
        profilePicURL: URL?, gender: String?, role: AdminUserRole, status: AdminUserStatus,
        isEmailVerified: Bool, createdAt: Date?
    ) {
        self.id = id
        self.fullName = fullName
        self.maskedEmail = maskedEmail
        self.countryCode = countryCode
        self.profilePicURL = profilePicURL
        self.gender = gender
        self.role = role
        self.status = status
        self.isEmailVerified = isEmailVerified
        self.createdAt = createdAt
    }

    /// Registered less than 7 × 24 h ago (a rolling window, not a calendar week).
    /// Depends on the device clock; future dates are never "new".
    public func isNew(now: Date = Date()) -> Bool {
        guard let createdAt else { return false }
        let age = now.timeIntervalSince(createdAt)
        return age >= 0 && age < 7 * 24 * 60 * 60
    }
}

public struct AdminUserDevice: Identifiable, Equatable, Sendable {
    public enum Platform: Equatable, Sendable {
        case ios, android, desktop, web, other(String), unknown
    }

    public let id: String
    public let platform: Platform
    public let name: String?
    public let appVersion: String?
    public let osVersion: String?
    public let isTrusted: Bool
    public let isActive: Bool
    public let lastUsedAt: Date?

    public init(
        id: String, platform: Platform, name: String?, appVersion: String?, osVersion: String?,
        isTrusted: Bool, isActive: Bool, lastUsedAt: Date?
    ) {
        self.id = id
        self.platform = platform
        self.name = name
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.isTrusted = isTrusted
        self.isActive = isActive
        self.lastUsedAt = lastUsedAt
    }

    /// Most recently used first; devices never used go last.
    public static func sortedByLastUse(_ devices: [AdminUserDevice]) -> [AdminUserDevice] {
        devices.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
    }
}

public struct AdminUserDetail: Equatable, Sendable {
    public let summary: AdminUserSummary
    public let maskedPhone: String?
    public let activeSessionCount: Int?
    public let failedLoginAttempts: Int?
    public let lockedUntil: Date?
    public let upcomingMatchesCount: Int?
    public let completedMatchesCount: Int?
    public let devices: [AdminUserDevice]

    public init(
        summary: AdminUserSummary, maskedPhone: String?, activeSessionCount: Int?,
        failedLoginAttempts: Int?, lockedUntil: Date?, upcomingMatchesCount: Int?,
        completedMatchesCount: Int?, devices: [AdminUserDevice]
    ) {
        self.summary = summary
        self.maskedPhone = maskedPhone
        self.activeSessionCount = activeSessionCount
        self.failedLoginAttempts = failedLoginAttempts
        self.lockedUntil = lockedUntil
        self.upcomingMatchesCount = upcomingMatchesCount
        self.completedMatchesCount = completedMatchesCount
        self.devices = AdminUserDevice.sortedByLastUse(devices)
    }

    public var id: String { summary.id }

    /// Copy with a new role/status after a successful access change.
    func withAccess(role: AdminUserRole, status: AdminUserStatus) -> AdminUserDetail {
        let s = summary
        return AdminUserDetail(
            summary: AdminUserSummary(
                id: s.id, fullName: s.fullName, maskedEmail: s.maskedEmail, countryCode: s.countryCode,
                profilePicURL: s.profilePicURL, gender: s.gender, role: role, status: status,
                isEmailVerified: s.isEmailVerified, createdAt: s.createdAt
            ),
            maskedPhone: maskedPhone, activeSessionCount: activeSessionCount,
            failedLoginAttempts: failedLoginAttempts, lockedUntil: lockedUntil,
            upcomingMatchesCount: upcomingMatchesCount, completedMatchesCount: completedMatchesCount,
            devices: devices
        )
    }
}

// MARK: - Payments

public struct AdminUserPayment: Identifiable, Equatable, Sendable {
    public struct Card: Equatable, Sendable {
        public let brand: String?
        public let last4: String?
    }

    public let id: String
    public let fieldName: String?
    public let matchStartsAt: Date?
    public let amountInCents: Int64
    /// ISO 4217 code as sent by the backend; never assumed to be MXN.
    public let currency: String
    public let status: AdminPaymentStatus
    public let paidAt: Date?
    public let refundedAt: Date?
    /// `nil` when Stripe hasn't supplied card details (yet).
    public let card: Card?

    public init(
        id: String, fieldName: String?, matchStartsAt: Date?, amountInCents: Int64, currency: String,
        status: AdminPaymentStatus, paidAt: Date?, refundedAt: Date?, card: Card?
    ) {
        self.id = id
        self.fieldName = fieldName
        self.matchStartsAt = matchStartsAt
        self.amountInCents = amountInCents
        self.currency = currency
        self.status = status
        self.paidAt = paidAt
        self.refundedAt = refundedAt
        self.card = card
    }
}

// MARK: - Paging

public struct AdminPage<Item: Equatable & Sendable>: Equatable, Sendable {
    public let items: [Item]
    public let page: Int
    public let pageSize: Int
    public let total: Int

    public init(items: [Item], page: Int, pageSize: Int, total: Int) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.total = total
    }

    /// At least 1, so an empty result still reads "Página 1 de 1".
    public var totalPages: Int {
        guard pageSize > 0, total > 0 else { return 1 }
        return (total + pageSize - 1) / pageSize
    }
}

// MARK: - Access change

/// Only the fields that changed are sent; the backend keeps the rest.
public struct AdminUserAccessChange: Equatable, Sendable {
    public let role: AdminUserRole?
    public let status: AdminUserStatus?

    public init(role: AdminUserRole?, status: AdminUserStatus?) {
        self.role = role
        self.status = status
    }

    /// `nil` when nothing differs from the current values.
    public static func diff(
        currentRole: AdminUserRole, currentStatus: AdminUserStatus,
        newRole: AdminUserRole, newStatus: AdminUserStatus
    ) -> AdminUserAccessChange? {
        let role = newRole != currentRole && newRole != .unknown ? newRole : nil
        let status = newStatus != currentStatus && newStatus != .unknown ? newStatus : nil
        guard role != nil || status != nil else { return nil }
        return AdminUserAccessChange(role: role, status: status)
    }
}

public enum AdminUsersError: Error, Equatable {
    case noAccessChanges
}
