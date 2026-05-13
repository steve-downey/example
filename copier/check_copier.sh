#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

set -euo pipefail

script_dir=$(realpath "$(dirname "$0")")
repo_root=$(realpath "$script_dir/..")

cleanup() {
    if [[ -n "${work_dir:-}" && -d "$work_dir" ]]; then
        rm -rf "$work_dir"
    fi
}

generate_project() {
    local destination="$1"
    shift
    uv run copier copy --trust --defaults "$@" "$template_source" "$destination" >/dev/null
}

check_consistency() {
    local output_dir="$work_dir/default"
    mkdir -p "$output_dir"
    generate_project "$output_dir"

    local diff_path="$work_dir/default.diff"
    diff -r \
        --exclude .git \
        --exclude build \
        --exclude .venv \
        --exclude template \
        --exclude copier \
        --exclude copier.yml \
        --exclude .copier-answers.yml \
        --exclude copier_test.yml \
        --exclude example.html \
        --exclude example.md \
        --exclude uv.lock \
        --exclude .build \
        --exclude .claude \
        --exclude CLAUDE.md \
        --exclude compile_commands.json \
        --exclude .update-submodules \
        "$repo_root" "$output_dir" >"$diff_path" || true

    if [[ -s "$diff_path" ]]; then
        echo "Discrepancy between repo and Copier output:" >&2
        cat "$diff_path" >&2
        exit 1
    fi
}

check_templating() {
    local output_dir="$work_dir/randomized"
    mkdir -p "$output_dir"
    generate_project \
        "$output_dir" \
        -d project_slug=oddity \
        -d project_title="Oddity C++ Sample" \
        -d library_name=label \
        -d include_prefix=acme \
        -d namespace=widget \
        -d maintainer_name="Taylor Example" \
        -d maintainer_email=taylor@example.invalid \
        -d sample_value=Taylor

    local grep_path="$work_dir/randomized.grep"
    grep -RIn \
        -e 'Example C\+\+ Full Stack Project' \
        -e 'example\.name' \
        -e 'smd/example/name' \
        -e 'example::name' \
        -e 'Steve Downey' \
        -e 'sdowney@gmail.com' \
        -e '"Steve"' \
        "$output_dir" >"$grep_path" || true

    if [[ -s "$grep_path" ]]; then
        echo 'Unrendered example-specific content found in randomized Copier output:' >&2
        cat "$grep_path" >&2
        exit 1
    fi
}

main() {
    work_dir=$(mktemp -d)
    trap cleanup EXIT
    template_source="$work_dir/template-source"
    rsync -a \
        --exclude .git \
        --exclude .git/ \
        --exclude .venv/ \
        --exclude build/ \
        "$repo_root/" "$template_source/"
    check_consistency
    check_templating
}

main "$@"
