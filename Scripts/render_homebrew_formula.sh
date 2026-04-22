#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="${SCRIPT_DIR}/../Packaging/homebrew/simulator-buddy.rb.template"

version=""
repo=""
checksums_file=""

usage() {
  cat <<'EOF'
Usage:
  ./Scripts/render_homebrew_formula.sh \
    --version <version> \
    --repo <owner/repo> \
    --checksums-file <path>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="$2"
      shift 2
      ;;
    --repo)
      repo="$2"
      shift 2
      ;;
    --checksums-file)
      checksums_file="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${version}" || -z "${repo}" || -z "${checksums_file}" ]]; then
  usage >&2
  exit 1
fi

arm64_sha="$(awk '/simulator-buddy-aarch64-apple-darwin.tar.gz$/ { print $1 }' "${checksums_file}")"
x86_64_sha="$(awk '/simulator-buddy-x86_64-apple-darwin.tar.gz$/ { print $1 }' "${checksums_file}")"

if [[ -z "${arm64_sha}" || -z "${x86_64_sha}" ]]; then
  echo "Missing required asset checksums in ${checksums_file}" >&2
  exit 1
fi

sed \
  -e "s|__VERSION__|${version}|g" \
  -e "s|__REPO__|${repo}|g" \
  -e "s|__ARM64_SHA__|${arm64_sha}|g" \
  -e "s|__X86_64_SHA__|${x86_64_sha}|g" \
  "${TEMPLATE_PATH}"
