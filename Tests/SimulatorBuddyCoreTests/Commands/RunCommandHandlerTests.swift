import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests covering app install and launch behavior.
struct RunCommandHandlerTests {
    /// Verifies provided simulator destinations skip UI, install the app, launch it, and forward launch status.
    @Test
    func providedSimulatorDestination_installsAndLaunchesApp() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo App.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Demo")
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "installed\n", stderr: ""),
                CommandResult(terminationStatus: 42, stdout: "launched\n", stderr: "launch warning\n"),
            ]
        )
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let picker = StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: picker,
            commandRunner: runner,
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { stdout.write($0) },
            standardError: { stderr.write($0) },
            streamStandardOutput: { stdout.write($0) },
            streamStandardError: { stderr.write($0) }
        )

        let exitCode = await app.run(
            arguments: [
                "run",
                "--app", appURL.path,
                "--destination", "platform=iOS Simulator,id=SIM-1",
            ]
        )

        let commands = await runner.snapshot()
        #expect(exitCode == 42)
        #expect(commands.count == 4)
        #expect(commands[0] == Command(
            executable: "xcrun",
            arguments: ["simctl", "bootstatus", "SIM-1", "-b"]
        ))
        #expect(commands[1] == Command(
            executable: "open",
            arguments: ["-a", "Simulator", "--args", "-CurrentDeviceUDID", "SIM-1"]
        ))
        #expect(commands[2] == Command(executable: "xcrun", arguments: ["simctl", "install", "SIM-1", appURL.path]))
        #expect(commands[3] == Command(
            executable: "xcrun",
            arguments: ["simctl", "launch", "--console-pty", "--terminate-running-process", "SIM-1", "com.example.Demo"]
        ))
        #expect(await picker.presentCallCount == 0)
        #expect(stdout.snapshot() == ["installed\n", "launched\n"])
        #expect(stderr.snapshot() == ["Streaming app logs. Press Ctrl-C to stop.\n", "launch warning\n"])
    }

    /// Verifies picker-based simulator launch records history and uses an explicit bundle identifier override.
    @Test
    func pickedSimulatorDestination_recordsSelectionAndUsesBundleOverride() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Ignored")
        let record = DestinationRecord(
            kind: .simulator,
            udid: "SIM-2",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .booted,
            stateDescription: "Booted"
        )
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
            ]
        )
        let historyStore = HistoryStore(paths: AppPaths(rootDirectory: rootDirectory))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [record], devices: []),
            historyStore: historyStore,
            pickerPresenter: StubPickerPresenter(result: .success(record)),
            commandRunner: runner,
            now: { Date(timeIntervalSince1970: 300) },
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp/workspace", isDirectory: true) },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(
            arguments: [
                "run",
                "--type", "simulator",
                "--app", appURL.path,
                "--bundle-id", "com.example.Override",
            ]
        )

        let commands = await runner.snapshot()
        let history = try await historyStore.resolveLast(
            type: .simulator,
            scope: SelectionScope(workingDirectory: URL(fileURLWithPath: "/tmp/workspace", isDirectory: true))
        )
        #expect(exitCode == 0)
        #expect(commands[0] == Command(
            executable: "xcrun",
            arguments: ["simctl", "bootstatus", "SIM-2", "-b"]
        ))
        #expect(commands[1] == Command(
            executable: "open",
            arguments: ["-a", "Simulator", "--args", "-CurrentDeviceUDID", "SIM-2"]
        ))
        #expect(commands[2] == Command(executable: "xcrun", arguments: ["simctl", "install", "SIM-2", appURL.path]))
        #expect(commands[3] == Command(
            executable: "xcrun",
            arguments: ["simctl", "launch", "--console-pty", "--terminate-running-process", "SIM-2", "com.example.Override"]
        ))
        #expect(history?.udid == "SIM-2")
    }

    /// Verifies skip-install launches an already-installed app without reinstalling it.
    @Test
    func skipInstall_launchesOnly() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Demo")
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "launched\n", stderr: ""),
            ]
        )
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled)),
            commandRunner: runner,
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(
            arguments: [
                "run",
                "--app", appURL.path,
                "--skip-install",
                "--destination", "platform=iOS Simulator,id=SIM-3",
            ]
        )

        let commands = await runner.snapshot()
        #expect(exitCode == 0)
        #expect(commands == [
            Command(
                executable: "xcrun",
                arguments: ["simctl", "bootstatus", "SIM-3", "-b"]
            ),
            Command(
                executable: "open",
                arguments: ["-a", "Simulator", "--args", "-CurrentDeviceUDID", "SIM-3"]
            ),
            Command(
                executable: "xcrun",
                arguments: ["simctl", "launch", "--console-pty", "--terminate-running-process", "SIM-3", "com.example.Demo"]
            ),
        ])
    }

    /// Verifies physical device destinations install through CoreDevice and launch the bundle identifier.
    @Test
    func providedDeviceDestination_installsAndLaunchesApp() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Demo")
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "installed\n", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "launched\n", stderr: ""),
            ]
        )
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled)),
            commandRunner: runner,
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(
            arguments: [
                "run",
                "--type", "device",
                "--app", appURL.path,
                "--destination", "platform=iOS,id=DEVICE-1",
            ]
        )

        let commands = await runner.snapshot()
        #expect(exitCode == 0)
        #expect(commands[0] == Command(
            executable: "xcrun",
            arguments: ["devicectl", "device", "install", "app", "--device", "DEVICE-1", appURL.path]
        ))
        #expect(commands[1] == Command(
            executable: "xcrun",
            arguments: [
                "devicectl",
                "device",
                "process",
                "launch",
                "--device",
                "DEVICE-1",
                "--terminate-existing",
                "--console",
                "com.example.Demo",
            ]
        ))
    }

}
