import Foundation

/// Implements `list`, `last`, and `select` destination commands.
final class DestinationCommandHandler: @unchecked Sendable {
    /// Fetches live destination records for command output.
    private let recordProvider: DestinationRecordProvider

    /// Reads and updates destination history.
    private let historyStore: HistoryStore

    /// Presents the native destination picker.
    private let pickerPresenter: any PickerPresenting

    /// Clock used for selected-at timestamps.
    private let now: @Sendable () -> Date

    /// Text sink for command output.
    private let standardOutput: @Sendable (String) -> Void

    /// Encoder used for JSON output.
    private let encoder: JSONEncoder

    /// Renderer used for table output.
    private let tableRenderer: DestinationTableRenderer

    /// Creates the destination command handler.
    init(
        recordProvider: DestinationRecordProvider,
        historyStore: HistoryStore,
        pickerPresenter: any PickerPresenting,
        now: @escaping @Sendable () -> Date,
        standardOutput: @escaping @Sendable (String) -> Void,
        encoder: JSONEncoder,
        tableRenderer: DestinationTableRenderer = DestinationTableRenderer()
    ) {
        self.recordProvider = recordProvider
        self.historyStore = historyStore
        self.pickerPresenter = pickerPresenter
        self.now = now
        self.standardOutput = standardOutput
        self.encoder = encoder
        self.tableRenderer = tableRenderer
    }

    /// Prints live destinations in table or JSON format.
    func list(
        type: DestinationQueryType,
        format: SelectOutputFormat,
        xcodeContext: XcodeSchemeContext?
    ) async throws {
        let records = try await recordProvider.fetchRecords(for: type, xcodeContext: xcodeContext)
        guard records.isEmpty == false else {
            throw SimulatorBuddyError.noDestinations(type)
        }

        switch format {
        case .json:
            standardOutput(try encodeJSON(records))
        case .table:
            standardOutput(tableRenderer.render(records: records))
        case .udid:
            throw SimulatorBuddyError.usage("`list` supports only `table` and `json` formats.")
        }
    }

    /// Prints the last selected destination if it is still available.
    func last(
        type: DestinationQueryType,
        scope: SelectionScope,
        format: SelectOutputFormat,
        xcodeContext: XcodeSchemeContext?
    ) async throws {
        guard let historyEntry = try await historyStore.resolveLast(type: type, scope: scope) else {
            throw SimulatorBuddyError.noHistory(type)
        }

        let records = try await recordProvider.fetchRecords(for: type, xcodeContext: xcodeContext)
        guard let record = records.first(where: { $0.udid == historyEntry.udid }) else {
            throw SimulatorBuddyError.historyDestinationUnavailable(historyEntry.udid)
        }

        let selection = ResolvedSelection(
            destination: record,
            scope: scope,
            selectedAt: historyEntry.selectedAt
        )

        try output(selection: selection, format: format)
    }

    /// Presents the picker, records the selection, and prints it.
    func select(
        type: DestinationQueryType,
        scope: SelectionScope,
        format: SelectOutputFormat,
        xcodeContext: XcodeSchemeContext?
    ) async throws {
        let record = try await pickerPresenter.present(
            queryType: type,
            scope: scope,
            xcodeContext: xcodeContext
        )
        let selection = ResolvedSelection(destination: record, scope: scope, selectedAt: now())
        try await historyStore.record(selection: selection)
        try output(selection: selection, format: format)
    }

    /// Writes a resolved selection in the requested output format.
    private func output(selection: ResolvedSelection, format: SelectOutputFormat) throws {
        switch format {
        case .udid:
            standardOutput(selection.destination.udid)
        case .json:
            standardOutput(try encodeJSON(selection))
        case .table:
            throw SimulatorBuddyError.usage("`select` and `last` support only `udid` and `json` formats.")
        }
    }

    /// Encodes a command output value as UTF-8 JSON text.
    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
