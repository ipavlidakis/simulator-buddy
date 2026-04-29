import Foundation

/// Async storage API for destination cache snapshots.
public protocol DestinationCacheStoring: Sendable {
    /// Loads the current cache snapshot.
    func load() async throws -> DestinationCacheSnapshot

    /// Replaces records for a destination family and returns the updated cache.
    func update(
        kind: DestinationKind,
        records: [DestinationRecord],
        fetchedAt: Date
    ) async throws -> DestinationCacheSnapshot
}
