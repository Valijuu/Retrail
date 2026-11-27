#!/usr/bin/env python3
"""Lists the largest Dart classes by lines of code (lib.sdd, class size rule).

    python3 tool/class_sizes.py [--root lib] [--top 15] [--warn 300] [--review 400] [--limit 500]

Generated files (*.g.dart, *.freezed.dart, app_localizations*.dart) are skipped.

Counts code lines per class: blank lines and comment-only lines are not counted,
and a class is measured from its declaration to its closing brace. Output is
advisory: the script exits 0 unless --fail-above is given and a class exceeds it.

Limits: a small lexer (strings, raw strings, // and /* */ comments). It does not
parse Dart fully, so exotic syntax can miscount by a few lines; the numbers are
for review, not for proof.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

CLASS_RE = re.compile(r"^\s*(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*(?:class|mixin|enum)\s+(\w+)")


def code_lines_and_classes(text: str, decl: dict):
    """Yields (name, start_line, end_line, code_lines) for each top-level or nested class."""
    lines = text.split("\n")
    # Per-line flag: does the line hold code (not blank, not comment only)?
    has_code = [False] * len(lines)
    depth_at_start = [0] * len(lines)
    pending_class = None
    if 0 in decl:
        pending_class = (decl[0], 0)
    in_block_comment = False
    depth = 0
    i = 0
    n = len(text)
    line_no = 0
    # Walk characters, tracking braces (outside strings/comments) and code presence.
    results = []
    stack = []  # (name, start_line, depth_after_open)
    raw_line_start = 0
    line_idx = 0
    while i < n:
        c = text[i]
        if c == "\n":
            line_idx += 1
            i += 1
            depth_at_start[min(line_idx, len(lines) - 1)] = depth
            if line_idx in decl and pending_class is None:
                pending_class = (decl[line_idx], line_idx)
            continue
        if in_block_comment:
            if text.startswith("*/", i):
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j == -1 else j
            continue
        if text.startswith("/*", i):
            in_block_comment = True
            i += 2
            continue
        if c in "\"'":
            quote = c
            triple = text.startswith(quote * 3, i)
            q = quote * 3 if triple else quote
            # raw string prefix r before the quote: treat escapes as literal
            raw = i > 0 and text[i - 1] == "r" and (i < 2 or not text[i - 2].isalnum())
            if has_code[line_idx] is False:
                has_code[line_idx] = True
            i += len(q)
            while i < n:
                if not raw and text[i] == "\\":
                    i += 2
                    continue
                if text.startswith(q, i):
                    i += len(q)
                    break
                if text[i] == "\n" and not triple:
                    break
                if text[i] == "\n":
                    line_idx += 1
                    depth_at_start[min(line_idx, len(lines) - 1)] = depth
                i += 1
            continue
        if not c.isspace():
            has_code[line_idx] = True
        if c == "{":
            depth += 1
            if pending_class is not None:
                stack.append((pending_class[0], pending_class[1], depth))
                pending_class = None
        elif c == "}":
            if stack and stack[-1][2] == depth:
                name, start, _ = stack.pop()
                results.append((name, start, line_idx))
            depth -= 1
        elif c == ";" and pending_class is not None:
            pending_class = None  # e.g. "class X = Y with Z;"
        i += 1
    # Count code lines per class from the per-line flag.
    out = []
    for name, start, end in results:
        count = sum(1 for k in range(start, end + 1) if k < len(has_code) and has_code[k])
        out.append((name, start + 1, end + 1, count))
    return out


def declarations(text: str):
    """Maps line numbers (0-based) of class declarations to their names."""
    found = {}
    for idx, line in enumerate(text.split("\n")):
        m = CLASS_RE.match(line)
        if m:
            found[idx] = m.group(1)
    return found


def scan(root: pathlib.Path):
    rows = []
    for path in sorted(root.rglob("*.dart")):
        if path.name.endswith((".g.dart", ".freezed.dart")) or path.name.startswith("app_localizations"):
            continue
        text = path.read_text(encoding="utf-8")
        decl = declarations(text)
        if not decl:
            continue
        for name, start, end, count in code_lines_and_classes(text, decl):
            if (start - 1) in decl:
                rows.append((count, path.as_posix(), name, start, end))
    rows.sort(reverse=True)
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default="lib")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--warn", type=int, default=300, help="from here: note in review")
    ap.add_argument("--review", type=int, default=400, help="from here: PR must justify the class")
    ap.add_argument("--limit", type=int, default=500, help="from here: split before merge")
    ap.add_argument("--fail-above", type=int, default=None, help="exit 1 if a class is above this")
    args = ap.parse_args()

    rows = scan(pathlib.Path(args.root))
    print(f"{'lines':>6}  {'class':<32} file")
    for count, path, name, start, end in rows[: args.top]:
        flag = "  LIMIT" if count >= args.limit else "  review" if count >= args.review else "  warn" if count >= args.warn else ""
        print(f"{count:>6}  {name:<32} {path}:{start}{flag}")
    over = [r for r in rows if args.fail_above is not None and r[0] > args.fail_above]
    print(f"\nclasses: {len(rows)}, >= {args.warn}: {sum(r[0] >= args.warn for r in rows)}, "
          f">= {args.review}: {sum(r[0] >= args.review for r in rows)}, >= {args.limit}: {sum(r[0] >= args.limit for r in rows)}")
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main())
