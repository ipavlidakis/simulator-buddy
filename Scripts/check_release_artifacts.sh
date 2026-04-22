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
printf '%s\n' "${formula}" > "${TMP_DIR}/simulator-buddy.rb"

tap_repo="$(mktemp -d)/tap.git"
(
  git init --bare "${tap_repo}" >/dev/null
  seed_repo="$(mktemp -d)"
  cd "${seed_repo}"
  git init -b main >/dev/null
  git config user.name test
  git config user.email test@example.com
  echo "# test" > README.md
  git add README.md
  git commit -m init >/dev/null
  git remote add origin "${tap_repo}"
  git push origin main >/dev/null
)

HOMEBREW_TAP_CLONE_URL="${tap_repo}" \
./Scripts/publish_homebrew_formula.sh \
  --tap-repository ipavlidakis/homebrew-tap \
  --formula-path "${TMP_DIR}/simulator-buddy.rb" \
  --release-version 0.1.0 \
  --formula-name simulator-buddy >/dev/null 2>&1
