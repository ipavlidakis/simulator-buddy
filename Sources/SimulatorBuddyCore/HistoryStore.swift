import Foundation

public struct HistorySnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public var lastSimulator: HistoryEntry?
    public var lastDevice: HistoryEntry?
    public var lastAny: HistoryEntry?

    public init(
        schemaVersion: Int = 1,
        lastSimulator: HistoryEntry? = nil,
        lastDevice: HistoryEntry? = nil,
        lastAny: HistoryEntry? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.lastSimulator = lastSimulator
        self.lastDevice = lastDevice
        self.lastAny = lastAny
    }

    public mutating func record(_ selection: ResolvedSelection) {
        let entry = HistoryEntry(
            kind: selection.destination.kind,
            udid: selection.destination.udid,
            name: selection.destination.name,
            runtime: selection.destination.runtime,
            selectedAt: selection.selectedAt
        )

        switch entry.kind {
        case .simulator:
            lastSimulator = entry
        case .device:
            lastDevice = entry
        }

        lastAny = entry
    }

    public func entry(for queryType: DestinationQueryType) -> HistoryEntry? {
        switch queryType {
        case .simulator:
            return lastSimulator
        case .device:
            return lastDevice
        case .all:
            if let lastAny {
                return lastAny
            }

            return [lastSimulator, lastDevice]
                .compactMap { $0 }
                .max { $0.selectedAt < $1.selectedAt }
        }
    }
}

public protocol HistoryProviding: Sendable {
    func resolveLast(type: DestinationQueryType, scope: SelectionScope?) async throws -> HistoryEntry?
}

public actor HistoryStore: HistoryProviding {
    private let paths: AppPaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

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

    public func loadGlobal() throws -> HistorySnapshot {
        try loadSnapshot(at: paths.globalHistoryFile)
    }

    public func loadScope(_ scope: SelectionScope) throws -> HistorySnapshot {
        try loadSnapshot(at: paths.historyFile(for: scope))
    }

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

    private func loadSnapshot(at url: URL) throws -> HistorySnapshot {
        guard fileManager.fileExists(atPath: url.path) else {
            return HistorySnapshot()
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(HistorySnapshot.self, from: data)
    }

    private func save(snapshot: HistorySnapshot, to url: URL) throws {
        try ensureParentDirectory(for: url)
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    private func ensureParentDirectory(for url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
    }
}
