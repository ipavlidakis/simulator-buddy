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

    /// Verifies cancellation terminates a live child process.
    @Test
    func runStreaming_cancellationTerminatesChildProcess() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let startedURL = directory.appendingPathComponent("started")
        let terminatedURL = directory.appendingPathComponent("terminated")
        let output = OutputRecorder()

        let task = Task {
            try await ProcessCommandRunner().run(
                Command(
                    executable: "perl",
                    arguments: [
                        "-e",
                        """
                        $SIG{TERM} = sub { open(my $f, '>', $ENV{TERMINATED}); close($f); exit 0; };
                        $SIG{INT} = $SIG{TERM};
                        open(my $f, '>', $ENV{STARTED}); close($f);
                        sleep 5;
                        """,
                    ],
                    environment: [
                        "STARTED": startedURL.path,
                        "TERMINATED": terminatedURL.path,
                    ]
                ),
                standardOutput: { output.write($0) },
                standardError: { _ in }
            )
        }

        #expect(await eventually {
            FileManager.default.fileExists(atPath: startedURL.path)
        })

        task.cancel()

        _ = try await task.value
        #expect(await eventually {
            FileManager.default.fileExists(atPath: terminatedURL.path)
        })
    }
}
