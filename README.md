# Simulator Buddy

`simulator-buddy` is a macOS CLI for selecting iOS simulators, physical devices, and local Mac destinations without falling back to terminal menus. It is designed for tools like Codex actions that need a real UDID back on stdout and want a native picker window instead of an in-terminal `select` flow.

It can also wrap `xcodebuild`: replace `xcodebuild ...` with
`simulator-buddy ...` and the selected destination is injected before the real
`xcodebuild` command runs.

`simulator-buddy` does not emulate `xcrun` in v1.

## Install

Requirements:

- macOS 15 or newer

Homebrew:

```bash
brew install ipavlidakis/tap/simulator-buddy
```

mise:

```bash
mise use -g github:ipavlidakis/simulator-buddy
```

Direct release download:

1. Download the matching archive from the latest GitHub release.
2. Extract it.
3. Move `simulator-buddy` somewhere on your `PATH`.

## Build From Source

```bash
swift build
swift test
swift run simulator-buddy --help
```

## Commands

List destinations:

```bash
simulator-buddy list --type all --format table
simulator-buddy list --type simulator --format json
simulator-buddy list --type macos --format json
```

Mac run destinations for a specific Xcode scheme:

```bash
simulator-buddy list --type macos \
  --xcode-project ./MyApp.xcodeproj --xcode-scheme MyApp --format json

# Only "Mac Catalyst" or only "Designed for iPad/iPhone" rows for that scheme:
simulator-buddy list --type macos-catalyst \
  --xcode-project ./MyApp.xcodeproj --xcode-scheme MyApp --format json
simulator-buddy list --type macos-designed-for-ipad \
  --xcode-project ./MyApp.xcodeproj --xcode-scheme MyApp --format json
```

Resolve the last used destination:

```bash
simulator-buddy last --type simulator
simulator-buddy last --type all --scope my-workspace --format json
```

Open the native picker and print the selected UDID:

```bash
simulator-buddy select --type all
simulator-buddy select --type device --scope my-workspace
simulator-buddy select --type macos --scope my-workspace
simulator-buddy select --type macos-designed-for-ipad \
  --xcode-project ./MyApp.xcodeproj --xcode-scheme MyApp --format json
simulator-buddy select --type simulator --format json
```

Write LLDB attach commands for a selected destination:

```bash
simulator-buddy debug \
  --type all \
  --process-name MyApp \
  --lldb-command-file /tmp/myapp-attach.lldb
```

Attach with LLDB:

```bash
lldb -s /tmp/myapp-attach.lldb
```

Run LLDB attach directly:

```bash
simulator-buddy attach --type all --process-name MyApp
simulator-buddy attach \
  --destination "platform=iOS Simulator,id=SIM-UDID-1" \
  --process-name MyApp
```

Install and launch an app on an iOS simulator:

```bash
simulator-buddy run \
  --destination "platform=iOS Simulator,id=SIM-UDID-1" \
  --app ./Build/Products/Debug-iphonesimulator/MyApp.app
```

Install and launch on a physical device, or open a local Mac app:

```bash
simulator-buddy run \
  --destination "platform=iOS,id=DEVICE-UDID-1" \
  --app ./Build/Products/Debug-iphoneos/MyApp.app

simulator-buddy run \
  --destination "platform=macOS,arch=arm64,variant=Designed for iPad,id=MAC-ID-1" \
  --app ./Build/Products/Debug-iphoneos/MyApp.app
```

Use `--skip-install` to foreground an app that is already installed.
For Designed-for-iPad-on-Mac builds, `run` wraps the generated iPhoneOS `.app`
in a stable macOS launcher bundle before opening it. The wrapper lives under
`~/Applications/simulator-buddy`, so macOS may ask for approval on first run and
reuse the same container afterwards.

Build, select a valid destination, install if needed, and launch:

```bash
simulator-buddy run \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -configuration Debug

simulator-buddy run \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -configuration Debug \
  --type simulator
```

Forward launch environment values exactly as provided:

```bash
simulator-buddy run \
  --env MY_FLAG=1 \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -configuration Debug
```

For Mac destinations, `run` passes each value through `open --env KEY=VALUE`.
For devices, `run` passes values through `devicectl --environment-variables`.
For simulators, `run` adds the `SIMCTL_CHILD_` transport prefix internally.

Filter simulator and Mac unified logs by category:

```bash
simulator-buddy run \
  --log-category Video \
  --log-category WebRTC \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -configuration Debug
```

`--log-category Video,WebRTC` is equivalent. Simulator and Mac log streaming
uses `process == "<CFBundleExecutable>"` plus the selected category predicates.
Physical devices still use `devicectl --console`; CoreDevice provides the live
console attachment there, but not the same category-filtered unified log stream.

Wrap `xcodebuild` and pick a valid destination for the scheme:

```bash
simulator-buddy \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  test
```

`--type` defaults to `all` when omitted.

## Destination Behavior

| Destination | Run launch | Run logs | Attach |
| --- | --- | --- | --- |
| iOS simulator | `simctl install`, `simctl launch` | `simctl spawn <udid> log stream`, scoped to app process and optional categories | LLDB `platform select ios-simulator`, then process attach |
| Physical iOS device | `devicectl device install app`, `devicectl device process launch --console` | `devicectl --console` app output; category filters are not applied | LLDB `device select <udid>`, then device process attach |
| Native Mac | `open -n` | host `log stream`, scoped to app process and optional categories | LLDB process attach |
| Designed for iPad/iPhone on Mac | stable wrapper in `~/Applications/simulator-buddy`, then `open -n` | host `log stream`, scoped to wrapped app process and optional categories | LLDB process attach |

`Ctrl-C`, Zed task stop, and task cancellation are forwarded to the active
child process so console-backed runs stop the launched app instead of leaving a
background `devicectl` or app process behind.

## Output Contract

- `list --format table` prints a human-readable table.
- `list --format json` prints an array of normalized destination records. For Mac rows loaded via `--xcode-project` / `--xcode-workspace`, each record includes `macOSVariant` and `xcodeDestinationSpecifier` (suitable for `xcodebuild -destination`).
- `last` prints the selected UDID by default, or a JSON selection payload with `--format json`.
- `select` prints the selected UDID by default, or a JSON selection payload with `--format json`.
- `debug` records the selected destination, writes an LLDB command file, and prints a JSON payload with `destination`, `scope`, `selectedAt`, and `lldbCommandFile`.
- `attach` records picker selections, writes a temporary LLDB command file, runs `lldb -s <file>`, streams LLDB output, and returns LLDB's exit code. `--destination <udid|specifier>` skips the picker.
- `run --app <path>` installs and launches on iOS simulators with `simctl`, physical devices with `devicectl`, and Mac destinations with `open`. Simulator runs also open Simulator.app on the selected device. Native Mac bundles open directly; Designed-for-iPad iPhoneOS bundles are copied into one stable wrapper per bundle identifier under `~/Applications/simulator-buddy` so macOS can launch them.
- Simulator and Mac `run` launches the app first, then streams app-scoped unified logs with `log stream`. `--log-category <category>` filters those streams by category; repeat it or pass comma-separated values for multiple categories. When no category is provided, the stream is still scoped to the app process.
- Physical-device `run` keeps using `devicectl --console` so terminal-visible device output stays attached to the launched process. `--log-category` is accepted but not applied to physical-device console output.
- Interrupting `run` forwards the terminal signal to the active child process. For console-attached launches, this also terminates the device app instead of leaving `devicectl` or the app running in the background.
- `run --app <path>` and build-and-run both support `--destination <udid|specifier>` to skip the picker, `--skip-install` to launch without reinstalling, and repeated `--env KEY=VALUE` flags forwarded unchanged through the selected launch mechanism.
- `run -project|-workspace ... -scheme ...` runs `xcodebuild -showdestinations`, prompts with only scheme-valid destinations, runs `xcodebuild build`, resolves the built `.app` through `xcodebuild -showBuildSettings`, then installs/opens/launches it with the same run backend as `run --app`. It uses Xcode's configured DerivedData unless the caller explicitly passes a build setting that changes Xcode output paths. Repeated `--env KEY=VALUE` flags apply only to the final app launch, not the build.
- Raw `xcodebuild` mode runs `xcodebuild -showdestinations` when project/workspace + scheme are present, prompts with only available scheme destinations, injects `-destination <specifier>`, streams real `xcodebuild` output, and returns `xcodebuild`'s exit code.
- Raw `xcodebuild` mode passes through unchanged when `-destination` already exists, scheme/project context is missing, or the invocation is info-only or clean-only.
- `select`, `debug`, `attach`, and `run` exit `130` when the picker is cancelled.

The generated LLDB command file uses:

- `platform select ios-simulator` and `process attach` for simulators.
- `device select <udid>` and `device process attach` for physical devices.
- `process attach` for local Mac destinations.

## How Selection Works

- Simulators are loaded from `xcrun simctl list devices available -j --json-output <file>`.
- Physical devices are loaded from `xcrun devicectl list devices --json-output <file>`.
- Mac destinations with **no** Xcode flags are loaded from `xcrun xctrace list devices` (legacy). When you pass `--xcode-scheme` and `--xcode-project` or `--xcode-workspace`, Mac rows are loaded from `xcodebuild -showdestinations` for that scheme. That yields one entry per local Mac **variant** (for example **Mac Catalyst** vs **Designed for iPad/iPhone**), each with the correct `xcodeDestinationSpecifier` for `xcodebuild -destination`.
- Raw `xcodebuild` mode uses `xcodebuild -showdestinations` for the requested project/workspace + scheme and shows only concrete, available iPhone, iPad, and Mac destinations from that output.
- Only iPhone and iPad simulators/devices and available Mac destinations are included in v1.
- Successful destination fetches update the cache used by future destination-loading flows.
- Picker results come from the records loaded for the current command invocation.

## Storage

All app data lives under:

```text
~/Library/Application Support/com.ipavlidakis.simulator-buddy/
```

Files:

- `history/global.json`
- `history/scopes/<sha256>.json`
- `cache/destinations.json`

Mac launcher wrappers for Designed-for-iPad/iPhone apps live outside this state
directory at:

```text
~/Applications/simulator-buddy/
```

The history tracks:

- last simulator
- last physical device
- last Mac
- last destination overall

The cache stores only normalized destination metadata and fetch timestamps.

## Privacy

This repository intentionally avoids shipping real local device identifiers in tracked files. Test fixtures and examples use sanitized values only.

## Codex Integration

Example `.codex/environments/environment.toml` snippets for a consuming repo:

```toml
[[actions]]
name = "Choose iOS Destination"
icon = "run"
command = "simulator-buddy select --type all"

[[actions]]
name = "Run App On Chosen Destination"
icon = "run"
command = """
simulator-buddy run \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -configuration Debug
"""
```

Debug a process on a chosen destination:

```toml
[[actions]]
name = "Debug App On Chosen Destination"
icon = "bug"
command = """
simulator-buddy attach --type all --process-name MyApp
"""
```

Run a built simulator app:

```toml
[[actions]]
name = "Run App On Chosen Simulator"
icon = "run"
command = """
simulator-buddy run --type simulator --app ./Build/Products/Debug-iphonesimulator/MyApp.app
"""
```

This keeps destination choice native and interactive while preserving
`xcodebuild` and LLDB exit codes for shell scripts and Codex actions.

## Zed Integration

Example `.zed/tasks.json` task:

```json
[
  {
    "label": "Run App",
    "command": "simulator-buddy",
    "args": [
      "run",
      "--log-category",
      "Video",
      "-project",
      "MyApp.xcodeproj",
      "-scheme",
      "MyApp",
      "-configuration",
      "Debug"
    ],
    "cwd": "$ZED_WORKTREE_ROOT",
    "use_new_terminal": false,
    "allow_concurrent_runs": false,
    "reveal": "always",
    "hide": "never",
    "save": "all"
  }
]
```

Stopping the task sends a terminal signal to `simulator-buddy`, which forwards
it to the active child process.

## Release Notes For Maintainers

Release assets are expected to use these exact names:

- `simulator-buddy-aarch64-apple-darwin.tar.gz`
- `simulator-buddy-x86_64-apple-darwin.tar.gz`
- `checksums.txt`
- `simulator-buddy.rb`

The Homebrew formula source is rendered from version + checksum metadata:

```bash
./Scripts/render_homebrew_formula.sh \
  --version <version> \
  --repo ipavlidakis/simulator-buddy \
  --checksums-file dist/checksums.txt
```

The output is intended to be committed in the companion tap repo.

The manual `release` workflow accepts an optional `changelog` input. When it is
provided, that text becomes the GitHub release notes; otherwise new releases use
generated notes.
