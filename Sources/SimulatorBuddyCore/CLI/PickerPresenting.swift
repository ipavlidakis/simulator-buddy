import Foundation

/// Presents a destination picker either from live data or a prefiltered record list.
public protocol PickerPresenting: Sendable {
    /// Presents picker data loaded by query type and optional Xcode context.
    func present(
        queryType: DestinationQueryType,
        scope: SelectionScope?,
        xcodeContext: XcodeSchemeContext?
    ) async throws -> DestinationRecord

    /// Presents an already-resolved destination list.
    func present(
        records: [DestinationRecord],
        queryType: DestinationQueryType,
        scope: SelectionScope?
    ) async throws -> DestinationRecord
}
