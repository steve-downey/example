#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Run the Copier round-trip consistency check.
# Delegates to copier/check_copier.sh from the repo root.

set -euo pipefail

script_dir=$(realpath "$(dirname "$0")")
repo_root=$(realpath "$script_dir/..")

exec bash "$repo_root/copier/check_copier.sh" "$@"
