import Foundation
@testable import SimulatorBuddyCore

/// In-memory actor test double for destination cache storage.
actor InMemoryCacheStore: DestinationCacheStoring {
    /// Current mutable cache snapshot.
    var snapshot: DestinationCacheSnapshot

    /// Creates a cache store seeded with a snapshot.
    init(snapshot: DestinationCacheSnapshot = DestinationCacheSnapshot()) {
        self.snapshot = snapshot
    }

    /// Returns the current cache snapshot.
    func load() async throws -> DestinationCacheSnapshot {
        snapshot
    }

    /// Updates one destination family in memory.
    func update(
        kind: DestinationKind,
        records: [DestinationRecord],
        fetchedAt: Date
    ) async throws -> DestinationCacheSnapshot {
        snapshot.update(kind: kind, records: records, fetchedAt: fetchedAt)
        return snapshot
    }
}
