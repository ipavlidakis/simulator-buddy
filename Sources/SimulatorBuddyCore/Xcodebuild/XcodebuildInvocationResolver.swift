import Foundation

/// Decides whether raw xcodebuild arguments should trigger destination selection.
struct XcodebuildInvocationResolver {
    /// Scanner for raw xcodebuild argument structure.
    private let argumentScanner: XcodebuildArgumentScanner

    /// Creates an invocation resolver.
    init(argumentScanner: XcodebuildArgumentScanner = XcodebuildArgumentScanner()) {
        self.argumentScanner = argumentScanner
    }

    /// Returns true when wrapper mode should inspect destinations and prompt.
    func shouldPromptForDestination(arguments: [String]) -> Bool {
        guard arguments.isEmpty == false else {
            return false
        }

        if destinationArgument(in: arguments) != nil {
            return false
        }

        if isInfoCommand(arguments: arguments) {
            return false
        }

        if isCleanOnly(arguments: arguments) {
            return false
        }

        return true
    }

    /// Extracts project/workspace and scheme from raw xcodebuild arguments.
    func context(from arguments: [String]) -> XcodeSchemeContext? {
        var projectPath: String?
        var workspacePath: String?
        var scheme: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-project":
                index += 1
                if arguments.indices.contains(index) {
                    projectPath = arguments[index]
                }
            case "-workspace":
                index += 1
                if arguments.indices.contains(index) {
                    workspacePath = arguments[index]
                }
            case "-scheme":
                index += 1
                if arguments.indices.contains(index) {
                    scheme = arguments[index]
                }
            default:
                if argument.hasPrefix("-project=") {
                    projectPath = String(argument.dropFirst("-project=".count))
                } else if argument.hasPrefix("-workspace=") {
                    workspacePath = String(argument.dropFirst("-workspace=".count))
                } else if argument.hasPrefix("-scheme=") {
                    scheme = String(argument.dropFirst("-scheme=".count))
                }
            }

            index += 1
        }

        guard let scheme, scheme.isEmpty == false else {
            return nil
        }

        if let projectPath, workspacePath == nil {
            return XcodeSchemeContext(root: .project(URL(fileURLWithPath: projectPath)), scheme: scheme)
        }

        if let workspacePath, projectPath == nil {
            return XcodeSchemeContext(root: .workspace(URL(fileURLWithPath: workspacePath)), scheme: scheme)
        }

        return nil
    }

    /// Builds arguments for the discovery `xcodebuild -showdestinations` call.
    func showDestinationsArguments(for context: XcodeSchemeContext) -> [String] {
        var arguments: [String] = []
        switch context.root {
        case let .project(url):
            arguments.append(contentsOf: ["-project", url.path])
        case let .workspace(url):
            arguments.append(contentsOf: ["-workspace", url.path])
        }
        arguments.append(contentsOf: ["-scheme", context.scheme, "-showdestinations"])
        return arguments
    }

    /// Inserts a selected destination before the first build action.
    func argumentsByInjectingDestination(_ destination: String, into arguments: [String]) -> [String] {
        argumentScanner.insertingDestination(destination, into: arguments)
    }

    /// Returns a caller-supplied destination specifier, if present.
    func destinationArgument(in arguments: [String]) -> String? {
        argumentScanner.destinationArgument(in: arguments)
    }

    /// Returns true when actions are compatible with build-and-run.
    func supportsBuildAndRunActions(arguments: [String]) -> Bool {
        argumentScanner.supportsBuildAndRunActions(in: arguments)
    }

    /// Returns true when arguments request xcodebuild metadata only.
    func isInfoOnlyCommand(arguments: [String]) -> Bool {
        isInfoCommand(arguments: arguments)
    }

    /// Ensures a build action exists in the argument list.
    func argumentsByEnsuringBuildAction(arguments: [String]) -> [String] {
        argumentScanner.ensuringBuildAction(in: arguments)
    }

    /// Removes build actions to create metadata-only xcodebuild arguments.
    func argumentsByRemovingActions(arguments: [String]) -> [String] {
        argumentScanner.removingActions(from: arguments)
    }

    /// Returns true for commands whose purpose is metadata, not building.
    private func isInfoCommand(arguments: [String]) -> Bool {
        let infoOptions: Set<String> = [
            "-help",
            "-usage",
            "-version",
            "-list",
            "-showBuildSettings",
            "-showdestinations",
            "-showsdks",
        ]
        return arguments.contains { infoOptions.contains($0) }
    }

    /// Returns true when `clean` is the only action.
    private func isCleanOnly(arguments: [String]) -> Bool {
        argumentScanner.actions(in: arguments) == ["clean"]
    }
}
