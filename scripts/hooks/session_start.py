"""SessionStart — no chat begins blind.

Reads real state off disk: where we are, and if the last session left a mess.
Does not replace /start. Guarantees the floor. Never fails.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[2]
STATE_LOG = PROJECT_DIR / "docs" / "state.md"


def _git(*args: str) -> str:
    try:
        out = subprocess.run(
            ["git", *args],
            cwd=PROJECT_DIR,
            capture_output=True,
            text=True,
            timeout=10,
        )
        return out.stdout.strip()
    except Exception:
        return ""


def _position() -> list[str]:
    try:
        text = STATE_LOG.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ["docs/state.md missing — new build is fine."]

    lines: list[str] = []
    capturing = False
    for line in text.splitlines():
        if line.startswith("**Current position:**"):
            capturing = True
        elif capturing and (
            line.startswith("## Open")
            or line.startswith("## Standing")
            or line.startswith("## Next session")
        ):
            break
        if capturing and line.strip():
            lines.append(line.rstrip())
        if len(lines) > 24:
            break
    return lines or ["Could not read current position from docs/state.md."]


def main() -> None:
    try:
        sys.stdin.read()
    except Exception:
        pass

    parts = [
        "DRAYWAR ALPHA — state from disk at session start (hook, not recall).",
        "",
        "WHERE THE BUILD IS, per docs/state.md:",
        *_position(),
        "",
    ]

    dirty = _git("status", "--porcelain")
    unpushed = _git("log", "--oneline", "@{u}..HEAD")

    if dirty or unpushed:
        parts.append("WARNING — last session did not end clean:")
        if dirty:
            parts.append(f"  - {len(dirty.splitlines())} uncommitted file(s)")
        if unpushed:
            parts.append(f"  - {len(unpushed.splitlines())} commit(s) not pushed")
        parts.append("  Sort that out BEFORE new work.")
    else:
        parts.append("Working tree clean and pushed. Nothing left behind.")

    parts += [
        "",
        "Run /start to load the plan and restate the current work.",
        "Talk to Elliot in plain English, short and blunt.",
        "Main chat orchestrates; subagents build; you verify their claims yourself.",
    ]

    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": "\n".join(parts),
                },
                "suppressOutput": True,
            }
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print(json.dumps({"suppressOutput": True}))
