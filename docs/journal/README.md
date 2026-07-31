# Journal

Append-only session history. `docs/state.md` stays short; this folder holds detail.

Create entries with:

```
python scripts/journal.py new-session "what this session is about"
python scripts/journal.py add NOTE "…" --detail "…"
```

Do not rewrite old entries. Correct later with a new entry.
