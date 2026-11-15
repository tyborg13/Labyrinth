extends "res://tools/atk01/audit.gd"
## atk-06 rest red-tile audit (proof tool; not a test, never in default groups).
## Reuses the atk-01 walk: at every idle decision point it reads the PASS forecast,
## every movement destination's forecast and the real resolution. On top of that
## it reads the red threat tiles exactly as the board draws them (the board's own
## rest alphas and Lob marks, on tiles the player can see): once at rest, and once
## with each destination hovered. Every simulated enemy activation also carries
## that foe's own plan at that moment (enemy_threat_tiles, the red set's source),
## so a plan that disagrees with its own resolution shows up directly.
const IntentBadges = preload("res://scripts/intent_badges.gd")
const LobView = preload("res://scripts/enemy_mechanics/lob_view.gd")
const BattlefieldRuleView = preload("res://scripts/battlefield_rule_view.gd")
const Memo = preload("res://scripts/combat_preview_memo.gd")
const EngineScript = preload("res://scripts/combat_engine.gd")
const RedTiles = preload("res://scripts/pass_forecast_red_tiles.gd")

# Plans are read on a separate engine so the scene's caches (and its timings) stay as they are.
var plan_engine: RefCounted = EngineScript.new()
var timing_engine: RefCounted = EngineScript.new()
var point_rest: Dictionary = {}
# atk-09: the red set the pre-atk-09 rule draws on the same state (no later
# activations' tiles; foes that die first keep their red), for paired before/after.
var point_rest_old: Dictionary = {}
var point_hero: Vector2i = Vector2i(-1, -1)
var point_reach: Dictionary = {}
var hover_previews: Array[Dictionary]
# [plan µs, whole replica µs] of each forecast replica run inside one check (the first is the UI's).
var trace_usec: Array[Array]

func _audit_decision_point() -> void:
	var board: Control = scene.get("board_view")
	var committed: Dictionary = scene.get("_combat_state")
	# The set the board holds right now (a stale plan would differ), then a fresh rest refresh.
	var held: Dictionary = _board_red(board)
	scene.set("_hovered_board_tile", INVALID)
	var started: int = Time.get_ticks_usec()
	scene.call("_refresh_stage_view")
	var refresh_usec: int = Time.get_ticks_usec() - started
	point_rest = _board_red(board)
	point_hero = committed["player"]["pos"]
	var marks: Dictionary = scene.get("_rest_pass_disc_marks")
	var died_first: Dictionary = marks.get("died_first", {}) if int(marks.get("revision", -1)) == int(scene.get("_combat_preview_revision")) else {}
	point_rest_old = _old_red(board, point_rest, died_first, committed, committed)
	var badges: Dictionary = {}
	for badge: Dictionary in (board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("badges", []):
		badges[str(badge.get("key", ""))] = {"acting": bool(badge.get("acting", false)), "cancelled": bool(badge.get("cancelled", false)), "family": str(badge.get("family", "")), "icon": str(badge.get("icon", ""))}
	point_reach = {}
	for threat: Dictionary in scene.call("_visible_enemy_threat_previews", scene.call("_board_display_state")):
		for tile: Vector2i in threat.get("attack", []): point_reach[tile] = true
	hover_previews.clear()
	var point_id: String = "%d-%d" % [hunt_seed, audit_points + 1]
	super._audit_decision_point()
	# Cost of building the red set from cold per-engine caches: at rest, and for every destination.
	var build_usec: int = _timed_build(committed, committed)
	var red_extra_usec: int = _timed_red_extra(board)
	var hover_usec: Array[int]
	for preview: Dictionary in hover_previews: hover_usec.append(_timed_build(committed, preview))
	hover_previews.clear()
	scene.set("_hovered_board_tile", INVALID)
	scene.call("_refresh_stage_view")
	var player: Dictionary = committed["player"]
	var status: Dictionary = {}
	for field: String in ["bleed", "burn", "burning", "chilled", "shock", "freeze", "immobilize", "expose"]:
		if player.has(field) and str(player[field]) not in ["0", "false", ""]: status[field] = player[field]
	samples.store_line(JSON.stringify({"kind": "red_point", "point": point_id, "hero": str(point_hero),
		"rest": _out(point_rest), "held_matches": _keys(held) == _keys(point_rest), "held": _out(held) if _keys(held) != _keys(point_rest) else {},
		"reach": point_reach.keys().map(func(tile: Vector2i) -> String: return str(tile)),
		"badges": badges, "build_usec": build_usec, "red_extra_usec": red_extra_usec, "hover_build_usec": hover_usec, "refresh_usec": refresh_usec, "hero_status": status,
		"rule": str((committed.get("battlefield_rule", {}) as Dictionary).get("rule", "")), "rule_due": BattlefieldRuleView.beat_before_next_player_turn(committed) if not BattlefieldRuleView.BattlefieldRules.active(committed).is_empty() else false}))

func _check(engine: RefCounted, committed: Dictionary, mode: String, tile: Vector2i, point_id: String) -> Dictionary:
	trace_usec.clear()
	var result: Dictionary = super._check(engine, committed, mode, tile, point_id)
	if not trace_usec.is_empty():
		result["plan_usec"] = trace_usec[0][0]
		result["trace_usec"] = trace_usec[0][1]
	var at: Vector2i = tile if mode == "move" else point_hero
	result["red"] = point_rest.has(at)
	result["red_owners"] = point_rest.get(at, [])
	result["red_old"] = point_rest_old.has(at)
	result["in_reach"] = point_reach.has(at)
	if mode != "pass":
		# What the board draws with this destination hovered (the movement preview).
		var board: Control = scene.get("board_view")
		scene.call("_refresh_stage_view")
		var hovered: Dictionary = _board_red(board)
		result["red_hover"] = hovered.has(at)
		result["hover_owners"] = hovered.get(at, [])
		var hover_preview: Dictionary = scene.call("_enemy_intent_preview_state", scene.call("_board_display_state"))
		var hover_died: Dictionary = (scene.call("_hover_red_forecast") as Dictionary).get("died_first_keys", {})
		result["red_hover_old"] = _old_red(board, hovered, hover_died, committed, hover_preview).has(at)
		result["hover_forecast_ready"] = bool(scene.get("_hover_red_forecast_ready"))
		# Red is only painted on tiles the player can see now.
		result["tile_seen"] = bool(board.call("_board_tile_is_visible_to_player", at))
		if mode == "move": hover_previews.append(scene.call("_enemy_intent_preview_state", scene.call("_board_display_state")))
	_keep_evidence(result, committed, point_id)
	return result

# A real save for the first few checks of each kind of disagreement (red vs the
# forecast, and a plan vs its own resolution), for reproductions and captures.
const EVIDENCE_PER_KEY: int = 4
const EVIDENCE_LIMIT: int = 400
var evidence_counts: Dictionary = {}
var evidence_saved: int = 0

func _keep_evidence(result: Dictionary, committed: Dictionary, point_id: String) -> void:
	var shown: Dictionary = result["shown"]
	var slices: Array = result["forecast_sim"]["slices"]
	var hit: bool = bool(shown["defeat"])
	var first: Dictionary = {}
	for slice: Dictionary in slices:
		# Block that simply expires at the start of the hero's turn is not a hit.
		var block: int = 0 if str(slice["actor"]) == "turn_start" else int(slice["block"])
		var hurts: bool = int(slice["hp"]) + block + int(slice["stoneskin"]) > 0 or (bool(slice["moved"]) and str(slice["actor"]) != "move")
		if hurts: hit = true
		if hurts and first.is_empty() and str(slice["actor"]) != "move": first = slice
		if str(slice.get("plan", "")) == "ok" and bool(slice.get("visible", false)) and bool(slice.get("covers", false)) != hurts:
			_evidence("plan:%s:%s:%s" % [slice.get("type", ""), ",".join(slice.get("acts", [])), slice.get("covers", false)], result, committed, point_id)
	# atk-09: the panel's Block row when the only Block the forecast loses expires at the turn start.
	var expiring: int = 0
	var taken: int = 0
	for slice: Dictionary in slices:
		if str(slice["actor"]) == "turn_start": expiring += int(slice["block"])
		else: taken += int(slice["block"])
	result["block_expiry_only"] = int(shown["block"]) > 0 and expiring > 0 and taken == 0
	# The same states the pre-atk-09 panel showed as a Block loss, now left out.
	result["block_expiry_hidden"] = int(shown["block"]) == 0 and expiring > 0 and taken == 0
	if bool(result["block_expiry_only"]): _evidence("%s:block_expiry" % result["mode"], result, committed, point_id)
	# The set drawn with this destination hovered, by the foe that explains it.
	if result.has("red_hover") and bool(result["red_hover"]) != hit:
		var owners: Array = result["hover_owners"]
		var who: String = str(first.get("type", first.get("actor", "walk")))
		if bool(result["red_hover"]): who = _enemy_type(committed, str(owners[0])) if not owners.is_empty() and str(owners[0]).begins_with("enemy_") else ",".join(owners)
		_evidence("hover:%s:%s:%s" % ["alarm" if bool(result["red_hover"]) else "miss", who, first.get("covers", "-")], result, committed, point_id)
	if bool(result["red"]) == hit: return
	var key: String = "%s:%s:" % [result["mode"], "alarm" if bool(result["red"]) else "miss"]
	if bool(result["red"]): key += ",".join(result["red_owners"]).get_slice("_", 0)
	elif first.is_empty(): key += "walk"
	elif not str(first["actor"]).begins_with("enemy_"): key += str(first["actor"])
	else: key += "n%d:%s:%s" % [mini(int(first["n"]), 2), first.get("covers", "-"), result.get("red_hover", "-")]
	_evidence(key, result, committed, point_id)

func _evidence(key: String, result: Dictionary, committed: Dictionary, point_id: String) -> void:
	if int(evidence_counts.get(key, 0)) >= EVIDENCE_PER_KEY or evidence_saved >= EVIDENCE_LIMIT: return
	evidence_counts[key] = int(evidence_counts.get(key, 0)) + 1
	evidence_saved += 1
	result["repro"] = _save_repro(point_id, committed)
	result["evidence_key"] = key

# atk-09: the pre-atk-09 red set on this state: drop tiles only later activations
# own, and give back the first-activation tiles of foes the forecast has die first.
func _old_red(board: Control, red: Dictionary, died_first: Dictionary, committed: Dictionary, preview: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for tile: Vector2i in red:
		var owners: Array = (red[tile] as Array).filter(func(owner: String) -> bool: return not owner.begins_with("later:"))
		if not owners.is_empty(): result[tile] = owners
	if died_first.is_empty(): return result
	var built: Dictionary = IntentBadges.build(plan_engine, committed, preview, "", scene.call("_surface_preview_information_state", preview))
	for threat: Dictionary in built.get("threats", []):
		if not died_first.has(str(threat.get("key", ""))): continue
		for tile: Vector2i in threat.get("tiles", []):
			if not bool(board.call("_board_tile_is_visible_to_player", tile)): continue
			var owners: Array = result.get(tile, [])
			owners.append("died_first:" + str(threat["key"]))
			result[tile] = owners
	return result

# --- the red set exactly as threat_operations draws it ------------------------------

func _board_red(board: Control) -> Dictionary:
	return board_red(board)

static func board_red(board: Control) -> Dictionary:
	var result: Dictionary = {}
	var rest: Dictionary = (board.get("presentation") as Dictionary).get("threats_at_rest", {})
	var alphas: Dictionary = board.get("_rest_threat_tile_alphas")
	var lob: Dictionary = LobView.marks(board)
	for tile: Vector2i in alphas:
		if not bool(board.call("_board_tile_is_visible_to_player", tile)): continue
		var owners: Array = []
		for threat: Dictionary in rest.get("threats", []):
			# atk-09: a later activation's tiles are owned by "later:<foe>".
			if (threat.get("tiles", []) as Array).has(tile): owners.append(("later:" if bool(threat.get("later", false)) else "") + str(threat.get("key", "")))
		result[tile] = owners
	for tile: Vector2i in lob:
		if not bool(board.call("_board_tile_is_visible_to_player", tile)): continue
		var owners: Array = result.get(tile, [])
		owners.append("lob:enemy_%d" % int(lob[tile]["enemy"]["id"]))
		result[tile] = owners
	return result

func _keys(red: Dictionary) -> Array:
	var keys: Array = red.keys().map(func(tile: Vector2i) -> String: return str(tile))
	keys.sort()
	return keys

func _out(red: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for tile: Vector2i in red: result[str(tile)] = red[tile]
	return result

func _timed_build(committed: Dictionary, preview: Dictionary) -> int:
	timing_engine._threat_preview_cache.clear()
	for field: String in ["_threat_coverage_memo", "_threat_geometry_memo", "_standard_plan_memo"]: timing_engine.set(field, Memo.new())
	EngineScript._shared_standard_plan_memo = Memo.new()
	EngineScript._shared_enemy_navigation_memo = Memo.new()
	var started: int = Time.get_ticks_usec()
	var known: Dictionary = scene.call("_surface_preview_information_state", preview)
	IntentBadges.build(timing_engine, committed, preview, "", known)
	if not BattlefieldRuleView.BattlefieldRules.active(committed).is_empty(): BattlefieldRuleView._due_tiles(committed)
	return Time.get_ticks_usec() - started

# atk-09: the work the red set adds per decision point: its plans inside the
# at-rest PASS forecast (a simulation the discs already run), measured by that
# code's own phase on a cold engine, plus applying the record to the rest set.
func _timed_red_extra(board: Control) -> int:
	var source: Dictionary = scene.call("_pass_preview_source_state_for_tile", INVALID)
	if source.is_empty() or not timing_engine.is_player_turn(source): return 0
	timing_engine.set_runtime_performance_instrumentation_enabled(true)
	var phase: Dictionary = timing_engine.preview_revealed_enemy_actions_before_player_turn_with_steps(timing_engine.finish_player_activation(source), true)
	var planned: int = int(timing_engine.runtime_performance_instrumentation_snapshot().get("pass_forecast_red_tiles", {}).get("total_usec", 0))
	timing_engine.set_runtime_performance_instrumentation_enabled(false)
	var fields: Dictionary = RedTiles.summary_fields(phase)
	var rest: Dictionary = (board.get("presentation") as Dictionary).get("threats_at_rest", {})
	var started: int = Time.get_ticks_usec()
	RedTiles.adjust(rest, fields["later_red_tiles"], fields["died_first_keys"])
	return planned + Time.get_ticks_usec() - started

# --- the atk-01 forecast replica, with each activation's own plan ---------------------

func _forecast_trace(engine: RefCounted, committed: Dictionary, source: Dictionary) -> Dictionary:
	var trace_started: int = Time.get_ticks_usec()
	var trace: Dictionary = _new_trace()
	trace["plan_usec"] = 0
	if source.is_empty() or not engine.is_player_turn(source):
		trace["phase_result"] = {}
		return trace
	if source.get("player", {}).get("pos", INVALID) != committed["player"]["pos"] or int(source.get("_pass_forecast_source_hp", -1)) >= 0:
		_add_slice(trace, ["move", 0, false], _hero(committed), _hero(source))
	var scheduled: Dictionary = engine.finish_player_activation(source)
	_add_slice(trace, ["turn_end", 0, false], _hero(source), _hero(scheduled))
	var ended: Dictionary = (trace["slices"] as Array).back()
	ended["beat"] = _beat_mark(source) != _beat_mark(scheduled)
	var prefix: Array = (trace["slices"] as Array).duplicate(true)
	var cursor: Dictionary = engine.begin_revealed_enemy_actions_preview(scheduled, true)
	while not bool(cursor.get("complete", false)):
		var state: Dictionary = cursor["state"]
		var actor: Array = _peek_actor(engine, state)
		var before: Dictionary = _hero(state)
		var rolling: bool = bool(cursor.get("choose_next_intents", true))
		var started: int = Time.get_ticks_usec()
		var plan: Dictionary = _plan(state, actor)
		trace["plan_usec"] = int(trace["plan_usec"]) + Time.get_ticks_usec() - started
		var step_count: int = (cursor.get("steps", []) as Array).size()
		var beat_before: String = _beat_mark(state)
		# A rule beat can fire inside a foe's own turn; keep a copy to replay that turn without it.
		var pre: Dictionary = state.duplicate(true) if not plan.is_empty() and not BattlefieldRuleView.BattlefieldRules.active(state).is_empty() else {}
		engine.advance_revealed_enemy_actions_preview(cursor)
		if not rolling and bool(cursor.get("choose_next_intents", false)):
			trace = _new_trace()
			trace["plan_usec"] = 0
			for slice: Dictionary in prefix:
				(trace["slices"] as Array).append(slice.duplicate(true))
				trace["counts"][slice["actor"]] = 1
				for field: String in ["hp", "block", "stoneskin"]: trace[field] = int(trace[field]) + int(slice[field])
			trace["restarted"] = true
			continue
		_add_slice(trace, actor, before, _hero(cursor["state"]))
		var slice: Dictionary = (trace["slices"] as Array).back()
		slice.merge(plan)
		if not plan.is_empty():
			var kinds: Array = []
			for step: Variant in (cursor.get("steps", []) as Array).slice(step_count):
				if step is Dictionary and not kinds.has(str(step.get("kind", ""))): kinds.append(str(step.get("kind", "")))
			slice["step_kinds"] = kinds
			var after: Array = (cursor["state"] as Dictionary).get("enemies", [])
			var index: int = plan_engine._enemy_index_for_id(cursor["state"], int(actor[1]))
			slice["alive_after"] = index >= 0 and int((after[index] as Dictionary).get("hp", 0)) > 0
			slice["beat"] = beat_before != _beat_mark(cursor["state"])
			var hurts: bool = int(slice["hp"]) + int(slice["block"]) + int(slice["stoneskin"]) > 0 or bool(slice["moved"])
			if bool(slice["beat"]) and not pre.is_empty() and str(plan.get("plan", "")) == "ok" and bool(plan.get("covers", false)) != hurts:
				slice["hurts_without_rule"] = _hurts_without_rule(engine, pre, int(actor[1]))
	var phase_result: Dictionary = engine.revealed_enemy_actions_preview_result(cursor)
	var after_state: Dictionary = phase_result.get("state", {})
	trace["phase_result"] = phase_result
	trace["tile"] = (after_state.get("player", {}) as Dictionary).get("pos", INVALID)
	trace["outcome"] = engine.combat_outcome(after_state)
	trace_usec.append([int(trace["plan_usec"]), Time.get_ticks_usec() - trace_started])
	return trace

# Which battlefield beat has fired (the dispatcher counts each one).
func _beat_mark(state: Dictionary) -> String:
	var rule: Dictionary = state.get("battlefield_rule", {})
	return "" if rule.is_empty() else "%s:%d" % [rule.get("rule", ""), int(rule.get("beats_fired", 0))]

# Diagnostic only: the same activation on a copy with the battlefield rule removed.
func _hurts_without_rule(engine: RefCounted, state: Dictionary, enemy_id: int) -> bool:
	var popped: Dictionary = engine._pop_next_actor(state)
	var next: Dictionary = popped.get("state", state)
	next.erase("battlefield_rule")
	next.erase("wind")
	var index: int = engine._enemy_index_for_id(next, enemy_id)
	if index < 0: return false
	var before: Dictionary = _hero(next)
	var after: Dictionary = _hero(engine.resolve_enemy_turn_with_steps(next, index, false, false)["state"])
	return before["pos"] != after["pos"] or int(before["hp"]) > int(after["hp"]) or int(after["received"]) > int(before["received"]) or int(before["block"]) > int(after["block"]) or int(before["stoneskin"]) > int(after["stoneskin"])

# The acting foe's own plan on the board as it stands when it acts (the plan the
# red set draws at rest, here in context): does it cover the hero's tile?
func _plan(state: Dictionary, actor: Array) -> Dictionary:
	if not str(actor[0]).begins_with("enemy_"): return {}
	var index: int = plan_engine._enemy_index_for_id(state, int(actor[1]))
	if index < 0: return {"plan": "missing"}
	var enemy: Dictionary = (state.get("enemies", []) as Array)[index]
	if int(enemy.get("hp", 0)) <= 0: return {"plan": "dead"}
	var hero: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var threat: Dictionary = plan_engine.enemy_threat_tiles(state, index)
	var tiles: Array = threat.get("projected_attack", [])
	var actions: Array = []
	for action: Dictionary in (enemy.get("intent", {}) as Dictionary).get("actions", []): actions.append(str(action.get("type", "")))
	return {"plan": "ok", "visible": plan_engine.is_enemy_visible_to_player(state, enemy), "covers": tiles.has(hero),
		"plan_tiles": tiles.map(func(tile: Vector2i) -> String: return str(tile)), "acts": actions, "intent": str((enemy.get("intent", {}) as Dictionary).get("id", "")), "type": str(enemy.get("type", ""))}
