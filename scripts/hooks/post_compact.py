"""PostCompact — re-orient after memory loss.

After compression, recollection feels fine and is not. Push back to files.
Never fails.
"""

from __future__ import annotations

import json
import sys

CONTEXT = """MEMORY WAS JUST COMPRESSED (harness hook).

Your memory of this session is incomplete, and it will not feel incomplete.
Treat "I finished X" as a claim, not a fact.

Before anything else:
1. Re-read docs/state.md — that is where the build actually is.
2. Re-read AGENTS.md if any rule is fuzzy.
3. Run: git log --oneline -5 — does it match what you think you did?
4. Run: powershell -ExecutionPolicy Bypass -File scripts/lint.ps1 — before
   claiming anything passes.

Do not mark work complete from memory. If evidence is not in the state log or
reproducible by a command, re-check or say it is unverified.
"""


def main() -> None:
    try:
        sys.stdin.read()
    except Exception:
        pass
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostCompact",
                    "additionalContext": CONTEXT,
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
