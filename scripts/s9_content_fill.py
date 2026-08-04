#!/usr/bin/env python3
"""S9 floor content fill — generate .tres rows + patch existing systems/entities/stations.

Run from repo root: python scripts/s9_content_fill.py
Idempotent for new files; rewrites listed targets.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "src" / "data" / "content"


def write(rel: str, body: str) -> None:
    path = CONTENT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body.strip() + "\n", encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT)}")


def commodity(cid: str, name: str, buy: int, sell: int, volume: int, note: str) -> None:
    write(
        f"commodities/{cid}.tres",
        f"""
[gd_resource type="Resource" script_class="Commodity" load_steps=2 format=3]

; {note}
[ext_resource type="Script" path="res://src/data/shapes/Commodity.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{cid}"
display_name = "{name}"
base_buy_price = {buy}
base_sell_price = {sell}
unit_volume = {volume}
""",
    )


def star_system(
    sid: str,
    name: str,
    held: str,
    policing: str,
    stations: list[str],
    gates: list[str],
    flavor: str,
) -> None:
    st = ", ".join(f'&"{s}"' for s in stations)
    gt = ", ".join(f'&"{g}"' for g in gates)
    write(
        f"star_systems/{sid}.tres",
        f"""
[gd_resource type="Resource" script_class="StarSystem" load_steps=2 format=3]

; S9 content fill.
[ext_resource type="Script" path="res://src/data/shapes/StarSystem.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{sid}"
display_name = "{name}"
held_by = &"{held}"
policing = &"{policing}"
station_ids = Array[StringName]([{st}])
gate_destination_ids = Array[StringName]([{gt}])
flavor_line = "{flavor}"
""",
    )


def station(
    sid: str,
    name: str,
    system: str,
    controller: str,
    offset: str,
    flavor: str,
    role: str,
    stock: dict[str, float],
    produces: dict[str, float],
    consumes: dict[str, float],
    scale: float,
) -> None:
    def dict_block(d: dict[str, float]) -> str:
        lines = [f'&"{k}": {v}' for k, v in d.items()]
        return "Dictionary[StringName, float]({\n" + ",\n".join(lines) + "\n})"

    write(
        f"stations/{sid}.tres",
        f"""
[gd_resource type="Resource" script_class="Station" load_steps=2 format=3]

; S9 content fill.
[ext_resource type="Script" path="res://src/data/shapes/Station.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{sid}"
display_name = "{name}"
system_id = &"{system}"
controller_entity_id = &"{controller}"
position_offset = {offset}
flavor_line = "{flavor}"
economy_role = &"{role}"
stock_targets = {dict_block(stock)}
produces = {dict_block(produces)}
consumes = {dict_block(consumes)}
market_scale = {scale}
""",
    )


def entity(
    eid: str,
    name: str,
    links: list[tuple[str, str]],
    systems: list[str],
    stations: list[str],
    default: float = 0.0,
    refuse: float = -50.0,
) -> None:
    load_steps = 3 + len(links)
    sub = []
    for i, (target, rel) in enumerate(links):
        sub.append(
            f"""
[sub_resource type="Resource" id="Link_{i}"]
script = ExtResource("2")
target_id = &"{target}"
relation_type = &"{rel}"
""".strip()
        )
    link_arr = ", ".join(f"SubResource(\"Link_{i}\")" for i in range(len(links)))
    sys = ", ".join(f'&"{s}"' for s in systems)
    st = ", ".join(f'&"{s}"' for s in stations)
    write(
        f"entities/{eid}.tres",
        f"""
[gd_resource type="Resource" script_class="Entity" load_steps={load_steps} format=3]

; S9 content fill.
[ext_resource type="Script" path="res://src/data/shapes/Entity.gd" id="1"]
[ext_resource type="Script" path="res://src/data/shapes/EntityLink.gd" id="2"]

{chr(10).join(sub)}

[resource]
script = ExtResource("1")
id = &"{eid}"
display_name = "{name}"
relationship_links = Array[ExtResource("2")]([{link_arr}])
reach_system_ids = Array[StringName]([{sys}])
reach_station_ids = Array[StringName]([{st}])
default_player_standing = {default}
dock_refusal_threshold = {refuse}
""",
    )


def person(pid: str, name: str, entity_id: str, rank: str, network: list[str]) -> None:
    net = ", ".join(f'&"{n}"' for n in network)
    write(
        f"people/{pid}.tres",
        f"""
[gd_resource type="Resource" script_class="Person" load_steps=2 format=3]

; S9 content fill.
[ext_resource type="Script" path="res://src/data/shapes/Person.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{pid}"
display_name = "{name}"
primary_entity_id = &"{entity_id}"
rank = &"{rank}"
network_person_ids = Array[StringName]([{net}])
default_player_standing = 0.0
""",
    )


def recovery(rid: str, name: str, person_id: str, entity_id: str, steps: list[tuple[str, str, float, float, bool]]) -> None:
    # steps: id, display, personal, entity, requires_prior
    load_steps = 2 + len(steps)
    subs = []
    for i, (sid, dname, pdelta, edelta, prior) in enumerate(steps):
        prior_s = "true" if prior else "false"
        subs.append(
            f"""
[sub_resource type="Resource" id="step_{i}"]
script = ExtResource("2")
id = &"{sid}"
display_name = "{dname}"
personal_standing_delta = {pdelta}
entity_standing_delta = {edelta}
requires_prior_success = {prior_s}
""".strip()
        )
    step_arr = ", ".join(f'SubResource("step_{i}")' for i in range(len(steps)))
    write(
        f"recovery_chains/{rid}.tres",
        f"""
[gd_resource type="Resource" script_class="RecoveryChain" load_steps={load_steps} format=3]

; S9 content fill.
[ext_resource type="Script" path="res://src/data/shapes/RecoveryChain.gd" id="1"]
[ext_resource type="Script" path="res://src/data/shapes/RecoveryStep.gd" id="2"]

{chr(10).join(subs)}

[resource]
script = ExtResource("1")
id = &"{rid}"
display_name = "{name}"
person_id = &"{person_id}"
entity_id = &"{entity_id}"
steps = Array[ExtResource("2")]([{step_arr}])
""",
    )


def contract(
    cid: str,
    name: str,
    entity: str,
    kind: str,
    pay: int,
    dest: str = "",
    target_sys: str = "",
    cargo: str = "",
    cargo_qty: int = 0,
    standing_c: float = 8.0,
    standing_f: float = -3.0,
    standing_a: float = -8.0,
) -> None:
    extra = ""
    if dest:
        extra += f'\ndestination_station_id = &"{dest}"'
    if target_sys:
        extra += f'\ntarget_system_id = &"{target_sys}"'
    if cargo:
        extra += f'\ncargo_commodity_id = &"{cargo}"\ncargo_quantity = {cargo_qty}'
    write(
        f"contract_types/{cid}.tres",
        f"""
[gd_resource type="Resource" script_class="ContractType" load_steps=2 format=3]

; S9 flashpoint / board fill.
[ext_resource type="Script" path="res://src/data/shapes/ContractType.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{cid}"
display_name = "{name}"
offering_entity_id = &"{entity}"
kind = &"{kind}"
standing_complete = {standing_c}
standing_fail = {standing_f}
standing_abandon = {standing_a}
pay_credits = {pay}{extra}
""",
    )


STANDARD_RECOVERY_STEPS = [
    ("step_deniable", "Off-books package drop", 12.0, 2.0, False),
    ("step_whisper", "Quiet word on the dock", 10.0, 2.0, True),
    ("step_cover", "Cover a short shift", 8.0, 3.0, True),
    ("step_vouch", "A vouch that sticks", 8.0, 4.0, True),
]


def main() -> None:
    # --- Commodities ---
    commodity(
        "commodity_ice",
        "Ice",
        14,
        9,
        1,
        "Water ice / coolant — cheap on outer belts, burns at industry.",
    )
    commodity(
        "commodity_components",
        "Components",
        42,
        28,
        1,
        "Ship components — yards make them; outer docks eat them.",
    )

    # --- Systems (new) ---
    star_system(
        "system_eta",
        "Eta Reach",
        "entity_eta_consortium",
        "contested",
        ["station_eta_forge", "station_eta_depot"],
        ["system_delta", "system_theta"],
        "Consortium mining reach off Delta — ore, ice, and hard bargaining.",
    )
    star_system(
        "system_theta",
        "Theta Rim",
        "entity_theta_watch",
        "patrolled",
        ["station_theta_gate", "station_theta_anchor"],
        ["system_eta", "system_zeta"],
        "Outer Watch line — thin patrols, long freights, strict berths.",
    )

    # Patch existing systems for densify + gates
    star_system(
        "system_alpha",
        "Alpha Reach",
        "entity_reach_authority",
        "patrolled",
        ["station_alpha_port", "station_alpha_yard", "station_alpha_customs"],
        ["system_beta"],
        "Patrolled Authority space — fees high, refined goods made at the port.",
    )
    star_system(
        "system_gamma",
        "Gamma Fringe",
        "entity_gamma_collective",
        "lawless",
        ["station_gamma_outpost", "station_gamma_rim", "station_gamma_cache"],
        ["system_beta", "system_epsilon"],
        "Lawless fringe — thin patrols, grain pays well, scrap is cheap. Gate out to Epsilon.",
    )
    star_system(
        "system_delta",
        "Delta Corridor",
        "entity_reach_authority",
        "patrolled",
        ["station_delta_port", "station_delta_yard"],
        ["system_beta", "system_eta"],
        "Second Reach lane off Beta — quieter pads, gate out toward Eta mining.",
    )
    star_system(
        "system_zeta",
        "Zeta Spur",
        "entity_gamma_collective",
        "lawless",
        ["station_zeta_spur"],
        ["system_epsilon", "system_theta"],
        "Far spur at the edge of the chart — multi-hour haul, scrap and silence.",
    )
    # Keep beta/epsilon as-is structure but rewrite for consistency
    star_system(
        "system_beta",
        "Beta Drift",
        "entity_beta_syndicate",
        "contested",
        ["station_beta_hub", "station_beta_spit"],
        ["system_alpha", "system_gamma", "system_delta"],
        "Contested corridor — Syndicate gray market, mixed traffic. Branch hub for Delta.",
    )
    star_system(
        "system_epsilon",
        "Epsilon Belt",
        "entity_beta_syndicate",
        "contested",
        ["station_epsilon_belt"],
        ["system_gamma", "system_zeta"],
        "Smuggle belt beyond Gamma — Syndicate gray docks, thin law.",
    )

    # --- Stations (new densify + outer) ---
    station(
        "station_alpha_customs",
        "Alpha Customs",
        "system_alpha",
        "entity_reach_authority",
        "Vector3(420, 0, -200)",
        "Inspection berth on the Authority approach — forms, fees, and cold stares.",
        "trade_hub",
        {
            "commodity_ore": 160.0,
            "commodity_scrap": 180.0,
            "commodity_alloy": 100.0,
            "commodity_medical": 55.0,
            "commodity_luxuries": 50.0,
            "commodity_ice": 90.0,
            "commodity_components": 70.0,
        },
        {"commodity_luxuries": 2.5, "commodity_components": 2.0},
        {"commodity_ore": 1.0, "commodity_ice": 1.2, "commodity_scrap": 1.4},
        1.6,
    )
    station(
        "station_gamma_cache",
        "Gamma Cache",
        "system_gamma",
        "entity_gamma_collective",
        "Vector3(100, 0, -380)",
        "Hidden freeport cache — ice crates and quiet scrap deals.",
        "frontier",
        {
            "commodity_grain": 200.0,
            "commodity_rations": 150.0,
            "commodity_scrap": 220.0,
            "commodity_ice": 200.0,
            "commodity_medical": 45.0,
            "commodity_components": 40.0,
        },
        {"commodity_scrap": 4.0, "commodity_ice": 5.0},
        {"commodity_grain": 0.9, "commodity_components": 1.8, "commodity_medical": 1.0},
        0.75,
    )
    station(
        "station_eta_forge",
        "Eta Forge",
        "system_eta",
        "entity_eta_consortium",
        "Vector3(240, 0, 420)",
        "Consortium forge — ore in, alloy and components out.",
        "industrial",
        {
            "commodity_ore": 220.0,
            "commodity_scrap": 160.0,
            "commodity_alloy": 100.0,
            "commodity_spare_parts": 90.0,
            "commodity_fuel_cells": 100.0,
            "commodity_ice": 140.0,
            "commodity_components": 85.0,
            "commodity_grain": 180.0,
        },
        {"commodity_alloy": 4.5, "commodity_components": 4.0},
        {"commodity_ore": 1.4, "commodity_ice": 1.1, "commodity_scrap": 1.2, "commodity_grain": 0.9},
        1.3,
    )
    station(
        "station_eta_depot",
        "Eta Depot",
        "system_eta",
        "entity_eta_consortium",
        "Vector3(-380, 0, 200)",
        "Ice and ore depot on the Consortium rim — cold holds, hard rates.",
        "refinery",
        {
            "commodity_ore": 240.0,
            "commodity_ice": 240.0,
            "commodity_fuel_cells": 100.0,
            "commodity_rations": 140.0,
            "commodity_spare_parts": 70.0,
            "commodity_components": 50.0,
            "commodity_medical": 40.0,
        },
        {"commodity_ore": 5.0, "commodity_ice": 6.0},
        {
            "commodity_rations": 0.9,
            "commodity_spare_parts": 1.4,
            "commodity_components": 1.6,
            "commodity_medical": 1.0,
        },
        1.0,
    )
    station(
        "station_theta_gate",
        "Theta Gate",
        "system_theta",
        "entity_theta_watch",
        "Vector3(200, 0, 500)",
        "Watch gate station — manifests checked, freights long, berths expensive.",
        "trade_hub",
        {
            "commodity_grain": 200.0,
            "commodity_rations": 150.0,
            "commodity_alloy": 95.0,
            "commodity_medical": 55.0,
            "commodity_luxuries": 45.0,
            "commodity_components": 80.0,
            "commodity_ice": 100.0,
            "commodity_fuel_cells": 120.0,
        },
        {"commodity_medical": 3.5, "commodity_luxuries": 2.5},
        {
            "commodity_ice": 1.3,
            "commodity_components": 1.5,
            "commodity_grain": 0.9,
            "commodity_fuel_cells": 1.2,
        },
        1.4,
    )
    station(
        "station_theta_anchor",
        "Theta Anchor",
        "system_theta",
        "entity_theta_watch",
        "Vector3(-360, 0, 180)",
        "Watch military anchor — munitions stockpiles and stern clerks.",
        "military",
        {
            "commodity_munitions": 80.0,
            "commodity_fuel_cells": 130.0,
            "commodity_alloy": 90.0,
            "commodity_spare_parts": 85.0,
            "commodity_medical": 60.0,
            "commodity_components": 75.0,
            "commodity_grain": 160.0,
        },
        {"commodity_munitions": 4.5, "commodity_fuel_cells": 3.5},
        {
            "commodity_alloy": 1.5,
            "commodity_components": 1.4,
            "commodity_grain": 0.9,
            "commodity_medical": 1.0,
        },
        1.2,
    )

    # Patch existing stations: add ice/components trade without rewriting whole economies.
    # Handled by patch_existing_stations() below.

    # --- Entities ---
    entity(
        "entity_eta_consortium",
        "Eta Consortium",
        [
            ("entity_beta_syndicate", "rival"),
            ("entity_free_haulers", "allied"),
        ],
        ["system_eta"],
        ["station_eta_forge", "station_eta_depot"],
    )
    entity(
        "entity_theta_watch",
        "Theta Watch",
        [
            ("entity_reach_authority", "allied"),
            ("entity_gamma_collective", "rival"),
        ],
        ["system_theta"],
        ["station_theta_gate", "station_theta_anchor"],
    )
    entity(
        "entity_lane_brokers",
        "Lane Brokers",
        [("entity_free_haulers", "allied")],
        [],
        [],
    )

    # Update existing entity reach for densified docks
    entity(
        "entity_reach_authority",
        "Reach Authority",
        [("entity_beta_syndicate", "rival"), ("entity_theta_watch", "allied")],
        ["system_alpha", "system_delta"],
        [
            "station_alpha_port",
            "station_alpha_yard",
            "station_alpha_customs",
            "station_delta_port",
            "station_delta_yard",
        ],
    )
    entity(
        "entity_beta_syndicate",
        "Drift Syndicate",
        [("entity_reach_authority", "rival"), ("entity_eta_consortium", "rival")],
        ["system_beta", "system_epsilon"],
        ["station_beta_hub", "station_beta_spit", "station_epsilon_belt"],
    )
    entity(
        "entity_gamma_collective",
        "Fringe Collective",
        [("entity_free_haulers", "allied"), ("entity_theta_watch", "rival")],
        ["system_gamma", "system_zeta"],
        [
            "station_gamma_outpost",
            "station_gamma_rim",
            "station_gamma_cache",
            "station_zeta_spur",
        ],
    )
    entity(
        "entity_free_haulers",
        "Free Haulers",
        [
            ("entity_gamma_collective", "allied"),
            ("entity_lane_brokers", "allied"),
            ("entity_eta_consortium", "allied"),
        ],
        [],
        [],
    )
    # player holding unchanged file — leave alone

    # --- People (16 new → 35 total) ---
    # Eta Consortium 4
    person("person_ec_rhea", "Foreman Rhea", "entity_eta_consortium", "low", ["person_ec_torr"])
    person("person_ec_torr", "Shift Boss Torr", "entity_eta_consortium", "mid", ["person_ec_rhea", "person_ec_vale"])
    person("person_ec_vale", "Ledger Vale", "entity_eta_consortium", "mid", ["person_ec_torr", "person_ec_quin"])
    person("person_ec_quin", "Director Quin", "entity_eta_consortium", "high", ["person_ec_vale"])
    # Theta Watch 4
    person("person_tw_holt", "Clerk Holt", "entity_theta_watch", "low", ["person_tw_sera"])
    person("person_tw_sera", "Sergeant Sera", "entity_theta_watch", "mid", ["person_tw_holt", "person_tw_brand"])
    person("person_tw_brand", "Marshal Brand", "entity_theta_watch", "mid", ["person_tw_sera", "person_tw_ivo"])
    person("person_tw_ivo", "Commander Ivo", "entity_theta_watch", "high", ["person_tw_brand"])
    # Lane Brokers 3
    person("person_lb_cass", "Broker Cass", "entity_lane_brokers", "low", ["person_lb_nils"])
    person("person_lb_nils", "Runner Nils", "entity_lane_brokers", "mid", ["person_lb_cass", "person_lb_ora"])
    person("person_lb_ora", "Principal Ora", "entity_lane_brokers", "high", ["person_lb_nils"])
    # Existing factions densify 5
    person("person_ra_pike", "Clerk Pike", "entity_reach_authority", "low", ["person_ra_mendi"])
    person("person_ra_juno", "Inspector Juno", "entity_reach_authority", "mid", ["person_ra_voss"])
    person("person_bs_lark", "Fixer Lark", "entity_beta_syndicate", "low", ["person_bs_jax"])
    person("person_gc_mire", "Scrap Mire", "entity_gamma_collective", "low", ["person_gc_kade"])
    person("person_fh_reed", "Hauler Reed", "entity_free_haulers", "low", ["person_fh_wren"])

    # --- Recovery (+4) ---
    recovery(
        "recovery_eta_rhea",
        "Rhea's Forge Path",
        "person_ec_rhea",
        "entity_eta_consortium",
        STANDARD_RECOVERY_STEPS,
    )
    recovery(
        "recovery_theta_holt",
        "Holt's Watch Path",
        "person_tw_holt",
        "entity_theta_watch",
        STANDARD_RECOVERY_STEPS,
    )
    recovery(
        "recovery_brokers_cass",
        "Cass's Ledger Path",
        "person_lb_cass",
        "entity_lane_brokers",
        STANDARD_RECOVERY_STEPS,
    )
    recovery(
        "recovery_reach_pike",
        "Pike's Customs Path",
        "person_ra_pike",
        "entity_reach_authority",
        STANDARD_RECOVERY_STEPS,
    )

    # --- Board contracts / completionist hooks ---
    contract(
        "contract_courier_eta_forge",
        "Courier job — parts run to Eta Forge",
        "entity_reach_authority",
        "delivery",
        160,
        dest="station_eta_forge",
    )
    contract(
        "contract_courier_theta_gate",
        "Courier job — sealed crate to Theta Gate",
        "entity_theta_watch",
        "delivery",
        170,
        dest="station_theta_gate",
    )
    contract(
        "contract_courier_eta_depot",
        "Courier job — ice manifest to Eta Depot",
        "entity_eta_consortium",
        "delivery",
        150,
        dest="station_eta_depot",
    )
    contract(
        "contract_bounty_eta",
        "Bounty — clear hostiles in Eta Reach",
        "entity_eta_consortium",
        "bounty",
        200,
        dest="station_eta_forge",
        target_sys="system_eta",
    )
    contract(
        "contract_bounty_theta",
        "Bounty — clear hostiles on the Theta line",
        "entity_theta_watch",
        "bounty",
        210,
        dest="station_theta_anchor",
        target_sys="system_theta",
    )
    contract(
        "contract_smuggle_ice_outer",
        "Quiet run — ice past Watch berths",
        "entity_lane_brokers",
        "smuggle",
        190,
        dest="station_theta_gate",
        cargo="commodity_ice",
        cargo_qty=6,
    )
    contract(
        "contract_flash_ledger_1",
        "Flashpoint: Ledger scrap — first pick-up",
        "entity_beta_syndicate",
        "delivery",
        140,
        dest="station_beta_spit",
    )
    contract(
        "contract_flash_ledger_2",
        "Flashpoint: Ledger scrap — dead-drop",
        "entity_beta_syndicate",
        "delivery",
        160,
        dest="station_epsilon_belt",
    )
    contract(
        "contract_flash_watchline_1",
        "Flashpoint: Watch line — supply hop",
        "entity_theta_watch",
        "delivery",
        155,
        dest="station_theta_anchor",
    )
    contract(
        "contract_flash_watchline_2",
        "Flashpoint: Watch line — fringe relay",
        "entity_theta_watch",
        "escort",
        180,
        dest="station_theta_gate",
    )

    patch_existing_stations()
    print("S9 content fill done.")


def patch_existing_stations() -> None:
    """Inject ice/components into existing station markets for no-dead-goods."""
    patches: dict[str, dict[str, dict[str, float]]] = {
        "station_alpha_port": {
            "stock": {"commodity_ice": 70.0, "commodity_components": 95.0},
            "produce": {"commodity_components": 2.5},
            "consume": {"commodity_ice": 1.3},
        },
        "station_alpha_yard": {
            "stock": {"commodity_ice": 100.0, "commodity_components": 100.0},
            "produce": {"commodity_components": 3.5},
            "consume": {"commodity_ice": 1.2},
        },
        "station_beta_hub": {
            "stock": {"commodity_ice": 80.0, "commodity_components": 70.0},
            "produce": {},
            "consume": {"commodity_components": 1.4, "commodity_ice": 0.9},
        },
        "station_beta_spit": {
            "stock": {"commodity_ice": 90.0, "commodity_components": 45.0},
            "produce": {"commodity_ice": 2.0},
            "consume": {"commodity_components": 1.5},
        },
        "station_delta_port": {
            "stock": {"commodity_ice": 110.0, "commodity_components": 60.0},
            "produce": {"commodity_ice": 2.5},
            "consume": {"commodity_components": 1.3},
        },
        "station_delta_yard": {
            "stock": {"commodity_ice": 100.0, "commodity_components": 95.0},
            "produce": {"commodity_components": 3.0},
            "consume": {"commodity_ice": 1.1},
        },
        "station_epsilon_belt": {
            "stock": {"commodity_ice": 180.0, "commodity_components": 50.0},
            "produce": {"commodity_ice": 4.0},
            "consume": {"commodity_components": 1.6},
        },
        "station_gamma_outpost": {
            "stock": {"commodity_ice": 160.0, "commodity_components": 45.0},
            "produce": {"commodity_ice": 3.0},
            "consume": {"commodity_components": 1.5},
        },
        "station_gamma_rim": {
            "stock": {"commodity_ice": 150.0, "commodity_components": 40.0},
            "produce": {"commodity_ice": 3.5},
            "consume": {"commodity_components": 1.7},
        },
        "station_zeta_spur": {
            "stock": {"commodity_ice": 200.0, "commodity_components": 35.0},
            "produce": {"commodity_ice": 4.5},
            "consume": {"commodity_components": 1.8},
        },
    }

    for station_id, ops in patches.items():
        path = CONTENT / "stations" / f"{station_id}.tres"
        text = path.read_text(encoding="utf-8")
        text = inject_dict_entries(text, "stock_targets", ops["stock"])
        text = inject_dict_entries(text, "produces", ops["produce"])
        text = inject_dict_entries(text, "consumes", ops["consume"])
        path.write_text(text, encoding="utf-8")
        print(f"patched {path.relative_to(ROOT)}")


def inject_dict_entries(text: str, field: str, entries: dict[str, float]) -> str:
    if not entries:
        return text
    marker = f"{field} = Dictionary[StringName, float]({{"
    if marker not in text:
        raise SystemExit(f"missing field {field}")
    # Insert before closing of that dict block (first "}\n)" after marker)
    start = text.index(marker)
    close = text.index("})", start)
    block = text[start:close]
    additions = []
    for k, v in entries.items():
        key = f'&"{k}"'
        if key in block:
            continue
        additions.append(f"{key}: {v}")
    if not additions:
        return text
    insert = ",\n".join(additions)
    # ensure trailing comma on previous last line if needed
    before = text[:close].rstrip()
    if not before.endswith(",") and not before.endswith("{"):
        before += ","
    return before + "\n" + insert + "\n" + text[close:]


if __name__ == "__main__":
    main()
