import SharedModels

extension AuthProvider {
    var analyticsMethod: AnalyticsAuthMethod {
        switch self {
        case .google: return .google
        case .apple: return .apple
        }
    }
}
