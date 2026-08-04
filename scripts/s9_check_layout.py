#!/usr/bin/env python3
from __future__ import annotations

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "src" / "data" / "content" / "stations"
GATE = (1100.0, 0.0, -800.0)
MIN_DOCK = 450.0
MIN_GATE = 1199.5

stations = []
for path in ROOT.glob("*.tres"):
    text = path.read_text(encoding="utf-8")
    sid = re.search(r'id = &"([^"]+)"', text).group(1)
    system = re.search(r'system_id = &"([^"]+)"', text).group(1)
    m = re.search(r"position_offset = Vector3\(([^)]+)\)", text)
    x, y, z = [float(v.strip()) for v in m.group(1).split(",")]
    stations.append((sid, system, x, y, z))

by_sys: dict[str, list] = {}
for row in stations:
    by_sys.setdefault(row[1], []).append(row)

ok = True
for system, rows in sorted(by_sys.items()):
    print(f"== {system} ==")
    for i, a in enumerate(rows):
        d_gate = math.dist((a[2], a[3], a[4]), GATE)
        flag = "OK" if d_gate >= MIN_GATE else "BAD"
        if flag == "BAD":
            ok = False
        print(f"  {flag} {a[0]} gate_dist={d_gate:.1f}")
        for b in rows[i + 1 :]:
            d = math.dist((a[2], a[3], a[4]), (b[2], b[3], b[4]))
            flag = "OK" if d >= MIN_DOCK else "BAD"
            if flag == "BAD":
                ok = False
            print(f"  {flag} {a[0]} <-> {b[0]} = {d:.1f}")

raise SystemExit(0 if ok else 1)
