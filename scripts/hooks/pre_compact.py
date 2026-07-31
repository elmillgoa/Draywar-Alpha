"""PreCompact — warn before chat memory is crushed.

Only reliable signal that room is almost gone. Model cannot detect this alone.
Never fails: a broken hook is worse than no hook.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[2]


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


def main() -> None:
    try:
        sys.stdin.read()
    except Exception:
        pass

    dirty = _git("status", "--porcelain")
    unpushed = _git("log", "--oneline", "@{u}..HEAD")

    risks: list[str] = []
    if dirty:
        risks.append(f"{len(dirty.splitlines())} uncommitted file(s)")
    if unpushed:
        risks.append(f"{len(unpushed.splitlines())} commit(s) not pushed")

    if risks:
        user_msg = (
            "Memory is being compressed. UNSAVED WORK: "
            + "; ".join(risks)
            + ". Agent told to write it down before continuing."
        )
    else:
        user_msg = (
            "Memory is being compressed. Tree is clean and pushed. Nothing at risk."
        )

    context = [
        "PRE-COMPACTION WARNING (harness hook — not your own judgement).",
        "",
        "This chat is about to be compressed. Details you hold will go fuzzy or",
        "vanish. You will NOT be able to tell afterwards what you forgot.",
        "",
        "Do this NOW, before any other work:",
        "1. Write real status into docs/state.md — what passed, with evidence.",
        "2. Journal a NOTE if anything would be lost.",
        "3. Commit, then push to origin (Draywar-Alpha).",
        "4. Do NOT start a new contract. Land this one or run /wrap.",
    ]
    if risks:
        context.append("")
        context.append("Uncommitted or unpushed right now: " + "; ".join(risks) + ".")

    print(
        json.dumps(
            {
                "systemMessage": user_msg,
                "hookSpecificOutput": {
                    "hookEventName": "PreCompact",
                    "additionalContext": "\n".join(context),
                },
            }
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print(json.dumps({"suppressOutput": True}))
