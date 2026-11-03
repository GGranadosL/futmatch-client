import Foundation

// MARK: - Protocol

struct RankingCacheEntry: Codable, Equatable {
    let board: RankingBoard
    /// When the response was stored. The TTL counts from here and reading never renews it.
    let savedAt: Date
}

protocol RankingCacheStore {
    func entry(for query: RankingQuery) -> RankingCacheEntry?
    /// Stores one page. For page 1 the later pages of the same season, community and
    /// category are dropped in the same write, so pages from before and after a refresh
    /// never mix. Other scopes are left alone.
    func save(_ board: RankingBoard, for query: RankingQuery, at date: Date)
    func clearAll()
}

// MARK: - File implementation

/// One JSON file per season + community + category, holding its pages. Each write
/// replaces the whole file atomically. Lives in Caches: it's disposable.
final class FileRankingCacheStore: RankingCacheStore {
    private struct ScopeFile: Codable {
        var pages: [Int: RankingCacheEntry]
    }

    private let directory: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    /// `<Caches>/ranking`.
    static func defaultDirectory(fileManager: FileManager = .default) -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return caches.appendingPathComponent("ranking", isDirectory: true)
    }

    func entry(for query: RankingQuery) -> RankingCacheEntry? {
        lock.lock(); defer { lock.unlock() }
        return read(scope: query.scopeKey)?.pages[query.page]
    }

    func save(_ board: RankingBoard, for query: RankingQuery, at date: Date) {
        lock.lock(); defer { lock.unlock() }
        var file = query.page == 1 ? ScopeFile(pages: [:]) : (read(scope: query.scopeKey) ?? ScopeFile(pages: [:]))
        file.pages[query.page] = RankingCacheEntry(board: board, savedAt: date)
        write(file, scope: query.scopeKey)
    }

    func clearAll() {
        lock.lock(); defer { lock.unlock() }
        try? fileManager.removeItem(at: directory)
    }

    // MARK: - Private

    private func url(scope: String) -> URL {
        directory.appendingPathComponent("\(scope).json")
    }

    private func read(scope: String) -> ScopeFile? {
        guard let data = try? Data(contentsOf: url(scope: scope)) else { return nil }
        return try? JSONDecoder().decode(ScopeFile.self, from: data)
    }

    private func write(_ file: ScopeFile, scope: String) {
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(scope: scope), options: .atomic)
    }
}
