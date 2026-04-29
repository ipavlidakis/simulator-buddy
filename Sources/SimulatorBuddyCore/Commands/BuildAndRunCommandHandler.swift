import Foundation

/// Builds an Xcode scheme, installs its app when required, and launches it.
final class BuildAndRunCommandHandler: @unchecked Sendable {
    /// Store updated with picker selections.
    private let historyStore: HistoryStore

    /// Picker used to choose among scheme-valid destinations.
    private let pickerPresenter: any PickerPresenting

    /// Runner used for xcodebuild discovery, build, and settings commands.
    private let commandRunner: any CommandRunning

    /// Resolves direct destination arguments.
    private let destinationResolver: DestinationArgumentResolver

    /// Existing app install and launch command handler.
    private let runCommand: RunCommandHandler

    /// Clock used for history timestamps.
    private let now: @Sendable () -> Date

    /// Live stdout sink for build and launch commands.
    private let streamStandardOutput: @Sendable (String) -> Void

    /// Live stderr sink for build and launch commands.
    private let streamStandardError: @Sendable (String) -> Void

    /// Resolver for Xcode command structure.
    private let invocationResolver: XcodebuildInvocationResolver

    /// Parser for scheme-valid destinations.
    private let destinationParser: XcodeShowDestinationsParser

    /// Parser for app product build settings.
    private let buildSettingsParser: XcodeBuildSettingsParser

    /// Replaces the AppKit picker process with a clean direct-run process.
    private let processReplacer: (any ProcessReplacing)?

    /// Executable path used when relaunching after a picker selection.
    private let executablePath: String?

    /// Builds direct-run arguments for the relaunch path.
    private let relaunchArgumentsBuilder: BuildAndRunRelaunchArgumentsBuilder

    /// Creates a build-and-run command handler.
    init(
        historyStore: HistoryStore,
        pickerPresenter: any PickerPresenting,
        commandRunner: any CommandRunning,
        destinationResolver: DestinationArgumentResolver,
        runCommand: RunCommandHandler,
        now: @escaping @Sendable () -> Date,
        streamStandardOutput: @escaping @Sendable (String) -> Void,
        streamStandardError: @escaping @Sendable (String) -> Void,
        invocationResolver: XcodebuildInvocationResolver = XcodebuildInvocationResolver(),
        destinationParser: XcodeShowDestinationsParser = XcodeShowDestinationsParser(),
        buildSettingsParser: XcodeBuildSettingsParser = XcodeBuildSettingsParser(),
        processReplacer: (any ProcessReplacing)? = nil,
        executablePath: String? = nil,
        relaunchArgumentsBuilder: BuildAndRunRelaunchArgumentsBuilder = BuildAndRunRelaunchArgumentsBuilder()
    ) {
        self.historyStore = historyStore
        self.pickerPresenter = pickerPresenter
        self.commandRunner = commandRunner
        self.destinationResolver = destinationResolver
        self.runCommand = runCommand
        self.now = now
        self.streamStandardOutput = streamStandardOutput
        self.streamStandardError = streamStandardError
        self.invocationResolver = invocationResolver
        self.destinationParser = destinationParser
        self.buildSettingsParser = buildSettingsParser
        self.processReplacer = processReplacer
        self.executablePath = executablePath
        self.relaunchArgumentsBuilder = relaunchArgumentsBuilder
    }

    /// Selects a destination, builds the scheme, resolves the app, and launches it.
    func run(
        type: DestinationQueryType,
        scope: SelectionScope,
        buildArguments: [String],
        bundleIdentifier: String?,
        skipInstall: Bool,
        environment: [EnvironmentVariable],
        logCategories: [String],
        destination: String?
    ) async throws -> Int32 {
        guard invocationResolver.context(from: buildArguments) != nil else {
            throw SimulatorBuddyError.usage("run requires -project or -workspace with -scheme.")
        }

        guard invocationResolver.isInfoOnlyCommand(arguments: buildArguments) == false else {
            throw SimulatorBuddyError.usage("run does not support xcodebuild info-only commands.")
        }

        guard invocationResolver.supportsBuildAndRunActions(arguments: buildArguments) else {
            throw SimulatorBuddyError.usage("run only supports xcodebuild clean/build actions.")
        }

        let destinationResolution = try await resolveDestination(
            type: type,
            scope: scope,
            arguments: buildArguments,
            destination: destination
        )
        guard case let .success(record, source) = destinationResolution else {
            return destinationResolution.exitCode
        }

        if source == .picker, let processReplacer, let executablePath {
            return try processReplacer.replaceCurrentProcess(
                executablePath: executablePath,
                arguments: relaunchArguments(
                    type: type,
                    scope: scope,
                    buildArguments: buildArguments,
                    bundleIdentifier: bundleIdentifier,
                    skipInstall: skipInstall,
                    environment: environment,
                    logCategories: logCategories,
                    record: record
                )
            )
        }

        let destinationArguments = argumentsByEnsuringDestination(for: record, arguments: buildArguments)
        let buildArguments = invocationResolver.argumentsByEnsuringBuildAction(arguments: destinationArguments)
        let buildStatus = try await runXcodebuild(arguments: buildArguments)
        guard buildStatus == 0 else {
            return buildStatus
        }

        let settingsStatus = try await resolveBuiltProduct(arguments: destinationArguments)
        guard case let .success(product) = settingsStatus else {
            return settingsStatus.exitCode
        }

        return try await runCommand.run(
            appURL: product.appURL,
            bundleIdentifier: bundleIdentifier ?? product.bundleIdentifier,
            skipInstall: skipInstall,
            environment: environment,
            logCategories: logCategories,
            destinationRecord: record
        )
    }

    /// Resolves a direct destination or presents the scheme-filtered picker.
    private func resolveDestination(
        type: DestinationQueryType,
        scope: SelectionScope,
        arguments: [String],
        destination: String?
    ) async throws -> BuildDestinationResolution {
        if let value = destination ?? invocationResolver.destinationArgument(in: arguments) {
            return .success(record: try await destinationResolver.resolve(value, type: type), source: .provided)
        }

        guard let context = invocationResolver.context(from: arguments) else {
            throw SimulatorBuddyError.usage("run requires -project or -workspace with -scheme.")
        }

        let result = try await commandRunner.run(Command(
            executable: "xcodebuild",
            arguments: invocationResolver.showDestinationsArguments(for: context)
        ))
        guard result.terminationStatus == 0 else {
            emit(result)
            return .failure(result.terminationStatus)
        }

        let records = destinationParser.parseRunDestinations(from: result.stdout)
        guard records.isEmpty == false else {
            throw SimulatorBuddyError.noDestinations(type)
        }

        let record = try await pickerPresenter.present(records: records, queryType: type, scope: scope)
        try await historyStore.record(selection: ResolvedSelection(destination: record, scope: scope, selectedAt: now()))
        return .success(record: record, source: .picker)
    }

    /// Builds direct-run arguments for the post-picker process replacement.
    private func relaunchArguments(
        type: DestinationQueryType,
        scope: SelectionScope,
        buildArguments: [String],
        bundleIdentifier: String?,
        skipInstall: Bool,
        environment: [EnvironmentVariable],
        logCategories: [String],
        record: DestinationRecord
    ) -> [String] {
        relaunchArgumentsBuilder.arguments(
            type: type,
            scope: scope,
            buildArguments: buildArguments,
            bundleIdentifier: bundleIdentifier,
            skipInstall: skipInstall,
            environment: environment,
            logCategories: logCategories,
            destination: record.xcodeDestinationSpecifier ?? "id=\(record.udid)"
        )
    }

    /// Returns arguments with a destination when one was not already supplied.
    private func argumentsByEnsuringDestination(
        for record: DestinationRecord,
        arguments: [String]
    ) -> [String] {
        guard invocationResolver.destinationArgument(in: arguments) == nil else {
            return arguments
        }

        let destination = record.xcodeDestinationSpecifier ?? "id=\(record.udid)"
        return invocationResolver.argumentsByInjectingDestination(destination, into: arguments)
    }

    /// Resolves the built app product by running `xcodebuild -showBuildSettings`.
    private func resolveBuiltProduct(arguments: [String]) async throws -> BuildProductResolution {
        let settingsArguments = invocationResolver.argumentsByRemovingActions(arguments: arguments) + ["-showBuildSettings"]
        let result = try await commandRunner.run(Command(executable: "xcodebuild", arguments: settingsArguments))
        guard result.terminationStatus == 0 else {
            emit(result)
            return .failure(result.terminationStatus)
        }

        return .success(try buildSettingsParser.parseBuiltProduct(from: result.stdout))
    }

    /// Runs `xcodebuild` with live output streaming.
    private func runXcodebuild(arguments: [String]) async throws -> Int32 {
        try await commandRunner.run(
            Command(executable: "xcodebuild", arguments: arguments),
            standardOutput: streamStandardOutput,
            standardError: streamStandardError
        )
    }

    /// Emits buffered command output through live sinks.
    private func emit(_ result: CommandResult) {
        if result.stdout.isEmpty == false {
            streamStandardOutput(result.stdout)
        }
        if result.stderr.isEmpty == false {
            streamStandardError(result.stderr)
        }
    }
}
