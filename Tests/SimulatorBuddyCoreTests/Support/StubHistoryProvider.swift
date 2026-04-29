import Foundation
@testable import SimulatorBuddyCore

/// History provider test double with configurable entries.
actor StubHistoryProvider: HistoryProviding {
    /// Entry returned for simulator queries.
    var simulatorEntry: HistoryEntry?

    /// Entry returned for physical device queries.
    var deviceEntry: HistoryEntry?

    /// Entry returned for Mac queries.
    var macEntry: HistoryEntry?

    /// Entry returned for all-destination queries when set.
    var allEntry: HistoryEntry?

    /// Creates a history provider seeded with optional entries.
    init(
        simulatorEntry: HistoryEntry? = nil,
        deviceEntry: HistoryEntry? = nil,
        macEntry: HistoryEntry? = nil,
        allEntry: HistoryEntry? = nil
    ) {
        self.simulatorEntry = simulatorEntry
        self.deviceEntry = deviceEntry
        self.macEntry = macEntry
        self.allEntry = allEntry
    }

    /// Resolves the configured entry for a query type.
    func resolveLast(type: DestinationQueryType, scope: SelectionScope?) async throws -> HistoryEntry? {
        switch type {
        case .simulator:
            return simulatorEntry
        case .device:
            return deviceEntry
        case .macOS, .macOSCatalyst, .macOSDesignedForIPad:
            return macEntry
        case .all:
            return allEntry ?? simulatorEntry ?? deviceEntry ?? macEntry
        }
    }
}
