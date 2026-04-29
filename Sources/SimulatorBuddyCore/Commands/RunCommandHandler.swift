import Foundation

/// Installs and launches an app bundle on the selected destination family.
final class RunCommandHandler: @unchecked Sendable {
    /// Stores picker-based destination selections.
    private let historyStore: HistoryStore

    /// Presents the destination picker when no destination argument is supplied.
    private let pickerPresenter: any PickerPresenting

    /// Runs install and launch subprocesses.
    private let commandRunner: any CommandRunning

    /// Resolves `--destination` strings into destination records.
    private let destinationResolver: DestinationArgumentResolver

    /// Reads launch metadata from `.app` bundles.
    private let appBundleInfoReader: AppBundleInfoReader

    /// Builds destination-specific install and launch commands.
    private let launchCommandBuilder: AppLaunchCommandBuilder

    /// Supplies timestamps for stored selections.
    private let now: @Sendable () -> Date

    /// Streams subprocess stdout chunks.
    private let streamStandardOutput: @Sendable (String) -> Void

    /// Streams subprocess stderr chunks.
    private let streamStandardError: @Sendable (String) -> Void

    /// Creates the run command handler.
    init(
        historyStore: HistoryStore,
        pickerPresenter: any PickerPresenting,
        commandRunner: any CommandRunning,
        destinationResolver: DestinationArgumentResolver,
        appBundleInfoReader: AppBundleInfoReader = AppBundleInfoReader(),
        macWrapperBuilder: MacAppBundleWrapperBuilder,
        now: @escaping @Sendable () -> Date,
        streamStandardOutput: @escaping @Sendable (String) -> Void,
        streamStandardError: @escaping @Sendable (String) -> Void
    ) {
        self.historyStore = historyStore
        self.pickerPresenter = pickerPresenter
        self.commandRunner = commandRunner
        self.destinationResolver = destinationResolver
        self.appBundleInfoReader = appBundleInfoReader
        launchCommandBuilder = AppLaunchCommandBuilder(macWrapperBuilder: macWrapperBuilder)
        self.now = now
        self.streamStandardOutput = streamStandardOutput
        self.streamStandardError = streamStandardError
    }

    /// Installs the app bundle when needed and launches it on the selected destination.
    func run(
        type: DestinationQueryType,
        scope: SelectionScope,
        appPath: String,
        bundleIdentifier: String?,
        skipInstall: Bool,
        environment: [EnvironmentVariable],
        logCategories: [String] = [],
        destination: String?
    ) async throws -> Int32 {
        let appURL = URL(fileURLWithPath: appPath)
        let appInfo = try appBundleInfoReader.read(at: appURL)
        let resolvedBundleIdentifier = bundleIdentifier ?? appInfo.bundleIdentifier
        let record = try await resolveDestination(type: type, scope: scope, destination: destination)

        return try await run(
            appURL: appURL,
            appInfo: appInfo,
            bundleIdentifier: resolvedBundleIdentifier,
            skipInstall: skipInstall,
            environment: environment,
            logCategories: logCategories,
            destinationRecord: record
        )
    }

    /// Installs and launches an already-resolved app and destination.
    func run(
        appURL: URL,
        bundleIdentifier: String?,
        skipInstall: Bool,
        environment: [EnvironmentVariable],
        logCategories: [String] = [],
        destinationRecord: DestinationRecord
    ) async throws -> Int32 {
        let appInfo = try appBundleInfoReader.read(at: appURL)
        let resolvedBundleIdentifier = bundleIdentifier ?? appInfo.bundleIdentifier
        return try await run(
            appURL: appURL,
            appInfo: appInfo,
            bundleIdentifier: resolvedBundleIdentifier,
            skipInstall: skipInstall,
            environment: environment,
            logCategories: logCategories,
            destinationRecord: destinationRecord
        )
    }

    /// Installs and launches an app with already-loaded bundle metadata.
    private func run(
        appURL: URL,
        appInfo: AppBundleInfo,
        bundleIdentifier: String,
        skipInstall: Bool,
        environment: [EnvironmentVariable],
        logCategories: [String],
        destinationRecord record: DestinationRecord
    ) async throws -> Int32 {
        if let simulatorBootCommand = launchCommandBuilder.simulatorBootCommand(for: record) {
            let bootStatus = try await runCommand(simulatorBootCommand)
            guard bootStatus == 0 else {
                return bootStatus
            }
        }

        if let simulatorUICommand = launchCommandBuilder.simulatorUICommand(for: record) {
            await runBestEffortCommand(simulatorUICommand)
        }

        if let installCommand = launchCommandBuilder.installCommand(
            for: record,
            appURL: appURL,
            skipInstall: skipInstall
        ) {
            let installStatus = try await runCommand(installCommand)
            guard installStatus == 0 else {
                return installStatus
            }
        }

        let command = try launchCommandBuilder.launchCommand(
            for: record,
            appURL: appURL,
            appInfo: appInfo,
            bundleIdentifier: bundleIdentifier,
            environment: environment
        )
        let logCommand = launchCommandBuilder.logStreamCommand(
            for: record,
            appInfo: appInfo,
            categories: logCategories
        )
        let streamsLogs = logCommand != nil || record.kind == .device
        streamStandardError(streamsLogs ? "Streaming app logs. Press Ctrl-C to stop.\n" : "Launching app.\n")
        let launchStatus = try await runCommand(command)
        guard launchStatus == 0 else {
            return launchStatus
        }

        if let logCommand {
            return try await runCommand(logCommand)
        }

        return launchStatus
    }

    /// Resolves either a direct destination argument or a picker choice.
    private func resolveDestination(
        type: DestinationQueryType,
        scope: SelectionScope,
        destination: String?
    ) async throws -> DestinationRecord {
        if let destination {
            return try await destinationResolver.resolve(destination, type: type)
        }

        let record = try await pickerPresenter.present(queryType: type, scope: scope, xcodeContext: nil)
        try await historyStore.record(
            selection: ResolvedSelection(destination: record, scope: scope, selectedAt: now())
        )
        return record
    }

    /// Runs one subprocess with live stdout and stderr streaming.
    private func runCommand(_ command: Command) async throws -> Int32 {
        try await commandRunner.run(
            command,
            standardOutput: streamStandardOutput,
            standardError: streamStandardError
        )
    }

    /// Runs a non-critical subprocess and keeps the main app run flow moving.
    private func runBestEffortCommand(_ command: Command) async {
        do {
            _ = try await commandRunner.run(
                command,
                standardOutput: streamStandardOutput,
                standardError: streamStandardError
            )
        } catch {
            streamStandardError("Could not open Simulator app: \(error.localizedDescription)\n")
        }
    }
}
