import Combine
import Foundation

/// Main-actor state model for the native destination picker.
@MainActor
public final class DestinationPickerViewModel: ObservableObject {
    /// Query that controls which destination sections are visible.
    public let queryType: DestinationQueryType

    /// Optional scope displayed and used for history pinning.
    public let scope: SelectionScope?

    /// Current picker search text.
    @Published public var searchText = ""

    /// Selection identifier for the currently highlighted row.
    @Published public var selectedIdentifier: String?

    /// Source simulator records before search filtering.
    @Published public private(set) var simulatorRecords: [DestinationRecord]

    /// Source physical device records before search filtering.
    @Published public private(set) var deviceRecords: [DestinationRecord]

    /// Source Mac records before search filtering.
    @Published public private(set) var macRecords: [DestinationRecord]

    /// Non-fatal simulator loading error.
    @Published public private(set) var simulatorErrorMessage: String?

    /// Non-fatal physical device loading error.
    @Published public private(set) var deviceErrorMessage: String?

    /// Non-fatal Mac loading error.
    @Published public private(set) var macErrorMessage: String?

    /// User-action error shown by the picker.
    @Published public private(set) var errorMessage: String?

    /// Completion callback invoked when the picker resolves or cancels.
    public var onResolve: (@MainActor (Result<DestinationRecord, DestinationPickerFailure>) -> Void)?

    /// Last selected simulator entry used for pinning and initial selection.
    private let lastSimulatorEntry: HistoryEntry?

    /// Last selected physical device entry used for pinning and initial selection.
    private let lastDeviceEntry: HistoryEntry?

    /// Last selected Mac entry used for pinning and initial selection.
    private let lastMacEntry: HistoryEntry?

    /// Guards against resolving the picker more than once.
    private var hasResolved = false

    /// Creates picker state from loaded records, errors, and history.
    public init(loadedSelection: LoadedDestinationSelection) {
        queryType = loadedSelection.queryType
        scope = loadedSelection.scope
        simulatorRecords = loadedSelection.simulatorRecords
        deviceRecords = loadedSelection.deviceRecords
        macRecords = loadedSelection.macRecords
        simulatorErrorMessage = loadedSelection.simulatorErrorMessage
        deviceErrorMessage = loadedSelection.deviceErrorMessage
        macErrorMessage = loadedSelection.macErrorMessage
        lastSimulatorEntry = loadedSelection.lastSimulatorEntry
        lastDeviceEntry = loadedSelection.lastDeviceEntry
        lastMacEntry = loadedSelection.lastMacEntry

        if let lastSimulatorEntry,
           simulatorRecords.contains(where: { $0.udid == lastSimulatorEntry.udid }) {
            selectedIdentifier = lastSimulatorEntry.udid
        } else if let lastDeviceEntry,
                  deviceRecords.contains(where: { $0.udid == lastDeviceEntry.udid }) {
            selectedIdentifier = lastDeviceEntry.udid
        } else if let lastMacEntry,
                  let record = macRecords.first(where: { $0.udid == lastMacEntry.udid }) {
            selectedIdentifier = record.selectionIdentifier
        } else {
            selectedIdentifier = (simulatorRecords + deviceRecords + macRecords).first?.selectionIdentifier
        }
    }

    /// Search-filtered simulator rows.
    public var displayedSimulators: [DestinationRecord] {
        displayedRecords(for: .simulator)
    }

    /// Search-filtered physical device rows.
    public var displayedDevices: [DestinationRecord] {
        displayedRecords(for: .device)
    }

    /// Search-filtered Mac rows.
    public var displayedMacs: [DestinationRecord] {
        displayedRecords(for: .macOS)
    }

    /// Indicates whether any section has selectable records.
    public var hasAnyRecords: Bool {
        simulatorRecords.isEmpty == false || deviceRecords.isEmpty == false || macRecords.isEmpty == false
    }

    /// Resolves the picker with the currently selected row.
    public func chooseSelected() {
        guard let record = selectedRecord(identifier: selectedIdentifier) else {
            errorMessage = "Choose a destination first."
            return
        }

        resolve(.success(record))
    }

    /// Cancels the picker.
    public func cancel() {
        resolve(.failure(.cancelled))
    }

    /// Returns the displayed record matching a selection identifier.
    public func selectedRecord(identifier: String?) -> DestinationRecord? {
        guard let identifier else {
            return nil
        }

        return (displayedSimulators + displayedDevices + displayedMacs).first {
            $0.selectionIdentifier == identifier
        }
    }

    /// Returns whether a record matches the relevant last-used history entry.
    public func isPinned(_ record: DestinationRecord) -> Bool {
        switch record.kind {
        case .simulator:
            return lastSimulatorEntry?.udid == record.udid
        case .device:
            return lastDeviceEntry?.udid == record.udid
        case .macOS:
            return lastMacEntry?.udid == record.udid
        }
    }

    /// Finishes the picker once with success or failure.
    private func resolve(_ result: Result<DestinationRecord, DestinationPickerFailure>) {
        guard hasResolved == false else {
            return
        }

        hasResolved = true
        onResolve?(result)
    }

    /// Returns search-filtered, pin-aware rows for a destination family.
    private func displayedRecords(for kind: DestinationKind) -> [DestinationRecord] {
        let filtered = currentRecords(for: kind).filter { $0.matches(searchText: searchText) }
        let pinnedUDID: String?

        switch kind {
        case .simulator:
            pinnedUDID = lastSimulatorEntry?.udid
        case .device:
            pinnedUDID = lastDeviceEntry?.udid
        case .macOS:
            pinnedUDID = lastMacEntry?.udid
        }

        return filtered.sorted { lhs, rhs in
            let lhsPinned = lhs.udid == pinnedUDID
            let rhsPinned = rhs.udid == pinnedUDID

            if lhsPinned != rhsPinned {
                return lhsPinned
            }

            return lhs.sortKey < rhs.sortKey
        }
    }

    /// Returns unfiltered records for a destination family.
    private func currentRecords(for kind: DestinationKind) -> [DestinationRecord] {
        switch kind {
        case .simulator:
            return simulatorRecords
        case .device:
            return deviceRecords
        case .macOS:
            return macRecords
        }
    }
}
