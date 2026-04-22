#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

touch "${TMP_DIR}/simulator-buddy-aarch64-apple-darwin.tar.gz"
touch "${TMP_DIR}/simulator-buddy-x86_64-apple-darwin.tar.gz"
shasum -a 256 \
  "${TMP_DIR}/simulator-buddy-aarch64-apple-darwin.tar.gz" \
  "${TMP_DIR}/simulator-buddy-x86_64-apple-darwin.tar.gz" \
  > "${TMP_DIR}/checksums.txt"

formula="$(
  "${SCRIPT_DIR}/render_homebrew_formula.sh" \
    --version 0.1.0 \
    --repo ipavlidakis/simulator-buddy \
    --checksums-file "${TMP_DIR}/checksums.txt"
)"

grep -q 'class SimulatorBuddy < Formula' <<<"${formula}"
grep -q 'simulator-buddy-aarch64-apple-darwin.tar.gz' <<<"${formula}"
grep -q 'simulator-buddy-x86_64-apple-darwin.tar.gz' <<<"${formula}"
grep -q 'bin.install "simulator-buddy"' <<<"${formula}"
