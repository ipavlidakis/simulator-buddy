import Foundation

/// Captured result for a subprocess whose output was buffered.
public struct CommandResult: Equatable, Sendable {
    /// Process termination status returned by Foundation `Process`.
    public let terminationStatus: Int32

    /// Complete UTF-8 decoded standard output.
    public let stdout: String

    /// Complete UTF-8 decoded standard error.
    public let stderr: String

    /// Creates a buffered subprocess result.
    public init(terminationStatus: Int32, stdout: String, stderr: String) {
        self.terminationStatus = terminationStatus
        self.stdout = stdout
        self.stderr = stderr
    }
}
