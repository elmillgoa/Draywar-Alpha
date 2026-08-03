extends Node
## Cross-system signal bus. All cross-domain communication goes through here.
## Catalog: docs/events.md — keep that file in the same commit as any new signal.

## TimeScale: the effective rate clocks will get after a change.
signal on_time_scale_changed(scale: float)

## TimeScale: combat lock opened or closed.
signal on_combat_lock_changed(locked: bool)

## WorldClock: bulk away-time advance finished (not per-frame).
signal on_world_time_advanced(total_elapsed_seconds: float, delta_seconds: float)

## SaveService: a career was loaded successfully from this path.
signal on_save_loaded(path: String)

## ConsoleService: who is out there? Systems answer with registrations.
signal on_console_commands_requested

## A system is offering a command for the console roster.
signal on_console_command_registered(name: StringName, usage: String, summary: String)

## ConsoleService: a registered name was submitted with these args.
signal on_console_command_invoked(name: StringName, args: PackedStringArray)

## Anything with something to say to the console view.
signal on_console_output(line: String)

## DebugConsole: the prompt opened or closed.
signal on_console_visibility_changed(open: bool)

## SystemWorld: the player is now in this system (session-only for A1).
signal on_system_entered(system_id: StringName)

## Player / DockingService: request to dock at this station.
signal on_dock_requested(station_id: StringName)

## DockingService: ship is now docked at this station.
signal on_docked(station_id: StringName)

## UI: request to leave this station.
signal on_undock_requested(station_id: StringName)

## DockingService: ship has left this station and is free-flying again.
signal on_undocked(station_id: StringName)

## DockingService: dock prompt state for the HUD (empty id clears).
signal on_dock_prompt_changed(station_id: StringName, can_dock: bool)

## PlayerShip: speed magnitude changed (session HUD).
signal on_player_speed_changed(speed: float)

## PlayerShip: throttle 0..1 changed (session HUD).
signal on_player_throttle_changed(throttle: float)

## StandingService: player standing with an Entity changed.
signal on_entity_standing_changed(
	entity_id: StringName, old_value: float, new_value: float, tier: StringName
)

## StandingService: player standing with a Person changed.
signal on_person_standing_changed(
	person_id: StringName, old_value: float, new_value: float, tier: StringName
)

## StandingService: protected status moment (system or station entry).
signal on_status_moment(
	kind: StringName, place_id: StringName, entity_id: StringName, standing: float, tier: StringName
)

## DockingService: dock blocked by standing with the station controller.
signal on_dock_refused(
	station_id: StringName, entity_id: StringName, standing: float, tier: StringName
)

## AttributionService: a kill was reported (before attribution decision).
signal on_kill_reported(
	system_id: StringName, victim_entity_id: StringName, witness_count: int, evidence: bool
)

## AttributionService: kill was attributed; standing delta already applied.
signal on_kill_attributed(
	system_id: StringName, entity_id: StringName, delta: float, reason: StringName
)

## AttributionService: kill was not attributed (no standing change from this kill).
signal on_kill_unattributed(system_id: StringName, victim_entity_id: StringName)

## UI / console: request to accept this mission template.
signal on_mission_accept_requested(template_id: StringName)

## MissionService: player accepted a mission.
signal on_mission_accepted(template_id: StringName, offering_entity_id: StringName)

## MissionService: mission completed; standing delta already applied.
signal on_mission_completed(template_id: StringName, entity_id: StringName, delta: float)

## MissionService: mission failed; standing delta already applied.
signal on_mission_failed(template_id: StringName, entity_id: StringName, delta: float)

## MissionService: mission abandoned; standing delta already applied.
signal on_mission_abandoned(template_id: StringName, entity_id: StringName, delta: float)

## UI / console: request to accept the next recovery step from this Person.
signal on_recovery_accept_requested(person_id: StringName)

## RecoveryService: a recovery step is available from this Person (e.g. on dock).
signal on_recovery_offered(chain_id: StringName, step_id: StringName, person_id: StringName)

## RecoveryService: player accepted a recovery step.
signal on_recovery_accepted(chain_id: StringName, step_id: StringName, person_id: StringName)

## RecoveryService: recovery step completed; standing deltas already applied.
signal on_recovery_completed(
	chain_id: StringName,
	step_id: StringName,
	person_id: StringName,
	entity_id: StringName,
	person_delta: float,
	entity_delta: float
)

## RecoveryService: recovery step failed; personal delta already applied.
signal on_recovery_failed(
	chain_id: StringName, step_id: StringName, person_id: StringName, person_delta: float
)

## RecoveryService: recovery step abandoned; personal delta already applied.
signal on_recovery_abandoned(
	chain_id: StringName, step_id: StringName, person_id: StringName, person_delta: float
)

## RecoveryService: player betrayed a recovery contact; standing already applied.
signal on_recovery_betrayed(person_id: StringName, person_delta: float, entity_delta: float)

## StandingService: a Person's recovery route is closed (betrayal, etc.).
signal on_person_closed(person_id: StringName, reason: StringName)

## GateTravelService: jump prompt for the HUD (empty dest clears).
signal on_gate_prompt_changed(destination_system_id: StringName, can_jump: bool)

## Ship / GateTravelService: request to jump to this system.
signal on_jump_requested(destination_system_id: StringName)

## Main: player left a system (before the destination is built).
signal on_system_exited(system_id: StringName)

## WalletService: credits changed.
signal on_credits_changed(credits: int)

## FuelService: fuel changed (current and max).
signal on_fuel_changed(fuel: float, fuel_max: float)

## HullConditionService: hull condition changed (current and max).
signal on_condition_changed(condition: float, condition_max: float)

## UI: request to complete the active mission.
signal on_mission_complete_requested

## UI: request to abandon the active mission.
signal on_mission_abandon_requested

## UI: request to complete the active recovery step.
signal on_recovery_complete_requested

## UI: request to abandon the active recovery step.
signal on_recovery_abandon_requested

## UI: request a favor bootstrap with this Person.
signal on_recovery_favor_requested(person_id: StringName)

## UI: request betrayal of this Person (or active recovery contact).
signal on_recovery_betray_requested(person_id: StringName)

## UI: request refuel at the docked station.
signal on_refuel_requested

## UI: request full repair at the docked station.
signal on_repair_requested

## UI: request Free Haulers emergency loan (E3.2, docked Services).
signal on_loan_borrow_requested

## UI: request manual debt repay from credits (E3.2, docked Services).
signal on_loan_repay_requested

## WalletService: debt owed / lender / grace changed (E3.2).
signal on_debt_changed(debt_owed: int, lender_id: StringName, grace_docks_left: int)

## Main menu: start a new career.
signal on_new_game_requested

## Main menu: continue the most recent career save.
signal on_continue_requested

## Main menu: quit the application.
signal on_quit_to_desktop_requested

## Pause menu: leave play and return to the main menu.
signal on_quit_to_menu_requested

## Life-path create UI: player confirmed three axis picks (E4.2).
signal on_life_path_confirmed(origin_id: StringName, trade_id: StringName, mark_id: StringName)

## Life-path create UI: player cancelled back to main menu (E4.2).
signal on_life_path_cancel_requested

## Opening annexation UI: player dismissed the beat (E4.3).
signal on_annexation_continue_requested

## Main: pause overlay opened or closed.
signal on_pause_changed(open: bool)

## Pause / UI: open the captain sheet.
signal on_captain_sheet_open_requested

## Captain sheet: close the sheet.
signal on_captain_sheet_close_requested

## Pause / flight: open the sector chart (E5.5).
signal on_sector_map_open_requested

## Sector map: close the chart.
signal on_sector_map_close_requested

## Pause menu: write the default career save.
signal on_manual_save_requested

## Pause menu: load the most recent career save.
signal on_manual_load_requested

## UI: request to buy this commodity quantity at the docked station.
signal on_trade_buy_requested(commodity_id: StringName, quantity: int)

## UI: request to sell this commodity quantity at the docked station.
signal on_trade_sell_requested(commodity_id: StringName, quantity: int)

## CargoService: hold contents or used volume changed.
signal on_cargo_changed

## CargoService: a buy or sell finished (credits already moved).
signal on_trade_completed(
	side: StringName, commodity_id: StringName, quantity: int, credits_delta: int
)

## MarketService: a player trade moved a station's market for this commodity.
signal on_market_changed(
	station_id: StringName, commodity_id: StringName, stock: int, unit_buy_price: int
)

## MarketService: a catch-up batch of market sim steps finished (never per step).
signal on_market_ticked(steps_applied: int, elapsed_seconds: float)

## MarketService: a new one-line sector headline is available for the ticker.
signal on_market_news(line: String)

## IncidentService: a new opportunistic space incident is offered (not a mission).
signal on_incident_offered(
	incident_id: StringName, kind: StringName, system_id: StringName, prompt: String
)

## IncidentService: HUD / console prompt for the offered incident.
signal on_incident_prompt(incident_id: StringName, kind: StringName, prompt: String)

## IncidentService: incident left the offered set (resolved / expired / promoted).
signal on_incident_resolved(
	incident_id: StringName,
	kind: StringName,
	system_id: StringName,
	outcome: StringName,
	promoted: bool
)

## Any money path: credits moved, tagged by activity for the telemetry log.
signal on_money_event(
	reason: StringName, credits_delta: int, credits_after: int, detail: Dictionary
)

## CargoService: fee-charging dock found jurisdictional contraband (fine + standing done).
signal on_contraband_seized(
	station_id: StringName,
	entity_id: StringName,
	commodity_ids: PackedStringArray,
	fine_paid: int,
	standing_delta: float
)

## EnforcementService: per-Entity heat changed (S4). Not standing.
signal on_heat_changed(entity_id: StringName, heat: float, reason: StringName)

## PlayerShip / HostileNpc: weapon discharged (travel bolt spawn).
signal on_weapon_fired

## PlayerShip: target lock acquired, cycled, or cleared.
## locked false clears the HUD lock line; label/distance are then empty / 0.
signal on_target_lock_changed(locked: bool, label: String, distance: float)

## HostileNpc: took damage; remaining hull after the hit.
signal on_hostile_damaged(remaining_hp: float)

## HostileNpc: died (before / with attribution report).
signal on_hostile_killed(system_id: StringName, victim_entity_id: StringName)

## HullConditionService: player hull took combat damage (condition after hit).
signal on_player_damaged(condition: float)

## HullConditionService: condition reached zero — fail state until dock + repair.
signal on_player_crippled

## HullConditionService: repair restored condition after a cripple.
signal on_player_repaired_from_cripple

## UI: request one-time Fighter purchase at the docked station (E2.5).
signal on_buy_fighter_requested

## UI: request switch to this owned hull while docked (E2.5).
signal on_switch_hull_requested(hull_id: StringName)

## ShipService: Fighter (or other) hull purchased once; ownership updated.
signal on_hull_purchased(hull_id: StringName)

## ShipService: active flyable hull changed (switch, load, or set).
signal on_hull_changed(old_hull_id: StringName, new_hull_id: StringName)

## UI: request install of a weapon or equipment item while docked (S5).
signal on_outfit_install_requested(item_id: StringName)

## UI: request uninstall of an installed item at a slot index (S5).
signal on_outfit_uninstall_requested(item_id: StringName, slot_index: int)

## ShipService: weapons/equipment on a hull changed (install, remove, load).
signal on_loadout_changed(hull_id: StringName)
