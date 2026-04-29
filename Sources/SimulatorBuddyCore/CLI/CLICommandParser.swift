import Foundation

/// Parses simulator-buddy commands and falls back to xcodebuild wrapper arguments.
struct CLICommandParser: Sendable {
    /// Supplies the directory used for implicit selection scopes.
    let currentWorkingDirectory: @Sendable () -> URL

    /// Converts raw command-line arguments into a typed command.
    func parse(arguments: [String]) throws -> ParsedCommand {
        guard let commandName = arguments.first else {
            return .help
        }

        if commandName == "--help" || commandName == "-h" {
            return .help
        }

        if commandName == "xcodebuild" {
            return .xcodebuild(arguments: Array(arguments.dropFirst()))
        }

        let builtinCommands: Set<String> = ["list", "last", "select", "debug", "attach", "run"]
        guard builtinCommands.contains(commandName) else {
            return .xcodebuild(arguments: arguments)
        }

        if arguments.dropFirst().contains(where: { $0 == "--help" || $0 == "-h" }) {
            return .help
        }

        if commandName == "run" {
            return try RunCommandParser(currentWorkingDirectory: currentWorkingDirectory)
                .parse(arguments: arguments)
        }

        let options = try parseOptions(arguments: arguments)
        let resolvedType = options.type ?? .all
        let resolvedScope = options.scope ?? SelectionScope(
            workingDirectory: currentWorkingDirectory()
        )
        let xcodeContext = try makeXcodeContext(
            projectPath: options.xcodeProjectPath,
            workspacePath: options.xcodeWorkspacePath,
            scheme: options.xcodeScheme
        )

        return try makeCommand(
            name: commandName,
            options: options,
            resolvedType: resolvedType,
            resolvedScope: resolvedScope,
            xcodeContext: xcodeContext
        )
    }

    /// Parses option/value pairs shared by the built-in commands.
    private func parseOptions(arguments: [String]) throws -> ParsedOptions {
        var options = ParsedOptions()
        var index = 1

        while index < arguments.count {
            switch arguments[index] {
            case "--type":
                index += 1
                options.type = try parseType(arguments, index: index)
            case "--format":
                index += 1
                options.format = try parseFormat(arguments, index: index)
            case "--scope":
                index += 1
                options.scope = SelectionScope(
                    explicit:
                    try parseValue(arguments, index: index, option: "--scope")
                )
            case "--process-name":
                index += 1
                options.processName = try parseValue(arguments, index: index, option: "--process-name")
            case "--lldb-command-file":
                index += 1
                options.lldbCommandFile = try parseValue(
                    arguments,
                    index: index,
                    option: "--lldb-command-file"
                )
            case "--destination":
                index += 1
                options.destination = try parseValue(arguments, index: index, option: "--destination")
            case "--app":
                index += 1
                options.appPath = try parseValue(arguments, index: index, option: "--app")
            case "--bundle-id":
                index += 1
                options.bundleIdentifier = try parseValue(arguments, index: index, option: "--bundle-id")
            case "--skip-install":
                options.skipInstall = true
            case "--xcode-project":
                index += 1
                options.xcodeProjectPath = try parseValue(
                    arguments,
                    index: index,
                    option: "--xcode-project"
                )
            case "--xcode-workspace":
                index += 1
                options.xcodeWorkspacePath = try parseValue(
                    arguments,
                    index: index,
                    option: "--xcode-workspace"
                )
            case "--xcode-scheme":
                index += 1
                options.xcodeScheme = try parseValue(arguments, index: index, option: "--xcode-scheme")
            default:
                throw SimulatorBuddyError.usage("Unknown argument: \(arguments[index])")
            }

            index += 1
        }

        return options
    }

    /// Builds the command enum after shared options have been normalized.
    private func makeCommand(
        name: String,
        options: ParsedOptions,
        resolvedType: DestinationQueryType,
        resolvedScope: SelectionScope,
        xcodeContext: XcodeSchemeContext?
    ) throws -> ParsedCommand {
        switch name {
        case "list":
            return .list(type: resolvedType, format: options.format ?? .table, xcodeContext: xcodeContext)
        case "last":
            return .last(
                type: resolvedType,
                scope: resolvedScope,
                format: options.format ?? .udid,
                xcodeContext: xcodeContext
            )
        case "select":
            return .select(
                type: resolvedType,
                scope: resolvedScope,
                format: options.format ?? .udid,
                xcodeContext: xcodeContext
            )
        case "debug":
            guard let processName = options.processName, processName.isEmpty == false else {
                throw SimulatorBuddyError.usage("Missing value for --process-name")
            }
            guard let lldbCommandFile = options.lldbCommandFile,
                  lldbCommandFile.isEmpty == false else {
                throw SimulatorBuddyError.usage("Missing value for --lldb-command-file")
            }
            return .debug(
                type: resolvedType,
                scope: resolvedScope,
                processName: processName,
                lldbCommandFile: lldbCommandFile,
                xcodeContext: xcodeContext
            )
        case "attach":
            guard let processName = options.processName, processName.isEmpty == false else {
                throw SimulatorBuddyError.usage("Missing value for --process-name")
            }
            return .attach(
                type: resolvedType,
                scope: resolvedScope,
                processName: processName,
                destination: options.destination
            )
        case "run":
            guard let appPath = options.appPath, appPath.isEmpty == false else {
                throw SimulatorBuddyError.usage("Missing value for --app")
            }
            return .run(
                type: resolvedType,
                scope: resolvedScope,
                appPath: appPath,
                bundleIdentifier: options.bundleIdentifier,
                skipInstall: options.skipInstall,
                environment: options.environment,
                logCategories: options.logCategories,
                destination: options.destination
            )
        default:
            throw SimulatorBuddyError.usage("Unknown command: \(name)")
        }
    }

    /// Creates Xcode scheme context from project/workspace flags when supplied.
    private func makeXcodeContext(
        projectPath: String?,
        workspacePath: String?,
        scheme: String?
    ) throws -> XcodeSchemeContext? {
        if projectPath != nil, workspacePath != nil {
            throw SimulatorBuddyError.usage("Pass only one of --xcode-project or --xcode-workspace.")
        }

        if projectPath != nil || workspacePath != nil {
            guard let scheme, scheme.isEmpty == false else {
                throw SimulatorBuddyError.usage("--xcode-scheme is required with --xcode-project or --xcode-workspace.")
            }

            if let projectPath {
                return XcodeSchemeContext(root: .project(URL(fileURLWithPath: projectPath)), scheme: scheme)
            }

            if let workspacePath {
                return XcodeSchemeContext(root: .workspace(URL(fileURLWithPath: workspacePath)), scheme: scheme)
            }
        }

        if scheme != nil {
            throw SimulatorBuddyError.usage("--xcode-scheme requires --xcode-project or --xcode-workspace.")
        }

        return nil
    }

    /// Parses a destination query type option.
    private func parseType(_ arguments: [String], index: Int) throws -> DestinationQueryType {
        let value = try parseValue(arguments, index: index, option: "--type")
        guard let type = DestinationQueryType(rawValue: value) else {
            throw SimulatorBuddyError.usage("Unsupported type: \(value)")
        }
        return type
    }

    /// Parses an output format option.
    private func parseFormat(_ arguments: [String], index: Int) throws -> SelectOutputFormat {
        let value = try parseValue(arguments, index: index, option: "--format")
        guard let format = SelectOutputFormat(rawValue: value) else {
            throw SimulatorBuddyError.usage("Unsupported format: \(value)")
        }
        return format
    }

    /// Reads the required value following an option flag.
    private func parseValue(_ arguments: [String], index: Int, option: String) throws -> String {
        guard arguments.indices.contains(index) else {
            throw SimulatorBuddyError.usage("Missing value for \(option)")
        }
        return arguments[index]
    }
}
