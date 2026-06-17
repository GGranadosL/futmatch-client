import Foundation

// MARK: - Sync Result

/// Outcome of a versioned matches fetch.
enum MatchesSyncResult: Equatable {
    /// Region version unchanged — caller keeps its current list.
    case unchanged(version: Int64)
    /// Region version changed — caller replaces its list and persists `version`.
    case changed(matches: [MatchItem], version: Int64)
}

// MARK: - Protocol

protocol FetchMatchesUseCaseProtocol {
    /// Fetches the versioned public feed for `region`. Reads the locally stored
    /// version as `sinceVersion`, persists any new version, and reports whether
    /// the list changed. `lat`/`lon` drive distance sort.
    func execute(region: MatchRegion, lat: Double?, lon: Double?) async throws -> MatchesSyncResult
}

// MARK: - Implementation

final class FetchMatchesUseCase: FetchMatchesUseCaseProtocol {
    private let matchService: MatchServiceProtocol
    private let versionStore: MatchVersionStoreProtocol

    init(matchService: MatchServiceProtocol, versionStore: MatchVersionStoreProtocol) {
        self.matchService = matchService
        self.versionStore = versionStore
    }

    func execute(
        region: MatchRegion = .default,
        lat: Double? = nil,
        lon: Double? = nil
    ) async throws -> MatchesSyncResult {
        let sinceVersion = versionStore.version(for: region.key)
        let result = try await matchService.fetchMatchesV2(
            sinceVersion: sinceVersion,
            countryCode: region.countryCode,
            stateCode: region.stateCode,
            lat: lat,
            lon: lon
        )

        // Persist under the region the backend echoes back (fall back to the
        // requested region if the response omits it).
        let storageKey = result.region.isEmpty ? region.key : result.region
        versionStore.setVersion(result.currentVersion, for: storageKey)

        if result.hasChanges, let matches = result.matches {
            return .changed(matches: matches, version: result.currentVersion)
        }
        return .unchanged(version: result.currentVersion)
    }
}
