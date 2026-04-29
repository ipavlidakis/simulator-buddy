import Foundation

/// Complete picker data payload including records, load errors, and history hints.
public struct LoadedDestinationSelection: Sendable {
    /// Query that requested this payload.
    public let queryType: DestinationQueryType

    /// Optional scope used to load last-used history.
    public let scope: SelectionScope?

    /// Simulator records available to display.
    public let simulatorRecords: [DestinationRecord]

    /// Physical device records available to display.
    public let deviceRecords: [DestinationRecord]

    /// Mac destination records available to display.
    public let macRecords: [DestinationRecord]

    /// Non-fatal simulator loading error shown in the picker.
    public let simulatorErrorMessage: String?

    /// Non-fatal physical device loading error shown in the picker.
    public let deviceErrorMessage: String?

    /// Non-fatal Mac destination loading error shown in the picker.
    public let macErrorMessage: String?

    /// Last selected simulator entry for the current scope.
    public let lastSimulatorEntry: HistoryEntry?

    /// Last selected device entry for the current scope.
    public let lastDeviceEntry: HistoryEntry?

    /// Last selected Mac entry for the current scope.
    public let lastMacEntry: HistoryEntry?

    /// Creates a fully loaded picker payload.
    public init(
        queryType: DestinationQueryType,
        scope: SelectionScope?,
        simulatorRecords: [DestinationRecord],
        deviceRecords: [DestinationRecord],
        macRecords: [DestinationRecord],
        simulatorErrorMessage: String?,
        deviceErrorMessage: String?,
        macErrorMessage: String?,
        lastSimulatorEntry: HistoryEntry?,
        lastDeviceEntry: HistoryEntry?,
        lastMacEntry: HistoryEntry?
    ) {
        self.queryType = queryType
        self.scope = scope
        self.simulatorRecords = simulatorRecords
        self.deviceRecords = deviceRecords
        self.macRecords = macRecords
        self.simulatorErrorMessage = simulatorErrorMessage
        self.deviceErrorMessage = deviceErrorMessage
        self.macErrorMessage = macErrorMessage
        self.lastSimulatorEntry = lastSimulatorEntry
        self.lastDeviceEntry = lastDeviceEntry
        self.lastMacEntry = lastMacEntry
    }
}
