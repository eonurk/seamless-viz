#!/usr/bin/env bash
# Download the public AML reference dataset from OSF into backend/data/AML.
# Files are verified against the SHA-256 hashes published by the OSF API.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AML_DIR="$ROOT_DIR/backend/data/AML"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to download the AML assets." >&2
  exit 1
fi

if ! command -v shasum >/dev/null 2>&1; then
  echo "shasum is required to verify the AML assets." >&2
  exit 1
fi

# path|OSF file GUID|sha256
ASSETS=$(cat <<'EOF'
meta.csv|crsf8|3ec6145452fff0a3b7f493f013540b524f57a62668282e3b17ef73aedbe7fae5
scores.csv|mp6zh|e55e441490ad9fc7eb2ab5ea051bd81c003bc6e2da9a6d824f37702388cb59c0
counts/uncorrected_counts.csv|rzq4n|6d832ec615897029ccbead1d7247e16a570bf33c3c6851f5af8d53c0db6ef9b2
counts/corrected_counts.csv|fkyn7|7c508a97fe24394b55dd70d4ab4f7cce17ecd1a25c7b1cb5e160150ec42a244f
counts/var_rank_genes_greater70blasts.csv|pqz9x|073a0416829e6d35d0714cb2ad3f8fcde58987b1c4b44825549e81f4ef49ae2d
aberrations/mutations.csv|hdwyk|51396aa1c552e225b7c092067741aa7d02ddd4b4fdb0a22aa74621496bb76b5a
aberrations/aberrations_oh.csv|cms8w|d5f52f4f67f8d3202f45b6e5c10af572d4df0c1983fbed74b656ae50585ecc0c
drug_response/drug_families.csv|2mx96|e91d21ca114ba4564d7575ef9bee6d8dac08b17a186d5bf2427d2f66ece15296
drug_response/ex_vivo_drug_response.csv|nwq35|dea6ee7e5e7794097d99625832509d3630a01a971274559d4cf84449a255f59f
EOF
)

verify() {
  local path="$1" expected="$2" actual
  [[ -f "$path" ]] || return 1
  actual="$(shasum -a 256 "$path" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]]
}

echo "AML reference data: https://osf.io/wq7gx/overview"

while IFS='|' read -r relative_path guid expected_hash; do
  target="$AML_DIR/$relative_path"
  if verify "$target" "$expected_hash"; then
    printf '  ok        %s\n' "$relative_path"
    continue
  fi

  mkdir -p "$(dirname "$target")"
  temporary="$target.part"
  rm -f "$temporary"
  printf '  download  %s\n' "$relative_path"
  curl --fail --location --retry 3 --output "$temporary" "https://osf.io/download/$guid/"

  if ! verify "$temporary" "$expected_hash"; then
    rm -f "$temporary"
    echo "Checksum verification failed for $relative_path" >&2
    exit 1
  fi

  mv "$temporary" "$target"
done <<< "$ASSETS"

echo "AML assets are present and verified."
