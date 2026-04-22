import Foundation

public struct DestinationCacheSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public var simulators: [DestinationRecord]
    public var devices: [DestinationRecord]
    public var simulatorFetchedAt: Date?
    public var deviceFetchedAt: Date?

    public init(
        schemaVersion: Int = 1,
        simulators: [DestinationRecord] = [],
        devices: [DestinationRecord] = [],
        simulatorFetchedAt: Date? = nil,
        deviceFetchedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.simulators = simulators
        self.devices = devices
        self.simulatorFetchedAt = simulatorFetchedAt
        self.deviceFetchedAt = deviceFetchedAt
    }

    public func records(for queryType: DestinationQueryType) -> [DestinationRecord] {
        switch queryType {
        case .simulator:
            return simulators
        case .device:
            return devices
        case .all:
            return simulators + devices
        }
    }

    public func fetchedAt(for kind: DestinationKind) -> Date? {
        switch kind {
        case .simulator:
            return simulatorFetchedAt
        case .device:
            return deviceFetchedAt
        }
    }

    public mutating func update(
        kind: DestinationKind,
        records: [DestinationRecord],
        fetchedAt: Date
    ) {
        switch kind {
        case .simulator:
            simulators = records
            simulatorFetchedAt = fetchedAt
        case .device:
            devices = records
            deviceFetchedAt = fetchedAt
        }
    }
}

public protocol DestinationCacheStoring: Sendable {
    func load() async throws -> DestinationCacheSnapshot
    func update(
        kind: DestinationKind,
        records: [DestinationRecord],
        fetchedAt: Date
    ) async throws -> DestinationCacheSnapshot
}

public actor DestinationCacheStore: DestinationCacheStoring {
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

    public func load() throws -> DestinationCacheSnapshot {
        guard fileManager.fileExists(atPath: paths.destinationCacheFile.path) else {
            return DestinationCacheSnapshot()
        }

        let data = try Data(contentsOf: paths.destinationCacheFile)
        return try decoder.decode(DestinationCacheSnapshot.self, from: data)
    }

    public func save(_ snapshot: DestinationCacheSnapshot) throws {
        try fileManager.createDirectory(
            at: paths.cacheDirectory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: paths.destinationCacheFile, options: .atomic)
    }

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
