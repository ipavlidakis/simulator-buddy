import Foundation

public struct DestinationCacheSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public var simulators: [DestinationRecord]
    public var devices: [DestinationRecord]
    public var macs: [DestinationRecord]
    public var simulatorFetchedAt: Date?
    public var deviceFetchedAt: Date?
    public var macFetchedAt: Date?

    public init(
        schemaVersion: Int = 1,
        simulators: [DestinationRecord] = [],
        devices: [DestinationRecord] = [],
        macs: [DestinationRecord] = [],
        simulatorFetchedAt: Date? = nil,
        deviceFetchedAt: Date? = nil,
        macFetchedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.simulators = simulators
        self.devices = devices
        self.macs = macs
        self.simulatorFetchedAt = simulatorFetchedAt
        self.deviceFetchedAt = deviceFetchedAt
        self.macFetchedAt = macFetchedAt
    }

    public func records(for queryType: DestinationQueryType) -> [DestinationRecord] {
        switch queryType {
        case .simulator:
            return simulators
        case .device:
            return devices
        case .macOS:
            return macs
        case .all:
            return simulators + devices + macs
        }
    }

    public func fetchedAt(for kind: DestinationKind) -> Date? {
        switch kind {
        case .simulator:
            return simulatorFetchedAt
        case .device:
            return deviceFetchedAt
        case .macOS:
            return macFetchedAt
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
        case .macOS:
            macs = records
            macFetchedAt = fetchedAt
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case simulators
        case devices
        case macs
        case simulatorFetchedAt
        case deviceFetchedAt
        case macFetchedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        simulators = try container.decodeIfPresent([DestinationRecord].self, forKey: .simulators) ?? []
        devices = try container.decodeIfPresent([DestinationRecord].self, forKey: .devices) ?? []
        macs = try container.decodeIfPresent([DestinationRecord].self, forKey: .macs) ?? []
        simulatorFetchedAt = try container.decodeIfPresent(Date.self, forKey: .simulatorFetchedAt)
        deviceFetchedAt = try container.decodeIfPresent(Date.self, forKey: .deviceFetchedAt)
        macFetchedAt = try container.decodeIfPresent(Date.self, forKey: .macFetchedAt)
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
