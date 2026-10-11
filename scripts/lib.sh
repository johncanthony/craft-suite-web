# Shared helpers for the build scripts. Source, do not run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="${SITE:-$ROOT/site}"
CACHE="${CACHE:-$ROOT/.cache}"

# Emit the non-comment rows of apps.tsv, tab separated:
#   path repo version zipbase title blurb
apps() {
  grep -vE '^\s*(#|$)' "$ROOT/apps.tsv"
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

log() { printf '%s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }
