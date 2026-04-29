import Foundation

/// Persisted summary of a selected destination.
public struct HistoryEntry: Codable, Equatable, Sendable {
    /// Destination family stored at selection time.
    public let kind: DestinationKind

    /// Destination identifier stored at selection time.
    public let udid: String

    /// Destination display name stored at selection time.
    public let name: String

    /// Runtime label stored at selection time.
    public let runtime: String?

    /// Selection timestamp used for recency and JSON output.
    public let selectedAt: Date

    /// Creates a persisted history entry.
    public init(
        kind: DestinationKind,
        udid: String,
        name: String,
        runtime: String?,
        selectedAt: Date
    ) {
        self.kind = kind
        self.udid = udid
        self.name = name
        self.runtime = runtime
        self.selectedAt = selectedAt
    }
}
