"""Draywar group-locator gate - audit finding #79 (Major).

scripts/check_boundaries.py polices res://src/ path references and class_name
uses. Its rule 1 forbids a file in systems/entities/ui/world statically
referencing a different one of those four; its rule 2 forbids one system
statically referencing another, with EventBus as the only sanctioned channel.

The codebase reaches across both boundaries constantly by a route that carries
**no path and no class name**: a Godot group lookup.

    var wallet: Node = tree.get_first_node_in_group(&"wallet_service")

is a service locator. It is text check_boundaries.py cannot see at all - no
`res://` path, no class_name - so 85 call sites reach across a policed
boundary through a gate that was built to police exactly that, and never
fires. 37 of those 85 sites are in src/systems; 21 of those 37 reach another
system, the exact thing rule 2 exists to forbid.

Two ways to close that hole were on the table. Forbidding the mechanism
breaks 37 working call sites and amounts to redesigning the architecture,
which this fix must not do. Sanctioning it by name is the blanket exemption
an architecture gate cannot survive. So: **the group lookup stays a
sanctioned pattern, but it becomes a declared and inventoried one**, policed
the same way an autoload is (scripts/check_globals.py, docs/globals.md).

    python scripts/check_groups.py

Exit 0 = clean. Exit 1 = a violation. Exit 2 = setup incomplete.

Intended to run alongside check_boundaries.py and check_globals.py as one of
lint.ps1's static gates (wired up separately - this script only adds itself
to the tree and does not touch lint.ps1).


WHAT COUNTS AS A GROUP LOOKUP

Three calls, anywhere under src/:

    add_to_group(...)             - a node declares its own membership
    get_first_node_in_group(...)  - the service-locator read
    get_nodes_in_group(...)       - the same read, plural

`is_in_group(...)` is deliberately not among them - see WHAT THIS CANNOT SEE.

A `.tscn` can also assign membership via a `groups=[...]` property on a
`[node]` line. No scene under src/ does this today (2 real project scenes
exist - Main.tscn and src/ui/console/DebugConsole.tscn - and zero set
`groups=`), but the day one does, this gate has to see it or the whole point
of the inventory is defeated by an editor checkbox nobody thought to police.
So .tscn is scanned too, even though the branch is unexercised today.


HOW A GROUP NAME IS RESOLVED

The literal argument to one of the three calls is read as:

  1. A string or StringName literal - `"wallet_service"` or `&"wallet_service"`.
  2. A `BalanceX.GROUP_Y` constant reference, resolved by parsing the actual
     `const GROUP_Y: StringName = &"..."` declaration out of every `.gd`
     under src/data/ (that is where every one of the project's 11 GROUP_*
     constants lives, in src/data/balance/*.gd, keyed by each file's own
     `class_name`).
  3. Anything else - a bare variable, a parameter, a computed expression -
     resolves to nothing. That call site is dynamic. See below.


THE REGISTRY: docs/groups.md

Every group name this gate finds - added, looked up, or scene-assigned -
must have an entry in docs/groups.md naming: which layer produces it, which
file(s) actually add it, and which layers are permitted to look it up. The
registry is read fresh every run, parsed off level-3 headings exactly the
way docs/globals.md is read by check_globals.py, and `strip_fenced_blocks()`
blanks out the doc's own worked example before parsing - the same trap
check_boundaries.py hit against docs/events.md the first time it ran, and
check_globals.py hit against docs/globals.md right after: a document that
documents its own entry format reads its own instructions as a real entry
if fenced code isn't blanked first.


THE FIVE FAILURE MODES (exit 1)

  1. A group is added or looked up that has no entry in docs/groups.md. This
     is the direction the whole gate exists for: a lookup that appeared with
     nobody arguing it against a boundary.
  2. A lookup reaches a declared group from a layer the registry does not
     list as permitted for it. The registry records where each group is
     ACTUALLY reached from today; a new reach from a new layer is a new
     boundary crossing and has to be a deliberate edit to the registry, not
     a side effect of adding a line of GDScript.
  3. A registry entry's declared producer file no longer adds that group (or
     never did) in the current tree. The list and reality disagreeing is
     exactly what check_globals.py's test 4 forbids for autoloads; the same
     logic applies here.
  4. A registry entry that nothing in the current tree looks up, directly or
     via a declared dynamic site. Dead weight in the registry is as
     misleading as a stale autoload declaration - UNLESS the entry's
     Permitted consumers field says `(none - write-only)`, the explicit,
     disclosed declaration that this producer has never had a consumer and
     that is the actual shape of the thing (docs/groups.md has two:
     `impact_body`, `money_log`). Rule 1 already forces every add_to_group
     call to have an entry regardless of whether anything reads it back, so
     without this escape hatch a genuinely write-only group could never
     satisfy both rules at once - it would need an entry to pass rule 1 and
     no entry to pass rule 4. The marker is what lets the registry say which
     situation it is instead of the gate guessing.
  5. A producer file whose actual layer (by its path under src/) disagrees
     with what the registry declares for it.

Symmetrically, a dynamic call site this gate detects that is NOT listed in
docs/groups.md's own "Dynamic call sites" section is also a failure (this is
requirement 5 from the build brief, kept separate from the five above
because it polices the registry's dynamic-sites list rather than its group
catalog) - and a dynamic site LISTED there that no longer resolves as
dynamic in the current tree is flagged too, so that section cannot go stale
either.


THE TWO SITES THIS GATE CANNOT READ DIRECTLY - AND WHY THAT IS FINE

    src/systems/save/CareerSave.gd:449
    src/ui/station/StationMenu.gd:957

Both are the same shape:

    static func _node_in_group(tree: SceneTree, group: StringName) -> Node:
        return tree.get_first_node_in_group(group)

`group` is a parameter, not a literal - unresolvable by a text scan, on
purpose (that is what makes it a wrapper). This gate does not attempt to
trace call sites back through local helper functions to recover what
literal a caller eventually supplied; it reports the wrapper's own call as
what it structurally is - dynamic - and requires docs/groups.md to say so in
the Dynamic call sites section. A caller that reaches `_node_in_group` (or
the second layer of wrapping in CareerSave.gd - `_merge_service_section` /
`_apply_or_reset_service` - or StationMenu.gd's `_group_bool`) with a
literal group name is consequently invisible to this gate too: it is not a
direct call to one of the three tracked functions, so it is not scanned at
all. Recorded as prose in the registry instead, where a human can read it.


WHAT THIS CANNOT SEE - read before trusting a green run

  * A group name built at runtime - `add_to_group("svc_" + kind)` - or
    passed through any local function, however shallow. Only a literal or a
    resolved Balance*.GROUP_* constant, written directly as the call's own
    argument, resolves. Everything else is dynamic, reported, and requires a
    matching line in the registry's Dynamic call sites section - the gate
    cannot verify WHICH groups actually flow through a dynamic site, only
    that the site exists and is disclosed.
  * `is_in_group(...)`. A node that already holds a reference and asks
    "are you tagged X" is not locating a service - it is a membership
    test on something it already has, a different mechanism from the
    locator this gate exists to police. Real call sites exist
    (src/entities/PlayerShip.gd:865, src/entities/PlayerProjectile.gd:89,
    src/world/HostileProjectile.gd:87) and none of them are scanned.
  * A membership added by a third party - an editor plugin, a test harness,
    anything outside src/.
  * **"Permitted consumers" is a declared policy, not a derived truth.** The
    registry records where each group is reached from AS OF the commit that
    last edited it. This gate enforces that the declared list and the real
    call sites agree; it has no opinion on whether a given crossing was ever
    a good idea. That judgement is what check_boundaries.py's cross-system
    rule already renders for two systems reached WITHOUT a group indirection
    - a reviewer reads this registry the way they read docs/globals.md's
    four tests, not the way they read a compiler error.


ARGUMENTS

    python scripts/check_groups.py --root X --registry Y

`--root` changes where `src/` is scanned from (default: this project's own
root). `--registry` changes which doc is checked against (default:
`<root>/docs/groups.md`). Both exist for the same reason check_globals.py's
`--project-file` / `--globals-doc` do: proving this gate bites - in both the
"undeclared lookup" and "layer not permitted" directions - means writing a
real violation somewhere. A `--root` fixture costs nothing and touches
nothing under the real src/; the project's own proof instead edits a real
file under src/systems/ and reverts it with `git checkout --`, which is fine
for the two directions that only make sense against real layer boundaries.


ENCODING

Everything is read as UTF-8 and printed as ASCII. The project's docs are
full of em dashes and a Windows console is cp1252 by default, so a tool that
echoes what it read crashes on the punctuation rather than on the problem
(docs/traps.md).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import NamedTuple, Optional

PROJECT_DIR = Path(__file__).resolve().parents[1]
REGISTRY_RELATIVE = "docs/groups.md"

# The four layers that must not know about each other, per check_boundaries.py.
# src/data is content, exempt as a target there and here. A .gd file directly
# under src/ (Main.gd) is the composition root - "root" below, never one of
# the four - matching check_boundaries.py's own treatment of it as exempt.
DECIDING_LAYERS = ("systems", "entities", "ui", "world")

GROUP_CALL_NAMES = ("add_to_group", "get_first_node_in_group", "get_nodes_in_group")
CALL_RE = re.compile(r"\b(add_to_group|get_first_node_in_group|get_nodes_in_group)\s*\(")
CALL_KIND = {
    "add_to_group": "add",
    "get_first_node_in_group": "get_first",
    "get_nodes_in_group": "get_nodes",
}

CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.MULTILINE)
CONST_STRING_RE = re.compile(
    r'^\s*const\s+([A-Za-z_]\w*)\s*(?::\s*[A-Za-z_]\w*)?\s*=\s*&?"([^"]*)"',
    re.MULTILINE,
)

LITERAL_DQ_RE = re.compile(r'^&?"([^"]*)"$')
LITERAL_SQ_RE = re.compile(r"^&?'([^']*)'$")
CONST_REF_RE = re.compile(r"^([A-Za-z_]\w*)\.([A-Za-z_]\w*)$")

TSCN_GROUPS_RE = re.compile(r"groups=\[(.*?)\]")
TSCN_STRING_RE = re.compile(r'"([^"]*)"')

GROUP_HEADING_RE = re.compile(r"^###\s+`([^`]+)`\s*->\s*`([^`]+)`\s*$", re.MULTILINE)
FIELD_LAYER_RE = re.compile(r"^[ \t]*-\s*\*\*Producer layer:\*\*\s*(\S+)\s*$", re.MULTILINE)
FIELD_ALSO_RE = re.compile(r"^[ \t]*-\s*\*\*Also added by:\*\*\s*(.+)$", re.MULTILINE)
FIELD_PERMIT_RE = re.compile(r"^[ \t]*-\s*\*\*Permitted consumers:\*\*\s*(.+)$", re.MULTILINE)
FIELD_DYNREF_RE = re.compile(r"^[ \t]*-\s*\*\*Reached via dynamic sites:\*\*\s*(.+)$", re.MULTILINE)
DYNAMIC_SECTION_RE = re.compile(r"^##\s+Dynamic call sites\s*$", re.MULTILINE)
SECTION_HEADING_RE = re.compile(r"^##\s+\S", re.MULTILINE)
DYNAMIC_HEADING_RE = re.compile(r"^###\s+`([^`]+)`\s*$", re.MULTILINE)
BACKTICK_TOKEN_RE = re.compile(r"`([^`]+)`")

violations: list[tuple[str, str]] = []


def report(location: str, message: str) -> None:
    violations.append((location, message))


def ascii_only(text: str) -> str:
    """Windows consoles are cp1252; our docs are not."""
    return text.encode("ascii", "replace").decode("ascii")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


# --- Reading GDScript without losing what is inside a string ----------------


def strip_comments(text: str) -> str:
    """Remove `#...` comments; string literals are kept verbatim, quotes and all.

    Adapted from check_boundaries.py's split_code_and_strings, which *blanks*
    string bodies because it only needs to know a reference exists inside one.
    This gate needs to read the group name written inside the string, so the
    string is kept instead of blanked. Triple-quoted strings are handled the
    same way check_boundaries.py handles them, for the same reason: a triple
    quote closing early on a bare `"` would silently corrupt everything read
    after it. Newlines are preserved everywhere so line numbers in the result
    match the original file exactly.
    """
    out: list[str] = []
    index = 0
    length = len(text)
    while index < length:
        char = text[index]

        if char == "#":
            while index < length and text[index] != "\n":
                index += 1
            continue

        if char in "\"'":
            quote = char
            triple = text[index:index + 3] == quote * 3
            span = 3 if triple else 1
            out.append(text[index:index + span])
            index += span
            while index < length:
                if text[index] == "\\" and index + 1 < length:
                    out.append(text[index:index + 2])
                    index += 2
                    continue
                if triple and text[index:index + 3] == quote * 3:
                    out.append(text[index:index + 3])
                    index += 3
                    break
                if not triple and text[index] == quote:
                    out.append(text[index])
                    index += 1
                    break
                if text[index] == "\n" and not triple:
                    break  # Unterminated: the compiler will say so, not us.
                out.append(text[index])
                index += 1
            continue

        out.append(char)
        index += 1

    return "".join(out)


def strip_fenced_blocks(markdown: str) -> str:
    """Blank out ``` fenced blocks, keeping line numbers intact.

    docs/groups.md documents its own entry format, and that example is a
    heading inside a code fence. Without this the checker reads its own
    instructions as a real entry - the same mistake check_boundaries.py made
    against docs/events.md, and check_globals.py against docs/globals.md.
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


def extract_first_argument(text: str, open_paren_index: int) -> str:
    """Given text[open_paren_index] == '(', return the first top-level argument.

    Stops at the first depth-0 comma or the matching close paren, tracking
    string and nested-paren state so a comma or paren inside a string (or
    inside `BalanceX.SOME_CALL()`-shaped nonsense) does not end capture early.
    """
    depth = 0
    quote = ""
    captured: list[str] = []
    stop_capture = False
    index = open_paren_index
    length = len(text)
    while index < length:
        char = text[index]

        if quote:
            if char == "\\" and index + 1 < length:
                if not stop_capture:
                    captured.append(text[index:index + 2])
                index += 2
                continue
            if not stop_capture:
                captured.append(char)
            if char == quote:
                quote = ""
            index += 1
            continue

        if char in "\"'":
            quote = char
            if not stop_capture:
                captured.append(char)
            index += 1
            continue

        if char == "(":
            depth += 1
            if depth > 1 and not stop_capture:
                captured.append(char)
            index += 1
            continue

        if char == ")":
            depth -= 1
            if depth == 0:
                index += 1
                break
            if not stop_capture:
                captured.append(char)
            index += 1
            continue

        if char == "," and depth == 1:
            stop_capture = True
            index += 1
            continue

        if not stop_capture:
            captured.append(char)
        index += 1

    return "".join(captured).strip()


# --- Layers -------------------------------------------------------------


def layer_of(relative_path: str) -> str:
    """'src/systems/foo/Bar.gd' -> 'systems'. 'src/Main.gd' -> 'root'."""
    parts = relative_path.split("/")
    if not parts or parts[0] != "src":
        return ""
    if len(parts) == 2:
        return "root"
    layer = parts[1]
    if layer == "data":
        return "data"
    if layer in DECIDING_LAYERS:
        return layer
    return "other"


# --- Balance*.GROUP_* constants ----------------------------------------


def balance_constants(root: Path) -> dict[str, tuple[str, str, int]]:
    """{'ClassName.CONST_NAME': (string value, declaring file, line)}.

    Scans every .gd under src/data/ (that is where the project's Balance*
    tunable files live, per src/systems/README.md's documented arrangement -
    see check_boundaries.py rule 2's exemption for why src/data is read by
    everyone). A file with no class_name falls back to its own filename stem,
    which is dead code for this project (every Balance file declares one) but
    keeps the index from silently dropping constants if that ever changes.
    """
    index: dict[str, tuple[str, str, int]] = {}
    data_dir = root / "src" / "data"
    if not data_dir.is_dir():
        return index
    for path in sorted(data_dir.rglob("*.gd")):
        clean = strip_comments(read(path))
        class_match = CLASS_NAME_RE.search(clean)
        class_name = class_match.group(1) if class_match else path.stem
        for match in CONST_STRING_RE.finditer(clean):
            line = clean.count("\n", 0, match.start()) + 1
            index["%s.%s" % (class_name, match.group(1))] = (
                match.group(2),
                rel(path, root),
                line,
            )
    return index


def resolve_argument(
    arg_text: str, constants: dict[str, tuple[str, str, int]]
) -> tuple[str, Optional[str]]:
    """Classify a call's first argument: ('literal'|'const'|'unknown_const'|'dynamic', value)."""
    text = arg_text.strip()
    match = LITERAL_DQ_RE.match(text) or LITERAL_SQ_RE.match(text)
    if match:
        return "literal", match.group(1)
    match = CONST_REF_RE.match(text)
    if match:
        key = "%s.%s" % (match.group(1), match.group(2))
        if key in constants:
            return "const", constants[key][0]
        return "unknown_const", None
    return "dynamic", None


# --- Scanning -------------------------------------------------------------


class Site(NamedTuple):
    file: str
    line: int
    kind: str  # 'add' | 'get_first' | 'get_nodes' | 'scene'
    layer: str
    group: Optional[str]
    raw_arg: str
    resolution: str  # 'literal' | 'const' | 'unknown_const' | 'dynamic' | 'scene'


def scanned_gd_files(src_dir: Path) -> list[Path]:
    return [path for path in sorted(src_dir.rglob("*.gd")) if path.is_file()]


def scanned_tscn_files(src_dir: Path) -> list[Path]:
    return [path for path in sorted(src_dir.rglob("*.tscn")) if path.is_file()]


def scan_gd_file(path: Path, root: Path, constants: dict[str, tuple[str, str, int]]) -> list[Site]:
    clean = strip_comments(read(path))
    file_rel = rel(path, root)
    file_layer = layer_of(file_rel)
    sites: list[Site] = []
    for match in CALL_RE.finditer(clean):
        kind = CALL_KIND[match.group(1)]
        open_paren = match.end() - 1
        arg_text = extract_first_argument(clean, open_paren)
        line = clean.count("\n", 0, match.start()) + 1
        resolution, value = resolve_argument(arg_text, constants)
        group = value if resolution in ("literal", "const") else None
        sites.append(Site(file_rel, line, kind, file_layer, group, arg_text, resolution))
    return sites


def scan_tscn_file(path: Path, root: Path) -> list[Site]:
    text = read(path)
    file_rel = rel(path, root)
    file_layer = layer_of(file_rel)
    sites: list[Site] = []
    for match in TSCN_GROUPS_RE.finditer(text):
        line = text.count("\n", 0, match.start()) + 1
        for string_match in TSCN_STRING_RE.finditer(match.group(1)):
            name = string_match.group(1)
            sites.append(Site(file_rel, line, "scene", file_layer, name, name, "scene"))
    return sites


def collect_sites(src_dir: Path, root: Path, constants: dict[str, tuple[str, str, int]]) -> list[Site]:
    sites: list[Site] = []
    for path in scanned_gd_files(src_dir):
        sites.extend(scan_gd_file(path, root, constants))
    for path in scanned_tscn_files(src_dir):
        sites.extend(scan_tscn_file(path, root))
    return sites


# --- The registry -----------------------------------------------------------


class GroupEntry(NamedTuple):
    name: str
    producers: list[str]
    producer_layer: str
    permitted: set[str]
    write_only: bool
    dynamic_refs: set[str]
    heading_line: int


def parse_registry(markdown: str) -> tuple[dict[str, GroupEntry], dict[str, int]]:
    text = strip_fenced_blocks(markdown)
    headings = list(GROUP_HEADING_RE.finditer(text))
    entries: dict[str, GroupEntry] = {}

    for index, match in enumerate(headings):
        name = match.group(1).strip()
        primary_producer = match.group(2).strip()
        block_end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        block = text[match.end():block_end]
        heading_line = text.count("\n", 0, match.start()) + 1

        layer_match = FIELD_LAYER_RE.search(block)
        producer_layer = layer_match.group(1).strip() if layer_match else ""

        producers = [primary_producer]
        also_match = FIELD_ALSO_RE.search(block)
        if also_match:
            producers.extend(BACKTICK_TOKEN_RE.findall(also_match.group(1)))

        permitted: set[str] = set()
        write_only = False
        permit_match = FIELD_PERMIT_RE.search(block)
        if permit_match:
            raw = permit_match.group(1).strip()
            if "write-only" in raw.lower() or "write only" in raw.lower():
                write_only = True
            elif raw and raw.strip("`").strip().lower() not in ("(none)", "none"):
                permitted = {
                    token.strip(" `")
                    for token in raw.split(",")
                    if token.strip(" `")
                }

        dynamic_refs: set[str] = set()
        dynref_match = FIELD_DYNREF_RE.search(block)
        if dynref_match:
            dynamic_refs = set(BACKTICK_TOKEN_RE.findall(dynref_match.group(1)))

        entries[name] = GroupEntry(
            name, producers, producer_layer, permitted, write_only, dynamic_refs, heading_line
        )

    dynamic_sites: dict[str, int] = {}
    section_match = DYNAMIC_SECTION_RE.search(text)
    if section_match is not None:
        after = text[section_match.end():]
        next_section = SECTION_HEADING_RE.search(after)
        section_text = after[:next_section.start()] if next_section else after
        base_offset = section_match.end()
        for dyn_match in DYNAMIC_HEADING_RE.finditer(section_text):
            location = dyn_match.group(1).strip()
            line = text.count("\n", 0, base_offset + dyn_match.start()) + 1
            dynamic_sites[location] = line

    return entries, dynamic_sites


# --- The five failure modes, plus the dynamic-site cross-check --------------


def check_undeclared(sites: list[Site], entries: dict[str, GroupEntry]) -> None:
    for site in sites:
        if site.group is None or site.group in entries:
            continue
        verb = "adds" if site.kind in ("add", "scene") else "looks up"
        report(
            "%s:%d" % (site.file, site.line),
            "%s group '%s', but docs/groups.md has no entry for it. Every group "
            "reachable by bare name is declared and inventoried, the same way an "
            "autoload is (docs/globals.md) - or it does not exist. Add an entry, "
            "or remove the call." % (verb, site.group),
        )


def check_layer_permission(sites: list[Site], entries: dict[str, GroupEntry]) -> None:
    for site in sites:
        if site.group is None or site.kind not in ("get_first", "get_nodes"):
            continue
        entry = entries.get(site.group)
        if entry is None or not entry.permitted:
            continue  # undeclared is reported separately; nothing to check yet.
        if site.layer and site.layer not in entry.permitted:
            report(
                "%s:%d" % (site.file, site.line),
                "src/%s looks up group '%s', but docs/groups.md permits only %s "
                "to reach it. Either this is a real new crossing that needs the "
                "registry updated to say so, or it is the boundary breach the "
                "registry exists to catch."
                % (site.layer, site.group, ", ".join(sorted(entry.permitted))),
            )


def check_producers(
    sites: list[Site], entries: dict[str, GroupEntry], registry_label: str
) -> None:
    added_files_by_group: dict[str, set[str]] = {}
    for site in sites:
        if site.kind in ("add", "scene") and site.group is not None:
            added_files_by_group.setdefault(site.group, set()).add(site.file)

    for name, entry in sorted(entries.items()):
        real_files = added_files_by_group.get(name, set())
        for producer in entry.producers:
            if producer not in real_files:
                report(
                    "%s:%d" % (registry_label, entry.heading_line),
                    "docs/groups.md says '%s' is added by %s, but no add_to_group "
                    "(or scene groups=) call in the current tree resolves '%s' "
                    "from that file. Fix whichever one is stale." % (name, producer, name),
                )
            layer = layer_of(producer)
            if layer and entry.producer_layer and layer != entry.producer_layer:
                report(
                    "%s:%d" % (registry_label, entry.heading_line),
                    "docs/groups.md says '%s' is produced from layer '%s', but %s "
                    "is actually in layer '%s'. Fix whichever one is stale."
                    % (name, entry.producer_layer, producer, layer),
                )


def check_orphans(
    entries: dict[str, GroupEntry],
    looked_up_groups: set[str],
    dynamic_sites: dict[str, int],
    registry_label: str,
) -> None:
    for name, entry in sorted(entries.items()):
        if name in looked_up_groups:
            continue
        if entry.write_only:
            # A group can be a real, deliberate producer with zero consumers -
            # impact_body and money_log both are. That is a different fact from
            # a stale entry whose last consumer was removed, and the registry
            # has to be able to say which one it is: "(none - write-only)" in
            # Permitted consumers is that explicit declaration, not silence.
            continue
        if entry.dynamic_refs:
            for ref in sorted(entry.dynamic_refs):
                if ref not in dynamic_sites:
                    report(
                        "%s:%d" % (registry_label, entry.heading_line),
                        "'%s' claims to be reached via dynamic site %s, but no "
                        "unresolvable call site at that location exists in the "
                        "current tree. Fix whichever one is stale." % (name, ref),
                    )
            continue
        report(
            "%s:%d" % (registry_label, entry.heading_line),
            "'%s' is declared in docs/groups.md but nothing in the current tree "
            "looks it up, directly or via a declared dynamic site. A group "
            "nobody reads is dead weight in the registry - remove the entry, or "
            "the lookup that was supposed to use it." % name,
        )


def check_dynamic_sites(
    sites: list[Site], dynamic_sites: dict[str, int], registry_label: str
) -> None:
    detected: dict[str, Site] = {}
    for site in sites:
        if site.group is None and site.kind in ("get_first", "get_nodes", "add"):
            detected["%s:%d" % (site.file, site.line)] = site

    for location, site in sorted(detected.items()):
        if location not in dynamic_sites:
            report(
                location,
                "the group argument here ('%s') is not a string literal and not "
                "a known Balance*.GROUP_* constant, so this gate cannot read it "
                "statically - and it is not listed in docs/groups.md's Dynamic "
                "call sites section. An unresolvable call site that is not "
                "documented is exactly the hole this gate exists to close."
                % site.raw_arg,
            )

    for location in sorted(dynamic_sites):
        if location not in detected:
            report(
                "%s:%d" % (registry_label, dynamic_sites[location]),
                "docs/groups.md lists %s as a dynamic call site, but the current "
                "tree has no unresolvable group call there any more. Fix "
                "whichever one is stale." % location,
            )


# --- Entry point ------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Draywar group-locator gate: every add_to_group / "
        "get_first_node_in_group / get_nodes_in_group call under src/ must "
        "resolve to a group declared in docs/groups.md, from a layer that "
        "registry permits."
    )
    parser.add_argument(
        "--root",
        default=str(PROJECT_DIR),
        help="project root to scan src/ under (default: this project's own root)",
    )
    parser.add_argument(
        "--registry",
        default=None,
        help="the registry doc to check against (default: <root>/docs/groups.md)",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    registry_path = (
        Path(args.registry).resolve() if args.registry else (root / REGISTRY_RELATIVE)
    )
    src_dir = root / "src"

    missing = []
    if not src_dir.is_dir():
        missing.append(str(src_dir))
    if not registry_path.is_file():
        missing.append(str(registry_path))
    if missing:
        print("SETUP INCOMPLETE:")
        for name in missing:
            print("  - %s is missing" % ascii_only(name))
        return 2

    constants = balance_constants(root)
    sites = collect_sites(src_dir, root, constants)
    entries, dynamic_sites = parse_registry(read(registry_path))

    try:
        registry_label = registry_path.relative_to(root).as_posix()
    except ValueError:
        registry_label = registry_path.as_posix()

    check_undeclared(sites, entries)
    check_layer_permission(sites, entries)
    check_producers(sites, entries, registry_label)
    looked_up_groups = {
        site.group for site in sites if site.group is not None and site.kind in ("get_first", "get_nodes")
    }
    check_orphans(entries, looked_up_groups, dynamic_sites, registry_label)
    check_dynamic_sites(sites, dynamic_sites, registry_label)

    added_groups = {
        site.group for site in sites if site.group is not None and site.kind in ("add", "scene")
    }
    dynamic_count = sum(1 for site in sites if site.group is None)
    gd_files = len(scanned_gd_files(src_dir))
    tscn_files = len(scanned_tscn_files(src_dir))

    print("")
    print(
        "Group check: %d call site(s) across %d file(s) under src/ (%d .gd, %d "
        ".tscn); %d group(s) added, %d group(s) looked up, %d dynamic call "
        "site(s); %d group(s) declared in %s."
        % (
            len(sites),
            gd_files + tscn_files,
            gd_files,
            tscn_files,
            len(added_groups),
            len(looked_up_groups),
            dynamic_count,
            len(entries),
            registry_label,
        )
    )

    if not violations:
        print(
            "Every group is declared, every lookup is from a permitted layer, "
            "every dynamic site is documented."
        )
        return 0

    print("%d VIOLATION(S):" % len(violations))
    for location, message in violations:
        print("  %s" % ascii_only(location))
        print("      %s" % ascii_only(message))
    print("")
    print("A group lookup is the same kind of sanctioned side-channel an")
    print("autoload is, and it gets the same treatment: declared, inventoried,")
    print("and checked every run. The registry is %s." % registry_label)
    return 1


if __name__ == "__main__":
    sys.exit(main())
