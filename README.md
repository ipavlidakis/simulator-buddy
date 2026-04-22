# Simulator Buddy

`simulator-buddy` is a macOS CLI for selecting iOS simulators and physical devices without falling back to terminal menus. It is designed for tools like Codex actions that need a real UDID back on stdout and want a native picker window instead of an in-terminal `select` flow.

## Install

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
simulator-buddy select --type simulator --format json
```

`--type` defaults to `all` when omitted.

## Output Contract

- `list --format table` prints a human-readable table.
- `list --format json` prints an array of normalized destination records.
- `last` prints the selected UDID by default, or a JSON selection payload with `--format json`.
- `select` prints the selected UDID by default, or a JSON selection payload with `--format json`.
- `select` exits `130` when the picker is cancelled.

## How Selection Works

- Simulators are loaded from `xcrun simctl list devices available -j --json-output <file>`.
- Physical devices are loaded from `xcrun devicectl list devices --json-output <file>`.
- Only iPhone and iPad simulators/devices are included in v1.
- The picker warm-starts from a cached destination list, labels the UI as cached/refreshing, and then validates selections against fresh live data before returning a result.
- A cached-only selection is never returned if the refresh later removes the destination or the refresh fails.

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
DESTINATION_ID="$(simulator-buddy select --type all)"
xcodebuild \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -destination "id=${DESTINATION_ID}" \
  build
"""
```

This keeps the destination choice native and interactive while still returning a plain UDID that shell scripts and Codex actions can consume.

## Release Notes For Maintainers

Release assets are expected to use these exact names:

- `simulator-buddy-aarch64-apple-darwin.tar.gz`
- `simulator-buddy-x86_64-apple-darwin.tar.gz`
- `checksums.txt`

The Homebrew formula source is rendered from version + checksum metadata:

```bash
./Scripts/render_homebrew_formula.sh \
  --version 0.1.0 \
  --repo ipavlidakis/simulator-buddy \
  --checksums-file dist/checksums.txt
```

The output is intended to be committed in the companion tap repo.
