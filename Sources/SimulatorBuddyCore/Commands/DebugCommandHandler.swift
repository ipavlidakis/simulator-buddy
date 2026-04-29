import Foundation

/// Implements the compatibility `debug` command that writes LLDB script JSON.
final class DebugCommandHandler: @unchecked Sendable {
    /// Store updated with the selected destination.
    private let historyStore: HistoryStore

    /// Picker used to choose a valid destination.
    private let pickerPresenter: any PickerPresenting

    /// Clock used for history and output timestamps.
    private let now: @Sendable () -> Date

    /// Text sink for the encoded debug connection payload.
    private let standardOutput: @Sendable (String) -> Void

    /// Encoder used for deterministic JSON output.
    private let encoder: JSONEncoder

    /// Builder that writes the LLDB attach script.
    private let commandBuilder: LLDBAttachCommandBuilder

    /// Creates the debug handler.
    init(
        historyStore: HistoryStore,
        pickerPresenter: any PickerPresenting,
        now: @escaping @Sendable () -> Date,
        standardOutput: @escaping @Sendable (String) -> Void,
        encoder: JSONEncoder,
        commandBuilder: LLDBAttachCommandBuilder = LLDBAttachCommandBuilder()
    ) {
        self.historyStore = historyStore
        self.pickerPresenter = pickerPresenter
        self.now = now
        self.standardOutput = standardOutput
        self.encoder = encoder
        self.commandBuilder = commandBuilder
    }

    /// Selects a destination, writes the LLDB file, records history, and emits JSON.
    func run(
        type: DestinationQueryType,
        scope: SelectionScope,
        processName: String,
        lldbCommandFile: String,
        xcodeContext: XcodeSchemeContext?
    ) async throws {
        let record = try await pickerPresenter.present(
            queryType: type,
            scope: scope,
            xcodeContext: xcodeContext
        )
        let selectedAt = now()
        let selection = ResolvedSelection(destination: record, scope: scope, selectedAt: selectedAt)
        try await historyStore.record(selection: selection)

        let commandFileURL = URL(fileURLWithPath: lldbCommandFile)
        try commandBuilder.writeCommandFile(
            at: commandFileURL,
            destination: record,
            processName: processName
        )

        let connection = DebugConnection(
            destination: record,
            scope: scope,
            selectedAt: selectedAt,
            lldbCommandFile: commandFileURL.path
        )
        standardOutput(String(decoding: try encoder.encode(connection), as: UTF8.self))
    }
}
