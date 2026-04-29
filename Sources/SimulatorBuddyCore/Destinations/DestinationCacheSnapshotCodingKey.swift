import Foundation

/// Coding keys for the destination cache document.
enum DestinationCacheSnapshotCodingKey: String, CodingKey {
    /// Cache schema version.
    case schemaVersion

    /// Cached simulator records.
    case simulators

    /// Cached physical device records.
    case devices

    /// Cached Mac records.
    case macs

    /// Simulator fetch timestamp.
    case simulatorFetchedAt

    /// Physical device fetch timestamp.
    case deviceFetchedAt

    /// Mac fetch timestamp.
    case macFetchedAt
}
