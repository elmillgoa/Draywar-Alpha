"""Draywar globals gate - contract P0.6.

Elliot ratified the globals policy verbatim in session 3 (journal 003#4): a thing
may occupy a globally-reachable name slot only if all four tests hold, and the
fourth of them is *this script*. "It is entered in a single declared list with a
one-line justification, AND a check fails the build when the real set and the
declared list disagree." Without the check, points 1-3 are an intention. With it,
adding a global is a visible deliberate act.

This script polices two different ways a name can occupy that kind of slot: an
autoload registered in project.godot, and a `class_name` script under src/ that
declares a top-level `static func` or `static var` and is therefore callable and
mutable from anywhere by bare name with no autoload involved at all (audit
finding #80, decided 2026-08-06 - this header used to name that gap and offer no
mitigation). Both are checked against docs/globals.md, each against its own
catalog, in both directions.

    python scripts/check_globals.py

Exit 0 = clean. Exit 1 = a violation. Exit 2 = setup incomplete.

Run by scripts/lint.ps1 as one of the static gates, and re-proved by
`python scripts/checkin.py --deep`, which builds a throwaway fixture pair - a
.godot file and a globals doc that agree - confirms this script passes on it,
then adds an autoload to the fixture that the doc does not declare and confirms
this script fails and names it. The control run is half the proof: without it a
checker that failed on everything would look like a working gate.

That sentence used to describe fault injection that did not exist anywhere
(audit finding RA-4, fixed 2026-08-06). All three static gates carried the same
false claim. If you change this script's detection, run `--deep` and watch the
proof fail - that is what it is for.


WHY THIS RULE IS WORTH A GATE

An autoload is reached by bare name. `EventBus.on_thing.emit()` carries no
`res://` path and no `class_name`, so it looks exactly like a local variable to
any text scan - and scripts/check_boundaries.py says so itself, under "What this
cannot see". Every other boundary in this project is policed by something.
Name-based access is the one that is not, which is why docs/state.md has carried
it as a blind spot since P0.2.

The risk is not three globals. It is three becoming eleven over a year, because
each addition looks reasonable on its own and nothing ever says no.

A `class_name` carrying a top-level `static func` or `static var` is reached the
identical way - `CareerSave.reset()` carries no `res://` path either, and it is
not an autoload, so nothing above ever saw it. The same year-long drift applies:
one static namespace looks like a convenience, a dozen is ambient global state
that nobody ever had to argue for.


THE PARSING CONTRACT WITH docs/globals.md

The document holds two catalogs, told apart by the arrow in the heading. Both are
level-3 headings holding a name and a script path, each in backticks, and nothing
else on the line:

    ### `EventBus` -> `res://src/systems/EventBus.gd`
    ### `CareerSave` => `res://src/systems/save/CareerSave.gd`

`->` is an autoload; `=>` is a static namespace. They are deliberately different
tokens, not a stylistic accident: a heading meant for one catalog cannot be
misread as an entry in the other, by this script's regexes or by a human
skimming the page.

Everything else on that page - the four tests, the justifications, how to add an
entry - is prose for humans and is not parsed. Fenced ``` blocks are blanked
before either scan, because the document documents its own entry format and both
examples above are headings inside a fence. check_boundaries.py learned this the
hard way against docs/events.md: without the blanking it reads its own
instructions as a real entry.

The autoload path is declared plainly, without the `*` that project.godot writes
in front of it. The star is the engine's marker for "expose this as a global
name"; it is stripped from both sides before comparing, so the declaration reads
as a path and not as engine syntax. A static namespace has no such marker to
strip - a `class_name` script is reachable the moment the file exists; there is
nothing in project.godot to normalise against.


WHAT IS COMPARED FOR AUTOLOADS, IN BOTH DIRECTIONS

  1. An autoload registered in project.godot with no entry in docs/globals.md.
     This is the direction the rule exists for: a global that arrived without
     anyone arguing it against the four tests.
  2. An entry in docs/globals.md with no autoload of that name. Either the
     declaration is stale, or the autoload has not been registered yet. Both are
     the list and reality disagreeing, which is what point 4 forbids.
  3. Both present, different paths. A name that points somewhere other than
     where the list says it does makes the list actively misleading, which is
     worse than not having one.


WHAT IS COMPARED FOR STATIC NAMESPACES, IN BOTH DIRECTIONS

Exactly the same three checks, aimed at the other catalog:

  1. A `class_name` under src/ with a top-level `static func` or `static var`
     and no entry in the `=>` catalog. A static namespace that arrived without
     anyone arguing it against the four tests - same failure as an undeclared
     autoload, same fix.
  2. A `=>` entry with no matching class_name anywhere under src/. Either the
     class was renamed or removed, its static members were removed (it is now a
     plain type and does not belong in this catalog at all), or the entry is
     stale.
  3. Both present, different paths. Same reasoning as the autoload case: a stale
     path is worse than no declaration, because it actively misleads.


WHAT IS DELIBERATELY IGNORED

Autoloads whose script lives under addons/. addons/godot_mcp is a licensed,
git-ignored editor tool - present only while the editor is open, never committed
(scripts/checkin.py asserts that) - and an editor plugin may register autoloads
of its own. Those are not architecture this project chose. Failing the build over
a tool that is not even in the repository would teach everyone to ignore this
gate, and a gate people ignore is worse than no gate.

The static-namespace scan ignores the same addons/ tree, for the same reason,
and it also ignores tests/: test-support code is not architecture the game
ships with, and a helper carrying static methods under tests/ is not a global
anyone is choosing to expose to the game - it is a fixture. Neither directory
sits under src/ today, so against the real tree this exclusion is a no-op; it
exists so a --src-dir fixture used to prove this gate (or a future
reorganisation) cannot smuggle either directory back in unnoticed.

A `class_name` with no top-level `static func` or `static var` is not scanned at
all - a plain type name is not a global. See "WHAT THIS CANNOT SEE" below for
why that is a deliberate line and not an oversight.

A top-level `const` on a `class_name` is likewise out of scope, even on a script
that also declares static members elsewhere in the file. `Balance.SOME_LIMIT` is
reached by bare name exactly the way `CareerSave.reset()` is, but a constant
cannot be reassigned - it reads as data, not as authority, the same reasoning
the Balance*.gd files already lean on for holding tuning numbers instead of
behaviour. Only `static var` (mutable global state) and `static func` (a
callable with no instance gating it) put a script in this catalog. `static var`
is the one that matters most: it is the mutable half.


WHAT THIS CANNOT SEE - read before trusting a green run

It compares lists to reality. It does not judge whether an entry deserves its
slot, in either catalog: the four tests are a human argument and the
justification text is not parsed. A global that is declared, registered (or
scanned), and completely unjustifiable passes cleanly. That is the review, and
the point of requiring the justification in writing is that the review has
something to read.

It now sees a `class_name` reached the way an autoload is. This header used to
read: "a class_name with static methods is reachable from anywhere too, and is
not an autoload. That is the same review matter." That hole is what this script
closes - see "WHAT IS COMPARED FOR STATIC NAMESPACES" above.

It still cannot see a `class_name` with no static member, and that is a
deliberate line, not the same kind of gap. A plain type name - `var ship:
PlayerShip` - carries no ambient authority; nothing reaches through it without
also holding an instance, so it fails test 1 and test 3 before it would ever
reach this script. src/ holds dozens of these (most of src/ui, src/world and
src/entities). Requiring a declaration for every typed reference would make this
gate noisy enough that switching it off starts to look reasonable, which is
precisely the failure check_magic_numbers.py's own header names: "A checker
noisy enough to be switched off is worse than no checker." Excluding plain type
names is what keeps this gate worth keeping on.


ARGUMENTS

All three inputs can be pointed elsewhere:

    python scripts/check_globals.py --project-file X --globals-doc Y --src-dir Z

With no arguments it reads the real project.godot, the real src/, and the real
docs/globals.md, which is how lint.ps1 runs it and the only behaviour that
matters in a normal run. The overrides exist because proving either half of this
gate bites in the "appeared and nobody declared it" direction otherwise means
editing a file real work depends on:

  - project.godot is read by strict typing, the boot, the test suite, and any
    other agent working in the tree.
  - src/ is the game's entire source tree, worked on by other agents and other
    tools at the same time this gate might need proving against it.

A fixture project.godot or a fixture src/ directory costs nothing and touches
neither.


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
SRC_DIR_RELATIVE = "src"

# An autoload whose script lives here is editor tooling, not project
# architecture. See "What is deliberately ignored" above.
IGNORED_PATH_PREFIXES = ("res://addons/",)

# Directories the static-namespace scan skips even if they turn up under
# --src-dir: editor tooling and test fixtures, not architecture the game
# ships with. See "What is deliberately ignored". Matched as an exact path
# component, not a substring, so a real folder named e.g. "addonsloader"
# is not caught by accident.
IGNORED_DIR_NAMES = ("addons", "tests")

# An .ini section heading: [autoload], [debug], [application].
SECTION_RE = re.compile(r"^\s*\[([^\]]+)\]\s*$")
# `EventBus="*res://src/systems/EventBus.gd"` inside that section.
ENTRY_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$")
# An autoload declaration: a level-3 heading holding a name and a path, both
# code-spanned, joined by a thin arrow.
DECLARATION_RE = re.compile(r"^###\s+`([^`]+)`\s*->\s*`([^`]+)`\s*$", re.MULTILINE)
# A static-namespace declaration: the same shape, joined by a fat arrow
# instead, so it cannot be confused with an autoload declaration above.
STATIC_DECLARATION_RE = re.compile(r"^###\s+`([^`]+)`\s*=>\s*`([^`]+)`\s*$", re.MULTILINE)

# `class_name Foo` at the top of a script. class_name is only legal
# unindented, but the leading \s* matches check_boundaries.py's own
# CLASS_NAME_RE for consistency between the two gates.
CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
# A top-level `static func` or `static var`. Anchored to column 0: GDScript
# is indentation-scoped, so a static member of a *nested* inner class is
# indented and does not match here - correct, because this gate is about
# names reachable by bare `Outer.thing()`, not two hops down through an
# instance of Outer.
STATIC_MEMBER_RE = re.compile(r"^(?:static var|static func)\b", re.MULTILINE)

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
    """{name: (script path, line)} for every autoload entry in docs/globals.md.

    The `->` catalog only - see strip_fenced_blocks() and DECLARATION_RE.
    """
    text = strip_fenced_blocks(markdown)
    found: dict[str, tuple[str, int]] = {}
    for match in DECLARATION_RE.finditer(text):
        line = text.count("\n", 0, match.start()) + 1
        found[match.group(1).strip()] = (match.group(2).strip(), line)
    return found


def static_namespaces(src_dir: Path) -> dict[str, tuple[str, int]]:
    """{class_name: (res:// path, line of the class_name declaration)} for
    every .gd file under src_dir that both declares a class_name and declares
    at least one top-level `static func` or `static var`.

    A class_name with no static member is a plain type name, not a global -
    see "WHAT IS DELIBERATELY IGNORED" and "WHAT THIS CANNOT SEE" in the
    module header. A top-level `const` does not count either, even though
    `Balance.SOME_LIMIT` is reached the same way a static var is: a constant
    cannot be reassigned, so it reads as data, the same reasoning the
    Balance*.gd files already lean on.

    src_dir defaults to <project>/src (see ARGUMENTS for why it can be
    pointed elsewhere). addons/ and tests/ are skipped even if they turn up
    under a --src-dir override - see IGNORED_DIR_NAMES.

    A missing src_dir is not an error here; main() already refuses to run
    with a missing --src-dir (setup incomplete, exit 2), so by the time this
    is called the directory exists. The is_dir() guard just keeps this
    function safe to call on its own.
    """
    found: dict[str, tuple[str, int]] = {}
    if not src_dir.is_dir():
        return found
    root = src_dir.resolve().parent
    for path in sorted(src_dir.rglob("*.gd")):
        parts = path.relative_to(src_dir).parts[:-1]
        if any(part in IGNORED_DIR_NAMES for part in parts):
            continue
        text = read(path)
        class_match = CLASS_NAME_RE.search(text)
        if class_match is None:
            continue
        if STATIC_MEMBER_RE.search(text) is None:
            continue
        line = text.count("\n", 0, class_match.start()) + 1
        res_path = "res://" + path.resolve().relative_to(root).as_posix()
        found[class_match.group(1)] = (res_path, line)
    return found


def declared_static_namespaces(markdown: str) -> dict[str, tuple[str, int]]:
    """{name: (res:// path, line)} for every static-namespace entry in
    docs/globals.md.

    The `=>` catalog only - see strip_fenced_blocks() and
    STATIC_DECLARATION_RE. Distinct from declared_globals() above so the two
    catalogs can never be conflated even by accident.
    """
    text = strip_fenced_blocks(markdown)
    found: dict[str, tuple[str, int]] = {}
    for match in STATIC_DECLARATION_RE.finditer(text):
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


def check_static_namespaces_agree(
    scanned: dict[str, tuple[str, int]],
    declared: dict[str, tuple[str, int]],
    src_label: str,
    declaration_label: str,
) -> None:
    """Same shape as check_lists_agree(), aimed at the `=>` catalog.

    Kept as a separate function rather than a generalised one so the autoload
    check above is provably unchanged - see "WHAT IS COMPARED FOR STATIC
    NAMESPACES" in the module header.
    """
    for name in sorted(scanned):
        path, line = scanned[name]
        location = path[len("res://"):] if path.startswith("res://") else path
        if name not in declared:
            report(
                "%s:%d" % (location, line),
                "class '%s' -> %s declares a top-level static func or static "
                "var and is reachable from anywhere by bare name (e.g. "
                "'%s.thing()') with no autoload involved, but is not declared "
                "in %s. That is the same kind of global slot an autoload "
                "occupies, argued the same way (journal 003#4): declare it "
                "with a justification, or remove the static member and let "
                "it go back to being a plain type name."
                % (name, path, name, declaration_label),
            )

    for name in sorted(declared):
        path, line = declared[name]
        if name not in scanned:
            report(
                "%s:%d" % (declaration_label, line),
                "'%s' -> %s is declared as a static namespace, but %s has no "
                "class_name '%s' with a top-level static func or static var. "
                "Either the class was renamed or removed, its static members "
                "were removed (it is now a plain type and does not belong "
                "here), or this entry is stale. Fix whichever one is wrong - "
                "the list and reality disagreeing is exactly what test 4 "
                "forbids." % (name, path, src_label, name),
            )
            continue

        scanned_path = scanned[name][0]
        if scanned_path != path:
            report(
                "%s:%d" % (declaration_label, line),
                "static namespace '%s' is declared as %s but the real class "
                "lives at %s. A name that points somewhere other than where "
                "the list says is worse than an undeclared one: the list is "
                "then actively misleading. Fix whichever one is wrong."
                % (name, path, scanned_path),
            )


# --- Entry point ------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Draywar globals gate: project.godot's autoloads and src/'s "
        "static namespaces must each match their catalog in docs/globals.md, "
        "in both directions."
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
    parser.add_argument(
        "--src-dir",
        default=str(PROJECT_DIR / SRC_DIR_RELATIVE),
        help="the tree to scan for static-namespace class_name scripts "
        "(default: <project>/src)",
    )
    args = parser.parse_args()

    project_file = Path(args.project_file)
    declaration_file = Path(args.globals_doc)
    src_dir = Path(args.src_dir)

    checks = (
        (project_file, project_file.is_file()),
        (declaration_file, declaration_file.is_file()),
        (src_dir, src_dir.is_dir()),
    )
    missing = [str(path) for path, ok in checks if not ok]
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
    src_label = label(src_dir, src_dir.as_posix())

    registered = registered_autoloads(read(project_file))
    declaration_text = read(declaration_file)
    declared = declared_globals(declaration_text)
    check_lists_agree(registered, declared, project_label, declaration_label)

    scanned_static = static_namespaces(src_dir)
    declared_static = declared_static_namespaces(declaration_text)
    check_static_namespaces_agree(
        scanned_static, declared_static, src_label, declaration_label
    )

    print("")
    print(
        "Globals check: %d autoload(s) in %s, %d declaration(s) in %s."
        % (len(registered), project_label, len(declared), declaration_label)
    )
    print(
        "Static namespaces: %d found under %s, %d declaration(s) in %s."
        % (len(scanned_static), src_label, len(declared_static), declaration_label)
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
