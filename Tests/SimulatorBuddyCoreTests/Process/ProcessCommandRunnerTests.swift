import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests for the real Foundation-backed command runner.
struct ProcessCommandRunnerTests {
    /// Verifies streaming runs wait for child termination and capture trailing output.
    @Test
    func runStreaming_waitsForProcessCompletion() async throws {
        let output = OutputRecorder()
        let status = try await ProcessCommandRunner().run(
            Command(executable: "sh", arguments: ["-c", "sleep 0.2; printf done"]),
            standardOutput: { output.write($0) },
            standardError: { _ in }
        )

        #expect(status == 0)
        #expect(output.snapshot().joined() == "done")
    }

    /// Verifies command-specific environment is visible to launched processes.
    @Test
    func run_forwardsEnvironment() async throws {
        let result = try await ProcessCommandRunner().run(Command(
            executable: "sh",
            arguments: ["-c", "printf \"$SIMULATOR_BUDDY_TEST_ENV\""],
            environment: ["SIMULATOR_BUDDY_TEST_ENV": "value"]
        ))

        #expect(result.terminationStatus == 0)
        #expect(result.stdout == "value")
    }
}
