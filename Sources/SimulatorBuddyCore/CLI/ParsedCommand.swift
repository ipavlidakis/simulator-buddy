import Foundation

/// Typed command selected from raw CLI arguments.
enum ParsedCommand {
    /// Print usage text.
    case help

    /// Print available destinations.
    case list(type: DestinationQueryType, format: SelectOutputFormat, xcodeContext: XcodeSchemeContext?)

    /// Print the last destination selected in history.
    case last(
        type: DestinationQueryType,
        scope: SelectionScope,
        format: SelectOutputFormat,
        xcodeContext: XcodeSchemeContext?
    )

    /// Present the picker and print the selected destination.
    case select(
        type: DestinationQueryType,
        scope: SelectionScope,
        format: SelectOutputFormat,
        xcodeContext: XcodeSchemeContext?
    )

    /// Write LLDB commands without launching LLDB.
    case debug(
        type: DestinationQueryType,
        scope: SelectionScope,
        processName: String,
        lldbCommandFile: String,
        xcodeContext: XcodeSchemeContext?
    )

    /// Launch LLDB and attach to the named process.
    case attach(
        type: DestinationQueryType,
        scope: SelectionScope,
        processName: String,
        destination: String?
    )

    /// Install and launch an existing app bundle.
    case run(
        type: DestinationQueryType,
        scope: SelectionScope,
        appPath: String,
        bundleIdentifier: String?,
        skipInstall: Bool,
        environment: [EnvironmentVariable],
        destination: String?
    )

    /// Build an Xcode scheme, install its app if required, and launch it.
    case buildAndRun(
        type: DestinationQueryType,
        scope: SelectionScope,
        buildArguments: [String],
        bundleIdentifier: String?,
        skipInstall: Bool,
        environment: [EnvironmentVariable],
        destination: String?
    )

    /// Forward raw arguments to xcodebuild, optionally injecting a destination.
    case xcodebuild(arguments: [String])
}
