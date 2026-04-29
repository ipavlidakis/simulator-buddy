import Foundation

/// Mutable accumulator used while parsing built-in command options.
struct ParsedOptions {
    /// Optional destination family filter.
    var type: DestinationQueryType?

    /// Optional output format requested by list/select/last.
    var format: SelectOutputFormat?

    /// Optional caller-supplied history scope.
    var scope: SelectionScope?

    /// Process name used by debug and attach commands.
    var processName: String?

    /// Output file used by the compatibility debug command.
    var lldbCommandFile: String?

    /// Destination UDID or xcodebuild specifier used by attach and run.
    var destination: String?

    /// App bundle path used by the run command.
    var appPath: String?

    /// Bundle identifier override used by the run command.
    var bundleIdentifier: String?

    /// Whether the run command should launch without reinstalling the app bundle.
    var skipInstall = false

    /// Raw environment variables forwarded to the launch command.
    var environment: [EnvironmentVariable] = []

    /// Optional `.xcodeproj` path used for destination filtering.
    var xcodeProjectPath: String?

    /// Optional `.xcworkspace` path used for destination filtering.
    var xcodeWorkspacePath: String?

    /// Optional scheme name used with project/workspace flags.
    var xcodeScheme: String?
}
