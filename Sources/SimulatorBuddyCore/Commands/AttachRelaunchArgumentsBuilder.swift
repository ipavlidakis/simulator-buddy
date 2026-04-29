/// Builds argv for the post-picker direct attach process.
struct AttachRelaunchArgumentsBuilder: Sendable {
    /// Creates an attach relaunch argument builder.
    init() {}

    /// Recreates the `attach` command with an explicit destination.
    func arguments(
        type: DestinationQueryType,
        scope: SelectionScope,
        processName: String,
        destination: String
    ) -> [String] {
        var arguments = [
            "attach",
            "--type", type.rawValue,
        ]

        if scope.isExplicit {
            arguments.append(contentsOf: ["--scope", scope.key])
        }

        arguments.append(contentsOf: [
            "--process-name", processName,
            "--destination", destination,
        ])
        return arguments
    }
}
