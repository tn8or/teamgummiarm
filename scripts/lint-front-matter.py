#!/usr/bin/env python3
"""Check the front matter of every non-draft post.

Rules (see README.md):
  - `description` is present and at most 155 characters
  - `tags` holds exactly one series tag (the list is `series` in data/tags.toml)
  - `date` is present and a valid date or date-time

Usage: scripts/lint-front-matter.py [repo root]. Exits 1 on any failure.
"""
import datetime
import pathlib
import sys
import tomllib

MAX_DESCRIPTION = 155


def front_matter(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "+++":
        raise ValueError("no TOML front matter (+++)")
    for end, line in enumerate(lines[1:], start=1):
        if line.strip() == "+++":
            return tomllib.loads("\n".join(lines[1:end]))
    raise ValueError("front matter is not closed with +++")


def valid_date(value):
    if isinstance(value, (datetime.date, datetime.datetime)):
        return True
    if isinstance(value, str):
        try:
            datetime.datetime.fromisoformat(value)
            return True
        except ValueError:
            return False
    return False


def check(fm, series):
    errors = []
    description = fm.get("description")
    if not isinstance(description, str) or not description.strip():
        errors.append("description: missing")
    elif len(description) > MAX_DESCRIPTION:
        errors.append(f"description: {len(description)} characters, max {MAX_DESCRIPTION}")
    tags = fm.get("tags") or []
    found = [t for t in tags if t in series]
    if len(found) != 1:
        errors.append(
            f"tags: needs exactly one series tag, found {', '.join(found) or 'none'}"
            f" (series: {', '.join(series)})"
        )
    if "date" not in fm:
        errors.append("date: missing")
    elif not valid_date(fm["date"]):
        errors.append(f"date: not a valid date: {fm['date']!r}")
    return errors


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    series = tomllib.loads((root / "data/tags.toml").read_text(encoding="utf-8"))["series"]
    failed = 0
    posts = sorted(p for p in (root / "content/posts").rglob("*.md") if p.name != "_index.md")
    for path in posts:
        rel = path.relative_to(root)
        try:
            fm = front_matter(path)
        except (ValueError, tomllib.TOMLDecodeError) as e:
            errors = [f"front matter: {e}"]
        else:
            if fm.get("draft"):
                continue
            errors = check(fm, series)
        for error in errors:
            print(f"::error file={rel}::{rel}: {error}")
            failed += 1
    if failed:
        print(f"{failed} front matter problem(s) in content/posts")
        return 1
    print(f"Front matter OK ({len(posts)} posts checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
