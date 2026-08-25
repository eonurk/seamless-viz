#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ENV_PREFIX="/opt/homebrew/Cellar/micromamba/2.1.0/envs/seamless_env"
ALT_ENV_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/micromamba}/envs/seamless_env"

ENV_PREFIX="${SEAMLESS_ENV_PREFIX:-$DEFAULT_ENV_PREFIX}"
if [[ ! -x "$ENV_PREFIX/bin/Rscript" && -x "$ALT_ENV_PREFIX/bin/Rscript" ]]; then
	ENV_PREFIX="$ALT_ENV_PREFIX"
fi

if [[ ! -x "$ENV_PREFIX/bin/Rscript" ]]; then
	echo "Could not find Rscript in env prefix: $ENV_PREFIX" >&2
	echo "Set SEAMLESS_ENV_PREFIX to your micromamba env path." >&2
	exit 1
fi

export PATH="$ENV_PREFIX/bin:$PATH"
if [[ -x "$ENV_PREFIX/bin/python" ]]; then
	export MOLECULAR_TOOLS_PYTHON="${MOLECULAR_TOOLS_PYTHON:-$ENV_PREFIX/bin/python}"
elif [[ -x "$ENV_PREFIX/bin/python3" ]]; then
	export MOLECULAR_TOOLS_PYTHON="${MOLECULAR_TOOLS_PYTHON:-$ENV_PREFIX/bin/python3}"
fi

export R_ENV="${R_ENV:-production}"
export R_PROFILE_USER="${R_PROFILE_USER:-$HOME/.Rprofile}"

cd "$SCRIPT_DIR"
exec "$ENV_PREFIX/bin/Rscript" backend.R
