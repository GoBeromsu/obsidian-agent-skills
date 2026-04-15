#!/usr/bin/env python3
"""Shared frontmatter parsing and repair helpers for obsidian-vault-doctor."""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Iterator

CANONICAL_DELIMITER_RE = re.compile(r"^---\s*$")
OVERSIZED_DELIMITER_RE = re.compile(r"^-{4,}\s*$")
MALFORMED_OPENER_RE = re.compile(r"^---([A-Za-z_][A-Za-z0-9_-]*\s*:.*)$")


def strip_line_ending(line: str) -> str:
    return line.rstrip("\r\n")


def detect_line_ending(line: str, default: str = "\n") -> str:
    if line.endswith("\r\n"):
        return "\r\n"
    if line.endswith("\n"):
        return "\n"
    return default


def default_line_ending(text: str) -> str:
    return "\r\n" if "\r\n" in text else "\n"


def opening_kind(line: str) -> str:
    if CANONICAL_DELIMITER_RE.match(line):
        return "canonical"
    if MALFORMED_OPENER_RE.match(line):
        return "malformed_opener"
    if OVERSIZED_DELIMITER_RE.match(line):
        return "oversized_delimiter"
    if line.startswith("---"):
        return "unknown_opener"
    return "none"


def parse_frontmatter(text: str) -> dict[str, object]:
    lines = text.splitlines(keepends=True)
    if not lines:
        return {
            "opening_kind": "none",
            "closing_kind": "none",
            "frontmatter": None,
            "issues": [],
            "missing_frontmatter": True,
            "closing_line_index": None,
        }

    opener = opening_kind(strip_line_ending(lines[0]))
    if opener == "none":
        return {
            "opening_kind": opener,
            "closing_kind": "none",
            "frontmatter": None,
            "issues": [],
            "missing_frontmatter": True,
            "closing_line_index": None,
        }

    closing_idx = None
    closing_kind = "none"
    for idx, line in enumerate(lines[1:], start=1):
        stripped = strip_line_ending(line)
        if CANONICAL_DELIMITER_RE.match(stripped):
            closing_idx = idx
            closing_kind = "canonical"
            break
        if OVERSIZED_DELIMITER_RE.match(stripped):
            closing_idx = idx
            closing_kind = "oversized_delimiter"
            break

    issues: list[str] = []
    if opener == "malformed_opener":
        issues.append("malformed_opener")
    elif opener == "oversized_delimiter":
        issues.append("oversized_opening_delimiter")
    elif opener == "unknown_opener":
        issues.append("unknown_opening_delimiter")

    if closing_idx is None:
        issues.append("missing_closing_delimiter")
    elif closing_kind == "oversized_delimiter":
        issues.append("oversized_closing_delimiter")

    frontmatter = None
    if closing_idx is not None:
        if opener == "malformed_opener":
            frontmatter = lines[0][3:] + "".join(lines[1:closing_idx])
        else:
            frontmatter = "".join(lines[1:closing_idx])

    return {
        "opening_kind": opener,
        "closing_kind": closing_kind,
        "frontmatter": frontmatter,
        "issues": issues,
        "missing_frontmatter": False,
        "closing_line_index": closing_idx,
    }


def repair_frontmatter_text(text: str) -> tuple[str, list[str]]:
    lines = text.splitlines(keepends=True)
    if not lines:
        return text, []

    changes: list[str] = []
    opener = opening_kind(strip_line_ending(lines[0]))
    newline = default_line_ending(text)
    start_index = 1

    if opener == "malformed_opener":
        remainder = lines[0][3:]
        if remainder and not remainder.endswith(("\n", "\r\n")):
            remainder = remainder + newline
        lines[0] = f"---{detect_line_ending(lines[0], newline)}"
        if remainder:
            lines.insert(1, remainder)
            start_index = 2
        changes.append("malformed_opener")
    elif opener == "oversized_delimiter":
        lines[0] = f"---{detect_line_ending(lines[0], newline)}"
        changes.append("oversized_opening_delimiter")

    if opener == "none":
        return text, changes

    for idx in range(start_index, len(lines)):
        stripped = strip_line_ending(lines[idx])
        if CANONICAL_DELIMITER_RE.match(stripped):
            break
        if OVERSIZED_DELIMITER_RE.match(stripped):
            lines[idx] = f"---{detect_line_ending(lines[idx], newline)}"
            changes.append("oversized_closing_delimiter")
            break

    return "".join(lines), changes


DEFAULT_EXCLUDE_DIRS = {'.obsidian', '.trash', '.git', '.omc', '.claude', '_archive', '02 Templates'}


def parse_list_field(fm: str, field_name: str, strip_quotes: bool = True) -> list[str]:
    """Extract YAML list values for a given field from raw frontmatter text."""
    vals: list[str] = []
    pattern = re.compile(rf'^{re.escape(field_name)}\s*:')
    in_field = False
    for line in fm.split('\n'):
        if pattern.match(line):
            in_field = True
            # Inline list: field: [a, b, c]
            m = re.match(rf'^{re.escape(field_name)}\s*:\s*\[(.+)\]', line)
            if m:
                vals = [x.strip().strip('"\'') if strip_quotes else x.strip() for x in m.group(1).split(',')]
                in_field = False
            # Empty list: field: []
            elif re.match(rf'^{re.escape(field_name)}\s*:\s*\[\s*\]', line):
                in_field = False
            # Single inline value: field: value
            else:
                m2 = re.match(rf'^{re.escape(field_name)}\s*:\s*(.+)', line)
                if m2:
                    val = m2.group(1).strip()
                    if val and not val.startswith('#'):
                        vals.append(val.strip('"\'') if strip_quotes else val)
            continue
        if in_field:
            list_m = re.match(r'^\s+-\s+(.*)', line)
            if list_m:
                val = list_m.group(1).strip()
                vals.append(val.strip('"\'') if strip_quotes else val)
            elif line and not line.startswith(' '):
                in_field = False
    return vals


def parse_tags(fm: str) -> list[str]:
    """Extract tags from frontmatter. Thin wrapper over parse_list_field."""
    return parse_list_field(fm, 'tags', strip_quotes=True)


def get_type_val(fm: str) -> str | None:
    """Extract and normalize the type value from frontmatter text."""
    m = re.search(r'^type:[ \t]*(.+)', fm, re.MULTILINE)
    if not m:
        return None
    val = m.group(1).strip().strip('"\'').lower().strip('[]').strip()
    if not val or val.startswith('-'):
        list_m = re.search(r'^type:\s*\n\s+-\s*(.+)', fm, re.MULTILINE)
        if list_m:
            return list_m.group(1).strip().strip('"\'').lower()
        return None
    return val


def iter_markdown_files(vault: Path, exclude_dirs: set[str] | None = None) -> Iterator[Path]:
    if exclude_dirs is None:
        exclude_dirs = DEFAULT_EXCLUDE_DIRS
    for root, dirs, files in os.walk(vault):
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        root_path = Path(root)
        for fname in files:
            if fname.endswith(".md"):
                yield root_path / fname
