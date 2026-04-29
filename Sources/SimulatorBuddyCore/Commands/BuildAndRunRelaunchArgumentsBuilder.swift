import Foundation

/// Builds argv for the post-picker direct run process.
struct BuildAndRunRelaunchArgumentsBuilder: Sendable {
    /// Creates a relaunch argument builder.
    init() {}

    /// Recreates the `run` command with an explicit destination.
    func arguments(
        type: DestinationQueryType,
        scope: SelectionScope,
        buildArguments: [String],
        bundleIdentifier: String?,
        skipInstall: Bool,
        environment: [EnvironmentVariable],
        logCategories: [String],
        destination: String
    ) -> [String] {
        var arguments = ["run", "--type", type.rawValue]

        if scope.isExplicit {
            arguments.append(contentsOf: ["--scope", scope.key])
        }

        for variable in environment {
            arguments.append(contentsOf: ["--env", variable.commandLineValue])
        }

        for category in logCategories {
            arguments.append(contentsOf: ["--log-category", category])
        }

        if let bundleIdentifier {
            arguments.append(contentsOf: ["--bundle-id", bundleIdentifier])
        }

        if skipInstall {
            arguments.append("--skip-install")
        }

        arguments.append(contentsOf: ["--destination", destination])
        arguments.append(contentsOf: buildArguments)
        return arguments
    }
}
