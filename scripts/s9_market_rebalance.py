#!/usr/bin/env python3
"""Rebalance station produces/consumes so sector ratios sit in [1.2, 1.6]."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "src" / "data" / "content" / "stations"
MIN_R = 1.2
MAX_R = 1.6
TARGET = 1.38

DICT_RE = r"Dictionary\[StringName, float\]\(\{(.*?)\}\)"


def parse_dict(block: str) -> dict[str, float]:
    out: dict[str, float] = {}
    for m in re.finditer(r'&"(commodity_[^"]+)":\s*([0-9.]+)', block):
        out[m.group(1)] = float(m.group(2))
    return out


def extract_field(text: str, field: str) -> dict[str, float]:
    m = re.search(rf"{field} = {DICT_RE}", text, re.S)
    if not m:
        return {}
    return parse_dict(m.group(1))


def extract_scale(text: str) -> float:
    m = re.search(r"market_scale = ([0-9.]+)", text)
    return float(m.group(1)) if m else 1.0


def replace_dict(text: str, field: str, data: dict[str, float]) -> str:
    if not data:
        body = ""
        new_block = f"{field} = Dictionary[StringName, float]({{}})"
    else:
        body = ",\n".join(f'&"{k}": {v}' for k, v in data.items())
        new_block = f"{field} = Dictionary[StringName, float]({{\n{body}\n}})"
    return re.sub(
        rf"{field} = {DICT_RE}",
        new_block,
        text,
        count=1,
        flags=re.S,
    )


def main() -> None:
    stations: dict[str, dict] = {}
    for path in sorted(ROOT.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        sid_m = re.search(r'id = &"([^"]+)"', text)
        if not sid_m:
            continue
        sid = sid_m.group(1)
        stations[sid] = {
            "path": path,
            "text": text,
            "produces": extract_field(text, "produces"),
            "consumes": extract_field(text, "consumes"),
            "stock": extract_field(text, "stock_targets"),
            "scale": extract_scale(text),
        }

    commodities: set[str] = set()
    for s in stations.values():
        commodities |= set(s["produces"]) | set(s["consumes"])

    def totals(c: str) -> tuple[float, float]:
        prod = sum(s["produces"].get(c, 0.0) * s["scale"] for s in stations.values())
        cons = sum(s["consumes"].get(c, 0.0) * s["scale"] for s in stations.values())
        return prod, cons

    print("BEFORE")
    for c in sorted(commodities):
        p, n = totals(c)
        r = p / n if n else 0.0
        print(f"  {c}: {r:.3f} (p={p:.2f} c={n:.2f})")

    for c in sorted(commodities):
        prod, cons = totals(c)
        if cons <= 0.0:
            for sid in ("station_alpha_port", "station_beta_hub", "station_theta_gate"):
                if sid not in stations:
                    continue
                s = stations[sid]
                if c not in s["consumes"]:
                    s["consumes"][c] = 1.0
                if c not in s["stock"]:
                    s["stock"][c] = 80.0
            prod, cons = totals(c)

        if prod <= 0.0:
            for sid in ("station_delta_port", "station_eta_depot", "station_alpha_yard"):
                if sid not in stations:
                    continue
                s = stations[sid]
                s["produces"][c] = 3.0
                if c not in s["stock"]:
                    s["stock"][c] = 120.0
                break
            prod, cons = totals(c)

        if prod > 0.0 and cons > 0.0:
            factor = (TARGET * cons) / prod
            for s in stations.values():
                if c in s["produces"]:
                    s["produces"][c] = round(max(0.4, s["produces"][c] * factor), 3)

        prod, cons = totals(c)
        ratio = prod / cons if cons else 0.0
        if ratio > MAX_R or ratio < MIN_R:
            producers = [(sid, s) for sid, s in stations.items() if c in s["produces"]]
            if producers:
                sid, s = max(
                    producers, key=lambda x: x[1]["produces"][c] * x[1]["scale"]
                )
                others = prod - s["produces"][c] * s["scale"]
                need = TARGET * cons - others
                if s["scale"] > 0:
                    s["produces"][c] = max(0.4, round(need / s["scale"], 3))

        # Every produce/consume key needs stock_targets row
        for s in stations.values():
            if c in s["produces"] or c in s["consumes"]:
                if c not in s["stock"]:
                    s["stock"][c] = 80.0

    print("AFTER")
    ok = True
    for c in sorted(commodities):
        p, n = totals(c)
        r = p / n if n else 0.0
        flag = "OK" if n and MIN_R <= r <= MAX_R else "BAD"
        if flag == "BAD":
            ok = False
        print(f"  {flag} {c}: {r:.3f} (p={p:.2f} c={n:.2f})")

    for sid, s in stations.items():
        text = s["text"]
        text = replace_dict(text, "stock_targets", s["stock"])
        text = replace_dict(text, "produces", s["produces"])
        text = replace_dict(text, "consumes", s["consumes"])
        if not text.endswith("\n"):
            text += "\n"
        s["path"].write_text(text, encoding="utf-8")
        print(f"wrote {s['path'].name}")

    if not ok:
        raise SystemExit("ratios still out of band")
    print("all ratios in band")


if __name__ == "__main__":
    main()
