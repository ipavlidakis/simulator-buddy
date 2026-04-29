import Foundation

/// Actor-backed JSON store for destination cache snapshots.
public actor DestinationCacheStore: DestinationCacheStoring {
    /// Paths used to locate the cache file.
    private let paths: AppPaths

    /// File system dependency used for reads and writes.
    private let fileManager: FileManager

    /// Encoder configured for deterministic cache JSON.
    private let encoder: JSONEncoder

    /// Decoder configured for ISO-8601 timestamps.
    private let decoder: JSONDecoder

    /// Creates a cache store rooted at the provided app paths.
    public init(paths: AppPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Loads the cache snapshot, returning an empty snapshot when no cache exists.
    public func load() throws -> DestinationCacheSnapshot {
        guard fileManager.fileExists(atPath: paths.destinationCacheFile.path) else {
            return DestinationCacheSnapshot()
        }

        let data = try Data(contentsOf: paths.destinationCacheFile)
        return try decoder.decode(DestinationCacheSnapshot.self, from: data)
    }

    /// Persists the complete cache snapshot atomically.
    public func save(_ snapshot: DestinationCacheSnapshot) throws {
        try fileManager.createDirectory(
            at: paths.cacheDirectory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: paths.destinationCacheFile, options: .atomic)
    }

    /// Updates one destination family in the cache and returns the new snapshot.
    public func update(
        kind: DestinationKind,
        records: [DestinationRecord],
        fetchedAt: Date
    ) throws -> DestinationCacheSnapshot {
        var snapshot = try load()
        snapshot.update(kind: kind, records: records, fetchedAt: fetchedAt)
        try save(snapshot)
        return snapshot
    }
}
