import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests covering compatibility debugger command file generation.
struct DebugCommandHandlerTests {
    /// Verifies simulator debug writes LLDB simulator attach commands and JSON output.
    @Test
    func simulator_writesLLDBAttachCommands() async throws {
        let rootDirectory = temporaryDirectory()
        let commandFile = rootDirectory.appendingPathComponent("attach.lldb")
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let record = DestinationRecord(
            kind: .simulator,
            udid: "SIM-1",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .booted,
            stateDescription: "Booted"
        )

        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [record], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .success(record)),
            now: { Date(timeIntervalSince1970: 100) },
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { stdout.write($0) },
            standardError: { stderr.write($0) }
        )

        let exitCode = await app.run(
            arguments: [
                "debug",
                "--type", "simulator",
                "--process-name", "MyApp",
                "--lldb-command-file", commandFile.path,
            ]
        )

        #expect(exitCode == 0)
        #expect(stderr.snapshot().isEmpty)
        #expect(stdout.snapshot().joined().contains("\"udid\" : \"SIM-1\""))
        let commands = try String(contentsOf: commandFile, encoding: .utf8)
        #expect(
            commands == """
            platform select ios-simulator
            process attach --name "MyApp" --waitfor --include-existing

            """
        )
    }

    /// Verifies device debug writes LLDB device select and attach commands.
    @Test
    func device_writesLLDBAttachCommands() async throws {
        let rootDirectory = temporaryDirectory()
        let commandFile = rootDirectory.appendingPathComponent("attach.lldb")
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let record = DestinationRecord(
            kind: .device,
            udid: "DEVICE-1",
            name: "iPhone Blue",
            runtime: "iOS 26.4",
            state: .connected,
            stateDescription: "Connected"
        )

        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: [record]),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .success(record)),
            now: { Date(timeIntervalSince1970: 100) },
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { stdout.write($0) },
            standardError: { stderr.write($0) }
        )

        let exitCode = await app.run(
            arguments: [
                "debug",
                "--type", "device",
                "--process-name", "MyApp",
                "--lldb-command-file", commandFile.path,
            ]
        )

        #expect(exitCode == 0)
        #expect(stderr.snapshot().isEmpty)
        #expect(stdout.snapshot().joined().contains("\"udid\" : \"DEVICE-1\""))
        let commands = try String(contentsOf: commandFile, encoding: .utf8)
        #expect(
            commands == """
            device select DEVICE-1
            device process attach --name "MyApp" --waitfor --include-existing

            """
        )
    }
}
