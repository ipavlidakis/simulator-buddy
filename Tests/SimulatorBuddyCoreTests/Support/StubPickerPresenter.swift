import Foundation
@testable import SimulatorBuddyCore

/// Picker presenter test double that returns a configured result.
actor StubPickerPresenter: PickerPresenting {
    /// Result returned by both picker presentation methods.
    private let result: Result<DestinationRecord, Error>

    /// Last record list passed to prefiltered presentation.
    private(set) var presentedRecords: [DestinationRecord]?

    /// Number of times either presentation method was called.
    private(set) var presentCallCount = 0

    /// Creates a picker presenter that returns the supplied result.
    init(result: Result<DestinationRecord, Error>) {
        self.result = result
    }

    /// Records a query presentation and returns the configured result.
    func present(
        queryType: DestinationQueryType,
        scope: SelectionScope?,
        xcodeContext: XcodeSchemeContext?
    ) async throws -> DestinationRecord {
        presentCallCount += 1
        return try result.get()
    }

    /// Records a prefiltered presentation and returns the configured result.
    func present(
        records: [DestinationRecord],
        queryType: DestinationQueryType,
        scope: SelectionScope?
    ) async throws -> DestinationRecord {
        presentedRecords = records
        presentCallCount += 1
        return try result.get()
    }
}
