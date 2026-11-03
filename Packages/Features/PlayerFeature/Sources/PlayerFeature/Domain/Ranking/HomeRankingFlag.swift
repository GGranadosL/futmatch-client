import Foundation
import Combine

/// `home_ranking_enabled` Remote Config flag: shows the Ranking card on Home in place of
/// the Last Match card. The app target fetches it from Firebase and writes it here; the
/// feature only reads the cached value, so it never touches Firebase directly.
public enum HomeRankingFlag {
    /// UserDefaults key holding the last activated value. Missing → `false`.
    public static let cachedEnabledKey = "fm_home_ranking_enabled"
    /// Posted after a new value is written, so an open Home switches cards without a relaunch.
    public static let didChangeNotification = Notification.Name("fm.homeRankingFlagDidChange")
}

protocol HomeRankingFlagProviding {
    var isEnabled: Bool { get }
    /// Emits the current value on the main queue every time the flag is rewritten.
    var changes: AnyPublisher<Bool, Never> { get }
}

struct UserDefaultsHomeRankingFlag: HomeRankingFlagProviding {
    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter

    init(defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    var isEnabled: Bool {
        (defaults.object(forKey: HomeRankingFlag.cachedEnabledKey) as? Bool) ?? false
    }

    var changes: AnyPublisher<Bool, Never> {
        let defaults = defaults
        return notificationCenter.publisher(for: HomeRankingFlag.didChangeNotification)
            .map { _ in (defaults.object(forKey: HomeRankingFlag.cachedEnabledKey) as? Bool) ?? false }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
