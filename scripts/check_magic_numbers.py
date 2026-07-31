"""Draywar balance gate - contract P0.3.

CLAUDE.md section 3: "No magic numbers. Every tunable lives in the balance
constants file." That is now a small layer rather than a single file -
src/data/Balance.gd and everything beside it in src/data/balance/. This makes
the rule fail a build instead of relying on review.

    python scripts/check_magic_numbers.py

Exit 0 = clean. Exit 1 = a violation. Exit 2 = setup incomplete.

Run by scripts/lint.ps1 as one of the static gates, and re-proved by
`python scripts/checkin.py --deep`, which writes a deliberate magic number into
src/ and confirms this script catches and names it.


WHY THIS RULE IS WORTH A GATE

A tunable that leaks into a system is a tunable nothing can reach. Difficulty
modes (Destination section 9) are meant to be a re-read of one file; every
number that got inlined somewhere is a number no difficulty mode, no balance
pass and no designer can change. The cost of a leak is invisible at the moment
it happens and expensive a year later, which is exactly the shape of problem a
build gate is for.


WHAT IS SCANNED

Every .gd file under src/ - the game. Three deliberate exclusions:

  * **the balance layer**, which is the point of the exercise:
    src/data/Balance.gd, and every .gd under src/data/balance/.

    That is deliberately a RULE and not a list. It was a list of one until P3.5,
    when the single balance file reached gdlint's thousand-line ceiling and was
    split by domain into Balance, BalanceFlight, BalanceCombat, BalanceNpc and
    BalanceWorld. A list of five would work today and would be wrong on exactly
    one day - the day somebody adds a sixth and cannot work out why this gate is
    shouting at a file full of nothing but tunables. Naming the directory means a
    new balance file is exempt because of where it is, which is a fact anybody
    can see, rather than because somebody remembered to come here.

    Nothing else under src/data is exempt, and that matters: shapes, readouts and
    placements live there too and are scanned like any other file. The exemption
    is the balance layer, not the data layer.
  * tests/, which asserts against literal expected values by its nature. A test
    that says `assert_eq(count, 3)` is doing its job; forcing it to say
    `assert_eq(count, Balance.SOMETHING)` would make it assert that the code
    agrees with itself, which is not a test.
  * scripts/, which is developer tooling and does not ship. Its numbers - frame
    counts, timeouts, exit codes - are not game tunables and Balance.gd is not
    where anyone would look for them.

Scene and resource files are not scanned. A .tscn is full of engine-written
transform numbers, and a .tres IS content - putting numbers there is the
arrangement working, not failing.


WHAT IS TOLERATED, AND WHY

A checker noisy enough to be switched off is worse than no checker, so the list
below is deliberate. Everything not on it is a violation.

  1. **0 and 1** (and 0.0, 1.0, and negated forms). Empty, first, identity,
     "one more", "not found". These are structural facts about counting, not
     decisions anybody would tune. Every other value must be named - including
     2 and 100. If a structural constant like "percent" starts appearing, the
     answer is to name it in the balance layer, not to widen this list; widening
     it is how a gate stops meaning anything.

  2. **Subscripts** - the 2 in `parts[2]`. An index is a position in a
     structure, and the structure is the thing that decides it. Note this is a
     subscript specifically: `[` following an identifier or a closing bracket.
     An array *literal* of numbers, `[10, 20, 30]`, is data and is caught.

  3. **Enum bodies.** `enum Phase { EARLY = 0, MID = 1 }` - explicit ordinals
     are identity, not magnitude.

  4. **@export annotation arguments** - the bounds in
     `@export_range(0, 250) var speed: float`. Those configure the inspector,
     not the game. The *default value* is outside the annotation
     (`@export var speed: float = 250.0`) and is caught, which is the right
     split: the editor hint is presentation, the default is balance.

  5. **Version numbers** - any `const`/`var` declaration whose name contains
     "version". A schema version is an identity, and bumping one is not tuning.

Comments and string literals are removed before anything is examined, so a
number in a docstring or in a "%d" format is not a violation. The removal is a
character scan rather than a regex because a `#` inside a string is not a
comment and a quote inside a comment does not open a string.


ENCODING

Everything is read as UTF-8 and printed as ASCII, because the project's docs and
comments are full of em dashes and a Windows console is cp1252 by default
(docs/traps.md).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = PROJECT_DIR / "src"

# The balance layer: the entry file, and the directory of domain files beside it.
# See "WHAT IS SCANNED" above for why this is two locations and not five names.
BALANCE_RELATIVE = "src/data/Balance.gd"
BALANCE_DIR_RELATIVE = "src/data/balance"
BALANCE_LAYER = "%s and %s/" % (BALANCE_RELATIVE, BALANCE_DIR_RELATIVE)

# Values that are structure rather than balance. See tolerance 1 above.
TOLERATED_VALUES = (0.0, 1.0)

# A numeric literal in code. The lookbehind keeps it from matching inside an
# identifier: the 3 of Vector3, the 8 of to_utf8_buffer, the 5 of 1.5 (which is
# matched whole, starting at the 1).
NUMBER_RE = re.compile(
    r"(?<![A-Za-z0-9_.])"
    r"(?:0[xX][0-9a-fA-F_]+"
    r"|0[bB][01_]+"
    r"|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?"
    r"|\.\d[\d_]*(?:[eE][+-]?\d+)?)"
)

# `const NAME` / `var NAME`, used only to spot version declarations.
DECLARATION_RE = re.compile(r"\b(?:const|var)\s+([A-Za-z_][A-Za-z0-9_]*)")

# An annotation immediately before an open paren: `@export_range(`.
ANNOTATION_RE = re.compile(r"@([A-Za-z_][A-Za-z0-9_]*)\s*$")

# `enum` or `enum Name` immediately before an open brace.
ENUM_RE = re.compile(r"\benum(?:\s+[A-Za-z_][A-Za-z0-9_]*)?\s*$")

violations: list[tuple[str, str]] = []


def ascii_only(text: str) -> str:
    return text.encode("ascii", "replace").decode("ascii")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def rel(path: Path) -> str:
    return path.relative_to(PROJECT_DIR).as_posix()


def literal_value(literal: str) -> float | None:
    text = literal.replace("_", "")
    try:
        if text[:2].lower() == "0x":
            return float(int(text, 16))
        if text[:2].lower() == "0b":
            return float(int(text, 2))
        return float(text)
    except ValueError:
        return None


def analyse(text: str) -> tuple[str, list[bool]]:
    """Return (code, tolerated) - two views of the file, character for character.

    `code` is the source with comments and string bodies replaced by spaces and
    newlines preserved, so offsets and line numbers still line up with the file
    on disk. `tolerated[i]` is True where a number at offset i sits inside a
    construct from the tolerance list - a subscript, an enum body, or an @export
    annotation's arguments.

    Scanned by character rather than by regex because the two are not
    separable otherwise: a '#' inside a string does not start a comment, and a
    quote inside a comment does not start a string.
    """
    code: list[str] = []
    tolerated: list[bool] = []
    # Open brackets, each with whether its contents are tolerated.
    stack: list[bool] = []

    def inside_tolerated() -> bool:
        return any(stack)

    def emit(char: str, ok: bool) -> None:
        code.append(char)
        tolerated.append(ok)

    def blank(chunk: str) -> None:
        for char in chunk:
            emit("\n" if char == "\n" else " ", False)

    index = 0
    length = len(text)
    while index < length:
        char = text[index]

        if char == "#":
            start = index
            while index < length and text[index] != "\n":
                index += 1
            blank(text[start:index])
            continue

        if char in "\"'":
            quote = char
            triple = text[index : index + 3] == quote * 3
            start = index
            index += 3 if triple else 1
            while index < length:
                if text[index] == "\\" and index + 1 < length:
                    index += 2
                    continue
                if triple and text[index : index + 3] == quote * 3:
                    index += 3
                    break
                if not triple and text[index] == quote:
                    index += 1
                    break
                if text[index] == "\n" and not triple:
                    break  # Unterminated; the compiler complains, not us.
                index += 1
            blank(text[start:index])
            continue

        if char in "([{":
            prefix = "".join(code).rstrip()
            opens = False
            if char == "(":
                match = ANNOTATION_RE.search(prefix)
                opens = match is not None and match.group(1).startswith("export")
            elif char == "[":
                # A subscript, not an array literal: `foo[2]` and `Array[int]`
                # end in an identifier or a closing bracket; `= [1, 2]` does not.
                opens = bool(prefix) and (prefix[-1].isalnum() or prefix[-1] in "_)]")
            else:
                opens = ENUM_RE.search(prefix) is not None
            stack.append(opens)
            emit(char, inside_tolerated())
            index += 1
            continue

        if char in ")]}":
            emit(char, inside_tolerated())
            if stack:
                stack.pop()
            index += 1
            continue

        emit(char, inside_tolerated())
        index += 1

    return "".join(code), tolerated


def line_of(code: str, offset: int) -> int:
    return code.count("\n", 0, offset) + 1


def line_text(code: str, offset: int) -> str:
    start = code.rfind("\n", 0, offset) + 1
    end = code.find("\n", offset)
    return code[start:] if end == -1 else code[start:end]


def is_balance_file(path: Path) -> bool:
    """Is this part of the balance layer, and therefore where numbers belong?

    A rule, not a list: the entry file, plus anything in the directory of domain
    files beside it. A balance file added tomorrow is exempt because of where it
    sits, with no edit here - which is the whole point, because an exemption list
    is a thing to forget exactly once.
    """
    relative = rel(path)
    return relative == BALANCE_RELATIVE or relative.startswith(BALANCE_DIR_RELATIVE + "/")


def scanned_files() -> list[Path]:
    if not SRC_DIR.is_dir():
        return []
    return [path for path in sorted(SRC_DIR.rglob("*.gd")) if not is_balance_file(path)]


def check_file(path: Path) -> int:
    """Report every untolerated numeric literal. Returns how many were examined."""
    code, tolerated = analyse(read(path))
    examined = 0

    for match in NUMBER_RE.finditer(code):
        literal = match.group(0)
        examined += 1

        if tolerated[match.start()]:
            continue

        value = literal_value(literal)
        if value is not None and value in TOLERATED_VALUES:
            continue

        declaration = DECLARATION_RE.search(line_text(code, match.start()))
        if declaration is not None and "version" in declaration.group(1).lower():
            continue

        violations.append(
            (
                "%s:%d" % (rel(path), line_of(code, match.start())),
                "magic number '%s'. Every tunable lives in the balance layer - %s "
                "(CLAUDE.md section 3) - name it in whichever of those files owns the "
                "domain and read it back as Balance.THE_NAME, BalanceFlight.THE_NAME, "
                "BalanceCombat.THE_NAME, BalanceNpc.THE_NAME or BalanceWorld.THE_NAME. "
                "Only 0 and 1, subscripts, enum ordinals, @export hints and version "
                "numbers are allowed inline; see this script's header before adding to "
                "that list." % (literal, BALANCE_LAYER),
            )
        )

    return examined


def main() -> int:
    missing: list[str] = []
    if not SRC_DIR.is_dir():
        missing.append("src/ is missing")
    if not (PROJECT_DIR / BALANCE_RELATIVE).exists():
        missing.append(
            "%s is missing. It is the balance layer's entry file and contract "
            "P0.3 requires it to exist." % BALANCE_RELATIVE
        )
    if not (PROJECT_DIR / BALANCE_DIR_RELATIVE).is_dir():
        missing.append(
            "%s/ is missing. It holds the balance layer's domain files, and its "
            "absence would silently make every number in them a violation."
            % BALANCE_DIR_RELATIVE
        )
    if missing:
        print("SETUP INCOMPLETE:")
        for item in missing:
            print("  - %s" % item)
        return 2

    files = scanned_files()
    examined = sum(check_file(path) for path in files)

    exempt = sum(1 for path in SRC_DIR.rglob("*.gd") if is_balance_file(path))
    print("")
    print(
        "Balance check: %d file(s) under src/, %d numeric literal(s). "
        "%d balance file(s) exempt (%s)."
        % (len(files), examined, exempt, BALANCE_LAYER)
    )

    if not violations:
        print("No magic numbers outside the balance layer.")
        return 0

    print("%d VIOLATION(S):" % len(violations))
    for location, message in violations:
        print("  %s" % ascii_only(location))
        print("      %s" % ascii_only(message))
    print("")
    print("The rule is in CLAUDE.md section 3; the balance layer is %s." % BALANCE_LAYER)
    return 1


if __name__ == "__main__":
    sys.exit(main())
