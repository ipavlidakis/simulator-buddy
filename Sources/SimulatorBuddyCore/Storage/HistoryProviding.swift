import Foundation

/// Read-only history API used by picker loading.
public protocol HistoryProviding: Sendable {
    /// Resolves the most recent destination for a query and optional scope.
    func resolveLast(type: DestinationQueryType, scope: SelectionScope?) async throws -> HistoryEntry?
}
