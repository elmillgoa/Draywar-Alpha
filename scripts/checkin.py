"""Draywar Alpha check-in — deterministic facts about the build.

    python scripts/checkin.py
    python scripts/checkin.py --deep

Exit 0 = ground is solid enough to start work.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path(r"C:\Godot\Godot_v4.6.1-stable_win64_console.exe")


def run(cmd: list[str], timeout: int = 120) -> tuple[int, str]:
    try:
        p = subprocess.run(
            cmd,
            cwd=PROJECT,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        out = (p.stdout or "") + (p.stderr or "")
        return p.returncode, out
    except FileNotFoundError as e:
        return 127, str(e)
    except subprocess.TimeoutExpired:
        return 124, "timeout"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--deep", action="store_true")
    args = parser.parse_args()
    failed = 0

    def check(name: str, ok: bool, detail: str = "") -> None:
        nonlocal failed
        status = "PASS" if ok else "FAIL"
        print(f"{status}  {name}" + (f"  — {detail}" if detail else ""))
        if not ok:
            failed += 1

    # Godot present
    check("godot binary", GODOT.is_file(), str(GODOT))

    # project.godot
    check("project.godot", (PROJECT / "project.godot").is_file())

    # Authority docs
    for rel in (
        "AGENTS.md",
        "Alpha/ALPHA_VISION.md",
        "Alpha/ALPHA_SCOPE.md",
        "Alpha/ALPHA_PHASE_PLAN.md",
        "docs/state.md",
        "docs/reputation_and_standing.md",
    ):
        check(f"doc {rel}", (PROJECT / rel).is_file())

    # EventBus + Main
    check("EventBus.gd", (PROJECT / "src/systems/EventBus.gd").is_file())
    check("Main scene", (PROJECT / "src/Main.tscn").is_file())

    # GUT
    check("GUT addon", (PROJECT / "addons/gut/plugin.cfg").is_file())

    # MCP config present (addon may be gitignored)
    check("MCP .mcp.json", (PROJECT / ".mcp.json").is_file())
    check("MCP .grok/config.toml", (PROJECT / ".grok/config.toml").is_file())
    mcp_addon = (PROJECT / "addons/godot_mcp/plugin.cfg").is_file()
    check("MCP addon on disk (local)", mcp_addon, "reinstall if FAIL — see docs/tooling.md")

    # Headless boot
    if GODOT.is_file():
        code, out = run(
            [str(GODOT), "--path", str(PROJECT), "--headless", "--quit-after", "2"],
            timeout=60,
        )
        ok = code == 0 and "ERROR:" not in out
        check("headless boot", ok, f"exit={code}" if not ok else "")
        if not ok and out.strip():
            print(out[-2000:])
    else:
        check("headless boot", False, "no godot")

    if args.deep:
        lint = PROJECT / "scripts" / "lint.ps1"
        if lint.is_file():
            code, out = run(
                [
                    "powershell",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(lint),
                ],
                timeout=180,
            )
            check("lint.ps1", code == 0, f"exit={code}")
            if code != 0 and out.strip():
                print(out[-3000:])
        else:
            check("lint.ps1", False, "missing")

    print()
    if failed:
        print(f"{failed} check(s) failed. Fix before building.")
        return 1
    print("Check-in clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
