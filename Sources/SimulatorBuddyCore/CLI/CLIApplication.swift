import Foundation

/// Coordinates command parsing and dispatch for the simulator-buddy CLI.
public final class CLIApplication: @unchecked Sendable {
    /// Parser that maps raw argv into first-class commands.
    private let parser: CLICommandParser

    /// Handler for `list`, `last`, and `select`.
    private let destinationCommands: DestinationCommandHandler

    /// Handler for compatibility debugger script generation.
    private let debugCommand: DebugCommandHandler

    /// Handler for direct LLDB attachment.
    private let attachCommand: AttachCommandHandler

    /// Handler for installing and launching apps.
    private let runCommand: RunCommandHandler

    /// Handler for building an Xcode scheme and launching its app.
    private let buildAndRunCommand: BuildAndRunCommandHandler

    /// Handler for raw xcodebuild replacement mode.
    private let xcodebuildWrapper: XcodebuildWrapperCommand

    /// Text sink for command results.
    private let standardOutput: @Sendable (String) -> Void

    /// Text sink for diagnostics.
    private let standardError: @Sendable (String) -> Void

    /// Usage text provider shared by help and parse failures.
    private let usage: CLIUsage

    /// Creates the application and wires all command handlers to shared dependencies.
    public init(
        fetcher: any DestinationFetching,
        historyStore: HistoryStore,
        pickerPresenter: any PickerPresenting,
        commandRunner: any CommandRunning = ProcessCommandRunner(),
        now: @escaping @Sendable () -> Date = Date.init,
        temporaryDirectory: @escaping @Sendable () -> URL = {
            FileManager.default.temporaryDirectory
        },
        macRunDirectory: URL = AppPaths().macRunDirectory,
        currentWorkingDirectory: @escaping @Sendable () -> URL,
        standardOutput: @escaping @Sendable (String) -> Void,
        standardError: @escaping @Sendable (String) -> Void,
        streamStandardOutput: @escaping @Sendable (String) -> Void = { _ in },
        streamStandardError: @escaping @Sendable (String) -> Void = { _ in },
        processReplacer: (any ProcessReplacing)? = nil,
        executablePath: String? = nil
    ) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let recordProvider = DestinationRecordProvider(fetcher: fetcher)
        let destinationResolver = DestinationArgumentResolver(recordProvider: recordProvider)
        parser = CLICommandParser(currentWorkingDirectory: currentWorkingDirectory)
        destinationCommands = DestinationCommandHandler(
            recordProvider: recordProvider,
            historyStore: historyStore,
            pickerPresenter: pickerPresenter,
            now: now,
            standardOutput: standardOutput,
            encoder: encoder
        )
        debugCommand = DebugCommandHandler(
            historyStore: historyStore,
            pickerPresenter: pickerPresenter,
            now: now,
            standardOutput: standardOutput,
            encoder: encoder
        )
        attachCommand = AttachCommandHandler(
            historyStore: historyStore,
            pickerPresenter: pickerPresenter,
            commandRunner: commandRunner,
            destinationResolver: destinationResolver,
            now: now,
            temporaryDirectory: temporaryDirectory,
            streamStandardOutput: streamStandardOutput,
            streamStandardError: streamStandardError,
            processReplacer: processReplacer,
            executablePath: executablePath
        )
        runCommand = RunCommandHandler(
            historyStore: historyStore,
            pickerPresenter: pickerPresenter,
            commandRunner: commandRunner,
            destinationResolver: destinationResolver,
            macWrapperBuilder: MacAppBundleWrapperBuilder(wrapperDirectory: macRunDirectory),
            now: now,
            streamStandardOutput: streamStandardOutput,
            streamStandardError: streamStandardError
        )
        buildAndRunCommand = BuildAndRunCommandHandler(
            historyStore: historyStore,
            pickerPresenter: pickerPresenter,
            commandRunner: commandRunner,
            destinationResolver: destinationResolver,
            runCommand: runCommand,
            now: now,
            streamStandardOutput: streamStandardOutput,
            streamStandardError: streamStandardError,
            processReplacer: processReplacer,
            executablePath: executablePath
        )
        xcodebuildWrapper = XcodebuildWrapperCommand(
            historyStore: historyStore,
            pickerPresenter: pickerPresenter,
            commandRunner: commandRunner,
            currentWorkingDirectory: currentWorkingDirectory,
            now: now,
            streamStandardOutput: streamStandardOutput,
            streamStandardError: streamStandardError
        )
        self.standardOutput = standardOutput
        self.standardError = standardError
        usage = CLIUsage()
    }

    /// Runs the CLI for raw arguments excluding the executable name.
    public func run(arguments: [String]) async -> Int32 {
        do {
            return try await runParsedCommand(parser.parse(arguments: arguments))
        } catch let failure as DestinationPickerFailure {
            return handlePickerFailure(failure)
        } catch {
            standardError(error.localizedDescription)
            return 1
        }
    }

    /// Dispatches a parsed command to the owning handler and returns the exit status.
    private func runParsedCommand(_ command: ParsedCommand) async throws -> Int32 {
        switch command {
        case .help:
            standardOutput(usage.text)
            return 0
        case let .list(type, format, xcodeContext):
            try await destinationCommands.list(type: type, format: format, xcodeContext: xcodeContext)
            return 0
        case let .last(type, scope, format, xcodeContext):
            try await destinationCommands.last(
                type: type,
                scope: scope,
                format: format,
                xcodeContext: xcodeContext
            )
            return 0
        case let .select(type, scope, format, xcodeContext):
            try await destinationCommands.select(
                type: type,
                scope: scope,
                format: format,
                xcodeContext: xcodeContext
            )
            return 0
        case let .debug(type, scope, processName, lldbCommandFile, xcodeContext):
            try await debugCommand.run(
                type: type,
                scope: scope,
                processName: processName,
                lldbCommandFile: lldbCommandFile,
                xcodeContext: xcodeContext
            )
            return 0
        case let .attach(type, scope, processName, destination):
            return try await attachCommand.run(
                type: type,
                scope: scope,
                processName: processName,
                destination: destination
            )
        case let .run(type, scope, appPath, bundleIdentifier, skipInstall, environment, destination):
            return try await runCommand.run(
                type: type,
                scope: scope,
                appPath: appPath,
                bundleIdentifier: bundleIdentifier,
                skipInstall: skipInstall,
                environment: environment,
                destination: destination
            )
        case let .buildAndRun(type, scope, buildArguments, bundleIdentifier, skipInstall, environment, destination):
            return try await buildAndRunCommand.run(
                type: type,
                scope: scope,
                buildArguments: buildArguments,
                bundleIdentifier: bundleIdentifier,
                skipInstall: skipInstall,
                environment: environment,
                destination: destination
            )
        case let .xcodebuild(arguments):
            return try await xcodebuildWrapper.run(arguments: arguments)
        }
    }

    /// Maps picker-specific failures to shell exit codes and stderr output.
    private func handlePickerFailure(_ failure: DestinationPickerFailure) -> Int32 {
        switch failure {
        case .cancelled:
            return 130
        default:
            standardError(failure.localizedDescription)
            return 1
        }
    }
}
