import AppKit
import SimulatorBuddyCore

/// AppKit/SwiftUI implementation of the picker presenter protocol.
final class NativePickerPresenter: PickerPresenting, @unchecked Sendable {
    /// Loader used when records must be fetched from system tools.
    private let loader: DestinationSelectionLoader

    /// History store used when presenting prefiltered records.
    private let historyStore: any HistoryProviding

    /// Guard for environments that cannot show UI.
    private let guiSessionAvailability: GUISessionAvailability

    /// Delegate retained for the lifetime of the native picker presenter.
    private let applicationDelegate = PickerApplicationDelegate()

    /// Creates a native picker presenter.
    init(
        fetcher: any DestinationFetching,
        cacheStore: any DestinationCacheStoring,
        historyStore: any HistoryProviding,
        guiSessionAvailability: GUISessionAvailability = GUISessionAvailability()
    ) {
        self.historyStore = historyStore
        self.guiSessionAvailability = guiSessionAvailability
        loader = DestinationSelectionLoader(
            fetcher: fetcher,
            cacheStore: cacheStore,
            historyStore: historyStore
        )
    }

    /// Loads records for a query and presents the native picker.
    @MainActor
    func present(
        queryType: DestinationQueryType,
        scope: SelectionScope?,
        xcodeContext: XcodeSchemeContext?
    ) async throws -> DestinationRecord {
        guard guiSessionAvailability.isAvailable() else {
            throw SimulatorBuddyError.guiUnavailable
        }

        NSApplication.shared.delegate = applicationDelegate
        let loadedSelection = try await loader.load(
            queryType: queryType,
            scope: scope,
            xcodeContext: xcodeContext
        )
        return try await PickerSession(
            viewModel: DestinationPickerViewModel(loadedSelection: loadedSelection)
        ).present()
    }

    /// Presents already-filtered records, used by xcodebuild wrapper mode.
    @MainActor
    func present(
        records: [DestinationRecord],
        queryType: DestinationQueryType,
        scope: SelectionScope?
    ) async throws -> DestinationRecord {
        guard guiSessionAvailability.isAvailable() else {
            throw SimulatorBuddyError.guiUnavailable
        }

        NSApplication.shared.delegate = applicationDelegate
        let loadedSelection = try await loadedSelection(
            records: records,
            queryType: queryType,
            scope: scope
        )
        return try await PickerSession(
            viewModel: DestinationPickerViewModel(loadedSelection: loadedSelection)
        ).present()
    }

    /// Builds loaded picker state from records supplied by the caller.
    private func loadedSelection(
        records: [DestinationRecord],
        queryType: DestinationQueryType,
        scope: SelectionScope?
    ) async throws -> LoadedDestinationSelection {
        async let simulatorHistory = history(type: .simulator, queryType: queryType, scope: scope)
        async let deviceHistory = history(type: .device, queryType: queryType, scope: scope)
        async let macHistory = history(type: .macOS, queryType: queryType, scope: scope)

        return LoadedDestinationSelection(
            queryType: queryType,
            scope: scope,
            simulatorRecords: filteredRecords(of: .simulator, in: records, queryType: queryType),
            deviceRecords: filteredRecords(of: .device, in: records, queryType: queryType),
            macRecords: filteredRecords(of: .macOS, in: records, queryType: queryType),
            simulatorErrorMessage: nil,
            deviceErrorMessage: nil,
            macErrorMessage: nil,
            lastSimulatorEntry: try await simulatorHistory,
            lastDeviceEntry: try await deviceHistory,
            lastMacEntry: try await macHistory
        )
    }

    /// Loads last-used history for a family when it is visible for the query.
    private func history(
        type: DestinationQueryType,
        queryType: DestinationQueryType,
        scope: SelectionScope?
    ) async throws -> HistoryEntry? {
        guard type.kinds.contains(where: queryType.includes) else {
            return nil
        }
        return try await historyStore.resolveLast(type: type, scope: scope)
    }

    /// Filters caller-supplied records to one destination family.
    private func filteredRecords(
        of kind: DestinationKind,
        in records: [DestinationRecord],
        queryType: DestinationQueryType
    ) -> [DestinationRecord] {
        guard queryType.includes(kind) else {
            return []
        }
        return records.filter { $0.kind == kind }
    }

}
