import Foundation

/// Builds install and launch commands for each supported destination family.
struct AppLaunchCommandBuilder {
    /// Creates wrappers for iPhoneOS apps launched on Mac destinations.
    private let macWrapperBuilder: MacAppBundleWrapperBuilder

    /// Creates an app launch command builder.
    init(macWrapperBuilder: MacAppBundleWrapperBuilder) {
        self.macWrapperBuilder = macWrapperBuilder
    }

    /// Builds the destination-specific install command, when the family has one.
    func installCommand(for record: DestinationRecord, appURL: URL, skipInstall: Bool) -> Command? {
        guard skipInstall == false else {
            return nil
        }

        switch record.kind {
        case .simulator:
            return Command(executable: "xcrun", arguments: ["simctl", "install", record.udid, appURL.path])
        case .device:
            return Command(
                executable: "xcrun",
                arguments: ["devicectl", "device", "install", "app", "--device", record.udid, appURL.path]
            )
        case .macOS:
            return nil
        }
    }

    /// Builds a best-effort command that makes the selected simulator visible.
    func simulatorUICommand(for record: DestinationRecord) -> Command? {
        guard record.kind == .simulator else {
            return nil
        }

        return Command(executable: "open", arguments: [
            "-a",
            "Simulator",
            "--args",
            "-CurrentDeviceUDID",
            record.udid,
        ])
    }

    /// Builds the command that boots and waits for a simulator destination.
    func simulatorBootCommand(for record: DestinationRecord) -> Command? {
        guard record.kind == .simulator else {
            return nil
        }

        return Command(executable: "xcrun", arguments: ["simctl", "bootstatus", record.udid, "-b"])
    }

    /// Builds the destination-specific launch command.
    func launchCommand(
        for record: DestinationRecord,
        appURL: URL,
        appInfo: AppBundleInfo,
        bundleIdentifier: String,
        environment: [EnvironmentVariable]
    ) throws -> Command {
        switch record.kind {
        case .simulator:
            return Command(
                executable: "xcrun",
                arguments: [
                    "simctl",
                    "launch",
                    "--terminate-running-process",
                    record.udid,
                    bundleIdentifier,
                ],
                environment: simulatorEnvironmentDictionary(from: environment)
            )
        case .device:
            return Command(
                executable: "xcrun",
                arguments: [
                    "devicectl",
                    "device",
                    "process",
                    "launch",
                    "--device",
                    record.udid,
                    "--terminate-existing",
                ] + (try deviceEnvironmentArguments(environment)) + [
                    "--console",
                    bundleIdentifier,
                ]
            )
        case .macOS:
            return Command(
                executable: "open",
                arguments: try macLaunchArguments(
                    appURL: appURL,
                    appInfo: appInfo,
                    environment: environment
                )
            )
        }
    }

    /// Builds a unified logging command for destination families that support it.
    func logStreamCommand(
        for record: DestinationRecord,
        appInfo: AppBundleInfo,
        categories: [String]
    ) -> Command? {
        guard let executableName = appInfo.executableName,
              executableName.isEmpty == false else {
            return nil
        }

        let logArguments = [
            "stream",
            "--style",
            "compact",
            "--predicate",
            logPredicate(process: executableName, categories: categories),
        ]

        switch record.kind {
        case .simulator:
            return Command(
                executable: "xcrun",
                arguments: ["simctl", "spawn", record.udid, "log"] + logArguments
            )
        case .device:
            return nil
        case .macOS:
            return Command(executable: "log", arguments: logArguments)
        }
    }

    /// Converts raw environment variables into a process environment dictionary.
    private func environmentDictionary(from environment: [EnvironmentVariable]) -> [String: String] {
        var dictionary: [String: String] = [:]
        for variable in environment {
            dictionary[variable.name] = variable.value
        }
        return dictionary
    }

    /// Converts app environment variables into the form required by `simctl`.
    private func simulatorEnvironmentDictionary(from environment: [EnvironmentVariable]) -> [String: String] {
        var dictionary: [String: String] = [:]
        for variable in environment {
            dictionary["SIMCTL_CHILD_\(variable.name)"] = variable.value
        }
        return dictionary
    }

    /// Converts app environment variables into repeated `open --env` arguments.
    private func openEnvironmentArguments(_ environment: [EnvironmentVariable]) -> [String] {
        environment.flatMap { ["--env", $0.commandLineValue] }
    }

    /// Builds `open` arguments for native Mac and wrapped iPhoneOS apps.
    private func macLaunchArguments(
        appURL: URL,
        appInfo: AppBundleInfo,
        environment: [EnvironmentVariable]
    ) throws -> [String] {
        let launchURL = try macLaunchAppURL(appURL: appURL, appInfo: appInfo)
        let baseArguments = ["-n"] + openEnvironmentArguments(environment)
        return baseArguments + [launchURL.path]
    }

    /// Converts raw environment variables into `devicectl` JSON arguments.
    private func deviceEnvironmentArguments(_ environment: [EnvironmentVariable]) throws -> [String] {
        let dictionary = environmentDictionary(from: environment)
        guard dictionary.isEmpty == false else {
            return []
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(dictionary)
        return ["--environment-variables", String(decoding: data, as: UTF8.self)]
    }

    /// Returns the app URL that macOS can open for the selected bundle kind.
    private func macLaunchAppURL(appURL: URL, appInfo: AppBundleInfo) throws -> URL {
        if needsMacWrapper(appInfo) {
            return try macWrapperBuilder.wrappedAppURL(for: appURL, appInfo: appInfo)
        }
        return appURL
    }

    /// Returns true for iPhoneOS bundles that require macOS wrapper launch.
    private func needsMacWrapper(_ appInfo: AppBundleInfo) -> Bool {
        appInfo.supportedPlatforms.contains("iPhoneOS")
            && appInfo.supportedPlatforms.contains("MacOSX") == false
    }

    /// Builds the unified log predicate used for app-scoped streaming.
    private func logPredicate(process: String, categories: [String]) -> String {
        let processPredicate = "process == \"\(escapedPredicateLiteral(process))\""
        let categoryPredicates = categories
            .filter { $0.isEmpty == false }
            .map { "category == \"\(escapedPredicateLiteral($0))\"" }

        guard categoryPredicates.isEmpty == false else {
            return processPredicate
        }

        if categoryPredicates.count == 1 {
            return "\(processPredicate) AND \(categoryPredicates[0])"
        }

        return "\(processPredicate) AND (\(categoryPredicates.joined(separator: " OR ")))"
    }

    /// Escapes a value for an NSPredicate double-quoted string literal.
    private func escapedPredicateLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
