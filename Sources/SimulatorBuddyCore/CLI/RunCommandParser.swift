import Foundation

/// Parses the built-in `run` command and its xcodebuild-style arguments.
struct RunCommandParser: Sendable {
    /// Supplies the directory used for implicit selection scopes.
    let currentWorkingDirectory: @Sendable () -> URL

    /// Converts `run` arguments into either app-run or build-and-run command form.
    func parse(arguments: [String]) throws -> ParsedCommand {
        var options = ParsedOptions()
        var buildArguments: [String] = []
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--type":
                index += 1
                options.type = try parseType(arguments, index: index)
            case "--scope":
                index += 1
                options.scope = SelectionScope(explicit: try parseValue(arguments, index: index, option: "--scope"))
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
            case "--env":
                index += 1
                let value = try parseValue(arguments, index: index, option: "--env")
                options.environment.append(try EnvironmentVariable(argument: value))
            case "--xcode-project":
                index += 1
                buildArguments.append(contentsOf: [
                    "-project",
                    try parseValue(arguments, index: index, option: "--xcode-project"),
                ])
            case "--xcode-workspace":
                index += 1
                buildArguments.append(contentsOf: [
                    "-workspace",
                    try parseValue(arguments, index: index, option: "--xcode-workspace"),
                ])
            case "--xcode-scheme":
                index += 1
                buildArguments.append(contentsOf: [
                    "-scheme",
                    try parseValue(arguments, index: index, option: "--xcode-scheme"),
                ])
            default:
                buildArguments.append(argument)
            }

            index += 1
        }

        return try command(options: options, buildArguments: buildArguments)
    }

    /// Builds the parsed command after run options are collected.
    private func command(options: ParsedOptions, buildArguments: [String]) throws -> ParsedCommand {
        let resolvedType = options.type ?? .all
        let resolvedScope = options.scope ?? SelectionScope(workingDirectory: currentWorkingDirectory())

        if let appPath = options.appPath {
            guard buildArguments.isEmpty else {
                throw SimulatorBuddyError.usage("Pass either --app or xcodebuild project/workspace flags.")
            }

            return .run(
                type: resolvedType,
                scope: resolvedScope,
                appPath: appPath,
                bundleIdentifier: options.bundleIdentifier,
                skipInstall: options.skipInstall,
                environment: options.environment,
                destination: options.destination
            )
        }

        guard buildArguments.isEmpty == false else {
            throw SimulatorBuddyError.usage("run requires --app or xcodebuild project/workspace flags.")
        }

        return .buildAndRun(
            type: resolvedType,
            scope: resolvedScope,
            buildArguments: buildArguments,
            bundleIdentifier: options.bundleIdentifier,
            skipInstall: options.skipInstall,
            environment: options.environment,
            destination: options.destination
        )
    }

    /// Parses a destination query type option.
    private func parseType(_ arguments: [String], index: Int) throws -> DestinationQueryType {
        let value = try parseValue(arguments, index: index, option: "--type")
        guard let type = DestinationQueryType(rawValue: value) else {
            throw SimulatorBuddyError.usage("Unsupported type: \(value)")
        }
        return type
    }

    /// Reads the required value following an option flag.
    private func parseValue(_ arguments: [String], index: Int, option: String) throws -> String {
        guard arguments.indices.contains(index) else {
            throw SimulatorBuddyError.usage("Missing value for \(option)")
        }
        return arguments[index]
    }
}
