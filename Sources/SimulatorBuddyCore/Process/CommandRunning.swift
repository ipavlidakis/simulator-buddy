import Foundation

/// Runs external commands for destination discovery, builds, and debugger attachment.
public protocol CommandRunning: Sendable {
    /// Runs a command and returns buffered stdout, stderr, and status.
    func run(_ command: Command) async throws -> CommandResult

    /// Runs a command while streaming stdout and stderr chunks as they arrive.
    func run(
        _ command: Command,
        standardOutput: @escaping @Sendable (String) -> Void,
        standardError: @escaping @Sendable (String) -> Void
    ) async throws -> Int32
}
