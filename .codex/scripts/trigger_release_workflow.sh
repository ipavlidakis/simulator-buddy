#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_REPOSITORY="${RELEASE_REPOSITORY:-ipavlidakis/simulator-buddy}"

cd "${ROOT_DIR}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_command gh
require_command git
require_command osascript

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated." >&2
  exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ -z "${current_branch}" || "${current_branch}" == "HEAD" ]]; then
  echo "Could not determine the current branch." >&2
  exit 1
fi

prompt_for_version() {
  local response

  if ! response="$(
    osascript <<'APPLESCRIPT'
tell application "System Events"
  activate
  set dialogResult to display dialog "Release version (for example 0.1.0)" default answer "" buttons {"Cancel", "Trigger"} default button "Trigger"
  return text returned of dialogResult
end tell
APPLESCRIPT
  )"; then
    echo "Release cancelled." >&2
    exit 130
  fi

  printf '%s\n' "${response}"
}

raw_version="${RELEASE_VERSION:-}"
if [[ -z "${raw_version}" ]]; then
  raw_version="$(prompt_for_version)"
fi

version="${raw_version#v}"

if [[ -z "${version}" ]]; then
  echo "Release version is required." >&2
  exit 1
fi

if [[ ! "${version}" =~ ^[0-9]+(\.[0-9]+){2}([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version: ${raw_version}" >&2
  exit 1
fi

release_tag="v${version}"

if [[ "${RELEASE_DRY_RUN:-0}" == "1" ]]; then
  echo "Dry run: gh workflow run release.yml --repo ${DEFAULT_REPOSITORY} --ref ${current_branch} -f version=${version}"
  exit 0
fi

gh workflow run release.yml \
  --repo "${DEFAULT_REPOSITORY}" \
  --ref "${current_branch}" \
  -f "version=${version}"

echo "Triggered release workflow for ${release_tag} on ${DEFAULT_REPOSITORY} (${current_branch})."
