import Foundation

/// Raw environment variable requested by a run command.
struct EnvironmentVariable: Equatable, Sendable {
    /// Variable name exactly as provided before the first `=` character.
    let name: String

    /// Variable value exactly as provided after the first `=` character.
    let value: String

    /// Recreates the `KEY=VALUE` form expected by launch tools.
    var commandLineValue: String {
        "\(name)=\(value)"
    }

    /// Creates a raw environment variable after validating that the name is usable.
    init(name: String, value: String) throws {
        guard name.isEmpty == false else {
            throw SimulatorBuddyError.usage("--env requires a non-empty variable name.")
        }

        self.name = name
        self.value = value
    }

    /// Parses `KEY=VALUE` text supplied after `--env`.
    init(argument: String) throws {
        guard let separator = argument.firstIndex(of: "=") else {
            throw SimulatorBuddyError.usage("--env requires KEY=VALUE.")
        }

        let name = String(argument[..<separator])
        let value = String(argument[argument.index(after: separator)...])
        try self.init(name: name, value: value)
    }
}
