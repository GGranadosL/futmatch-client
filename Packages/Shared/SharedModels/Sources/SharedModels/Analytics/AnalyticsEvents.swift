import Foundation

private func event(_ name: String, _ parameters: [String: AnalyticsValue] = [:]) -> AnalyticsEvent {
    AnalyticsEvent(name: name, parameters: parameters)
}

// MARK: - Login

public enum AuthEvents {
    public enum MFAStage: String {
        case sendCode = "send_code"
        case verifyCode = "verify_code"
        case googleLinkVerify = "google_link_verify"
    }

    public static func loginStarted(_ method: AnalyticsAuthMethod) -> AnalyticsEvent {
        event("login_started", ["method": .string(method.rawValue)])
    }
    public static func loginMFARequired(_ method: AnalyticsAuthMethod) -> AnalyticsEvent {
        event("login_mfa_required", ["method": .string(method.rawValue)])
    }
    public static func loginSuccess(_ method: AnalyticsAuthMethod) -> AnalyticsEvent {
        event("login_success", ["method": .string(method.rawValue)])
    }
    public static func loginError(_ method: AnalyticsAuthMethod, errorCode: String) -> AnalyticsEvent {
        event("login_error", ["method": .string(method.rawValue), "error_code": .string(errorCode)])
    }
    public static func loginMFAError(_ stage: MFAStage, errorCode: String) -> AnalyticsEvent {
        event("login_mfa_error", ["stage": .string(stage.rawValue), "error_code": .string(errorCode)])
    }
}

// MARK: - Sign up

public enum SignUpEvents {
    /// Step labels and names are analytics literals, never UI text.
    public static func stepLabelAndName(forStep step: Int) -> (label: String, name: String)? {
        switch step {
        case 1: return ("ONE", "Personal Info")
        case 2: return ("TWO", "Contact")
        case 3: return ("THREE", "Football Profile")
        case 4: return ("CONFIRMATION", "Confirmation")
        default: return nil
        }
    }

    public static func started(_ method: AnalyticsAuthMethod) -> AnalyticsEvent {
        event("signup_started", ["method": .string(method.rawValue)])
    }
    public static func stepCompleted(step: Int, method: AnalyticsAuthMethod) -> AnalyticsEvent? {
        guard let names = stepLabelAndName(forStep: step) else { return nil }
        return event("signup_step_completed", [
            "step_label": .string(names.label),
            "step_name": .string(names.name),
            "method": .string(method.rawValue)
        ])
    }
    public static func submitted(_ method: AnalyticsAuthMethod) -> AnalyticsEvent {
        event("signup_submitted", ["method": .string(method.rawValue)])
    }
    public static func success(_ method: AnalyticsAuthMethod) -> AnalyticsEvent {
        event("signup_success", ["method": .string(method.rawValue)])
    }
    public static func error(_ method: AnalyticsAuthMethod, errorCode: String) -> AnalyticsEvent {
        event("signup_error", ["method": .string(method.rawValue), "error_code": .string(errorCode)])
    }
}

// MARK: - Password reset

public enum PasswordResetEvents {
    public enum Stage: String {
        case sendCode = "send_code"
        case verifyCode = "verify_code"
        case resendCode = "resend_code"
        case updatePassword = "update_password"
    }

    public static let started = event("password_reset_started")
    public static let codeSent = event("password_reset_code_sent")
    public static let codeVerified = event("password_reset_code_verified")
    public static let codeResent = event("password_reset_code_resent")
    public static let submitted = event("password_reset_submitted")
    public static let success = event("password_reset_success")

    public static func error(_ stage: Stage, errorCode: String) -> AnalyticsEvent {
        event("password_reset_error", ["stage": .string(stage.rawValue), "error_code": .string(errorCode)])
    }
}

// MARK: - Match join / leave

public enum MatchEvents {
    public static func joinStarted(matchId: String, source: AnalyticsJoinSource, team: AnalyticsTeam) -> AnalyticsEvent {
        event("match_join_started", [
            "match_id": .string(matchId),
            "source": .string(source.rawValue),
            "team": .string(team.rawValue)
        ])
    }
    public static func reservationCreated(matchId: String) -> AnalyticsEvent {
        event("match_reservation_created", ["match_id": .string(matchId)])
    }
    public static func joinSuccess(matchId: String, reusedPayment: Bool) -> AnalyticsEvent {
        event("match_join_success", ["match_id": .string(matchId), "reused_payment": .flag(reusedPayment)])
    }
    public static func joinError(matchId: String, errorCode: String) -> AnalyticsEvent {
        event("match_join_error", ["match_id": .string(matchId), "error_code": .string(errorCode)])
    }
    public static func leaveStarted(matchId: String) -> AnalyticsEvent {
        event("match_leave_started", ["match_id": .string(matchId)])
    }
    public static func leaveSuccess(matchId: String, expired: Bool) -> AnalyticsEvent {
        event("match_leave_success", ["match_id": .string(matchId), "expired": .flag(expired)])
    }
    public static func leaveError(matchId: String, errorCode: String) -> AnalyticsEvent {
        event("match_leave_error", ["match_id": .string(matchId), "error_code": .string(errorCode)])
    }
}

// MARK: - Payment

public enum PaymentEvents {
    public enum CancelStage: String {
        case paymentSheet = "payment_sheet"
        case localAuthorization = "local_authorization"
    }
    public enum ErrorStage: String {
        case recovery
        case localAuthorization = "local_authorization"
        case paymentSheet = "payment_sheet"
        case confirmation
    }

    public static func started(matchId: String) -> AnalyticsEvent {
        event("payment_started", ["match_id": .string(matchId)])
    }
    public static func sheetOpened(matchId: String) -> AnalyticsEvent {
        event("payment_sheet_opened", ["match_id": .string(matchId)])
    }
    public static func submitted(matchId: String) -> AnalyticsEvent {
        event("payment_submitted", ["match_id": .string(matchId)])
    }
    public static func confirmed(matchId: String) -> AnalyticsEvent {
        event("payment_confirmed", ["match_id": .string(matchId)])
    }
    public static func canceled(matchId: String, stage: CancelStage) -> AnalyticsEvent {
        event("payment_canceled", ["match_id": .string(matchId), "stage": .string(stage.rawValue)])
    }
    public static func pending(matchId: String) -> AnalyticsEvent {
        event("payment_pending", ["match_id": .string(matchId)])
    }
    public static func error(matchId: String, stage: ErrorStage, errorCode: String) -> AnalyticsEvent {
        event("payment_error", [
            "match_id": .string(matchId),
            "stage": .string(stage.rawValue),
            "error_code": .string(errorCode)
        ])
    }
}
