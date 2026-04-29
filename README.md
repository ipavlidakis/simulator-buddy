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
simulator-buddy's Application Support directory, so macOS may ask for approval
on first run and reuse the same container afterwards.

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

Wrap `xcodebuild` and pick a valid destination for the scheme:

```bash
simulator-buddy \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  test
```

`--type` defaults to `all` when omitted.

## Output Contract

- `list --format table` prints a human-readable table.
- `list --format json` prints an array of normalized destination records. For Mac rows loaded via `--xcode-project` / `--xcode-workspace`, each record includes `macOSVariant` and `xcodeDestinationSpecifier` (suitable for `xcodebuild -destination`).
- `last` prints the selected UDID by default, or a JSON selection payload with `--format json`.
- `select` prints the selected UDID by default, or a JSON selection payload with `--format json`.
- `debug` records the selected destination, writes an LLDB command file, and prints a JSON payload with `destination`, `scope`, `selectedAt`, and `lldbCommandFile`.
- `attach` records picker selections, writes a temporary LLDB command file, runs `lldb -s <file>`, streams LLDB output, and returns LLDB's exit code. `--destination <udid|specifier>` skips the picker.
- `run --app <path>` installs and launches on iOS simulators with `simctl`, physical devices with `devicectl`, and Mac destinations with `open`. Simulator runs also open Simulator.app on the selected device. Native Mac bundles open directly; Designed-for-iPad iPhoneOS bundles are copied into one stable wrapper per bundle identifier so macOS can launch them. It attaches the launched app to the terminal where supported (`simctl --console-pty`, `devicectl --console`, or `open -W` stdio), without starting a whole-system log stream. It stays attached until the app exits or the command is interrupted. `--destination <udid|specifier>` skips the picker, `--skip-install` launches without reinstalling, and repeated `--env KEY=VALUE` flags are forwarded unchanged through the selected launch mechanism.
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
