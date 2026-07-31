"""Draywar architecture gate - contract P0.2.

The EventBus rule (CLAUDE.md section 3) is the one architectural decision every
later contract inherits: **cross-system communication goes through the bus,
never a direct reference across a boundary.** A rule that lives only in prose is
a rule that gets skimmed. This makes it fail the build.

    python scripts/check_boundaries.py

Exit 0 = clean. Exit 1 = a violation. Exit 2 = setup incomplete.

Run by scripts/lint.ps1 as one of the static gates, and re-proved by
`python scripts/checkin.py --deep`, which writes a deliberate violation into
src/ and confirms this script catches and names it.


WHAT COUNTS AS A BOUNDARY

src/ has five layers. Four of them decide things and must not know about each
other; the fifth is content everybody may read.

    src/systems    services and rules engines
    src/entities   things with a transform in the 3D world
    src/ui         everything the player reads
    src/world      the places those things exist in - scenes, not objects
    src/data       content and tunable numbers - readable by anyone

src/world was added by P1.1 and added to DECIDING_LAYERS in the same commit,
which is the whole point of it: a fourth top-level directory that this script
did not walk would be neither scanned as a source nor visible as a reference
target, so an entire layer would have opted out of the project's central gate
and nothing would have said so. A world scene holds no ship and a ship scene
holds no world; src/Main.gd - the composition root, exempt here by design -
is what joins them.

Inside src/systems there is a second, finer boundary: **one system is one
immediate child of src/systems** - either a single .gd file, or a directory and
everything under it. A system that grows past one file gets a directory of its
own, and the files inside it may refer to each other freely; that is one system
talking to itself. Two different children of src/systems may not.


THE FIVE RULES

  1. Cross-layer. No file in systems/entities/ui/world may statically reference
     a file in a different one of those four. src/data is exempt as a target.
  2. Cross-system. No system may statically reference another system. EventBus
     is exempt - it is the sanctioned channel. src/data is exempt here too, and
     that exemption has to be stated twice because the first version of this
     file only stated it once: rule 2 fell through to *any* target outside the
     source system, so a system reading src/data/Balance.gd was reported as
     "system 'systems/Foo.gd' references system 'data'". src/data is not a
     system. Every system is expected to read it - src/systems/README.md says
     tunables live there - so the bug made the documented arrangement
     unbuildable. Found by contract P0.3, whose content loader is the first
     system that had to read data.
  3. The bus is a pipe. src/systems/EventBus.gd references nothing under src/ at
     all, including data. If it ever needs to know something, that logic belongs
     in a system that listens.
  4. Every bus signal is fully typed. The engine covers this too - verified,
     4.6.1 rejects `signal foo(a)` with `Parameter "a" has no static type` - but
     only while `untyped_declaration=2` is in project.godot, and the editor is
     documented to rewrite that file and drop settings (docs/traps.md). This
     check does not depend on any project setting, so the bus stays typed even
     if the engine's enforcement is weakened.
  5. The catalog matches the bus. Every signal in EventBus.gd appears in
     docs/events.md with an identical signature, and vice versa. CLAUDE.md
     requires the catalog to be updated in the same commit that adds a signal;
     this is what makes that true rather than aspirational.


WHAT THIS CANNOT SEE - read before trusting a green run

Static text analysis catches static references. It does not catch:

  * a path assembled at runtime - `load("res://src/" + layer + "/Thing.gd")`;
  * a node found by walking the tree - `get_parent().get_child(0)`, or a
    NodePath that arrives from a scene file or an export;
  * a reference passed in as an argument by a third party;
  * **a reference through an autoload global.** `EventBus` and `ContentLibrary`
    are reached by bare name, with no path and no class_name, so nothing here
    matches them. Deliberate for both - docs/events.md states the rule: a signal
    has no return value, so a system that must *ask* something exposes a method
    and the caller reaches it as an autoload rather than as a node reference.
    The consequence is that WHICH globals exist is a design decision this
    checker does not police. Adding a third is a decision, not a convenience.

Those are review matters, and the runtime tests in tests/ are the other half of
the proof: they run each demo system with the other one absent and assert it
still works, which no amount of text scanning can establish.

Within one layer, entity-to-entity and ui-to-ui references are deliberately NOT
flagged. A ship scene containing a turret and a HUD built from panels are both
legitimate composition. The directory READMEs forbid reaching into another
entity's *internals*, which is a judgement no text scan can make.


ENCODING

Everything is read as UTF-8 and printed as ASCII. The project's docs are full of
em dashes and a Windows console is cp1252 by default, so a tool that echoes what
it read crashes on the punctuation rather than on the problem (docs/traps.md).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = PROJECT_DIR / "src"
BUS_RELATIVE = "src/systems/EventBus.gd"
CATALOG_RELATIVE = "docs/events.md"

# The four layers that must not know about each other. src/data is content and
# is deliberately absent: everything is allowed to read it.
#
# Adding a directory here is what brings a new layer under the gate. A layer
# left out of this tuple is not scanned AND is not recognised as a target, so
# references both out of it and into it are invisible - which is silence, not a
# pass. P1.1 added "world" and proved the extension bites before trusting it.
DECIDING_LAYERS = ("systems", "entities", "ui", "world")

# File types that can carry a reference. .tscn and .tres matter as much as .gd -
# wiring two layers together in the editor produces an ext_resource line, and
# that is exactly as much of a violation as a preload.
SCANNED_SUFFIXES = (".gd", ".tscn", ".tres")

RES_PATH_RE = re.compile(r"res://src/[A-Za-z0-9_./-]+")
CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
# Multi-line parameter lists are legal GDScript (gdformat wraps long signals).
SIGNAL_RE = re.compile(
    r"^signal\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:\((.*?)\))?",
    re.MULTILINE | re.DOTALL,
)
# A catalog entry is a level-3 heading holding nothing but a code-spanned
# signature: ### `on_demo_probe_sent(sequence: int, sender: StringName)`
CATALOG_ENTRY_RE = re.compile(r"^###\s+`([^`]+)`\s*$", re.MULTILINE)

violations: list[tuple[str, str]] = []


def report(location: str, message: str) -> None:
    violations.append((location, message))


def ascii_only(text: str) -> str:
    """Windows consoles are cp1252; our docs are not."""
    return text.encode("ascii", "replace").decode("ascii")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def rel(path: Path) -> str:
    return path.relative_to(PROJECT_DIR).as_posix()


# --- Reading GDScript without being fooled by its own text ------------------


def split_code_and_strings(text: str) -> tuple[str, list[tuple[int, str]]]:
    """Separate GDScript source into executable text and string literals.

    Two different rules need two different views of a file. Path references live
    *inside* string literals, so a comment that happens to name a path is
    documentation and not a reference. Class-name references live in the code,
    so a class name mentioned in a comment or inside a string is not one either.

    Returns (code with comments and string bodies removed, [(line, literal)]).
    """
    code: list[str] = []
    literals: list[tuple[int, str]] = []

    index = 0
    line = 1
    length = len(text)
    while index < length:
        char = text[index]

        if char == "\n":
            code.append("\n")
            line += 1
            index += 1
            continue

        if char == "#":
            while index < length and text[index] != "\n":
                index += 1
            continue

        if char in "\"'":
            quote = char
            start_line = line
            triple = text[index:index + 3] == quote * 3
            index += 3 if triple else 1
            buffer: list[str] = []
            while index < length:
                if text[index] == "\\" and index + 1 < length:
                    if text[index + 1] == "\n":
                        line += 1
                    buffer.append(text[index + 1])
                    index += 2
                    continue
                if triple and text[index:index + 3] == quote * 3:
                    index += 3
                    break
                if not triple and text[index] == quote:
                    index += 1
                    break
                if text[index] == "\n":
                    line += 1
                    if not triple:
                        break  # Unterminated: the compiler will say so, not us.
                buffer.append(text[index])
                index += 1
            literals.append((start_line, "".join(buffer)))
            code.append(" ")
            continue

        code.append(char)
        index += 1

    return "".join(code), literals


# --- Boundaries -------------------------------------------------------------


def layer_of(relative_path: str) -> str:
    """'src/systems/foo/Bar.gd' -> 'systems'. Empty string if outside src/."""
    parts = relative_path.split("/")
    if len(parts) < 3 or parts[0] != "src":
        return ""
    return parts[1]


def unit_of(relative_path: str) -> str:
    """The boundary a file belongs to.

    One system is one immediate child of src/systems, so:
        src/systems/EventBus.gd          -> systems/EventBus.gd
        src/systems/jurisdiction/Any.gd  -> systems/jurisdiction
    Outside src/systems the layer itself is the unit; finer boundaries there are
    a review matter, not something a text scan can judge.
    """
    parts = relative_path.split("/")
    layer = layer_of(relative_path)
    if not layer:
        return ""
    if layer != "systems":
        return layer
    return "systems/" + parts[2]


def scanned_files() -> list[Path]:
    found: list[Path] = []
    for layer in DECIDING_LAYERS:
        layer_dir = SRC_DIR / layer
        if not layer_dir.is_dir():
            continue
        for path in sorted(layer_dir.rglob("*")):
            if path.is_file() and path.suffix in SCANNED_SUFFIXES:
                found.append(path)
    return found


def class_name_index() -> dict[str, str]:
    """Every `class_name X` declared anywhere under src/, mapped to its file."""
    index: dict[str, str] = {}
    if not SRC_DIR.is_dir():
        return index
    for path in sorted(SRC_DIR.rglob("*.gd")):
        code, _ = split_code_and_strings(read(path))
        for match in CLASS_NAME_RE.finditer(code):
            index[match.group(1)] = rel(path)
    return index


def references_in(path: Path) -> list[tuple[int, str, str]]:
    """(line, target relative path, how it was referenced) for one file."""
    text = read(path)
    found: list[tuple[int, str, str]] = []

    if path.suffix == ".gd":
        code, literals = split_code_and_strings(text)
        for line, literal in literals:
            for match in RES_PATH_RE.finditer(literal):
                found.append((line, match.group(0)[len("res://"):], "path"))
        classes = class_name_index()
        for name, owner in classes.items():
            if owner == rel(path):
                continue
            for match in re.finditer(r"\b%s\b" % re.escape(name), code):
                line = code.count("\n", 0, match.start()) + 1
                found.append((line, owner, "class_name %s" % name))
    else:
        for match in RES_PATH_RE.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            found.append((line, match.group(0)[len("res://"):], "resource path"))

    return found


def check_boundaries() -> None:
    for path in scanned_files():
        source = rel(path)
        source_layer = layer_of(source)
        source_unit = unit_of(source)
        is_bus = source == BUS_RELATIVE

        for line, target, how in references_in(path):
            if target == source:
                continue
            target_layer = layer_of(target)
            if not target_layer:
                continue

            if is_bus:
                report(
                    "%s:%d" % (source, line),
                    "the bus references %s (%s). EventBus.gd is a pipe: it must "
                    "reference nothing under src/, not even data." % (target, how),
                )
                continue

            if target == BUS_RELATIVE:
                continue  # The sanctioned channel.

            if target_layer in DECIDING_LAYERS and target_layer != source_layer:
                report(
                    "%s:%d" % (source, line),
                    "src/%s reaches directly into src/%s -> %s (%s). "
                    "Cross-layer traffic goes through the EventBus."
                    % (source_layer, target_layer, target, how),
                )
            elif (
                source_layer == "systems"
                and target_layer == "systems"
                and unit_of(target) != source_unit
            ):
                report(
                    "%s:%d" % (source, line),
                    "system '%s' references system '%s' directly -> %s (%s). "
                    "Systems talk to each other through the EventBus only."
                    % (source_unit, unit_of(target), target, how),
                )


# --- The bus's own signals --------------------------------------------------


def split_parameters(argument_text: str) -> list[str]:
    """Split a parameter list on top-level commas.

    `Array[int]` and a default of `Vector2(1, 2)` both contain commas that are
    not separators, so bracket depth is tracked rather than calling .split(",").
    """
    parts: list[str] = []
    depth = 0
    current: list[str] = []
    for char in argument_text:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            parts.append("".join(current))
            current = []
            continue
        current.append(char)
    if "".join(current).strip():
        parts.append("".join(current))
    return [part.strip() for part in parts if part.strip()]


def bus_signals(bus_text: str) -> list[tuple[str, str, list[str]]]:
    """(name, normalised signature, parameters) for every signal in EventBus.gd."""
    code, _ = split_code_and_strings(bus_text)
    out: list[tuple[str, str, list[str]]] = []
    for match in SIGNAL_RE.finditer(code):
        name = match.group(1)
        raw_params = match.group(2) or ""
        # Collapse whitespace so multi-line signals match the catalog line.
        raw_params = " ".join(raw_params.split())
        params = split_parameters(raw_params)
        out.append((name, "%s(%s)" % (name, ", ".join(params)), params))
    return out


def check_signals_are_typed(signals: list[tuple[str, str, list[str]]]) -> None:
    for name, _signature, params in signals:
        for param in params:
            declaration = param.split("=")[0]
            if ":" not in declaration:
                report(
                    BUS_RELATIVE,
                    "signal %s has an untyped parameter '%s'. The engine normally "
                    "rejects this too, but only while untyped_declaration=2 "
                    "survives in project.godot; the bus is checked regardless."
                    % (name, declaration.strip()),
                )


def strip_fenced_blocks(markdown: str) -> str:
    """Blank out ``` fenced blocks, keeping line numbers intact.

    docs/events.md documents its own entry format, and that example is a heading
    inside a code fence. Without this the checker reads its own instructions as a
    catalog entry and fails - which it did, the first time it was run.
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


def check_catalog_matches(signals: list[tuple[str, str, list[str]]]) -> None:
    catalog_path = PROJECT_DIR / CATALOG_RELATIVE
    documented = {
        " ".join(match.group(1).split()): match.group(1)
        for match in CATALOG_ENTRY_RE.finditer(strip_fenced_blocks(read(catalog_path)))
    }
    declared = {" ".join(signature.split()): signature for _n, signature, _p in signals}

    for key, signature in sorted(declared.items()):
        if key not in documented:
            report(
                CATALOG_RELATIVE,
                "signal `%s` is declared in %s but is not in the catalog. "
                "CLAUDE.md section 3: a new signal is documented in the same "
                "commit that introduces it." % (signature, BUS_RELATIVE),
            )
    for key, signature in sorted(documented.items()):
        if key not in declared:
            report(
                CATALOG_RELATIVE,
                "the catalog documents `%s`, which no longer exists in %s (or "
                "whose signature has changed). Fix whichever one is wrong."
                % (signature, BUS_RELATIVE),
            )


# --- Entry point ------------------------------------------------------------


def main() -> int:
    missing = [
        name
        for name in (BUS_RELATIVE, CATALOG_RELATIVE)
        if not (PROJECT_DIR / name).exists()
    ]
    if not SRC_DIR.is_dir():
        missing.append("src/")
    if missing:
        print("SETUP INCOMPLETE:")
        for name in missing:
            print("  - %s is missing" % name)
        return 2

    signals = bus_signals(read(PROJECT_DIR / BUS_RELATIVE))
    check_boundaries()
    check_signals_are_typed(signals)
    check_catalog_matches(signals)

    files = scanned_files()
    print("")
    print("Architecture check: %d file(s) under src/, %d bus signal(s)."
          % (len(files), len(signals)))

    if not violations:
        print("No boundary violations; the signal catalog matches the bus.")
        return 0

    print("%d VIOLATION(S):" % len(violations))
    for location, message in violations:
        print("  %s" % ascii_only(location))
        print("      %s" % ascii_only(message))
    print("")
    print("The rule is in CLAUDE.md section 3; the catalog is docs/events.md.")
    print("Cross-boundary traffic goes through the EventBus - see")
    print("src/systems/DemoProbeSystem.gd for the worked example.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
