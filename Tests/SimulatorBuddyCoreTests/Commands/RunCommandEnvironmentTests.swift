import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests covering destination-specific app environment forwarding during launch.
struct RunCommandEnvironmentTests {
    /// Verifies simulator launches receive caller-provided app environment through `SIMCTL_CHILD_`.
    @Test
    func simulatorLaunch_forwardsEnvironment() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Demo")
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
            ]
        )
        let app = makeApplication(rootDirectory: rootDirectory, runner: runner)

        let exitCode = await app.run(arguments: [
            "run",
            "--env", "STREAM_VIDEO_TERMINAL_LOGS=1",
            "--app", appURL.path,
            "--destination", "platform=iOS Simulator,id=SIM-1",
        ])

        let commands = await runner.snapshot()
        #expect(exitCode == 0)
        #expect(commands[0] == Command(
            executable: "xcrun",
            arguments: ["simctl", "bootstatus", "SIM-1", "-b"]
        ))
        #expect(commands[1] == Command(
            executable: "open",
            arguments: ["-a", "Simulator", "--args", "-CurrentDeviceUDID", "SIM-1"]
        ))
        #expect(commands[3] == Command(
            executable: "xcrun",
            arguments: ["simctl", "launch", "--console-pty", "--terminate-running-process", "SIM-1", "com.example.Demo"],
            environment: ["SIMCTL_CHILD_STREAM_VIDEO_TERMINAL_LOGS": "1"]
        ))
    }

    /// Verifies physical device launches receive caller-provided environment without key rewriting.
    @Test
    func deviceLaunch_forwardsEnvironment() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Demo")
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
            ]
        )
        let app = makeApplication(rootDirectory: rootDirectory, runner: runner)

        let exitCode = await app.run(arguments: [
            "run",
            "--type", "device",
            "--env", "STREAM_VIDEO_TERMINAL_LOGS=1",
            "--app", appURL.path,
            "--destination", "platform=iOS,id=DEVICE-1",
        ])

        let commands = await runner.snapshot()
        #expect(exitCode == 0)
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
                "--environment-variables",
                #"{"STREAM_VIDEO_TERMINAL_LOGS":"1"}"#,
                "--console",
                "com.example.Demo",
            ]
        ))
    }

    /// Verifies Mac launches pass environment through `open --env`.
    @Test
    func macLaunch_forwardsEnvironment() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(
            at: appURL,
            bundleIdentifier: "com.example.Demo",
            supportedPlatforms: ["MacOSX"]
        )
        let runner = RecordingCommandRunner(
            results: [CommandResult(terminationStatus: 0, stdout: "", stderr: "")]
        )
        let app = makeApplication(rootDirectory: rootDirectory, runner: runner)

        let exitCode = await app.run(arguments: [
            "run",
            "--type", "macos",
            "--env", "STREAM_VIDEO_TERMINAL_LOGS=1",
            "--app", appURL.path,
            "--destination", "platform=macOS,arch=arm64,variant=Mac Catalyst,id=MAC-1",
        ])

        let commands = await runner.snapshot()
        #expect(exitCode == 0)
        #expect(commands == [Command(
            executable: "open",
            arguments: [
                "-n",
                "-W",
                "-o",
                "/dev/stdout",
                "--stderr",
                "/dev/stderr",
                "--env",
                "STREAM_VIDEO_TERMINAL_LOGS=1",
                appURL.path,
            ]
        )])
    }

    /// Verifies build-and-run forwards raw environment to the final physical-device launch command.
    @Test
    func buildAndRunDevice_forwardsEnvironment() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory
            .appendingPathComponent("Build/Products/Debug-iphoneos/Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Demo")
        let selectedRecord = DestinationRecord(
            kind: .device,
            udid: "DEVICE-1",
            name: "iPhone",
            runtime: nil,
            state: .available,
            stateDescription: "Available",
            xcodeDestinationSpecifier: "platform=iOS,id=DEVICE-1"
        )
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: showDestinationsOutput, stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: buildSettingsOutput(rootDirectory: rootDirectory), stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
            ]
        )
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .success(selectedRecord)),
            commandRunner: runner,
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(arguments: [
            "run",
            "--env", "STREAM_VIDEO_TERMINAL_LOGS=1",
            "-project", "/tmp/App.xcodeproj",
            "-scheme", "App",
        ])

        let commands = await runner.snapshot()
        #expect(exitCode == 0)
        #expect(commands.last == Command(
            executable: "xcrun",
            arguments: [
                "devicectl",
                "device",
                "process",
                "launch",
                "--device",
                "DEVICE-1",
                "--terminate-existing",
                "--environment-variables",
                #"{"STREAM_VIDEO_TERMINAL_LOGS":"1"}"#,
                "--console",
                "com.example.Demo",
            ]
        ))
    }

    /// Creates a CLI app instance for environment forwarding tests.
    private func makeApplication(rootDirectory: URL, runner: RecordingCommandRunner) -> CLIApplication {
        CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled)),
            commandRunner: runner,
            macRunDirectory: rootDirectory.appendingPathComponent("mac-run", isDirectory: true),
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { _ in },
            standardError: { _ in }
        )
    }

    /// Sample `xcodebuild -showdestinations` output for build-and-run coverage.
    private var showDestinationsOutput: String {
        """
        Available destinations for the "App" scheme:
            { platform:iOS Simulator, arch:arm64, id:SIM-1, OS:26.5, name:iPhone Air }
        """
    }

    /// Builds `xcodebuild -showBuildSettings` output for an app product.
    private func buildSettingsOutput(rootDirectory: URL) -> String {
        """
        Build settings for action build and target DemoApp:
            FULL_PRODUCT_NAME = Demo.app
            PRODUCT_BUNDLE_IDENTIFIER = com.example.Demo
            TARGET_BUILD_DIR = \(rootDirectory.path)/Build/Products/Debug-iphoneos
        """
    }
}
