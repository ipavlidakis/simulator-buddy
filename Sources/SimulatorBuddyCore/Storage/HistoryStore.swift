import Foundation

/// Actor-backed JSON store for global and scoped destination history.
public actor HistoryStore: HistoryProviding {
    /// Paths used to locate history files.
    private let paths: AppPaths

    /// File system dependency used for reads and writes.
    private let fileManager: FileManager

    /// Encoder configured for deterministic JSON history.
    private let encoder: JSONEncoder

    /// Decoder configured for ISO-8601 timestamps.
    private let decoder: JSONDecoder

    /// Creates a history store rooted at the provided app paths.
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

    /// Loads global history, returning an empty snapshot when no file exists.
    public func loadGlobal() throws -> HistorySnapshot {
        try loadSnapshot(at: paths.globalHistoryFile)
    }

    /// Loads scoped history, returning an empty snapshot when no file exists.
    public func loadScope(_ scope: SelectionScope) throws -> HistorySnapshot {
        try loadSnapshot(at: paths.historyFile(for: scope))
    }

    /// Records a selection globally and in its scope when present.
    public func record(selection: ResolvedSelection) throws {
        var globalSnapshot = try loadGlobal()
        globalSnapshot.record(selection)
        try save(snapshot: globalSnapshot, to: paths.globalHistoryFile)

        if let scope = selection.scope {
            var scopedSnapshot = try loadScope(scope)
            scopedSnapshot.record(selection)
            try save(snapshot: scopedSnapshot, to: paths.historyFile(for: scope))
        }
    }

    /// Resolves scoped history first, then falls back to global history.
    public func resolveLast(
        type: DestinationQueryType,
        scope: SelectionScope?
    ) throws -> HistoryEntry? {
        if let scope {
            let scopedEntry = try loadScope(scope).entry(for: type)
            if let scopedEntry {
                return scopedEntry
            }
        }

        return try loadGlobal().entry(for: type)
    }

    /// Loads a history snapshot from disk or returns an empty snapshot.
    private func loadSnapshot(at url: URL) throws -> HistorySnapshot {
        guard fileManager.fileExists(atPath: url.path) else {
            return HistorySnapshot()
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(HistorySnapshot.self, from: data)
    }

    /// Writes a history snapshot atomically to disk.
    private func save(snapshot: HistorySnapshot, to url: URL) throws {
        try ensureParentDirectory(for: url)
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    /// Ensures the parent directory exists for a history file URL.
    private func ensureParentDirectory(for url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
    }
}
