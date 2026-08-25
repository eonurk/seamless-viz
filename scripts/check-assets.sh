#!/usr/bin/env bash
# Downloads missing public AML data from OSF, then reports whether the
# bind-mounted reference data and molecular tool artifacts are in place.
# Run on the HOST before `docker compose up`.
#
#   ./scripts/check-assets.sh
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT_DIR/backend"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
amber() { printf '\033[33m%s\033[0m\n' "$*"; }

if ! "$ROOT_DIR/scripts/download-aml-assets.sh"; then
  red "AML download or verification failed. Check the network connection and retry."
  exit 1
fi

if ! "$ROOT_DIR/scripts/install-molecular-tools.sh"; then
  red "Molecular tool setup failed. Check the error above and retry."
  exit 1
fi

required_missing=0
optional_missing=0

check() {
  local kind="$1" label="$2" path="$3"
  if [[ -e "$BACKEND/$path" ]]; then
    green "  ok        $label"
  elif [[ "$kind" == required ]]; then
    red   "  MISSING   $label  ($path)"
    required_missing=$((required_missing + 1))
  else
    amber "  optional  $label  ($path)"
    optional_missing=$((optional_missing + 1))
  fi
}

echo
echo "AML reference data (required)"
check required "AML metadata"            "data/AML/meta.csv"
check required "AML raw counts"          "data/AML/counts/uncorrected_counts.csv"
check required "AML batch-corrected counts" "data/AML/counts/corrected_counts.csv"
check required "AML gene positions"      "data/AML/gene_positions_hg38.csv"
check required "AML drug response"       "data/AML/drug_response/ex_vivo_drug_response.csv"
check required "AML aberrations"         "data/AML/aberrations/aberrations_oh.csv"

echo
echo "Additional disease data (optional)"
check optional "B-ALL training matrix"   "data/B-ALL/training_rna_raw_full_ensembl_b_all_direct_plus_derived.parquet"
check optional "T-ALL training matrix"   "data/T-ALL/training_rna_raw_full_ensembl_t_all_direct_plus_derived.parquet"

echo
echo "Molecular tools (public tools installed automatically; Bridge optional)"
check optional "AMLmapR source"     "tools/AMLmapR/R/functions.R"
check optional "ALLCatchR source"   "tools/ALLCatchR_bcrabl1/DESCRIPTION"
check optional "ALLSorts source"    "tools/ALLSorts/ALLSorts"
check optional "ALLSorts model"     "tools_runtime/ALLSorts/models/allsorts/allsorts.pkl.gz"
check optional "TALLSorts source"   "tools/TALLSorts/TALLSorts"
check optional "TALLSorts model"    "tools_runtime/TALLSorts/models/tallsorts/tallsorts_default_model.pkl.gz"
check optional "Bridge bundle"      "tools_runtime/Bridge/bridge_inference_with_gtex1252_plus_srp03245568_healthy_balanced.bundle"

echo
echo "Precomputed caches (optional -- regenerated on demand, slowly)"
check optional "reference cache" "cache/.reference"

echo
if (( required_missing > 0 )); then
  red "$required_missing required asset(s) missing."
  echo "Re-run ./scripts/download-aml-assets.sh, then check the files above."
  exit 1
fi

if (( optional_missing > 0 )); then
  amber "All required assets present; $optional_missing optional artifact(s) missing."
  echo "The dashboard will run. Endpoints for the missing tools report themselves"
  echo "as unavailable via GET /molecular-tools."
else
  green "All assets present."
fi

# tools_runtime is derived from tools/ -- remind the reader if it looks stale.
if [[ -d "$BACKEND/tools" && ! -e "$BACKEND/tools_runtime/ALLSorts/models/allsorts/allsorts.pkl.gz" ]]; then
  echo
  echo "Hint: run ./backend/prepare_tools_runtime.sh to populate tools_runtime/ from tools/."
fi
