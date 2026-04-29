import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests covering direct LLDB attach command behavior.
struct AttachCommandHandlerTests {
    /// Verifies provided destination skips picker, writes LLDB commands, and forwards status.
    @Test
    func providedDestination_runsLLDBAndReturnsStatus() async throws {
        let rootDirectory = temporaryDirectory()
        let runner = RecordingCommandRunner(
            results: [CommandResult(terminationStatus: 7, stdout: "lldb out", stderr: "lldb err")]
        )
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let picker = StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: picker,
            commandRunner: runner,
            temporaryDirectory: { rootDirectory },
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { stdout.write($0) },
            standardError: { stderr.write($0) },
            streamStandardOutput: { stdout.write($0) },
            streamStandardError: { stderr.write($0) }
        )

        let exitCode = await app.run(
            arguments: [
                "attach",
                "--destination", "platform=iOS Simulator,id=SIM-1",
                "--process-name", "My \"App\"",
            ]
        )

        let commands = await runner.snapshot()
        #expect(exitCode == 7)
        #expect(commands.count == 1)
        #expect(commands[0].executable == "lldb")
        #expect(commands[0].arguments.first == "-s")
        #expect(await picker.presentCallCount == 0)
        #expect(stdout.snapshot().contains("lldb out"))
        #expect(stderr.snapshot().contains("lldb err"))

        let commandFile = try #require(commands[0].arguments.dropFirst().first)
        let commandsText = try String(contentsOfFile: commandFile, encoding: .utf8)
        #expect(
            commandsText == """
            platform select ios-simulator
            process attach --name "My \\"App\\"" --waitfor --include-existing

            """
        )
    }

    /// Verifies picker-based attach records history and writes device attach commands.
    @Test
    func pickedDestination_recordsSelectionAndRunsLLDB() async throws {
        let rootDirectory = temporaryDirectory()
        let record = DestinationRecord(
            kind: .device,
            udid: "DEVICE-1",
            name: "iPhone Blue",
            runtime: "iOS 26.4",
            state: .connected,
            stateDescription: "Connected"
        )
        let runner = RecordingCommandRunner(
            results: [CommandResult(terminationStatus: 0, stdout: "", stderr: "")]
        )
        let historyStore = HistoryStore(paths: AppPaths(rootDirectory: rootDirectory))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: [record]),
            historyStore: historyStore,
            pickerPresenter: StubPickerPresenter(result: .success(record)),
            commandRunner: runner,
            now: { Date(timeIntervalSince1970: 200) },
            temporaryDirectory: { rootDirectory },
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(
            arguments: ["attach", "--process-name", "Vesputio", "--type", "device"]
        )

        let history = try await historyStore.resolveLast(
            type: .device,
            scope: SelectionScope(workingDirectory: URL(fileURLWithPath: "/tmp", isDirectory: true))
        )
        #expect(exitCode == 0)
        #expect(history?.udid == "DEVICE-1")
        let lldbCommands = await runner.snapshot()
        let commandFile = try #require(lldbCommands.first?.arguments.dropFirst().first)
        let commandsText = try String(contentsOfFile: commandFile, encoding: .utf8)
        #expect(
            commandsText == """
            device select DEVICE-1
            device process attach --name "Vesputio" --waitfor --include-existing

            """
        )
    }
}
