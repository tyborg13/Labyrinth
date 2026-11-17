extends "res://tools/atk06/audit.gd"
## Opt-in targeted encounter / widened hit audit. atk06 defaults are untouched.
## Configuration is via ATK13_* so the inherited CLI remains byte-compatible.
const Observer = preload("res://tools/atk13/observed_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const PROOF_TIME_SCALE: float = 64.0
const PROOF_MAX_FPS: int = 0
const PROOF_TURN_LIMIT: int = 36
const PROOF_MOVE_PROBABILITY: float = 0.75
const PROOF_ENTRY_DIRECTION := Vector2i.UP
var entered: bool = false
var forecast_chain_owners: Dictionary = {}
var oracle: RefCounted = Observer.new()
var tier: int = int(OS.get_environment("ATK13_TIER"))
var turn_limit: int = PROOF_TURN_LIMIT
var intent_counts: Dictionary = {}
var advance_rng := RandomNumberGenerator.new()

func _initialize() -> void:
	super._initialize()
	Engine.time_scale = PROOF_TIME_SCALE
	Engine.max_fps = PROOF_MAX_FPS
	advance_rng.seed = hunt_seed
	if not OS.get_environment("ATK13_TURNS").is_empty(): turn_limit = int(OS.get_environment("ATK13_TURNS"))

func _tick() -> void:
	if finished or busy or not is_instance_valid(scene): return
	if bool(scene.get("_animation_lock")): return
	if settle_frames > 0:
		settle_frames -= 1
		return
	var run: Dictionary = scene.get("_run_state")
	if not entered:
		if str(run.get("mode", "")) != "room" or bool(scene.get("_dialogue_active")) or scene.get("_opening_boon_flow").active():
			super._tick()
			return
		_enter_cantor(run)
		return
	if bool(scene.get("_dialogue_active")) or scene.get("_opening_boon_flow").active():
		super._tick()
		return
	var state: Dictionary = scene.get("_combat_state")
	if str(run.get("mode", "")) != "combat" or state.is_empty():
		_finish("encounter_complete")
		return
	var engine: RefCounted = scene.get("_combat_engine")
	if not engine.combat_outcome(state).is_empty():
		_finish(engine.combat_outcome(state))
		return
	if not _audit_ready(): return
	var started: int = Time.get_ticks_usec()
	_audit_decision_point()
	audit_usec += Time.get_ticks_usec() - started
	if audit_points >= turn_limit:
		_finish("target_turn_limit")
		return
	# Full-health walk, no hero attacks: sample the complete production cycle.
	# Actual continuation uses committed engine transitions, not animation time.
	var next: Dictionary = state
	var legal: Array = engine.player_movement_targets(state)
	if not legal.is_empty() and advance_rng.randf() < PROOF_MOVE_PROBABILITY:
		next = engine.apply_player_movement(state, legal[advance_rng.randi_range(0, legal.size() - 1)])
		Committed.accept(engine, next)
	oracle.receipts.clear()
	oracle.observing = true
	next = Committed.finish_player_activation(oracle, next)
	next = Committed.advance_to_player(oracle, next)["state"]
	oracle.observing = false
	samples.store_line(JSON.stringify({"kind": "walked", "point": "%d-%d" % [hunt_seed, audit_points], "receipts": oracle.receipts}))
	var updated: Dictionary = run.duplicate(true)
	updated["combat_state"] = next
	scene.call("_load_run_state", updated)
	settle_frames = SETTLE_FRAMES

func _enter_cantor(run: Dictionary) -> void:
	var selected: Dictionary = {}
	var available: Array[int]
	for room: Dictionary in run["rooms"].values():
		if str(room.get("guardian_id", "")) != "storm_cantor": continue
		var local_tier: int = posmod(int(room["depth"]) - 1, 4) + 1
		if not available.has(local_tier): available.append(local_tier)
		if local_tier == tier and selected.is_empty(): selected = room
	if selected.is_empty():
		samples.store_line(JSON.stringify({"kind": "tier_unavailable", "seed": hunt_seed, "tier": tier, "available": available}))
		_finish("tier_unavailable")
		return
	var prepared: Dictionary = run.duplicate(true)
	var room: Dictionary = Graph.room(prepared, selected["coord"])
	room["cleared"] = false
	room["revealed"] = true
	room["visited"] = true
	room["sealed"] = false
	prepared["current_room"] = room["coord"]
	var run_engine: RefCounted = scene.get("_run_engine")
	prepared["current_room_layout"] = run_engine._display_layout_for_room(int(run["seed"]), room, PROOF_ENTRY_DIRECTION)
	prepared["mode"] = "pre_battle"
	prepared["pre_battle_pending"] = true
	prepared["pre_battle_travel_dir"] = PROOF_ENTRY_DIRECTION
	prepared["combat_state"] = {}
	Graph.refresh_knowledge(prepared)
	prepared = run_engine.begin_pre_battle_combat(prepared)
	scene.call("_load_run_state", prepared)
	entered = true
	settle_frames = SETTLE_FRAMES
	samples.store_line(JSON.stringify({"kind": "target_encounter", "seed": hunt_seed, "tier": tier, "depth": room["depth"], "section": room["section_index"], "available": available, "health": hunt_health}))

func _audit_decision_point() -> void:
	var state: Dictionary = scene.get("_combat_state")
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		var key: String = str(enemy["type"]) + ":" + str(enemy.get("intent", {}).get("id", ""))
		intent_counts[key] = int(intent_counts.get(key, 0)) + 1
	super._audit_decision_point()
	samples.flush()

func _hero(state: Dictionary) -> Dictionary:
	return Observer.hero(state)

func _add_slice(trace: Dictionary, entry: Array, before: Dictionary, after: Dictionary) -> void:
	super._add_slice(trace, entry, before, after)
	(trace["slices"] as Array).back()["statuses"] = Observer.delta(before, after)["statuses"]

func _check(engine: RefCounted, committed: Dictionary, mode: String, tile: Vector2i, point_id: String) -> Dictionary:
	var result: Dictionary = super._check(engine, committed, mode, tile, point_id)
	result["tier"] = tier
	result["oracle_matches_production"] = bool(result.get("actual_trace", {}).get("oracle_matches_production", false))
	var shown_plans: Dictionary = {}
	for enemy: Dictionary in committed.get("enemies", []):
		var index: int = engine._enemy_index_for_id(committed, int(enemy["id"]))
		shown_plans["enemy_%d" % int(enemy["id"])] = engine.enemy_threat_tiles(committed, index).get("projected_attack", [])
	result["shown_plans"] = shown_plans
	var rule_rows: Dictionary = {}
	for enemy: Dictionary in committed.get("enemies", []):
		var rows: Array = preload("res://scripts/battlefield_rules/intent_rows.gd").tokens(committed, enemy, enemy.get("intent", {}))
		if not rows.is_empty(): rule_rows["enemy_%d" % int(enemy["id"])] = rows
	result["announced_rule_rows"] = rule_rows
	result["forecast_chain_hero_owners"] = forecast_chain_owners.duplicate()
	result["forecast_chain_receipt_version"] = 1
	# Every point has a resumable production save, including status-only misses.
	result["repro"] = _save_repro(point_id, committed)
	return result

func _actual_trace(_engine: RefCounted, committed: Dictionary, state: Dictionary) -> Dictionary:
	oracle.receipts.clear()
	oracle.observing = true
	var result: Dictionary = super._actual_trace(oracle, committed, state)
	var baseline: Dictionary = super._actual_trace(_engine, committed, state)
	result["oracle_matches_production"] = result == baseline
	oracle.observing = false
	result["receipts"] = oracle.receipts.duplicate(true)
	return result

func _emit_sample(context: Dictionary, row: Dictionary) -> void:
	if row.get("kind") == "check":
		# The base serializer intentionally copies only legacy fields. Add the
		# oracle receipts here from actual_trace, retained until _check returns.
		row["receipts"] = oracle.receipts.duplicate(true)
	super._emit_sample(context, row)

func _finish(outcome: String) -> void:
	if samples != null: samples.store_line(JSON.stringify({"kind": "atk13_coverage", "tier": tier, "intents": intent_counts}))
	await super._finish(outcome)

func _shown(summary: Dictionary) -> Dictionary:
	var shown: Dictionary = super._shown(summary)
	var portraits: Array[Dictionary]
	var inks: Dictionary = {"block": Color.WHITE, "stoneskin": Color.WHITE, "health": Color.WHITE, "defiance": Color.WHITE, "unknown": Color.WHITE}
	var status_rows: Dictionary = {}
	for row: Dictionary in preload("res://scripts/pass_forecast_focus_tooltip.gd").rows(summary, portraits, inks):
		if row.has("status_gain"):
			status_rows[str(row["status_gain"])] = int(str(row["parts"][0]["text"]).trim_prefix("+"))
	shown["status_rows"] = status_rows
	return shown

func _forecast_trace(engine: RefCounted, committed: Dictionary, source: Dictionary) -> Dictionary:
	var result: Dictionary = super._forecast_trace(engine, committed, source)
	forecast_chain_owners = result.get("phase_result", {}).get("chain_hero_owners", {}).duplicate()
	return result
