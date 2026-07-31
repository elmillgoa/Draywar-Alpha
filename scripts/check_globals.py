"""Draywar globals gate - contract P0.6.

Elliot ratified the globals policy verbatim in session 3 (journal 003#4): a thing
may occupy a globally-reachable name slot only if all four tests hold, and the
fourth of them is *this script*. "It is entered in a single declared list with a
one-line justification, AND a check fails the build when the real set and the
declared list disagree." Without the check, points 1-3 are an intention. With it,
adding a global is a visible deliberate act.

    python scripts/check_globals.py

Exit 0 = clean. Exit 1 = a violation. Exit 2 = setup incomplete.

Run by scripts/lint.ps1 as one of the static gates, and re-proved by
`python scripts/checkin.py --deep`, which renames a declaration on purpose and
confirms this script catches and names both halves of the resulting mismatch.


WHY THIS RULE IS WORTH A GATE

An autoload is reached by bare name. `EventBus.on_thing.emit()` carries no
`res://` path and no `class_name`, so it looks exactly like a local variable to
any text scan - and scripts/check_boundaries.py says so itself, under "What this
cannot see". Every other boundary in this project is policed by something.
Name-based access is the one that is not, which is why docs/state.md has carried
it as a blind spot since P0.2.

The risk is not three globals. It is three becoming eleven over a year, because
each addition looks reasonable on its own and nothing ever says no.


THE PARSING CONTRACT WITH docs/globals.md

The declared list is read from level-3 headings holding a name and a script path,
each in backticks, separated by an arrow, and nothing else:

    ### `EventBus` -> `res://src/systems/EventBus.gd`

Everything else on that page - the four tests, the justifications, how to add a
global - is prose for humans and is not parsed. Fenced ``` blocks are blanked
before the scan, because the document documents its own entry format and that
example is a heading inside a fence. check_boundaries.py learned this the hard
way against docs/events.md: without the blanking it reads its own instructions as
a real entry.

The path is declared plainly, without the `*` that project.godot writes in front
of it. The star is the engine's marker for "expose this as a global name"; it is
stripped from both sides before comparing, so the declaration reads as a path and
not as engine syntax.


WHAT IS COMPARED, IN BOTH DIRECTIONS

  1. An autoload registered in project.godot with no entry in docs/globals.md.
     This is the direction the rule exists for: a global that arrived without
     anyone arguing it against the four tests.
  2. An entry in docs/globals.md with no autoload of that name. Either the
     declaration is stale, or the autoload has not been registered yet. Both are
     the list and reality disagreeing, which is what point 4 forbids.
  3. Both present, different paths. A name that points somewhere other than
     where the list says it does makes the list actively misleading, which is
     worse than not having one.


WHAT IS DELIBERATELY IGNORED

Autoloads whose script lives under addons/. addons/godot_mcp is a licensed,
git-ignored editor tool - present only while the editor is open, never committed
(scripts/checkin.py asserts that) - and an editor plugin may register autoloads
of its own. Those are not architecture this project chose. Failing the build over
a tool that is not even in the repository would teach everyone to ignore this
gate, and a gate people ignore is worse than no gate.


WHAT THIS CANNOT SEE - read before trusting a green run

It compares two lists. It does not judge whether an entry deserves its slot: the
four tests are a human argument and the justification text is not parsed. A
global that is declared, registered and completely unjustifiable passes cleanly.
That is the review, and the point of requiring the justification in writing is
that the review has something to read.

It also cannot see a name made global some other way - a `class_name` with static
methods is reachable from anywhere too, and is not an autoload. That is the same
review matter.


ARGUMENTS

Both inputs can be pointed elsewhere:

    python scripts/check_globals.py --project-file X --globals-doc Y

With no arguments it reads the real project.godot and the real docs/globals.md,
which is how lint.ps1 runs it and the only behaviour that matters in a normal
run. The overrides exist because proving this gate bites in the "an autoload
appeared and nobody declared it" direction otherwise means editing project.godot
- a file that strict typing, the boot, the test suite and any other agent working
in the tree all depend on. A fixture pair costs nothing and touches nothing.


ENCODING

Everything is read as UTF-8 and printed as ASCII. The project's docs are full of
em dashes and a Windows console is cp1252 by default, so a tool that echoes what
it read crashes on the punctuation rather than on the problem (docs/traps.md).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[1]
PROJECT_FILE_RELATIVE = "project.godot"
DECLARATION_RELATIVE = "docs/globals.md"

# An autoload whose script lives here is editor tooling, not project
# architecture. See "What is deliberately ignored" above.
IGNORED_PATH_PREFIXES = ("res://addons/",)

# An .ini section heading: [autoload], [debug], [application].
SECTION_RE = re.compile(r"^\s*\[([^\]]+)\]\s*$")
# `EventBus="*res://src/systems/EventBus.gd"` inside that section.
ENTRY_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$")
# A declaration: a level-3 heading holding a name and a path, both code-spanned.
DECLARATION_RE = re.compile(r"^###\s+`([^`]+)`\s*->\s*`([^`]+)`\s*$", re.MULTILINE)

violations: list[tuple[str, str]] = []


def report(location: str, message: str) -> None:
    violations.append((location, message))


def ascii_only(text: str) -> str:
    """Windows consoles are cp1252; our docs are not."""
    return text.encode("ascii", "replace").decode("ascii")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


# --- Reading the two sides --------------------------------------------------


def normalise_path(raw: str) -> str:
    """Strip the quoting and the engine's global marker off an autoload value.

    project.godot writes `EventBus="*res://src/systems/EventBus.gd"`. The `*`
    means "expose this as a global name"; without it the node still exists at
    /root/EventBus but the bare name does not resolve. Both occupy the name slot
    as far as this rule is concerned - a name at /root is still a name reachable
    from anywhere - so the star is stripped rather than filtered on.
    """
    value = raw.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        value = value[1:-1]
    return value[1:] if value.startswith("*") else value


def registered_autoloads(text: str) -> dict[str, tuple[str, int]]:
    """{name: (script path, line)} for every autoload in project.godot.

    Parsed by hand rather than with configparser: project.godot is .ini-shaped
    but not .ini - it uses ; comments, unquoted values and PackedStringArray()
    calls, and configparser's interpolation chokes on % in a path.

    A missing [autoload] section is not an error here. It means zero autoloads,
    every declaration then fails as "declared but not registered", and the run
    names them - which is the right outcome, because the Godot editor rewriting
    project.godot and dropping settings is a documented trap (docs/traps.md).
    """
    found: dict[str, tuple[str, int]] = {}
    section = ""
    for number, line in enumerate(text.splitlines(), start=1):
        heading = SECTION_RE.match(line)
        if heading is not None:
            section = heading.group(1).strip()
            continue
        if section != "autoload":
            continue
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        entry = ENTRY_RE.match(line)
        if entry is None:
            continue
        path = normalise_path(entry.group(2))
        if path.startswith(IGNORED_PATH_PREFIXES):
            continue
        found[entry.group(1)] = (path, number)
    return found


def strip_fenced_blocks(markdown: str) -> str:
    """Blank out ``` fenced blocks, keeping line numbers intact.

    docs/globals.md documents its own entry format, and that example is a
    heading inside a code fence. Without this the checker reads its own
    instructions as a declaration - the identical mistake check_boundaries.py
    made against docs/events.md the first time it was run.
    """
    out: list[str] = []
    fenced = False
    for line in markdown.splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
            out.append("")
            continue
        out.append("" if fenced else line)
    return "\n".join(out)


def declared_globals(markdown: str) -> dict[str, tuple[str, int]]:
    """{name: (script path, line)} for every entry in docs/globals.md."""
    text = strip_fenced_blocks(markdown)
    found: dict[str, tuple[str, int]] = {}
    for match in DECLARATION_RE.finditer(text):
        line = text.count("\n", 0, match.start()) + 1
        found[match.group(1).strip()] = (match.group(2).strip(), line)
    return found


# --- The comparison ---------------------------------------------------------


def check_lists_agree(
    registered: dict[str, tuple[str, int]],
    declared: dict[str, tuple[str, int]],
    project_label: str,
    declaration_label: str,
) -> None:
    for name in sorted(registered):
        path, line = registered[name]
        if name not in declared:
            report(
                "%s:%d" % (project_label, line),
                "autoload '%s' -> %s occupies a global name slot but is not "
                "declared in %s. A global is reached by bare name, where no "
                "other gate can see the call, so every one is declared and "
                "justified against the four tests (journal 003#4) or it does "
                "not exist. Declare it, or remove the autoload."
                % (name, path, declaration_label),
            )

    for name in sorted(declared):
        path, line = declared[name]
        if name not in registered:
            report(
                "%s:%d" % (declaration_label, line),
                "'%s' -> %s is declared as a global, but %s registers no "
                "autoload by that name. Either the autoload was removed and "
                "this entry is stale, or it has not been registered yet. Fix "
                "whichever one is wrong - the list and reality disagreeing is "
                "exactly what test 4 forbids." % (name, path, project_label),
            )
            continue

        registered_path = registered[name][0]
        if registered_path != path:
            report(
                "%s:%d" % (declaration_label, line),
                "global '%s' is declared as %s but %s registers it as %s. A "
                "name that points somewhere other than where the list says is "
                "worse than an undeclared one: the list is then actively "
                "misleading. Fix whichever one is wrong."
                % (name, path, project_label, registered_path),
            )


# --- Entry point ------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Draywar globals gate: project.godot's autoloads must match "
        "docs/globals.md, in both directions."
    )
    parser.add_argument(
        "--project-file",
        default=str(PROJECT_DIR / PROJECT_FILE_RELATIVE),
        help="the .godot file to read autoloads from (default: the project's)",
    )
    parser.add_argument(
        "--globals-doc",
        default=str(PROJECT_DIR / DECLARATION_RELATIVE),
        help="the declared list to compare against (default: docs/globals.md)",
    )
    args = parser.parse_args()

    project_file = Path(args.project_file)
    declaration_file = Path(args.globals_doc)

    missing = [str(path) for path in (project_file, declaration_file) if not path.is_file()]
    if missing:
        print("SETUP INCOMPLETE:")
        for name in missing:
            print("  - %s is missing" % ascii_only(name))
        return 2

    def label(path: Path, fallback: str) -> str:
        try:
            return path.resolve().relative_to(PROJECT_DIR).as_posix()
        except ValueError:
            return fallback

    project_label = label(project_file, project_file.as_posix())
    declaration_label = label(declaration_file, declaration_file.as_posix())

    registered = registered_autoloads(read(project_file))
    declared = declared_globals(read(declaration_file))
    check_lists_agree(registered, declared, project_label, declaration_label)

    print("")
    print(
        "Globals check: %d autoload(s) in %s, %d declaration(s) in %s."
        % (len(registered), project_label, len(declared), declaration_label)
    )

    if not violations:
        print("Every global name is declared, and every declaration is real.")
        return 0

    print("%d VIOLATION(S):" % len(violations))
    for location, message in violations:
        print("  %s" % ascii_only(location))
        print("      %s" % ascii_only(message))
    print("")
    print("The rule is journal 003#4, ratified by Elliot; the list is %s."
          % declaration_label)
    print("A global is reached by bare name, where no other gate can see it -")
    print("which is exactly why the list is short and changing it is deliberate.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
