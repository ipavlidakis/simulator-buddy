import Foundation

/// Codable history document storing last-used destinations by family.
public struct HistorySnapshot: Codable, Equatable, Sendable {
    /// Schema version for future history migrations.
    public let schemaVersion: Int

    /// Last selected simulator.
    public var lastSimulator: HistoryEntry?

    /// Last selected physical device.
    public var lastDevice: HistoryEntry?

    /// Last selected Mac destination.
    public var lastMac: HistoryEntry?

    /// Last selected destination across all families.
    public var lastAny: HistoryEntry?

    /// Creates a history snapshot with optional existing entries.
    public init(
        schemaVersion: Int = 1,
        lastSimulator: HistoryEntry? = nil,
        lastDevice: HistoryEntry? = nil,
        lastMac: HistoryEntry? = nil,
        lastAny: HistoryEntry? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.lastSimulator = lastSimulator
        self.lastDevice = lastDevice
        self.lastMac = lastMac
        self.lastAny = lastAny
    }

    /// Records a selection into its family bucket and the global any bucket.
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
        case .macOS:
            lastMac = entry
        }

        lastAny = entry
    }

    /// Returns the best history entry for a destination query.
    public func entry(for queryType: DestinationQueryType) -> HistoryEntry? {
        switch queryType {
        case .simulator:
            return lastSimulator
        case .device:
            return lastDevice
        case .macOS, .macOSCatalyst, .macOSDesignedForIPad:
            return lastMac
        case .all:
            if let lastAny {
                return lastAny
            }

            return [lastSimulator, lastDevice, lastMac]
                .compactMap { $0 }
                .max { $0.selectedAt < $1.selectedAt }
        }
    }
}
