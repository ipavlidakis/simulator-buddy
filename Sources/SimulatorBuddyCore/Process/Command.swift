import Foundation

/// Describes an executable and arguments to launch through the command runner.
public struct Command: Equatable, Sendable {
    /// Executable name or path resolved through `/usr/bin/env`.
    public let executable: String

    /// Arguments passed verbatim to the executable.
    public let arguments: [String]

    /// Extra environment variables supplied to the launched process.
    public let environment: [String: String]

    /// Creates a command from its executable, ordered arguments, and environment additions.
    public init(executable: String, arguments: [String], environment: [String: String] = [:]) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
    }
}
