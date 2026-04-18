#!/usr/bin/env python3
"""Create an Obsidian note from a temp file and verify readback.

This helper exists so runtime agents do not invent unsupported Obsidian CLI
arguments such as `file=/tmp/...` on `obsidian create`.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REQUIRED_SCALAR_KEYS = (
    "date_created",
    "date_modified",
    "image",
    "review",
    "source",
    "status",
    "title",
    "type",
    "up",
)

REQUIRED_LIST_KEYS = ("aliases", "author", "speaker", "tags")
REQUIRED_TAGS = {"reference", "reference/video"}


def run_obsidian(vault: str, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        ["obsidian", f"vault={vault}", *args],
        capture_output=True,
        text=True,
    )
    if check and proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "obsidian command failed")
    return proc


def normalize_value(text: str) -> str:
    return text.strip().strip('"').strip("'")


def normalize_match(text: str) -> str:
    return re.sub(r"\s+", "", text).lower()


def split_frontmatter(text: str) -> tuple[str, str]:
    lines = text.splitlines()
    if len(lines) < 3 or lines[0].strip() != "---":
        return "", text

    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            return "\n".join(lines[1:idx]), "\n".join(lines[idx + 1 :])

    return "", text


def parse_frontmatter(text: str) -> dict[str, object]:
    data: dict[str, object] = {}
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith((" ", "\t")):
            i += 1
            continue
        if ":" not in line:
            i += 1
            continue

        key, raw = line.split(":", 1)
        key = key.strip()
        raw = raw.strip()
        if raw == "":
            items: list[str] = []
            i += 1
            while i < len(lines):
                entry = lines[i].lstrip()
                if not entry.startswith("- "):
                    break
                items.append(normalize_value(entry[2:]))
                i += 1
            data[key] = items
            continue
        if raw == "[]":
            data[key] = []
        else:
            data[key] = normalize_value(raw)
        i += 1
    return data


def clean_transcript_text(text: str) -> str:
    cleaned: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line == "WEBVTT" or "-->" in line:
            continue
        if re.fullmatch(r"\d+", line):
            continue
        if line.startswith(("Kind:", "Language:")):
            continue
        line = re.sub(r"<[^>]+>", "", line)
        line = " ".join(line.split())
        if not line:
            continue
        if cleaned and cleaned[-1] == line:
            continue
        cleaned.append(line)
    return "\n".join(cleaned)


def default_min_chapters(duration_seconds: int) -> int:
    if duration_seconds >= 3600:
        return 8
    if duration_seconds >= 2400:
        return 6
    if duration_seconds >= 1200:
        return 4
    if duration_seconds >= 600:
        return 3
    return 2


def default_min_chars(duration_seconds: int) -> int:
    if duration_seconds >= 3600:
        return 8000
    if duration_seconds >= 2400:
        return 6000
    if duration_seconds >= 1200:
        return 4000
    if duration_seconds >= 600:
        return 2500
    return 1200


def fail(message: str) -> int:
    print(message, file=sys.stderr)
    return 1


def validate_frontmatter_schema(frontmatter: dict[str, object]) -> str | None:
    for key in REQUIRED_SCALAR_KEYS:
        value = frontmatter.get(key)
        if not isinstance(value, str) or not value:
            return f"write-verification failed: missing required frontmatter key: {key}"

    for key in REQUIRED_LIST_KEYS:
        value = frontmatter.get(key)
        if not isinstance(value, list):
            return f"write-verification failed: frontmatter key must be a YAML list: {key}"

    tags = {normalize_value(str(item)) for item in frontmatter.get("tags", [])}
    if not REQUIRED_TAGS.issubset(tags):
        return "write-verification failed: tags must include reference and reference/video"

    return None


def validate_expected_frontmatter(
    frontmatter: dict[str, object],
    *,
    expect_title: str | None,
    expect_type: str | None,
    expect_up: str | None,
    prefix: str = "",
) -> str | None:
    expectations = (
        ("title", expect_title),
        ("type", expect_type),
        ("up", expect_up),
    )

    for key, expected in expectations:
        if expected is None:
            continue
        actual = frontmatter.get(key)
        if actual != expected:
            return (
                f"write-verification failed: {prefix}{key} mismatch "
                f"(expected {expected}, got {actual})"
            )

    return None


def validate_body_structure(body: str) -> tuple[int, str | None]:
    if not re.search(r"(?m)^> \[![^\]]+\] TL;DR\s*$", body):
        return 0, "write-verification failed: TL;DR must be a callout"
    if re.search(r"(?m)^## TL;DR\s*$", body):
        return 0, "write-verification failed: plain ## TL;DR heading is not allowed"
    if "## Summary" not in body:
        return 0, "write-verification failed: missing ## Summary section"
    if "## 강의 전문" not in body:
        return 0, "write-verification failed: missing ## 강의 전문 section"
    if re.search(r"(?m)^## Chapters\s*$", body):
        return 0, "write-verification failed: ## Chapters is not allowed"

    chapter_count = len(re.findall(r"(?m)^### ", body))
    mermaid_count = len(re.findall(r"(?m)^```mermaid\s*$", body))
    if mermaid_count < chapter_count:
        return (
            chapter_count,
            f"write-verification failed: mermaid count {mermaid_count} is less than chapter count {chapter_count}",
        )

    return chapter_count, None


def resolve_validation_floors(
    *,
    duration_seconds: int | None,
    min_chars: int,
    min_chapters: int,
    transcript_file: str | None,
) -> tuple[int, int]:
    resolved_min_chars = min_chars
    resolved_min_chapters = min_chapters

    if duration_seconds:
        resolved_min_chars = max(resolved_min_chars, default_min_chars(duration_seconds))
        resolved_min_chapters = max(resolved_min_chapters, default_min_chapters(duration_seconds))

    if transcript_file:
        transcript_path = Path(transcript_file).expanduser()
        if transcript_path.is_file():
            cleaned = clean_transcript_text(transcript_path.read_text(encoding="utf-8", errors="ignore"))
            resolved_min_chars = max(resolved_min_chars, int(len(cleaned) * 0.04))

    return resolved_min_chars, resolved_min_chapters


def validate_body_density(
    body: str,
    *,
    chapter_count: int,
    min_chars: int,
    min_chapters: int,
    anchors: list[str],
) -> str | None:
    body_chars = len(body)
    if min_chars and body_chars < min_chars:
        return f"write-verification failed: body too short ({body_chars} chars, need >= {min_chars})"
    if min_chapters and chapter_count < min_chapters:
        return f"write-verification failed: chapter count too low ({chapter_count}, need >= {min_chapters})"

    normalized_body = normalize_match(body)
    missing_anchors = [anchor for anchor in anchors if normalize_match(anchor) not in normalized_body]
    if missing_anchors:
        return "write-verification failed: missing anchor coverage: " + ", ".join(missing_anchors)

    return None


def read_property_with_fallback(
    vault: str,
    path: str,
    name: str,
    fallback_value: object,
) -> tuple[int, str, str]:
    result = run_obsidian(
        vault,
        "property:read",
        f"name={name}",
        f"path={path}",
        check=False,
    )
    value = normalize_value(result.stdout)
    if not value:
        value = normalize_value(str(fallback_value))
    detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
    return result.returncode, value, detail


def main() -> int:
    parser = argparse.ArgumentParser(description="Write a note via obsidian CLI and verify readback.")
    parser.add_argument("--vault", required=True, help="Vault name for obsidian CLI.")
    parser.add_argument("--path", required=True, help="Vault-relative note path.")
    parser.add_argument("--input", required=True, help="Temp markdown file to write.")
    parser.add_argument("--expect-status", help="Expected status property after write.")
    parser.add_argument("--expect-source", help="Expected source property after write.")
    parser.add_argument("--expect-title", help="Expected title property/frontmatter value.")
    parser.add_argument("--expect-type", help="Expected type frontmatter value.")
    parser.add_argument("--expect-up", help="Expected up frontmatter value.")
    parser.add_argument("--duration-seconds", type=int, help="Video duration used for validation floors.")
    parser.add_argument("--min-chars", type=int, help="Minimum body characters required.")
    parser.add_argument("--min-chapters", type=int, help="Minimum chapter count required.")
    parser.add_argument("--transcript-file", help="Transcript file used to derive a transcript-size floor.")
    parser.add_argument("--anchor", action="append", default=[], help="Anchor that must appear in the note body.")
    parser.add_argument("--overwrite", action="store_true", help="Pass overwrite to obsidian create.")
    args = parser.parse_args()

    input_path = Path(args.input).expanduser()
    if not input_path.is_file():
        return fail(f"write-verification failed: input file not found: {input_path}")

    content = input_path.read_text(encoding="utf-8")
    if not content.strip():
        return fail(f"write-verification failed: input file is empty: {input_path}")

    frontmatter_text, body = split_frontmatter(content)
    if not frontmatter_text:
        return fail("write-verification failed: missing frontmatter block")

    frontmatter = parse_frontmatter(frontmatter_text)
    schema_error = validate_frontmatter_schema(frontmatter)
    if schema_error:
        return fail(schema_error)

    expected_frontmatter_error = validate_expected_frontmatter(
        frontmatter,
        expect_title=args.expect_title,
        expect_type=args.expect_type,
        expect_up=args.expect_up,
    )
    if expected_frontmatter_error:
        return fail(expected_frontmatter_error)

    chapter_count, body_structure_error = validate_body_structure(body)
    if body_structure_error:
        return fail(body_structure_error)

    min_chars, min_chapters = resolve_validation_floors(
        duration_seconds=args.duration_seconds,
        min_chars=args.min_chars or 0,
        min_chapters=args.min_chapters or 0,
        transcript_file=args.transcript_file,
    )
    body_density_error = validate_body_density(
        body,
        chapter_count=chapter_count,
        min_chars=min_chars,
        min_chapters=min_chapters,
        anchors=args.anchor,
    )
    if body_density_error:
            return fail(body_density_error)

    create_args = ["create", f"path={args.path}", f"content={content}"]
    if args.overwrite:
        create_args.append("overwrite")

    created = run_obsidian(args.vault, *create_args, check=False)
    if created.returncode != 0:
        return fail(
            "write-verification failed: obsidian create failed: "
            + (created.stderr.strip() or created.stdout.strip() or f"exit {created.returncode}")
        )

    readback = run_obsidian(args.vault, "read", f"path={args.path}", check=False)
    if readback.returncode != 0 or not readback.stdout.strip():
        detail = readback.stderr.strip() or readback.stdout.strip() or f"exit {readback.returncode}"
        return fail(f"write-verification failed: obsidian read failed: {detail}")

    rb_frontmatter_text, rb_body = split_frontmatter(readback.stdout)
    rb_frontmatter = parse_frontmatter(rb_frontmatter_text)
    if not rb_frontmatter_text or not rb_body.strip():
        return fail("write-verification failed: readback missing frontmatter or body")
    readback_error = validate_expected_frontmatter(
        rb_frontmatter,
        expect_title=args.expect_title,
        expect_type=args.expect_type,
        expect_up=args.expect_up,
        prefix="readback ",
    )
    if readback_error:
        return fail(readback_error)

    if args.expect_status:
        status_code, got_status, detail = read_property_with_fallback(
            args.vault,
            args.path,
            "status",
            rb_frontmatter.get("status", ""),
        )
        if status_code != 0 or got_status != args.expect_status:
            return fail(
                f"write-verification failed: status mismatch (expected {args.expect_status}, got {got_status or detail})"
            )

    if args.expect_source:
        source_code, got_source, detail = read_property_with_fallback(
            args.vault,
            args.path,
            "source",
            rb_frontmatter.get("source", ""),
        )
        if source_code != 0 or got_source != args.expect_source:
            return fail(
                f"write-verification failed: source mismatch (expected {args.expect_source}, got {got_source or detail})"
            )

    print(f"CREATED {args.path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
