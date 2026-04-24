# Simulator Buddy Agents Guide

- Keep responses short, direct, and implementation-focused.
- This repo is a macOS SwiftPM CLI. Prefer `swift build`, `swift run`, and `swift test`.
- For bugs and regressions, add or update tests first, then fix the code, then rerun `swift test`.
- Do not commit sensitive local data. Docs, fixtures, screenshots, and tests must not include real device names, UDIDs, serials, ECIDs, hostnames, or local paths.
- Keep release and packaging outputs deterministic. If you change release asset names, checksums, or install instructions, update the release scripts, workflows, and README together.
- For releases, trigger `release.yml` with `workflow_dispatch`: `gh workflow run release.yml --ref main -f version=<version> -F changelog=@<file>`.
- Release changelogs must use `Added`, `Changed`, and `Fixed` sections with clear bullet entries capped at 80 characters.
- Avoid speculative features. Build only what the current CLI contract needs.
