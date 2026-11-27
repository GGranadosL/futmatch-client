import Foundation

// MARK: - App Icon Badge

/// The number iOS shows on the app icon. Kept equal to the Home bell's unread counter.
protocol AppIconBadgeProtocol {
    func setCount(_ count: Int)
}
