import Foundation
@testable import SimulatorBuddyCore

/// Command runner test double that records commands and returns queued results.
actor RecordingCommandRunner: CommandRunning {
    /// Results returned by successive command runs.
    private var results: [CommandResult]

    /// Commands observed by the runner.
    private var commands: [Command] = []

    /// Creates a runner with queued results.
    init(results: [CommandResult]) {
        self.results = results
    }

    /// Records a command and returns the next queued buffered result.
    func run(_ command: Command) async throws -> CommandResult {
        commands.append(command)
        if results.isEmpty {
            return CommandResult(terminationStatus: 0, stdout: "", stderr: "")
        }

        return results.removeFirst()
    }

    /// Returns all recorded commands.
    func snapshot() -> [Command] {
        commands
    }

    /// Records a command, streams queued output, and returns queued status.
    func run(
        _ command: Command,
        standardOutput: @escaping @Sendable (String) -> Void,
        standardError: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        let result = try await run(command)
        if result.stdout.isEmpty == false {
            standardOutput(result.stdout)
        }
        if result.stderr.isEmpty == false {
            standardError(result.stderr)
        }
        return result.terminationStatus
    }
}
