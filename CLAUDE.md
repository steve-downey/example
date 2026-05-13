# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Dual purpose of this repo

This repository is *both* a working C++ project *and* a Copier template for bootstrapping new projects from the same layout.

- The repository itself lives at the top level (`src/`, `CMakeLists.txt`, `Makefile`, `infra/`, `etc/`, etc.).
- The Copier template lives under `template/` and is configured by `copier.yml` at the root.
- The script `copier/check_copier.sh` enforces that rendering the template with default answers produces a tree byte-for-byte identical to the repo root (excluding a small set of paths), and that a randomized render contains no example-specific names. **When you change something in the repo root that has a `template/` counterpart, change both.** Otherwise `check_copier.sh` and the `copier_test.yml` GitHub Action will fail.
- Copier uses non-default delimiters (see `_envops` in `copier.yml`): `[[[ var ]]]` for variables, `[% %]` for blocks, `[# #]` for comments. Template files use the `.jinja` suffix.

## Build and test workflow

Everything is driven by the top-level `Makefile`. Default target is `test`, which configures, builds, and runs ctest.

- `make` — configure, build, run all tests in the default sanitizer config (`Asan`)
- `make compile` — build only
- `make test` / `make ctest` — run the test suite (ctest discovers GoogleTest cases)
- `make lint` — run all pre-commit hooks (clang-format, gersemi for CMake, markdownlint, codespell, shellcheck, gitleaks, checkmake, mbake-validate)
- `make lint-manual` — pre-commit hooks gated behind the `manual` stage
- `make coverage` / `make view-coverage` — gcov-based coverage build + HTML report
- `make install` then `make testinstall` — install to `./.install/` and verify the installed package builds via `installtest/`
- `make presentation` — build, test, then export `*.org` files to HTML / reveal slides via Emacs + org-transclusion
- `make help` — list documented targets

### Compilers and configs

Compilers are expected on `PATH` with versioned names (`g++-15`, `clang++-21`, etc.). Pick one via `TOOLCHAIN=`:

- `make TOOLCHAIN=gcc-15` — uses `etc/gcc-15-toolchain.cmake`
- `make TOOLCHAIN=clang-21 CONFIG=RelWithDebInfo` — toolchain + non-default CMake config

`CONFIG` is one of `RelWithDebInfo`, `Debug`, `Tsan`, `Asan` (default), `Gcov`. The generator is `Ninja Multi-Config`, so all configs coexist in one build tree at `.build/build-<toolchain>/` (or `.build/build-system/` when `TOOLCHAIN` is unset).

### Running a single test

`gtest_discover_tests` registers each GoogleTest case with ctest. To run one:

```shell
make compile                                    # ensure binary is current
.venv/bin/ctest --test-dir .build/build-system \
    -C Asan -R <TestName> --output-on-failure
```

Or filter at the binary level: `.build/build-system/src/smd/example/Asan/name_test --gtest_filter=Foo.Bar`.

### Python tooling

All Python tooling (cmake, ninja, pre-commit, gcovr, mbake, clang-format, copier) is pulled in via `uv` into a local `.venv`. The Makefile prepends `uv run` to invocations, so you generally don't need to activate the venv manually. `make dev-shell` (or `make bash` / `make zsh`) drops you into a shell with the venv active. If `uv` itself is missing, `make install-uv` runs `pipx install uv`.

## Code layout

C++ source lives entirely under `src/` using a merged Pitchfork layout — headers, sources, and tests live together by component rather than in separate `include/` / `tests/` trees. Install rules expose `src/` as the include root, so `#include <smd/example/name.hpp>` resolves to `src/smd/example/name.hpp` both in-tree and post-install.

- `src/smd/example/` — the sample library `example.name` (header `name.hpp`, impl `name.cpp`, test `name.test.cpp`)
- `src/examples/` — a `hello` executable that links the library
- `installtest/` — a separate CMake project consumed by `make testinstall` to verify the installed package via `find_package`

## CMake structure

CMake is "post-modern": target-oriented *and* file-set-oriented. The library exposes its headers as a named `FILE_SET` (`example_name_headers`) so `CMAKE_VERIFY_INTERFACE_HEADER_SETS` and the standard install rules can use it directly.

Two dependency-resolution paths exist for GoogleTest, controlled by `CMAKE_PROJECT_TOP_LEVEL_INCLUDES`:

- **FetchContent** (default in the Makefile and CMake presets): `infra/cmake/use-fetch-content.cmake`. The Makefile passes `-DBEMANINFRA_googletest_REPO=file:///home/sdowney/bld/googletest/googletest.git` — change or remove this if you don't have a local clone.
- **vcpkg**: if `vcpkg` is on `PATH`, the Makefile switches to the vcpkg toolchain and uses the overlay triplet `x64-linux-custom` from `./cmake/`.

`infra/` is vendored from the [Beman infra project](https://github.com/bemanproject/infra) via `git subtree`. The `beman_install_library` helper handles install + export-set boilerplate. `CMakePresets.json` mainly exists to support Beman CI tooling — the Makefile is the primary developer interface.

## CI / linting expectations

- **pre-commit** is the source of truth for lint. Run `make lint` before pushing. CI runs the same hooks via `pre-commit-check.yml`.
- **`copier_test.yml`** runs `copier/check_copier.sh` — keep `template/` in sync with the repo root, or this fails.
- **`test_makefile.yaml`** and **`ci_tests.yml`** exercise the Makefile across compilers/configs and the Beman CI flow respectively.
- Sanitizer-clean by default: the default `Asan` build runs ASan + compatible sanitizers in tests. Don't introduce sanitizer regressions without switching CONFIG explicitly.

## Conventions worth knowing

- The pair of matching UUID comments around code blocks (e.g. `// 44cc988c-...` … `// 44cc988c-... end` in `name.hpp` / `name.cpp`) are anchors for `org-transclusion` in the presentation export — don't delete them.
- License header on source files: `// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception`.
- `clang-format` and `gersemi` (CMake) are enforced — let the tools format; don't fight them.
