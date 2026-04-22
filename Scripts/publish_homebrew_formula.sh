#!/usr/bin/env bash
set -euo pipefail

tap_repository=""
formula_path=""
release_version=""
formula_name="simulator-buddy"
branch="${HOMEBREW_TAP_BRANCH:-main}"

usage() {
  cat <<'EOF'
Usage:
  ./Scripts/publish_homebrew_formula.sh \
    --tap-repository <owner/homebrew-tap> \
    --formula-path <path> \
    --release-version <version> \
    [--formula-name <name>]

Environment:
  HOMEBREW_TAP_TOKEN
    GitHub token with push access to the tap repository.

Optional environment:
  HOMEBREW_TAP_CLONE_URL
    Override clone URL for testing.
  HOMEBREW_TAP_BRANCH
    Override target branch. Defaults to main.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tap-repository)
      tap_repository="$2"
      shift 2
      ;;
    --formula-path)
      formula_path="$2"
      shift 2
      ;;
    --release-version)
      release_version="$2"
      shift 2
      ;;
    --formula-name)
      formula_name="$2"
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

if [[ -z "${tap_repository}" || -z "${formula_path}" || -z "${release_version}" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "${formula_path}" ]]; then
  echo "Formula file not found: ${formula_path}" >&2
  exit 1
fi

if [[ -z "${HOMEBREW_TAP_CLONE_URL:-}" && -z "${HOMEBREW_TAP_TOKEN:-}" ]]; then
  echo "HOMEBREW_TAP_TOKEN is required unless HOMEBREW_TAP_CLONE_URL is provided." >&2
  exit 1
fi

clone_url="${HOMEBREW_TAP_CLONE_URL:-https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${tap_repository}.git}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

git clone --branch "${branch}" "${clone_url}" "${workdir}/tap"

tap_dir="${workdir}/tap"
formula_destination="${tap_dir}/Formula/${formula_name}.rb"

mkdir -p "${tap_dir}/Formula"
cp "${formula_path}" "${formula_destination}"

if [[ ! -f "${tap_dir}/README.md" ]]; then
  cat > "${tap_dir}/README.md" <<EOF
# ${tap_repository}

Homebrew tap for ${formula_name}.

## Install

\`\`\`bash
brew install ${tap_repository#*/homebrew-}/${formula_name}
\`\`\`
EOF
fi

(
  cd "${tap_dir}"

  git config user.name "ipavlidakis"
  git config user.email "472467+ipavlidakis@users.noreply.github.com"
  git add Formula README.md

  if git diff --cached --quiet; then
    echo "No Homebrew tap changes to publish."
    exit 0
  fi

  git commit -m "Update ${formula_name} to v${release_version}"
  git push origin "${branch}"
)
