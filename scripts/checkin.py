"""Draywar check-in — deterministic facts about the build.

    python scripts/checkin.py
    python scripts/checkin.py --deep

Exit 0 = ground is solid enough to start work.
Live authorities: AGENTS, guardrails, Steam plan, product direction, standing.

--deep does two things beyond the checks above. First it runs
scripts/lint.ps1, the full static-gate pass (this now includes a full Godot
type check, so --deep is slow - budget a couple of minutes). Second, and this
is the point of --deep rather than a restatement of lint.ps1: a gate that only
*claims* it is proven to work is not proven to work, so this harness actually
proves the three static gates for real, by fault injection, instead of taking
their word for it.

For each of check_boundaries.py, check_magic_numbers.py and check_globals.py,
this runs the gate twice - once against an unmodified copy or fixture, to
confirm the control case still passes clean (exit 0), and once against the
same copy or fixture with one deliberate violation planted, to confirm the
gate fails (exit 1) AND names the planted file in its output. Asserting only
the second half would let a gate that fails on everything look like a working
one; asserting only the first half would let a gate that never fails look
clean. Both have to hold.

check_boundaries.py and check_magic_numbers.py are proven against a disposable
temp copy of src/ (via each script's --root argument) - never the real src/,
so a run killed mid-way leaves no poison file for git to pick up. check_globals
.py is proven against a fixture project.godot/docs/globals.md/src-dir triple
(its existing --project-file/--globals-doc/--src-dir arguments), so that one
needs no copy of the real src/ either - an empty fixture directory stands in
for it. Every proof prints its own PASS/FAIL line in the same style as the
checks above, and a failure here fails the whole run.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path(r"C:\Godot\Godot_v4.6.1-stable_win64_console.exe")

CheckFn = Callable[[str, bool, str], None]


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


def run_python(script: Path, extra_args: list[str], timeout: int = 60) -> tuple[int, str]:
    """Run one of the other two checkers (or check_globals.py) as a subprocess.

    Always a fresh interpreter, never an in-process import. Each checker keeps
    its findings in a module-level list and rebinds its own PROJECT_DIR/SRC_DIR
    globals from --root - importing three of these into one process and calling
    main() repeatedly would let state from one proof leak into the next. A
    subprocess per run costs a moment and buys total isolation, and it is the
    same pattern this file already uses for lint.ps1 and the Godot binary.
    """
    return run([sys.executable, str(script), *extra_args], timeout=timeout)


def prove_boundaries_gate(check: CheckFn) -> None:
    """Fault-inject scripts/check_boundaries.py in a disposable copy of src/.

    Copies src/ and docs/events.md into a temp directory (check_boundaries.py
    needs both to get past its own SETUP INCOMPLETE check), confirms the gate
    passes clean against the unmodified copy, then plants
    src/ui/_InjectedProbe.gd - a ui-layer file statically naming
    src/systems/ContentLibrary.gd, a real cross-layer reference that is not the
    EventBus (the one sanctioned exception) - and confirms the gate fails and
    names the planted file. The real src/ is never written to; the copy is
    removed whether the proof passes or the process is killed first.
    """
    script = PROJECT / "scripts" / "check_boundaries.py"
    tmp = Path(tempfile.mkdtemp(prefix="checkin_deep_boundaries_"))
    try:
        shutil.copytree(PROJECT / "src", tmp / "src")
        (tmp / "docs").mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / "docs" / "events.md", tmp / "docs" / "events.md")

        code, out = run_python(script, ["--root", str(tmp)])
        check(
            "deep: check_boundaries.py passes on an unmodified copy",
            code == 0,
            "" if code == 0 else f"exit={code}",
        )
        if code != 0:
            print(out[-2000:])

        probe = tmp / "src" / "ui" / "_InjectedProbe.gd"
        probe.write_text(
            "extends Node\n"
            "# Planted on purpose by checkin.py --deep to prove check_boundaries.py"
            " bites.\n"
            'const PROBE := preload("res://src/systems/ContentLibrary.gd")\n',
            encoding="utf-8",
        )
        code, out = run_python(script, ["--root", str(tmp)])
        caught = code == 1 and "_InjectedProbe.gd" in out and "ContentLibrary.gd" in out
        check(
            "deep: check_boundaries.py catches and names the planted cross-layer "
            "reference",
            caught,
            "" if caught else f"exit={code}, planted file not named in output",
        )
        if not caught:
            print(out[-2000:])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def prove_magic_numbers_gate(check: CheckFn) -> None:
    """Fault-inject scripts/check_magic_numbers.py in a disposable copy of src/.

    Copies src/ into a temp directory, confirms the gate passes clean against
    the unmodified copy, then plants src/ui/_InjectedMagicNumber.gd with a
    literal (4242.0) that is not 0 or 1, not a subscript, not an enum ordinal,
    not inside an @export annotation's arguments, and not on a declaration
    whose name contains "version" - a genuine violation under every tolerance
    this gate grants - and confirms the gate fails and names the planted file.
    The real src/ is never written to.
    """
    script = PROJECT / "scripts" / "check_magic_numbers.py"
    tmp = Path(tempfile.mkdtemp(prefix="checkin_deep_magicnum_"))
    try:
        shutil.copytree(PROJECT / "src", tmp / "src")

        code, out = run_python(script, ["--root", str(tmp)])
        check(
            "deep: check_magic_numbers.py passes on an unmodified copy",
            code == 0,
            "" if code == 0 else f"exit={code}",
        )
        if code != 0:
            print(out[-2000:])

        probe = tmp / "src" / "ui" / "_InjectedMagicNumber.gd"
        probe.write_text(
            "extends Node\n"
            "# Planted on purpose by checkin.py --deep to prove"
            " check_magic_numbers.py bites.\n"
            "var speed: float = 4242.0\n",
            encoding="utf-8",
        )
        code, out = run_python(script, ["--root", str(tmp)])
        caught = code == 1 and "_InjectedMagicNumber.gd" in out and "4242" in out
        check(
            "deep: check_magic_numbers.py catches and names the planted magic "
            "number",
            caught,
            "" if caught else f"exit={code}, planted file not named in output",
        )
        if not caught:
            print(out[-2000:])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def prove_globals_gate(check: CheckFn) -> None:
    """Fault-inject scripts/check_globals.py against a fixture pair.

    No copy of the real src/ needed - check_globals.py reads two files and one
    directory, and its --project-file/--globals-doc/--src-dir arguments exist
    for exactly this proof (see its ARGUMENTS header section). --src-dir is
    pointed at an empty fixture directory rather than left at its default: this
    script now also scans src/ for class_name scripts with a top-level static
    func/var (audit finding #80's static-namespace catalog), and the real src/
    has many legitimate ones undeclared in a two-line fixture doc. An empty
    --src-dir keeps that second catalog trivially empty in both runs below, so
    this proof stays aimed only at the autoload direction it is testing.

    Writes a matched fixture pair, confirms it passes clean, then adds one
    autoload (InjectedProbeGlobal) to the project-file fixture only - the
    undeclared-global direction, the one the whole gate exists for - and
    confirms the gate fails and names it.
    """
    script = PROJECT / "scripts" / "check_globals.py"
    tmp = Path(tempfile.mkdtemp(prefix="checkin_deep_globals_"))
    try:
        empty_src = tmp / "src_fixture"
        empty_src.mkdir()

        clean_project = tmp / "project_clean.godot"
        clean_doc = tmp / "globals_clean.md"
        clean_project.write_text(
            '[autoload]\n\nEventBus="*res://src/systems/EventBus.gd"\n',
            encoding="utf-8",
        )
        clean_doc.write_text(
            "### `EventBus` -> `res://src/systems/EventBus.gd`\n",
            encoding="utf-8",
        )

        code, out = run_python(
            script,
            [
                "--project-file",
                str(clean_project),
                "--globals-doc",
                str(clean_doc),
                "--src-dir",
                str(empty_src),
            ],
        )
        check(
            "deep: check_globals.py passes on a matched fixture pair",
            code == 0,
            "" if code == 0 else f"exit={code}",
        )
        if code != 0:
            print(out[-2000:])

        poisoned_project = tmp / "project_poisoned.godot"
        poisoned_project.write_text(
            "[autoload]\n\n"
            'EventBus="*res://src/systems/EventBus.gd"\n'
            'InjectedProbeGlobal="*res://src/systems/_InjectedProbeGlobal.gd"\n',
            encoding="utf-8",
        )
        code, out = run_python(
            script,
            [
                "--project-file",
                str(poisoned_project),
                "--globals-doc",
                str(clean_doc),
                "--src-dir",
                str(empty_src),
            ],
        )
        caught = code == 1 and "InjectedProbeGlobal" in out
        check(
            "deep: check_globals.py catches and names the undeclared autoload",
            caught,
            "" if caught else f"exit={code}, planted autoload not named in output",
        )
        if not caught:
            print(out[-2000:])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--deep", action="store_true")
    args = parser.parse_args()
    failed = 0

    def check(name: str, ok: bool, detail: str = "") -> None:
        nonlocal failed
        status = "PASS" if ok else "FAIL"
        print(f"{status}  {name}" + (f"  -- {detail}" if detail else ""))
        if not ok:
            failed += 1

    # Godot present
    check("godot binary", GODOT.is_file(), str(GODOT))

    # project.godot
    check("project.godot", (PROJECT / "project.godot").is_file())

    # Live authority docs (Steam plan stack — not closed Alpha queues)
    for rel in (
        "AGENTS.md",
        "DRAYWAR_AGENT_GUARDRAILS_v2.md",
        "docs/STEAM_PHASE_PLAN.md",
        "docs/PRODUCT_DIRECTION.md",
        "docs/reputation_and_standing.md",
        "docs/state.md",
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
    check("MCP addon on disk (local)", mcp_addon, "reinstall if FAIL - see docs/tooling.md")

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
            # lint.ps1 now runs the full Godot type check as one of its gates,
            # which takes a couple of minutes on its own; 180s was too tight
            # for that plus the other static gates it also runs.
            code, out = run(
                [
                    "powershell",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(lint),
                ],
                timeout=600,
            )
            check("lint.ps1", code == 0, f"exit={code}")
            if code != 0 and out.strip():
                print(out[-3000:])
        else:
            check("lint.ps1", False, "missing")

        # lint.ps1 above only proves the three static gates ran and returned
        # 0. It does not prove they would have caught anything if they
        # hadn't - that's what these three do, each in its own disposable
        # copy or fixture. See this file's header and each prove_*_gate()
        # docstring for what is planted and why.
        print()
        prove_boundaries_gate(check)
        prove_magic_numbers_gate(check)
        prove_globals_gate(check)

    print()
    if failed:
        print(f"{failed} check(s) failed. Fix before building.")
        return 1
    print("Check-in clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
