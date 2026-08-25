#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_TOOLS_DIR="${SRC_TOOLS_DIR:-$ROOT_DIR/tools}"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT_DIR/tools_runtime}"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

need() {
  [[ -e "$1" ]] || { echo "Missing: $1" >&2; exit 1; }
}

copy_optional_file() {
  local src="$1"
  local dst_dir="$2"
  local dst="$dst_dir/$(basename "$src")"
  mkdir -p "$dst_dir"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$dst_dir/"
    return 0
  fi
  if [[ -f "$dst" ]]; then
    log "Source missing, keeping existing runtime file: $dst"
    return 0
  fi
  log "Optional runtime file not supplied: $dst"
  return 0
}

sync_or_keep_existing_dir() {
  local src_dir="$1"
  local dst_dir="$2"
  if [[ -d "$src_dir" ]]; then
    mkdir -p "$dst_dir"
    cp -R "$src_dir/." "$dst_dir/"
    return 0
  fi
  if [[ -d "$dst_dir" ]] && [[ -n "$(find "$dst_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    log "Source missing, keeping existing runtime directory: $dst_dir"
    return 0
  fi
  echo "Missing: $src_dir (and no existing runtime contents at $dst_dir)" >&2
  exit 1
}

log "Preparing runtime tool artifacts in $RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR/Bridge" "$RUNTIME_DIR/ALLSorts/models" "$RUNTIME_DIR/TALLSorts/models"

# Bridge bundle (official bundle-first path)
copy_optional_file \
  "$SRC_TOOLS_DIR/Bridge/bridge_inference_with_gtex1252_plus_srp03245568_healthy_balanced.bundle" \
  "$RUNTIME_DIR/Bridge"

# ALLSorts model artifacts
sync_or_keep_existing_dir \
  "$SRC_TOOLS_DIR/ALLSorts/ALLSorts/models/allsorts" \
  "$RUNTIME_DIR/ALLSorts/models/allsorts"

# TALLSorts model artifacts
sync_or_keep_existing_dir \
  "$SRC_TOOLS_DIR/TALLSorts/TALLSorts/models/tallsorts" \
  "$RUNTIME_DIR/TALLSorts/models/tallsorts"

log "Done. Runtime artifacts:"
du -sh \
  "$RUNTIME_DIR/Bridge" \
  "$RUNTIME_DIR/ALLSorts/models/allsorts" \
  "$RUNTIME_DIR/TALLSorts/models/tallsorts"
