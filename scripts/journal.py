"""Append-only build journal for Draywar.

Why a script rather than editing markdown by hand: an agent cannot reliably
know the date or time, cannot be trusted to pick the right file consistently
across dozens of sessions, and hand-editing an append-only log invites
accidental rewriting of history. This makes recording an event one cheap,
uniform command.

    python scripts/journal.py new-session "Godot MCP wired up"
    python scripts/journal.py add CONTRACT "P0.5 complete" --detail "..."
    python scripts/journal.py list

Entries append to the newest session file in docs/journal/. Nothing here ever
edits or deletes an existing entry — that is the whole point of the format.
Consolidation happens by writing a separate summary file, never by rewriting
the raw record.
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[1]
JOURNAL_DIR = PROJECT_DIR / "docs" / "journal"

# Entry types map onto the categories the guardrails already care about, so the
# journal can be filtered for exactly the question being asked later.
TYPES = {
    "CONTRACT": "A contract landed, partially landed, or was blocked",
    "DECISION": "Elliot decided something — never re-ask a decision recorded here",
    "AMENDMENT": "The locked plan changed, with a version bump",
    "TRAP": "Something gave a wrong answer or a silent false pass",
    "GATE": "A human sign-off gate was opened, signed, or refused",
    "DEVIATION": "Acted then reported — went beyond the documented layout or notes",
    "BLOCKER": "Work stopped and why",
    "NOTE": "Anything else a future session would want to know",
}

SESSION_RE = re.compile(r"^(\d{3})-\d{4}-\d{2}-\d{2}\.md$")


def _session_files() -> list[Path]:
    if not JOURNAL_DIR.exists():
        return []
    files = [p for p in JOURNAL_DIR.iterdir() if SESSION_RE.match(p.name)]
    return sorted(files, key=lambda p: p.name)


def _newest_session() -> Path | None:
    files = _session_files()
    return files[-1] if files else None


def cmd_new_session(args: argparse.Namespace) -> int:
    JOURNAL_DIR.mkdir(parents=True, exist_ok=True)
    existing = _session_files()
    number = 1
    if existing:
        match = SESSION_RE.match(existing[-1].name)
        if match:
            number = int(match.group(1)) + 1

    now = datetime.now()
    path = JOURNAL_DIR / f"{number:03d}-{now:%Y-%m-%d}.md"
    if path.exists():
        print(f"Already exists: {path.name}", file=sys.stderr)
        return 1

    title = args.title or "(untitled)"
    path.write_text(
        f"# Session {number:03d} — {now:%Y-%m-%d}\n\n"
        f"**{title}**\n\n"
        "Append-only. Newest entry at the bottom. Do not edit entries above.\n\n"
        "---\n",
        encoding="utf-8",
    )
    print(f"Created docs/journal/{path.name}")
    return 0


def cmd_add(args: argparse.Namespace) -> int:
    entry_type = args.type.upper()
    if entry_type not in TYPES:
        print(
            f"Unknown type {entry_type!r}. Valid: {', '.join(sorted(TYPES))}",
            file=sys.stderr,
        )
        return 1

    path = _newest_session()
    if path is None:
        print(
            "No session file yet. Run: python scripts/journal.py new-session "
            '"what this session is about"',
            file=sys.stderr,
        )
        return 1

    # Entries carry a citable ID (e.g. 001#5) so a later entry can supersede an
    # earlier one by name. Correcting the record must be traceable, not silent.
    match = SESSION_RE.match(path.name)
    session_no = match.group(1) if match else "000"
    existing = len(
        re.findall(r"^### `[A-Z]+`", path.read_text(encoding="utf-8"), re.M)
    )
    entry_id = f"{session_no}#{existing + 1}"

    now = datetime.now()
    block = [f"\n### `{entry_type}` · {entry_id} · {now:%H:%M} · {args.summary}\n"]
    if args.detail:
        block.append(f"\n{args.detail.strip()}\n")

    with path.open("a", encoding="utf-8") as handle:
        handle.write("".join(block))

    print(f"Recorded {entry_type} as {entry_id} in docs/journal/{path.name}")
    return 0


def cmd_list(_: argparse.Namespace) -> int:
    files = _session_files()
    if not files:
        print("No journal entries yet.")
        return 0
    print(f"{len(files)} session file(s) in docs/journal/:\n")
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        counts: dict[str, int] = {}
        for line in text.splitlines():
            match = re.match(r"^### `([A-Z]+)`", line)
            if match:
                counts[match.group(1)] = counts.get(match.group(1), 0) + 1
        title = ""
        for line in text.splitlines():
            if line.startswith("**") and line.endswith("**"):
                title = line.strip("*")
                break
        summary = ", ".join(f"{k}:{v}" for k, v in sorted(counts.items())) or "empty"
        print(f"  {path.name}  {title}")
        print(f"      {summary}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    new = sub.add_parser("new-session", help="Start a new session journal file")
    new.add_argument("title", nargs="?", help="One line on what this session is about")
    new.set_defaults(func=cmd_new_session)

    add = sub.add_parser("add", help="Append an entry to the current session")
    add.add_argument("type", help=" | ".join(f"{k} ({v})" for k, v in TYPES.items()))
    add.add_argument("summary", help="One line. What happened.")
    add.add_argument("--detail", help="Optional body: evidence, reasoning, options")
    add.set_defaults(func=cmd_add)

    lst = sub.add_parser("list", help="Show sessions and entry counts")
    lst.set_defaults(func=cmd_list)

    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
