import Foundation

/// Destination fetcher that shells out to Apple developer tools.
public final class SystemDestinationFetcher: DestinationFetching, @unchecked Sendable {
    /// Command runner used for xcrun invocations.
    private let runner: any CommandRunning

    /// File manager used for temporary JSON files.
    private let fileManager: FileManager

    /// Directory used for temporary command output files.
    private let temporaryDirectory: URL

    /// Parser for simctl, devicectl, and xctrace output.
    private let deviceParser: SimulatorDeviceJSONParser

    /// Parser for xcodebuild `-showdestinations` output.
    private let xcodeDestinationParser: XcodeShowDestinationsParser

    /// Provider for the current macOS version label.
    private let osVersionProvider: OperatingSystemVersionProvider

    /// Creates a system fetcher with injectable process, parser, and filesystem dependencies.
    public init(
        runner: any CommandRunning,
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        deviceParser: SimulatorDeviceJSONParser = SimulatorDeviceJSONParser(),
        xcodeDestinationParser: XcodeShowDestinationsParser = XcodeShowDestinationsParser(),
        osVersionProvider: OperatingSystemVersionProvider = OperatingSystemVersionProvider()
    ) {
        self.runner = runner
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
        self.deviceParser = deviceParser
        self.xcodeDestinationParser = xcodeDestinationParser
        self.osVersionProvider = osVersionProvider
    }

    /// Fetches available iPhone and iPad simulators through `simctl`.
    public func fetchSimulators() async throws -> [DestinationRecord] {
        let outputURL = temporaryJSONURL()
        defer {
            try? fileManager.removeItem(at: outputURL)
        }

        let result = try await runner.run(
            Command(
                executable: "xcrun",
                arguments: [
                    "simctl",
                    "list",
                    "devices",
                    "available",
                    "-j",
                    "--json-output",
                    outputURL.path,
                ]
            )
        )

        guard result.terminationStatus == 0 else {
            throw SimulatorBuddyError.commandFailed(
                result.stderr.isEmpty ? "simctl list failed." : result.stderr
            )
        }

        return try deviceParser.parseSimulators(from: Data(contentsOf: outputURL))
    }

    /// Fetches physical iPhone and iPad devices through `devicectl`.
    public func fetchDevices() async throws -> [DestinationRecord] {
        let outputURL = temporaryJSONURL()
        defer {
            try? fileManager.removeItem(at: outputURL)
        }

        let result = try await runner.run(
            Command(
                executable: "xcrun",
                arguments: [
                    "devicectl",
                    "list",
                    "devices",
                    "--json-output",
                    outputURL.path,
                ]
            )
        )

        guard result.terminationStatus == 0 else {
            throw SimulatorBuddyError.commandFailed(
                result.stderr.isEmpty ? "devicectl list devices failed." : result.stderr
            )
        }

        return try deviceParser.parseDevices(from: Data(contentsOf: outputURL))
    }

    /// Fetches local Mac devices through `xctrace list devices`.
    public func fetchMacs() async throws -> [DestinationRecord] {
        let result = try await runner.run(
            Command(executable: "xcrun", arguments: ["xctrace", "list", "devices"])
        )

        guard result.terminationStatus == 0 else {
            throw SimulatorBuddyError.commandFailed(
                result.stderr.isEmpty ? "xctrace list devices failed." : result.stderr
            )
        }

        return deviceParser.parseMacs(
            from: result.stdout,
            osVersion: osVersionProvider.currentVersion()
        )
    }

    /// Fetches Mac run destinations for an Xcode scheme through `xcodebuild -showdestinations`.
    public func fetchMacRunDestinationsFromXcode(context: XcodeSchemeContext) async throws
        -> [DestinationRecord]
    {
        let result = try await runner.run(
            Command(executable: "xcrun", arguments: xcodeShowDestinationArguments(context: context))
        )

        guard result.terminationStatus == 0 else {
            throw SimulatorBuddyError.commandFailed(
                result.stderr.isEmpty ? "xcodebuild -showdestinations failed." : result.stderr
            )
        }

        return xcodeDestinationParser.parseMacOSRunDestinations(from: result.stdout)
    }

    /// Creates a unique temporary JSON output URL.
    private func temporaryJSONURL() -> URL {
        temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    /// Builds the `xcrun xcodebuild -showdestinations` argument list.
    private func xcodeShowDestinationArguments(context: XcodeSchemeContext) -> [String] {
        var arguments = ["xcodebuild"]
        switch context.root {
        case let .project(url):
            arguments.append(contentsOf: ["-project", url.path])
        case let .workspace(url):
            arguments.append(contentsOf: ["-workspace", url.path])
        }
        arguments.append(contentsOf: ["-scheme", context.scheme, "-showdestinations"])
        return arguments
    }
}
