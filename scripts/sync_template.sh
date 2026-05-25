#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Mirror byte-identical support files from the repo root into template/, then
# run the Copier round-trip check. Files that contain templated [[[ ... ]]]
# placeholders (i.e. the *.jinja files) are NOT synced here -- those require
# manual editing because the substitutions can't be reliably reverse-derived.
#
# Workflow: edit something at the repo root (e.g. a workflow file), run
# `make sync-template`, and check_copier.sh will tell you whether any jinja
# files still need a hand-edit.

set -euo pipefail

script_dir=$(realpath "$(dirname "$0")")
repo_root=$(realpath "$script_dir/..")
cd "$repo_root"

# Paths to mirror. Trailing slash => recursive directory sync (with --delete,
# so template-side extras are removed). No trailing slash => single file copy.
# Do NOT add jinja-templated paths here, and do NOT use whole-directory sync
# for any directory that contains *.jinja files -- --delete would eat them.
# Pick those files out one by one instead (e.g. installtest/README.md).
SYNC_PATHS=(
  ".bake.toml"
  ".clang-format"
  ".codespell_ignore"
  ".dockerignore"
  ".git-blame-ignore-revs"
  ".gitignore"
  ".markdownlint.yaml"
  ".pre-commit-config.yaml"
  ".python-version"
  ".emacs.d/"
  ".github/CODEOWNERS"
  ".github/dependabot.yml"
  ".github/workflows/"
  "CMakePresets.json"
  "LICENSE"
  "cmake/"
  "docs/doxygen-awesome-darkmode-toggle.js"
  "docs/doxygen-awesome.css"
  "docs/header.html"
  "docs/mrdocs.yml"
  "etc/"
  "infra/"
  "installtest/README.md"
  "lockfile.json"
  "papers/"
  "pyproject.toml"
  "scripts/"
  "src/CMakeLists.txt"
  "vcpkg-configuration.json"
  "vcpkg.json"
)

# Filenames that must never land in template/ even when they sit under a
# synced directory. These belong to the canonical repo only -- rendered
# projects don't need them.
#   copier_test.yml: the round-trip CI workflow
#   sync_template.sh: this script itself
RSYNC_EXCLUDES=(
  "--exclude=copier_test.yml"
  "--exclude=sync_template.sh"
)

echo "Syncing repo paths into template/ ..."
for path in "${SYNC_PATHS[@]}"; do
  src="$repo_root/$path"
  dst="$repo_root/template/$path"
  if [[ "$path" == */ ]]; then
    mkdir -p "$dst"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$src" "$dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
  fi
done

echo
echo "Running Copier round-trip check ..."
bash "$repo_root/copier/check_copier.sh"
