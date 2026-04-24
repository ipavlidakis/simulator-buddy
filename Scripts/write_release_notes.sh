#!/usr/bin/env bash
set -euo pipefail

output_path=""
notes=""

usage() {
  cat <<'EOF'
Usage:
  ./Scripts/write_release_notes.sh \
    --output-path <path> \
    [--notes <text>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-path)
      output_path="$2"
      shift 2
      ;;
    --notes)
      notes="$2"
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

if [[ -z "${output_path}" ]]; then
  usage >&2
  exit 1
fi

if [[ -z "${notes}" ]]; then
  rm -f "${output_path}"
  exit 0
fi

mkdir -p "$(dirname "${output_path}")"
printf '%s\n' "${notes}" > "${output_path}"
