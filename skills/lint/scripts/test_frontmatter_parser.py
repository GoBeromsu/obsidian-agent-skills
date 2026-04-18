#!/usr/bin/env python3
"""Fixture-style checks for shared frontmatter parsing and repair helpers."""

from __future__ import annotations

from frontmatter_parser import parse_frontmatter, repair_frontmatter_text


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    cases = [
        (
            "valid",
            "---\naliases: []\ntype: note\n---\nbody\n",
            [],
            [],
        ),
        (
            "malformed opener",
            "---aliases: []\ntype: note\n---\nbody\n",
            ["malformed_opener"],
            ["malformed_opener"],
        ),
        (
            "oversized delimiters",
            "-----\naliases: []\ntype: note\n-----\nbody\n",
            ["oversized_opening_delimiter", "oversized_closing_delimiter"],
            ["oversized_opening_delimiter", "oversized_closing_delimiter"],
        ),
    ]

    for label, raw_text, expected_issues, expected_repairs in cases:
        parsed = parse_frontmatter(raw_text)
        assert_true(parsed["issues"] == expected_issues, f"{label}: issues mismatch: {parsed['issues']}")

        repaired_text, repairs = repair_frontmatter_text(raw_text)
        assert_true(repairs == expected_repairs, f"{label}: repairs mismatch: {repairs}")

        reparsed = parse_frontmatter(repaired_text)
        assert_true(reparsed["issues"] == [], f"{label}: repaired text still invalid: {reparsed['issues']}")
        assert_true(repaired_text.startswith("---\n"), f"{label}: repaired opener not canonical")

    print("PASS: frontmatter parser fixtures")


if __name__ == "__main__":
    main()
