import Foundation

/// Implements `simulator-buddy attach` by selecting a destination and launching LLDB.
final class AttachCommandHandler: @unchecked Sendable {
    /// Store updated when the picker chooses a destination.
    private let historyStore: HistoryStore

    /// Native picker used when no destination is supplied.
    private let pickerPresenter: any PickerPresenting

    /// Runner used to launch LLDB.
    private let commandRunner: any CommandRunning

    /// Resolver for supplied UDIDs or xcodebuild destination specifiers.
    private let destinationResolver: DestinationArgumentResolver

    /// Clock used for history timestamps.
    private let now: @Sendable () -> Date

    /// Directory where temporary LLDB scripts are created.
    private let temporaryDirectory: @Sendable () -> URL

    /// Live stdout sink for the LLDB process.
    private let streamStandardOutput: @Sendable (String) -> Void

    /// Live stderr sink for the LLDB process.
    private let streamStandardError: @Sendable (String) -> Void

    /// Builder that writes the LLDB attach script.
    private let commandBuilder: LLDBAttachCommandBuilder

    /// Replaces the AppKit picker process with a clean direct-attach process.
    private let processReplacer: (any ProcessReplacing)?

    /// Executable path used when relaunching after a picker selection.
    private let executablePath: String?

    /// Builds direct-attach arguments for the relaunch path.
    private let relaunchArgumentsBuilder: AttachRelaunchArgumentsBuilder

    /// Creates the attach handler with injectable process and picker dependencies.
    init(
        historyStore: HistoryStore,
        pickerPresenter: any PickerPresenting,
        commandRunner: any CommandRunning,
        destinationResolver: DestinationArgumentResolver,
        now: @escaping @Sendable () -> Date,
        temporaryDirectory: @escaping @Sendable () -> URL,
        streamStandardOutput: @escaping @Sendable (String) -> Void,
        streamStandardError: @escaping @Sendable (String) -> Void,
        commandBuilder: LLDBAttachCommandBuilder = LLDBAttachCommandBuilder(),
        processReplacer: (any ProcessReplacing)? = nil,
        executablePath: String? = nil,
        relaunchArgumentsBuilder: AttachRelaunchArgumentsBuilder = AttachRelaunchArgumentsBuilder()
    ) {
        self.historyStore = historyStore
        self.pickerPresenter = pickerPresenter
        self.commandRunner = commandRunner
        self.destinationResolver = destinationResolver
        self.now = now
        self.temporaryDirectory = temporaryDirectory
        self.streamStandardOutput = streamStandardOutput
        self.streamStandardError = streamStandardError
        self.commandBuilder = commandBuilder
        self.processReplacer = processReplacer
        self.executablePath = executablePath
        self.relaunchArgumentsBuilder = relaunchArgumentsBuilder
    }

    /// Resolves a destination, writes an LLDB script, runs LLDB, and returns its exit code.
    func run(
        type: DestinationQueryType,
        scope: SelectionScope,
        processName: String,
        destination: String?
    ) async throws -> Int32 {
        let resolution = try await resolveDestination(
            type: type,
            scope: scope,
            destination: destination
        )
        if resolution.source == .picker, let processReplacer, let executablePath {
            return try processReplacer.replaceCurrentProcess(
                executablePath: executablePath,
                arguments: relaunchArguments(
                    type: type,
                    scope: scope,
                    processName: processName,
                    record: resolution.record
                )
            )
        }

        let commandFileURL = temporaryDirectory()
            .appendingPathComponent("simulator-buddy-\(UUID().uuidString)")
            .appendingPathExtension("lldb")
        try commandBuilder.writeCommandFile(
            at: commandFileURL,
            destination: resolution.record,
            processName: processName
        )

        return try await commandRunner.run(
            Command(executable: "lldb", arguments: ["-s", commandFileURL.path]),
            standardOutput: streamStandardOutput,
            standardError: streamStandardError
        )
    }

    /// Resolves a provided destination string or prompts the user and records history.
    private func resolveDestination(
        type: DestinationQueryType,
        scope: SelectionScope,
        destination: String?
    ) async throws -> AttachDestinationResolution {
        if let destination, destination.isEmpty == false {
            return AttachDestinationResolution(
                record: try await destinationResolver.resolve(destination, type: type),
                source: .provided
            )
        }

        let record = try await pickerPresenter.present(
            queryType: type,
            scope: scope,
            xcodeContext: nil
        )
        let selection = ResolvedSelection(destination: record, scope: scope, selectedAt: now())
        try await historyStore.record(selection: selection)
        return AttachDestinationResolution(record: record, source: .picker)
    }

    /// Builds direct-attach arguments for the post-picker process replacement.
    private func relaunchArguments(
        type: DestinationQueryType,
        scope: SelectionScope,
        processName: String,
        record: DestinationRecord
    ) -> [String] {
        relaunchArgumentsBuilder.arguments(
            type: type,
            scope: scope,
            processName: processName,
            destination: record.xcodeDestinationSpecifier ?? record.udid
        )
    }
}
