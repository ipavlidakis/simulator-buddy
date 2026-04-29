import Combine
import Foundation

public enum DestinationPickerFailure: Error, LocalizedError, Sendable {
    case cancelled
    case noDestinations(DestinationQueryType)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Selection cancelled."
        case let .noDestinations(type):
            return "No \(type.rawValue) destinations are currently available."
        }
    }
}

@MainActor
public final class DestinationPickerViewModel: ObservableObject {
    public let queryType: DestinationQueryType
    public let scope: SelectionScope?

    @Published public var searchText = ""
    @Published public var selectedIdentifier: String?
    @Published public private(set) var simulatorRecords: [DestinationRecord]
    @Published public private(set) var deviceRecords: [DestinationRecord]
    @Published public private(set) var macRecords: [DestinationRecord]
    @Published public private(set) var simulatorErrorMessage: String?
    @Published public private(set) var deviceErrorMessage: String?
    @Published public private(set) var macErrorMessage: String?
    @Published public private(set) var errorMessage: String?

    public var onResolve: (@MainActor (Result<DestinationRecord, DestinationPickerFailure>) -> Void)?

    private let lastSimulatorEntry: HistoryEntry?
    private let lastDeviceEntry: HistoryEntry?
    private let lastMacEntry: HistoryEntry?
    private var hasResolved = false

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

    public var displayedSimulators: [DestinationRecord] {
        displayedRecords(for: .simulator)
    }

    public var displayedDevices: [DestinationRecord] {
        displayedRecords(for: .device)
    }

    public var displayedMacs: [DestinationRecord] {
        displayedRecords(for: .macOS)
    }

    public var hasAnyRecords: Bool {
        simulatorRecords.isEmpty == false || deviceRecords.isEmpty == false || macRecords.isEmpty == false
    }

    public func chooseSelected() {
        guard let record = selectedRecord(identifier: selectedIdentifier) else {
            errorMessage = "Choose a destination first."
            return
        }

        resolve(.success(record))
    }

    public func cancel() {
        resolve(.failure(.cancelled))
    }

    public func selectedRecord(identifier: String?) -> DestinationRecord? {
        guard let identifier else {
            return nil
        }

        return (displayedSimulators + displayedDevices + displayedMacs).first {
            $0.selectionIdentifier == identifier
        }
    }

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

    private func resolve(_ result: Result<DestinationRecord, DestinationPickerFailure>) {
        guard hasResolved == false else {
            return
        }

        hasResolved = true
        onResolve?(result)
    }

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
