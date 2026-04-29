import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests covering Mac destination launch behavior.
struct RunCommandHandlerMacTests {
    /// Verifies native Mac app bundles are opened directly without an install step.
    @Test
    func nativeMacDestination_opensAppBundle() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(
            at: appURL,
            bundleIdentifier: "com.example.Demo",
            executableName: "Demo",
            supportedPlatforms: ["MacOSX"]
        )
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
            ]
        )
        let stderr = OutputRecorder()
        let app = makeApplication(rootDirectory: rootDirectory, runner: runner, streamStandardError: stderr.write)

        let exitCode = await app.run(
            arguments: [
                "run",
                "--type", "macos",
                "--app", appURL.path,
                "--destination", "platform=macOS,arch=arm64,variant=Mac Catalyst,id=MAC-1",
            ]
        )

        let commands = await runner.snapshot()
        #expect(exitCode == 0)
        #expect(commands == [
            Command(executable: "open", arguments: ["-n", appURL.path]),
            Command(
                executable: "log",
                arguments: [
                    "stream",
                    "--style",
                    "compact",
                    "--predicate",
                    #"process == "Demo""#,
                ]
            ),
        ])
        #expect(stderr.snapshot() == ["Streaming app logs. Press Ctrl-C to stop.\n"])
    }

    /// Verifies iPhoneOS app bundles selected for Mac get wrapped before `open`.
    @Test
    func designedForIPadDestination_wrapsIPhoneOSAppBeforeOpen() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(
            at: appURL,
            bundleIdentifier: "com.example.Demo",
            executableName: "Demo",
            supportedPlatforms: ["iPhoneOS"]
        )
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 42, stdout: "log\n", stderr: ""),
            ]
        )
        let app = makeApplication(rootDirectory: rootDirectory, runner: runner)

        let exitCode = await app.run(
            arguments: [
                "run",
                "--type", "macos",
                "--log-category", "Video,WebRTC",
                "--app", appURL.path,
                "--destination", "platform=macOS,arch=arm64,variant=Designed for iPad,id=MAC-1",
            ]
        )

        let commands = await runner.snapshot()
        let wrappedPath = try #require(commands.first?.arguments.last)
        let wrappedURL = URL(fileURLWithPath: wrappedPath)
        let copiedAppURL = wrappedURL
            .appendingPathComponent("Wrapper", isDirectory: true)
            .appendingPathComponent("Demo.app", isDirectory: true)
        let bundleMetadataURL = wrappedURL
            .appendingPathComponent("Wrapper", isDirectory: true)
            .appendingPathComponent("BundleMetadata.plist")
        #expect(exitCode == 42)
        #expect(commands.count == 2)
        #expect(commands.first?.executable == "open")
        #expect(commands.first?.arguments.first == "-n")
        #expect(commands.first?.arguments.contains("-W") == false)
        #expect(commands.last == Command(
            executable: "log",
            arguments: [
                "stream",
                "--style",
                "compact",
                "--predicate",
                #"process == "Demo" AND (category == "Video" OR category == "WebRTC")"#,
            ]
        ))
        #expect(wrappedPath != appURL.path)
        #expect(wrappedURL.lastPathComponent == "com.example.Demo.app")
        #expect(FileManager.default.fileExists(atPath: copiedAppURL.path))
        #expect(FileManager.default.fileExists(atPath: bundleMetadataURL.path))
        #expect(
            (try? FileManager.default.destinationOfSymbolicLink(
                atPath: wrappedURL.appendingPathComponent("WrappedBundle").path
            )) == "Wrapper/Demo.app"
        )
    }

    /// Verifies repeated launches reuse the same wrapper container for first-run approval.
    @Test
    func designedForIPadDestination_reusesStableWrapperContainer() async throws {
        let rootDirectory = temporaryDirectory()
        let appURL = rootDirectory.appendingPathComponent("Demo.app", isDirectory: true)
        try AppBundleFixtureFactory().makeAppBundle(
            at: appURL,
            bundleIdentifier: "com.example.Demo",
            supportedPlatforms: ["iPhoneOS"]
        )
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
                CommandResult(terminationStatus: 0, stdout: "", stderr: ""),
            ]
        )
        let app = makeApplication(rootDirectory: rootDirectory, runner: runner)
        let arguments = [
            "run",
            "--type", "macos",
            "--app", appURL.path,
            "--destination", "platform=macOS,arch=arm64,variant=Designed for iPad,id=MAC-1",
        ]

        let firstExitCode = await app.run(arguments: arguments)
        let secondExitCode = await app.run(arguments: arguments)

        let commands = await runner.snapshot()
        #expect(firstExitCode == 0)
        #expect(secondExitCode == 0)
        #expect(commands.count == 2)
        #expect(commands[0].arguments.last == commands[1].arguments.last)
    }

    /// Creates a CLI app instance for Mac run tests.
    private func makeApplication(
        rootDirectory: URL,
        runner: RecordingCommandRunner,
        streamStandardError: @escaping @Sendable (String) -> Void = { _ in }
    ) -> CLIApplication {
        CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled)),
            commandRunner: runner,
            temporaryDirectory: { rootDirectory },
            macRunDirectory: rootDirectory.appendingPathComponent("mac-run", isDirectory: true),
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { _ in },
            standardError: { _ in },
            streamStandardError: streamStandardError
        )
    }
}
