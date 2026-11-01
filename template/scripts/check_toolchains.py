#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
"""Check that every toolchain file supports every documented build config.

The Makefile documents the configurations it builds (``_configuration_types``,
or a ``CONFIGS`` list).  CMake does not complain when a configuration has no
flags: ``make TOOLCHAIN=x CONFIG=Gcov coverage`` on a toolchain that never set
``CMAKE_CXX_FLAGS_GCOV`` configures and builds happily, without coverage.

This script reads each toolchain file statically, following its ``include()``
lines so shared flags files count, and reports

  error  a documented config with no CMAKE_CXX_FLAGS_<CONFIG> in the toolchain
  error  no CMAKE_CXX_COMPILER set
  error  a set() of a CMAKE_*FLAGS* name CMake does not define
         (CMAKE_LINKER_FLAGS_GCOV is not CMAKE_EXE_LINKER_FLAGS_GCOV)
  note   flags defined for configs the Makefile does not build

A toolchain that genuinely cannot build a config opts out with a comment:

    # unsupported-configs: Gcov Tsan

Diagnostics are ``file:line: severity: message`` so compilation-mode can jump
to them.  Exits 1 when there is any error.  Standard library only.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

# CMake's own flag variables.  Anything else named CMAKE_*FLAGS* is a typo
# CMake would silently ignore.
VALID_FLAGS_VAR = re.compile(
    r"""^CMAKE_(?:
          (?:C|CXX|CUDA|Fortran|HIP|ISPC|OBJC|OBJCXX|RC|Swift|ASM(?:_[A-Z]+)?)
              _(?:FLAGS|LINK_FLAGS)(?:_[A-Z0-9]+)?(?:_INIT)?
        | (?:EXE|SHARED|MODULE|STATIC)_LINKER_FLAGS(?:_[A-Z0-9]+)?(?:_INIT)?
        | REQUIRED_FLAGS
        )$""",
    re.X,
)
LOOKS_LIKE_FLAGS_VAR = re.compile(r"^CMAKE_.*FLAGS")
CXX_CONFIG_FLAGS = re.compile(r"^CMAKE_CXX_FLAGS_([A-Z0-9]+)$")
UNSUPPORTED_COMMENT = re.compile(r"^\s*#\s*unsupported-configs:\s*(.*?)\s*$", re.M)

# Configs CMake knows out of the box; flags for them are never a mistake.
STANDARD_CONFIGS = {"DEBUG", "RELEASE", "RELWITHDEBINFO", "MINSIZEREL"}


# --- a minimal CMake reader -------------------------------------------------


def parse_args(text: str, i: int, line: int):
    """Read the arguments of a command from TEXT[I:] up to the closing paren.

    Return (args, index after the paren, line).  Quoted arguments come back
    without their quotes, with backslash-newline continuations removed.
    """
    args: list[str] = []
    cur: str | None = None
    depth = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            buf: list[str] = []
            while i < n and text[i] != '"':
                if text[i] == "\\" and i + 1 < n:
                    if text[i + 1] == "\n":
                        line += 1
                    else:
                        buf.append(text[i : i + 2])
                    i += 2
                    continue
                if text[i] == "\n":
                    line += 1
                buf.append(text[i])
                i += 1
            args.append("".join(buf))
            i += 1
        elif c == "#":
            while i < n and text[i] != "\n":
                i += 1
        elif c in " \t\n":
            if c == "\n":
                line += 1
            if cur is not None:
                args.append(cur)
                cur = None
            i += 1
        elif c == "(":
            depth += 1
            cur = (cur or "") + c
            i += 1
        elif c == ")":
            if depth == 0:
                if cur is not None:
                    args.append(cur)
                return args, i + 1, line
            depth -= 1
            cur = (cur or "") + c
            i += 1
        else:
            cur = (cur or "") + c
            i += 1
    return args, i, line


def parse_commands(text: str):
    """Yield (line, command name in lower case, args) for each command in TEXT."""
    i, n, line = 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
        elif c == "#":
            while i < n and text[i] != "\n":
                i += 1
        elif c.isalpha() or c == "_":
            j = i
            while j < n and (text[j].isalnum() or text[j] == "_"):
                j += 1
            name = text[i:j].lower()
            k = j
            while k < n and text[k] in " \t":
                k += 1
            if k < n and text[k] == "(":
                start = line
                args, i, line = parse_args(text, k + 1, line)
                yield start, name, args
            else:
                i = j
        else:
            i += 1


# --- the check -------------------------------------------------------------


class Report:
    def __init__(self, root: str):
        self.root = root
        self.errors = 0
        self.seen: set[tuple] = set()

    def _emit(self, path: str, line: int, severity: str, message: str):
        key = (path, line, message)
        if key in self.seen:  # a shared flags file is reached from many toolchains
            return
        self.seen.add(key)
        if severity == "error":
            self.errors += 1
        print(f"{os.path.relpath(path, self.root)}:{line}: {severity}: {message}")

    def error(self, path, line, message):
        self._emit(path, line, "error", message)

    def warning(self, path, line, message):
        self._emit(path, line, "warning", message)


def read_commands(path: str, report: Report, stack: tuple[str, ...] = ()):
    """Commands of PATH and, in place, of the files it include()s.

    Yields (file, line, name, args).  Includes are resolved only through
    ${CMAKE_CURRENT_LIST_DIR}; a path that still needs other variables is
    reported and skipped.
    """
    if path in stack:
        report.error(path, 1, "include cycle: " + " -> ".join(stack + (path,)))
        return
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        report.error(stack[-1] if stack else path, 1, f"cannot read {path}: {e}")
        return
    here = os.path.dirname(os.path.abspath(path))
    for line, name, args in parse_commands(text):
        if name == "include" and args:
            target = args[0].replace("${CMAKE_CURRENT_LIST_DIR}", here)
            if "${" in target or "$ENV{" in target:
                report.warning(path, line, f"include not followed: {args[0]}")
                continue
            target = os.path.normpath(os.path.join(here, target))
            if not os.path.isfile(target):
                report.error(path, line, f"included file not found: {args[0]}")
                continue
            yield from read_commands(target, report, stack + (path,))
        else:
            yield path, line, name, args


def documented_configs(makefile: str) -> list[str]:
    """The configs the Makefile builds, in its order."""
    with open(makefile, encoding="utf-8") as f:
        text = f.read()
    m = re.search(r"^CONFIGS\s*:?=\s*(.+?)\s*$", text, re.M)
    if m:
        return m.group(1).split()
    m = re.search(r'^_configuration_types\s*\?=\s*"([^"]*)"', text, re.M)
    if m:
        return [c for c in m.group(1).split(";") if c]
    sys.exit(f"{makefile}: neither CONFIGS nor _configuration_types found")


def toolchain_files(toolchain_dir: str) -> list[str]:
    files = glob.glob(os.path.join(toolchain_dir, "toolchain.cmake"))
    files += glob.glob(os.path.join(toolchain_dir, "*-toolchain.cmake"))
    return sorted(set(files))


def check_toolchain(path: str, configs: list[str], report: Report) -> set[str]:
    """Check one toolchain file.  Return the configs it defines CXX flags for."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    unsupported: dict[str, int] = {}
    for m in UNSUPPORTED_COMMENT.finditer(text):
        for c in m.group(1).split():
            unsupported[c.upper()] = text.count("\n", 0, m.start()) + 1

    defined: dict[str, tuple[str, int]] = {}
    has_compiler = False
    for file, line, name, args in read_commands(path, report):
        if name != "set" or not args:
            continue
        var = args[0]
        if var == "CMAKE_CXX_COMPILER":
            has_compiler = True
        if LOOKS_LIKE_FLAGS_VAR.match(var) and not VALID_FLAGS_VAR.match(var):
            report.error(file, line, f"{var} is not a CMake variable; it is ignored")
        m = CXX_CONFIG_FLAGS.match(var)
        if m and m.group(1) != "INIT":
            defined.setdefault(m.group(1), (file, line))

    if not has_compiler:
        report.error(path, 1, "does not set CMAKE_CXX_COMPILER")

    wanted = {c.upper(): c for c in configs}
    for upper, shown in wanted.items():
        if upper in defined:
            if upper in unsupported:
                report.warning(
                    path,
                    unsupported[upper],
                    f"{shown} is listed as unsupported but CMAKE_CXX_FLAGS_{upper} is set",
                )
        elif upper not in unsupported:
            report.error(
                path,
                1,
                f"no CMAKE_CXX_FLAGS_{upper}: config {shown} would build with no flags",
            )
    for upper, line in unsupported.items():
        if upper not in wanted:
            report.warning(path, line, f"unsupported-configs names an undocumented config: {upper}")
    return set(defined)


def main(argv: list[str] | None = None) -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", default=os.path.dirname(here), help="project root (default: parent of this script)")
    parser.add_argument("--makefile", default="Makefile", help="Makefile naming the configs, relative to --root")
    parser.add_argument("--toolchain-dir", default="etc", help="directory of the toolchain files, relative to --root")
    parser.add_argument("--configs", help="comma or space separated configs, instead of reading the Makefile")
    args = parser.parse_args(argv)

    root = os.path.abspath(args.root)
    if args.configs:
        configs = [c for c in re.split(r"[,\s]+", args.configs) if c]
    else:
        configs = documented_configs(os.path.join(root, args.makefile))
    files = toolchain_files(os.path.join(root, args.toolchain_dir))
    if not files:
        print(f"no toolchain files under {args.toolchain_dir}/", file=sys.stderr)
        return 1

    report = Report(root)
    extra: dict[str, list[str]] = {}
    for path in files:
        for c in check_toolchain(path, configs, report) - {c.upper() for c in configs}:
            extra.setdefault(c, []).append(os.path.basename(path))

    for c, where in sorted(extra.items()):
        if c not in STANDARD_CONFIGS:
            print(f"note: CMAKE_CXX_FLAGS_{c} is set but no documented config uses it ({len(where)} toolchains)")
    status = "FAILED" if report.errors else "OK"
    print(f"checked {len(files)} toolchains against configs {' '.join(configs)}: {status}")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
