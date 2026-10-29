import MapKit
import UIKit

/// Opens a match venue in Apple Maps or Google Maps. Uses the venue coordinate when
/// the backend supplied one and falls back to a text search of "venue, address"
/// (the Home payload may have no coordinates). If nothing resolves, nothing happens.
@MainActor
enum MatchDirections {
    /// Needs `comgooglemaps` in `LSApplicationQueriesSchemes` (it is in the app's Info.plist).
    static var isGoogleMapsInstalled: Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func openInAppleMaps(venueName: String, address: String, coordinate: CLLocationCoordinate2D?) {
        if let coordinate {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = venueName
            item.openInMaps(launchOptions: [
                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate)
            ])
            return
        }
        guard let query = searchQuery(venueName: venueName, address: address) else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        MKLocalSearch(request: request).start { response, _ in
            response?.mapItems.first?.openInMaps()
        }
    }

    static func openInGoogleMaps(venueName: String, address: String, coordinate: CLLocationCoordinate2D?) {
        var components = URLComponents()
        components.scheme = "comgooglemaps"
        components.host = ""
        if let coordinate {
            let point = "\(coordinate.latitude),\(coordinate.longitude)"
            components.queryItems = [
                URLQueryItem(name: "q", value: point),
                URLQueryItem(name: "center", value: point),
                URLQueryItem(name: "zoom", value: "16")
            ]
        } else if let query = searchQuery(venueName: venueName, address: address) {
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        } else {
            return
        }
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    private static func searchQuery(venueName: String, address: String) -> String? {
        let query = [venueName, address]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: ", ")
        return query.isEmpty ? nil : query
    }
}
