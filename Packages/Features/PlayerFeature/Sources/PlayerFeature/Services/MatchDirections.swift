import MapKit

/// Opens Apple Maps for a match venue. Uses the venue coordinate when the backend
/// supplied one and falls back to a text search of "venue, address" (the Home
/// payload has no coordinates). If Maps cannot resolve it, nothing happens.
@MainActor
enum MatchDirections {
    static func open(venueName: String, address: String, coordinate: CLLocationCoordinate2D?) {
        if let coordinate {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = venueName
            item.openInMaps()
            return
        }
        let query = [venueName, address]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: ", ")
        guard !query.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        MKLocalSearch(request: request).start { response, _ in
            response?.mapItems.first?.openInMaps()
        }
    }
}
