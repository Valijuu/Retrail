#!/usr/bin/env python3
"""Refuses raw SQL that is built from anything but fixed text.

Drift's `customSelect`, `customStatement`, `customUpdate`, `customInsert` and
`customWriteReturning` take SQL as their first argument. The SQL must be a
plain literal: no `$` interpolation, no `+` concatenation and no variable.
Values go in through the `variables:` argument as `Variable`s.

Exception, on the same line as the call:  // sql-ok: <reason>

Usage: tool/check_raw_sql.py [paths...]   (default: lib test integration_test)
Exit 0 when clean, 1 when a call is unsafe.
"""

import re
import sys
from pathlib import Path

CALL = re.compile(r"\bcustom(?:Select|Statement|Update|Insert|WriteReturning)\s*\(")
DEFAULT_ROOTS = ["lib", "test", "integration_test"]


def first_argument_problem(src: str, start: int) -> str | None:
    """Return a reason if the first argument at `start` is not a plain literal."""
    i = start
    n = len(src)
    while i < n and src[i].isspace():
        i += 1
    if i >= n:
        return "no SQL argument"
    if src[i] not in "'\"" and not src.startswith(("r'", 'r"'), i):
        return "SQL is not a string literal"
    while True:
        raw = src[i] == "r"
        if raw:
            i += 1
        quote = src[i]
        triple = src.startswith(quote * 3, i)
        delim = quote * 3 if triple else quote
        i += len(delim)
        while True:
            if i >= n:
                return "unterminated string"
            ch = src[i]
            if not raw and ch == "\\":
                i += 2
                continue
            if ch == "$" and not raw:
                # Dart `$name` or `${expr}` interpolation inside SQL text.
                if i + 1 < n and (src[i + 1] == "{" or src[i + 1].isalpha() or src[i + 1] == "_"):
                    return "string interpolation ($) in SQL"
            if src.startswith(delim, i):
                i += len(delim)
                break
            i += 1
        # Adjacent literals concatenate implicitly and are fine; `+` is not.
        j = i
        while j < n and src[j].isspace():
            j += 1
        if j < n and src[j] == "+":
            return "SQL built with +"
        if j < n and (src[j] in "'\"" or src.startswith("r'", j) or src.startswith('r"', j)):
            i = j
            continue
        return None


def scan(path: Path) -> list[str]:
    src = path.read_text(encoding="utf-8")
    problems = []
    for m in CALL.finditer(src):
        line_no = src.count("\n", 0, m.start()) + 1
        line = src.splitlines()[line_no - 1]
        if "sql-ok:" in line:
            continue
        reason = first_argument_problem(src, m.end())
        if reason:
            problems.append(f"{path}:{line_no}: {reason}: {line.strip()}")
    return problems


def main(argv: list[str]) -> int:
    roots = [Path(p) for p in argv] or [Path(p) for p in DEFAULT_ROOTS]
    files = []
    for root in roots:
        if root.is_file():
            files.append(root)
        elif root.is_dir():
            files.extend(sorted(root.rglob("*.dart")))
    problems = []
    for f in files:
        if f.name.endswith((".g.dart", ".drift.dart", ".freezed.dart")):
            continue
        problems.extend(scan(f))
    for p in problems:
        print(p, file=sys.stderr)
    if problems:
        print(
            "check_raw_sql: use a fixed SQL literal with Variable arguments "
            "(or add `// sql-ok: <reason>` on the call line).",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
