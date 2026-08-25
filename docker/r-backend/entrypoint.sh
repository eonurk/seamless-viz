#!/usr/bin/env bash
# Runtime preflight for the seAMLess compute backend.
#
# Reference data and molecular tool artifacts are bind-mounted rather than baked
# into the image, so we validate them here and fail fast with an actionable
# message instead of letting an endpoint 500 later.
set -euo pipefail

BACKEND_DIR="${SEAMLESS_BACKEND_DIR:-/app/backend}"
RLIBS="${R_LIBS_USER:-/opt/rlibs}"

log()  { printf '[preflight] %s\n' "$*"; }
warn() { printf '[preflight] WARNING: %s\n' "$*" >&2; }
die()  { printf '[preflight] ERROR: %s\n' "$*" >&2; exit 1; }

mkdir -p "$RLIBS" "$BACKEND_DIR/cache" "${SEAMLESS_UPLOADS_DIR:-/shared/uploads}"

# --- hard requirements -----------------------------------------------------
[[ -f "$BACKEND_DIR/plumber.R" ]] || die \
  "$BACKEND_DIR/plumber.R not found. The repo is not mounted -- check the
             r-backend volumes in docker-compose.yml."

if [[ ! -d "$BACKEND_DIR/data" ]] || [[ -z "$(ls -A "$BACKEND_DIR/data" 2>/dev/null)" ]]; then
  die "$BACKEND_DIR/data is missing or empty.
             Run ./scripts/check-assets.sh on the host before starting Docker
             (see docs/DOCKER.md#reference-data)."
fi

log "reference data present:$(cd "$BACKEND_DIR/data" && printf ' %s' */ 2>/dev/null || echo ' (none)')"

# --- optional molecular tools ----------------------------------------------
# Each tool degrades independently: /molecular-tools reports availability and
# the matching endpoint returns a descriptive error when artifacts are absent.
check_optional() {
  local label="$1" path="$2"
  if [[ -e "$path" ]]; then
    log "$label: ok"
    return 0
  fi
  warn "$label unavailable (missing $path)"
  return 1
}

check_optional "AMLmapR"  "$BACKEND_DIR/tools/AMLmapR/R/functions.R"           || true
check_optional "ALLSorts" "$BACKEND_DIR/tools_runtime/ALLSorts/models/allsorts/allsorts.pkl.gz" || true
check_optional "TALLSorts" "$BACKEND_DIR/tools_runtime/TALLSorts/models/tallsorts/tallsorts_default_model.pkl.gz" || true
check_optional "Bridge bundle" \
  "$BACKEND_DIR/tools_runtime/Bridge/bridge_inference_with_gtex1252_plus_srp03245568_healthy_balanced.bundle" || true

if [[ -x "${BRIDGE_PYTHON:-}" ]]; then
  log "Bridge python: ${BRIDGE_PYTHON}"
else
  warn "Bridge python env absent (image built with WITH_BRIDGE=0); /bridge-predict will report unavailable"
fi

# --- ALLCatchRbcrabl1 -------------------------------------------------------
# Ships as R source inside the bind-mounted tools/ tree, so it cannot be built
# at image-build time. Install once into the persistent R library volume.
ALLCATCHR_SRC="$BACKEND_DIR/tools/ALLCatchR_bcrabl1"
if [[ -d "$ALLCATCHR_SRC" ]]; then
  if micromamba run -n base Rscript -e \
       'quit(status = as.integer(!requireNamespace("ALLCatchRbcrabl1", quietly = TRUE)))' 2>/dev/null; then
    log "ALLCatchRbcrabl1: ok"
  else
    log "ALLCatchRbcrabl1: building from $ALLCATCHR_SRC (first run only, ~1 min)"
    if micromamba run -n base R CMD INSTALL --library="$RLIBS" "$ALLCATCHR_SRC"; then
      log "ALLCatchRbcrabl1: installed into $RLIBS"
    else
      warn "ALLCatchRbcrabl1 install failed; /allcatchr-predict will be unavailable"
    fi
  fi
else
  warn "ALLCatchRbcrabl1 source not mounted; /allcatchr-predict will be unavailable"
fi

log "starting plumber on ${R_BACKEND_HOST:-0.0.0.0}:${R_BACKEND_PORT:-5555}"
exec "$@"
