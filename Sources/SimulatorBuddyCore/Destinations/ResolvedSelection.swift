import Foundation

/// Destination selection enriched with scope and timestamp metadata.
public struct ResolvedSelection: Codable, Equatable, Sendable {
    /// Selected destination record.
    public let destination: DestinationRecord

    /// History scope where the selection was recorded.
    public let scope: SelectionScope?

    /// Timestamp when this selection was made or restored.
    public let selectedAt: Date

    /// Creates a resolved destination selection.
    public init(destination: DestinationRecord, scope: SelectionScope?, selectedAt: Date) {
        self.destination = destination
        self.scope = scope
        self.selectedAt = selectedAt
    }
}
