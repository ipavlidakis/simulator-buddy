import Foundation

/// Codable cache document containing latest destination lists by family.
public struct DestinationCacheSnapshot: Codable, Equatable, Sendable {
    /// Schema version for forward-compatible cache migrations.
    public let schemaVersion: Int

    /// Cached simulator destinations.
    public var simulators: [DestinationRecord]

    /// Cached physical device destinations.
    public var devices: [DestinationRecord]

    /// Cached Mac destinations.
    public var macs: [DestinationRecord]

    /// Last successful simulator fetch time.
    public var simulatorFetchedAt: Date?

    /// Last successful physical device fetch time.
    public var deviceFetchedAt: Date?

    /// Last successful Mac fetch time.
    public var macFetchedAt: Date?

    /// Creates a cache snapshot with optional existing records and timestamps.
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

    /// Decodes cache snapshots while tolerating fields missing from older versions.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DestinationCacheSnapshotCodingKey.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        simulators = try container.decodeIfPresent([DestinationRecord].self, forKey: .simulators) ?? []
        devices = try container.decodeIfPresent([DestinationRecord].self, forKey: .devices) ?? []
        macs = try container.decodeIfPresent([DestinationRecord].self, forKey: .macs) ?? []
        simulatorFetchedAt = try container.decodeIfPresent(Date.self, forKey: .simulatorFetchedAt)
        deviceFetchedAt = try container.decodeIfPresent(Date.self, forKey: .deviceFetchedAt)
        macFetchedAt = try container.decodeIfPresent(Date.self, forKey: .macFetchedAt)
    }

    /// Returns cached records relevant to the query type.
    public func records(for queryType: DestinationQueryType) -> [DestinationRecord] {
        switch queryType {
        case .simulator:
            return simulators
        case .device:
            return devices
        case .macOS, .macOSCatalyst, .macOSDesignedForIPad:
            return macs
        case .all:
            return simulators + devices + macs
        }
    }

    /// Returns the last fetch timestamp for the destination family.
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

    /// Replaces one cached family and updates its fetch timestamp.
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
}
