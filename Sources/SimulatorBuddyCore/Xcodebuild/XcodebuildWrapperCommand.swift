import Foundation

/// Implements raw xcodebuild replacement mode with optional destination injection.
final class XcodebuildWrapperCommand: @unchecked Sendable {
    /// Store updated with picker selections.
    private let historyStore: HistoryStore

    /// Picker used to choose among scheme-valid destinations.
    private let pickerPresenter: any PickerPresenting

    /// Runner used for discovery and final xcodebuild invocation.
    private let commandRunner: any CommandRunning

    /// Working directory used for implicit history scope.
    private let currentWorkingDirectory: @Sendable () -> URL

    /// Clock used for history timestamps.
    private let now: @Sendable () -> Date

    /// Live stdout sink for xcodebuild.
    private let streamStandardOutput: @Sendable (String) -> Void

    /// Live stderr sink for xcodebuild.
    private let streamStandardError: @Sendable (String) -> Void

    /// Resolver for prompt eligibility and Xcode context.
    private let invocationResolver: XcodebuildInvocationResolver

    /// Parser for show-destinations output.
    private let destinationParser: XcodeShowDestinationsParser

    /// Creates the wrapper command with injectable process, picker, and parser dependencies.
    init(
        historyStore: HistoryStore,
        pickerPresenter: any PickerPresenting,
        commandRunner: any CommandRunning,
        currentWorkingDirectory: @escaping @Sendable () -> URL,
        now: @escaping @Sendable () -> Date,
        streamStandardOutput: @escaping @Sendable (String) -> Void,
        streamStandardError: @escaping @Sendable (String) -> Void,
        invocationResolver: XcodebuildInvocationResolver = XcodebuildInvocationResolver(),
        destinationParser: XcodeShowDestinationsParser = XcodeShowDestinationsParser()
    ) {
        self.historyStore = historyStore
        self.pickerPresenter = pickerPresenter
        self.commandRunner = commandRunner
        self.currentWorkingDirectory = currentWorkingDirectory
        self.now = now
        self.streamStandardOutput = streamStandardOutput
        self.streamStandardError = streamStandardError
        self.invocationResolver = invocationResolver
        self.destinationParser = destinationParser
    }

    /// Runs raw xcodebuild, injecting a picker-selected destination when safe.
    func run(arguments: [String]) async throws -> Int32 {
        guard invocationResolver.shouldPromptForDestination(arguments: arguments),
              let xcodeContext = invocationResolver.context(from: arguments)
        else {
            return try await runXcodebuild(arguments: arguments)
        }

        let showDestinations = try await commandRunner.run(
            Command(
                executable: "xcodebuild",
                arguments: invocationResolver.showDestinationsArguments(for: xcodeContext)
            )
        )

        guard showDestinations.terminationStatus == 0 else {
            return try await runXcodebuild(arguments: arguments)
        }

        let records = destinationParser.parseRunDestinations(from: showDestinations.stdout)
        guard records.isEmpty == false else {
            return try await runXcodebuild(arguments: arguments)
        }

        let scope = SelectionScope(workingDirectory: currentWorkingDirectory())
        let record = try await pickerPresenter.present(records: records, queryType: .all, scope: scope)
        let selection = ResolvedSelection(destination: record, scope: scope, selectedAt: now())
        try await historyStore.record(selection: selection)

        let destination = record.xcodeDestinationSpecifier ?? "id=\(record.udid)"
        let injectedArguments = invocationResolver.argumentsByInjectingDestination(destination, into: arguments)
        return try await runXcodebuild(arguments: injectedArguments)
    }

    /// Runs the real xcodebuild with live output streaming.
    private func runXcodebuild(arguments: [String]) async throws -> Int32 {
        try await commandRunner.run(
            Command(executable: "xcodebuild", arguments: arguments),
            standardOutput: streamStandardOutput,
            standardError: streamStandardError
        )
    }
}
