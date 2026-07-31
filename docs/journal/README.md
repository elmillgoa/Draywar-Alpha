# The build journal

Append-only record of **why** things are the way they are.

| File | Answers |
|------|---------|
| `docs/state.md` | Where are we **now**? Short. Rewritten. Loaded every session. |
| `docs/journal/` | **Why** is it like this? Long. Never rewritten. Search, don't dump. |
| `docs/traps.md` | What lies silently? Curated, permanent. |
| `docs/eras.md` | Which epoch does an old note belong to? |

**Do not read the whole journal to get up to speed.** That burns context. Use
`/start` + `state.md`. Search the journal for a specific question (especially
"did Elliot already decide this?").

## The one rule

**Never edit or delete an existing entry.** Wrong? Append a correction that
names what it supersedes (e.g. `SUPERSEDES 001#4`). Both stay visible.

## Commands

```
python scripts/journal.py new-session "what this session is about"
python scripts/journal.py add CONTRACT "A0 complete" --detail "..."
python scripts/journal.py list
```

## Entry types

| Type | Use |
|------|-----|
| `CONTRACT` | Work landed, partial, or blocked + evidence |
| `DECISION` | Elliot decided. Check here before re-asking. |
| `AMENDMENT` | Plan changed + version bump |
| `TRAP` | Silent false pass. Also add to `docs/traps.md`. |
| `GATE` | Sign-off opened/signed/refused — his words quoted |
| `DEVIATION` | Acted then reported |
| `BLOCKER` | Stopped and why |
| `NOTE` | Anything else a future session needs |

## When to record

At checkpoints, not every keystroke:

- Work finishes / blocks
- Elliot decides or signs a gate
- Plan amends
- Surprise, especially fake-green
- Judgement call a reasonable person might question later (**highest value**)
- Session ends (`/wrap`)

## Rotation

Keep **12** newest session files live. Older → `docs/journal/archive/`.
Search archive when needed; never load it wholesale at boot.

## Memory hooks (not the journal)

Harness hooks in `scripts/hooks/` fire on session start and when chat memory is
compressed. They force a write to disk before forgetfulness. See `docs/tooling.md`.
They do **not** replace `/wrap`.
