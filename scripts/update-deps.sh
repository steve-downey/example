#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Bump dependency versions locally — pre-commit hooks, Python packages,
# GitHub Actions pins — then sync non-jinja files into template/.
# Finishes by running Renovate in local/discovery mode to report any
# remaining outdated deps (including those in template/*.jinja files).

set -euo pipefail

script_dir=$(realpath "$(dirname "$0")")
repo_root=$(realpath "$script_dir/..")
cd "$repo_root"

section() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

section "Updating pre-commit hooks (root)"
uv run pre-commit autoupdate || echo "  (some hooks could not be checked — see above)"

section "Updating pre-commit hooks (template)"
uv run pre-commit autoupdate --config template/.pre-commit-config.yaml || echo "  (some hooks could not be checked — see above)"

section "Upgrading Python dependencies"
uv lock --upgrade
uv sync

section "Syncing non-jinja files into template/"
bash scripts/sync_template.sh

section "Running Renovate local discovery"
if command -v npx >/dev/null 2>&1; then
    LOG_LEVEL="${RENOVATE_LOG_LEVEL:-info}" \
    npx --yes renovate --platform=local 2>&1 \
        | grep -E '(INFO|WARN|packageFiles|updates)' || true
    echo "  (Renovate local mode is discovery-only — see above for outdated deps)"
else
    echo "  npx not found; skipping Renovate discovery. Install Node.js for full coverage."
fi
