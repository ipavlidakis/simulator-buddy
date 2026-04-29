import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests for one-command build, install, and launch behavior.
struct BuildAndRunCommandHandlerTests {
    /// Verifies `run` with Xcode flags selects, builds, resolves product settings, installs, and launches.
    @Test
    func xcodeRun_selectsBuildsInstallsAndLaunches() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory
            .appendingPathComponent("Build/Products/Debug-iphonesimulator/Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Demo")
        let selectedRecord = DestinationRecord(
            kind: .simulator,
            udid: "SIM-1",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .available,
            stateDescription: "Available",
            xcodeDestinationSpecifier: "platform=iOS Simulator,id=SIM-1"
        )
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: showDestinationsOutput, stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "build\n", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: buildSettingsOutput(rootDirectory: rootDirectory), stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "installed\n", stderr: ""),
                CommandResult(terminationStatus: 7, stdout: "launched\n", stderr: "launch stderr\n"),
            ]
        )
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .success(selectedRecord)),
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
                "-project", "/tmp/App.xcodeproj",
                "-scheme", "App",
                "-configuration", "Debug",
            ]
        )

        let commands = await runner.snapshot()
        #expect(exitCode == 7)
        #expect(commands == [
            Command(
                executable: "xcodebuild",
                arguments: ["-project", "/tmp/App.xcodeproj", "-scheme", "App", "-showdestinations"]
            ),
            Command(
                executable: "xcodebuild",
                arguments: [
                    "-project", "/tmp/App.xcodeproj",
                    "-scheme", "App",
                    "-configuration", "Debug",
                    "-destination", "platform=iOS Simulator,id=SIM-1",
                    "build",
                ]
            ),
            Command(
                executable: "xcodebuild",
                arguments: [
                    "-project", "/tmp/App.xcodeproj",
                    "-scheme", "App",
                    "-configuration", "Debug",
                    "-destination", "platform=iOS Simulator,id=SIM-1",
                    "-showBuildSettings",
                ]
            ),
            Command(
                executable: "xcrun",
                arguments: ["simctl", "bootstatus", "SIM-1", "-b"]
            ),
            Command(executable: "open", arguments: ["-a", "Simulator", "--args", "-CurrentDeviceUDID", "SIM-1"]),
            Command(executable: "xcrun", arguments: ["simctl", "install", "SIM-1", appURL.path]),
            Command(
                executable: "xcrun",
                arguments: ["simctl", "launch", "--console-pty", "--terminate-running-process", "SIM-1", "com.example.Demo"]
            ),
        ])
        #expect(stdout.snapshot() == ["build\n", "installed\n", "launched\n"])
        #expect(stderr.snapshot() == ["Streaming app logs. Press Ctrl-C to stop.\n", "launch stderr\n"])
    }

    /// Verifies build failure stops before product lookup, install, or launch.
    @Test
    func xcodeRun_buildFailureReturnsBuildStatus() async throws {
        let rootDirectory = temporaryDirectory()
        let selectedRecord = DestinationRecord(
            kind: .simulator,
            udid: "SIM-1",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .available,
            stateDescription: "Available",
            xcodeDestinationSpecifier: "platform=iOS Simulator,id=SIM-1"
        )
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: showDestinationsOutput, stderr: ""),
                CommandResult(terminationStatus: 65, stdout: "", stderr: "build failed\n"),
            ]
        )
        let stderr = OutputRecorder()
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .success(selectedRecord)),
            commandRunner: runner,
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { _ in },
            standardError: { stderr.write($0) },
            streamStandardError: { stderr.write($0) }
        )

        let exitCode = await app.run(arguments: ["run", "-project", "/tmp/App.xcodeproj", "-scheme", "App"])

        #expect(exitCode == 65)
        #expect(await runner.snapshot().count == 2)
        #expect(stderr.snapshot() == ["build failed\n"])
    }

    /// Verifies a provided destination skips destination discovery and picker UI.
    @Test
    func xcodeRun_providedDestinationSkipsPicker() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory
            .appendingPathComponent("Build/Products/Debug-iphonesimulator/Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(at: appURL, bundleIdentifier: "com.example.Demo")
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "build\n", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: buildSettingsOutput(rootDirectory: rootDirectory), stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "installed\n", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "launched\n", stderr: ""),
            ]
        )
        let picker = StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: picker,
            commandRunner: runner,
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(
            arguments: [
                "run",
                "--destination", "platform=iOS Simulator,id=SIM-1",
                "-project", "/tmp/App.xcodeproj",
                "-scheme", "App",
            ]
        )

        let commands = await runner.snapshot()
        #expect(exitCode == 0)
        #expect(commands.first == Command(
            executable: "xcodebuild",
            arguments: [
                "-project", "/tmp/App.xcodeproj",
                "-scheme", "App",
                "-destination", "platform=iOS Simulator,id=SIM-1",
                "build",
            ]
        ))
        #expect(await picker.presentCallCount == 0)
    }

    /// Sample `xcodebuild -showdestinations` output used by the build-and-run tests.
    private var showDestinationsOutput: String {
        """
        Available destinations for the "App" scheme:
            { platform:iOS Simulator, arch:arm64, id:SIM-1, OS:26.5, name:iPhone Air }
        """
    }

    /// Builds `xcodebuild -showBuildSettings` output for a test app product.
    private func buildSettingsOutput(rootDirectory: URL) -> String {
        """
        Build settings for action build and target DemoApp:
            FULL_PRODUCT_NAME = Demo.app
            PRODUCT_BUNDLE_IDENTIFIER = com.example.Demo
            TARGET_BUILD_DIR = \(rootDirectory.path)/Build/Products/Debug-iphonesimulator
        """
    }
}
