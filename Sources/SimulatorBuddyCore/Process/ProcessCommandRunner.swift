import Foundation

/// Foundation `Process` implementation of `CommandRunning`.
public final class ProcessCommandRunner: CommandRunning, @unchecked Sendable {
    /// Creates a command runner that resolves executables through `/usr/bin/env`.
    public init() {}

    /// Runs a command and buffers both output streams until termination.
    public func run(_ command: Command) async throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        let stdoutBuffer = ProcessOutputBuffer()
        let stderrBuffer = ProcessOutputBuffer()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command.executable] + command.arguments
        process.environment = processEnvironment(for: command)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutHandle.readabilityHandler = { handle in
            stdoutBuffer.append(handle.availableData)
        }
        stderrHandle.readabilityHandler = { handle in
            stderrBuffer.append(handle.availableData)
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            throw error
        }

        stdoutHandle.readabilityHandler = nil
        stderrHandle.readabilityHandler = nil
        stdoutBuffer.append(stdoutHandle.readDataToEndOfFile())
        stderrBuffer.append(stderrHandle.readDataToEndOfFile())

        return CommandResult(
            terminationStatus: process.terminationStatus,
            stdout: stdoutBuffer.string(),
            stderr: stderrBuffer.string()
        )
    }

    /// Runs a command with live stdout/stderr streaming and returns its exit status.
    public func run(
        _ command: Command,
        standardOutput: @escaping @Sendable (String) -> Void,
        standardError: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command.executable] + command.arguments
        process.environment = processEnvironment(for: command)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty == false {
                standardOutput(String(decoding: data, as: UTF8.self))
            }
        }

        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty == false {
                standardError(String(decoding: data, as: UTF8.self))
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            throw error
        }

        stdoutHandle.readabilityHandler = nil
        stderrHandle.readabilityHandler = nil
        let remainingStdout = stdoutHandle.readDataToEndOfFile()
        if remainingStdout.isEmpty == false {
            standardOutput(String(decoding: remainingStdout, as: UTF8.self))
        }
        let remainingStderr = stderrHandle.readDataToEndOfFile()
        if remainingStderr.isEmpty == false {
            standardError(String(decoding: remainingStderr, as: UTF8.self))
        }
        return process.terminationStatus
    }

    /// Builds process environment by overlaying command variables onto inherited values.
    private func processEnvironment(for command: Command) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        for variable in command.environment {
            environment[variable.key] = variable.value
        }
        return environment
    }
}
