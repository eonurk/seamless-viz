#!/usr/bin/env bash
# Install pinned molecular-classifier sources and models from their upstream
# repositories. Bridge source is installed in the Docker image; its restricted
# model bundle must be supplied separately by an authorized user.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${SEAMLESS_TOOLS_DIR:-$ROOT_DIR/backend/tools}"
RUNTIME_DIR="${SEAMLESS_TOOLS_RUNTIME_DIR:-$ROOT_DIR/backend/tools_runtime}"

for command_name in curl shasum tar; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required to install the molecular tools." >&2
    exit 1
  fi
done

log() { printf '  %-9s %s\n' "$1" "$2"; }

verify_sha256() {
  local path="$1" expected="$2" actual
  actual="$(shasum -a 256 "$path" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]]
}

install_archive() {
  local name="$1" repository="$2" revision="$3" archive_sha="$4" marker="$5"
  local target="$TOOLS_DIR/$name"

  if [[ -e "$target/$marker" ]]; then
    if [[ -f "$target/.seamless-revision" ]]; then
      log "ok" "$name ($(cat "$target/.seamless-revision"))"
    else
      log "ok" "$name (existing local copy)"
    fi
    return 0
  fi

  if [[ -e "$target" ]]; then
    echo "Incomplete tool directory already exists: $target" >&2
    echo "Move it aside and rerun this script." >&2
    exit 1
  fi

  local temporary archive unpack
  temporary="$(mktemp -d "${TMPDIR:-/tmp}/seamless-${name}.XXXXXX")"
  archive="$temporary/source.tar.gz"
  unpack="$temporary/unpacked"
  trap 'rm -rf "$temporary"' RETURN

  log "download" "$name"
  curl --fail --location --retry 3 --output "$archive" \
    "https://codeload.github.com/$repository/tar.gz/$revision"

  if ! verify_sha256 "$archive" "$archive_sha"; then
    echo "Checksum verification failed for $name" >&2
    exit 1
  fi

  mkdir -p "$unpack" "$TOOLS_DIR"
  tar -xzf "$archive" -C "$unpack" --strip-components=1
  if [[ ! -e "$unpack/$marker" ]]; then
    echo "The $name archive does not contain the expected file: $marker" >&2
    exit 1
  fi

  printf '%s\n' "$revision" > "$unpack/.seamless-revision"
  mv "$unpack" "$target"
  rm -rf "$temporary"
  trap - RETURN
  log "installed" "$name"
}

install_bridge_bundle() {
  local filename="bridge_inference_with_gtex1252_plus_srp03245568_healthy_balanced.bundle"
  local target="$RUNTIME_DIR/Bridge/$filename"
  local source_path="${BRIDGE_BUNDLE_PATH:-}"
  local source_url="${BRIDGE_BUNDLE_URL:-}"
  local expected_sha="${BRIDGE_BUNDLE_SHA256:-}"

  if [[ -f "$target" ]]; then
    if [[ -n "$expected_sha" ]] && ! verify_sha256 "$target" "$expected_sha"; then
      echo "Existing Bridge bundle failed checksum verification: $target" >&2
      exit 1
    fi
    log "ok" "Bridge bundle"
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  if [[ -n "$source_path" ]]; then
    if [[ ! -f "$source_path" ]]; then
      echo "Bridge bundle file not found: $source_path" >&2
      exit 1
    fi
    if [[ -n "$expected_sha" ]] && ! verify_sha256 "$source_path" "$expected_sha"; then
      echo "Bridge source bundle failed checksum verification." >&2
      exit 1
    fi
    cp "$source_path" "$target"
    log "installed" "Bridge bundle from local file"
    return 0
  fi

  if [[ -n "$source_url" ]]; then
    if [[ -z "$expected_sha" ]]; then
      echo "BRIDGE_BUNDLE_SHA256 is required with BRIDGE_BUNDLE_URL." >&2
      exit 1
    fi
    local temporary
    temporary="$target.part"
    rm -f "$temporary"
    log "download" "Bridge bundle (authorized private URL)"
    curl --fail --location --retry 3 --output "$temporary" "$source_url"
    if ! verify_sha256 "$temporary" "$expected_sha"; then
      rm -f "$temporary"
      echo "Downloaded Bridge bundle failed checksum verification." >&2
      exit 1
    fi
    mv "$temporary" "$target"
    log "installed" "Bridge bundle"
    return 0
  fi

  log "optional" "Bridge bundle not supplied (restricted, non-commercial model)"
}

echo "Molecular classifier sources"
install_archive \
  "AMLmapR" "jeppeseverens/AMLmapR" \
  "a3e227dc2dbf77a647eb7a4d4a58c95fc617f9c4" \
  "4921554fedfa100496db2941b8ba58dbf885ddb8ffe96a94db79dcbaa7d9c1f6" \
  "R/functions.R"
install_archive \
  "ALLSorts" "Oshlack/ALLSorts" \
  "f215e74984d1d27f0cb9bc8ef2acff512786c5ab" \
  "f97a3933fce2f71c55d83640fe3b1a1237dd893d0e8d5f867a231b9f79c187f0" \
  "ALLSorts/models/allsorts/allsorts.pkl.gz"
install_archive \
  "TALLSorts" "Oshlack/TALLSorts" \
  "a3cae68e6d714660e07432816253b29fc75075be" \
  "ae1de6e410e584fde5076f0451d3254dc4b468c82e1a831edeefc4e68effa4a9" \
  "TALLSorts/models/tallsorts/tallsorts_default_model.pkl.gz"
install_archive \
  "ALLCatchR_bcrabl1" "ThomasBeder/ALLCatchR_bcrabl1" \
  "e38e654ca1596b3803f9ea5ab21982b4d3af8a7c" \
  "e6ba8eeb18484f045d0aea04ffbcd1126a5d1dcd146fbf13c91b52b5098ca0f6" \
  "DESCRIPTION"

echo
echo "Runtime model artifacts"
SRC_TOOLS_DIR="$TOOLS_DIR" RUNTIME_DIR="$RUNTIME_DIR" \
  "$ROOT_DIR/backend/prepare_tools_runtime.sh"
install_bridge_bundle

echo
echo "Molecular tool setup complete."
