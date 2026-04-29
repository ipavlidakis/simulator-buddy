import Synchronization
@testable import SimulatorBuddyCore

/// Test double that records process replacement requests.
final class RecordingProcessReplacer: ProcessReplacing, @unchecked Sendable {
    /// Exit code returned instead of replacing the process.
    private let exitCode: Int32

    /// Recorded executable path and argv.
    private let recordedRequest = Mutex<(String, [String])?>(nil)

    /// Creates a recording process replacer.
    init(exitCode: Int32) {
        self.exitCode = exitCode
    }

    /// Records replacement inputs and returns the configured exit code.
    func replaceCurrentProcess(executablePath: String, arguments: [String]) throws -> Int32 {
        recordedRequest.withLock { request in
            request = (executablePath, arguments)
        }
        return exitCode
    }

    /// Returns the last replacement request.
    func snapshot() -> (String, [String])? {
        recordedRequest.withLock { request in
            request
        }
    }
}
