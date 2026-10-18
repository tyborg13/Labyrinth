extends RefCounted

const Omens = preload("res://scripts/omen_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const MapNode = preload("res://scripts/section_map_node.gd")
const ShopFixture = preload("res://tests/suites/scavenger_shop_suite.gd")
const MotionFixture = preload("res://tests/suites/combat_motion_timing_suite.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const SyncClock = preload("res://tests/sfx_sync_clock.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")

static func run(h: SceneTree) -> void:
	_projectiles(h)
	_state_changes(h)
	_ground(h)
	_movement(h)
	_veil(h)
	_ui(h)
	_run_contexts(h)
	_ambience(h)
	_branches(h)
	_composite_relays(h)

static func _composite_relays(h: SceneTree) -> void:
	for variant: String in ["walk_then_blink", "blink_then_walk", "walk_blink_walk"]:
		MotionFixture._install_fixture(h.scene, false)
		h._begin("movement/" + variant)
		var before: Dictionary = h._state()
		before["enemies"].clear()
		before["relics"] = ["unclouded_sun"]
		var source: Vector2i = Vector2i(2, 4) if variant == "blink_then_walk" else Vector2i(3, 4)
		var destination: Vector2i = Vector2i(6, 4) if variant == "walk_then_blink" else Vector2i(5, 4)
		before["umbra"]["light_sources"] = [{"owner": "player", "pos": source, "radius": 0, "remaining_activations": 2}, {"owner": "player", "pos": destination, "radius": 0, "remaining_activations": 2}]
		var after: Dictionary = before.duplicate(true)
		after["player"]["pos"] = Vector2i(6, 4)
		var action: Dictionary = {"type": "move", "range": 5, "amount": 5}
		var path: Array[Vector2i]
		path.assign(h.scene.get("_combat_engine").path_for_player_action(before, action, Vector2i(6, 4)))
		var segments: Array = h.scene.player_move_segments(before, path, {})
		var kinds: Array[String]
		h.walk_actor = "player"
		var rendered_unit: Dictionary = h.scene.call("_animation_actor_unit", before, "player")
		for segment: Dictionary in segments:
			kinds.append("walk" if segment.has("walk") else "blink")
			for tile: Vector2i in segment.get("walk", []).slice(1):
				h.walk_goals[h.scene.get("board_view").draw_tile_for_unit_origin(rendered_unit, tile)] = h.scene.get("board_view").world_position_for_unit_origin(rendered_unit, tile)
		if "_".join(kinds) != variant.replace("_then_", "_"):
			h.failures.append("Composite relay fixture has the wrong movement segments: " + variant)
		h._invoke("_animate_player_action_step", [before, after, "step", action, Vector2i(6, 4)])
		var blinks: Array = h.events.filter(func(event: Dictionary) -> bool: return event["cue"] == "move.blink" and event["result"] == "played")
		if blinks.size() != 1:
			h.failures.append("Composite relay must play exactly one blink: " + variant)
		# The climax observer finds the first post-rift submission, including
		# the next walk's position override while logical player.pos is stale.
		h._finish(before)

static func _projectiles(h: SceneTree) -> void:
	for weapon: String in ["bow", "crossbow", "spear", ""]:
		h._begin("release/" + weapon)
		var before: Dictionary = h._state()
		h.router.begin_player_action(before, {"type": "ranged"}, weapon)
		var effect: Dictionary = {"kind": "ranged", "from": Vector2i(3, 3), "to": Vector2i(4, 4)}
		var count: int = Fx.animation_frame_count(effect, h.scene.ATTACK_FRAMES, false)
		var seconds: float = Fx.animation_frame_seconds(effect, h.scene.ATTACK_FRAME_SECONDS, false)
		h._invoke("_play_timed_animation_frames", [count, seconds, func(frame_number: int) -> void:
			h.scene.call("_render_board_state", before, {"effect": effect, "effect_progress": float(frame_number) / float(count)})
		])
		h._finish(before)
	for kind: String in ["Bleed", "Fire"]:
		h._begin("status_tick/" + kind)
		var before: Dictionary = h._state()
		var after: Dictionary = before.duplicate(true)
		after["player"]["hp"] -= 2
		h.router.begin_enemy_action(before, {"kind": "status_damage", "label": kind}, {})
		h.scene.call("_render_board_state", after, {"impact_actor_keys": ["player"]})
		h._finish(before)
	h._begin("enemy/claw")
	var before: Dictionary = h._state()
	var after: Dictionary = before.duplicate(true)
	after["player"]["hp"] -= 6
	h.router.begin_enemy_action(before, {"kind": "melee", "damage": 6}, {"type": "crawler"})
	h.scene.call("_render_board_state", before, {"effect": {"kind": "melee"}, "effect_progress": 0.1})
	h.clock.step(h)
	h.scene.call("_render_board_state", after, {"effect": {"kind": "melee"}, "effect_progress": 0.8, "impact_actor_keys": ["player"]})
	h._finish(before)
	h._present_hit("neutral_spell", {"type": "ranged", "damage": 3}, "", 4)
	# Each real enemy action starts behind the existing pacing gate.
	for type: String in ["crawler", "warden", "tharokh"]:
		h._begin("enemy_action/" + type)
		before = h._state()
		before["enemies"][0]["type"] = type
		before["enemies"][0]["intent"] = {"id": "sync_fixture", "actions": []}
		var step: Dictionary = {"kind": "intent", "actor_key": "enemy_1", "actor_name": type, "intent_name": "Fixture"}
		h.scene.get("_combat_pacing").begin_enemies()
		h.scene.get("_intent_callouts").set("_announced", {})
		h._invoke("_animate_enemy_phase_steps", [before, [step]])
		h.scene.get("_combat_pacing").end_scope()
		h._finish(before)

static func _state_changes(h: SceneTree) -> void:
	for kind: String in ["heal", "illusion.spawn", "illusion.break", "crate.hit", "crate.break", "deck", "relic"]:
		h._begin("state/" + kind)
		var before: Dictionary = h._state()
		if kind == "heal": before["player"]["hp"] -= 2
		if kind == "illusion.break": before["illusions"] = [{"id": 99, "hp": 1, "pos": Vector2i(3, 3)}]
		if kind.begins_with("crate."): before["terrain"] = [{"id": 99, "kind": "crate", "hp": 3, "pos": Vector2i(3, 3)}]
		if kind == "relic": before["relics"] = ["iron_lung"]
		var after: Dictionary = before.duplicate(true)
		match kind:
			"heal": after["player"]["hp"] += 2
			"illusion.spawn": after["illusions"] = [{"id": 99, "hp": 1, "pos": Vector2i(3, 3)}]
			"illusion.break": after["illusions"] = []
			"crate.hit": after["terrain"][0]["hp"] = 2
			"crate.break": after["terrain"][0]["hp"] = 0
			"deck":
				after["deck"]["cycles"] = int(before["deck"].get("cycles", 0)) + 1
				after["deck"]["burned"] = ["spark"]
			"relic": after["log"] = [str(Data.relic_def("iron_lung").get("name", "")) + " triggers."]
		h.router.begin_player_action(before, {"type": "fixture"})
		h.scene.call("_render_board_state", after, {})
		h._finish(before)
	for kind: String in ["illuminate", "vision", "truesight", "dispel_umbra"]:
		h._begin("player/" + kind)
		var before: Dictionary = h._state()
		h._invoke("_animate_player_action_step", [before, before, "spark", {"type": kind, "radius": 1, "amount": 1}, Vector2i(3, 3)])
		h._finish(before)
	_fatigue(h)

static func _fatigue(h: SceneTree) -> void:
	# Fatigue requests on every presentation frame; all but the first request
	# hit cooldown. Earlier scenario durations must not choose the baseline's
	# spike phase (pace-01 changed 21 requests to 20 while still playing once).
	# Keep the original baseline case at phase zero and exercise every other
	# spike phase separately, checking actual plays and complete feedback below.
	for phase: int in range(SyncClock.SPIKE_CADENCE_FRAMES if h.frame_profile == "spikes" else 1):
		h._begin("fatigue" if phase == 0 else "fatigue/spike_phase_%d" % phase)
		if h.frame_profile == "spikes": h.clock.frame_index = phase
		_fatigue_case(h)

static func _fatigue_case(h: SceneTree) -> void:
	var before: Dictionary = h._state()
	var fatigue: Array[Dictionary]
	fatigue.append({"damage": 1, "amount": 1})
	var texts: Array = h.scene.call("_fatigue_floating_texts_for_events", before, fatigue)
	var authored_ms: float = FloatingText.total_duration(texts) * 1000.0 / h.combat_scale
	h._invoke("_animate_fatigue_damage", [before, fatigue])
	var requests: Array = h.events.filter(func(event: Dictionary) -> bool: return event["cue"] == "fatigue")
	var plays: int = requests.filter(func(event: Dictionary) -> bool: return event["result"] == "played").size()
	if plays != 1: h.failures.append("Every fatigue presentation must play its cue once: " + h.scenario)
	var frames: Array = h.clock.frames.filter(func(frame: Dictionary) -> bool: return frame["shown"].has("impact_actor_keys"))
	var observed_ms: float = float(frames.back()["time_ms"]) - float(frames[0]["time_ms"]) if not frames.is_empty() else 0.0
	if observed_ms < authored_ms: h.failures.append("Fatigue capture must cover its full authored feedback: " + h.scenario)
	print("SFX SYNC FATIGUE: %s / %sx / %s: %d requests, %d plays, %.3f/%.3f ms feedback" % [h.frame_profile, h.combat_scale, h.scenario, requests.size(), plays, observed_ms, authored_ms])
	h._finish(before)

static func _ground(h: SceneTree) -> void:
	for surface: String in ["fire", "ice", "electrified", "rubble"]:
		h._begin("surface/" + surface)
		var before: Dictionary = h._state()
		var after: Dictionary = before.duplicate(true)
		var ground: Array = [{"kind": "surface_created", "surface": surface, "tile": Vector2i(3, 3)}]
		h.router.begin_player_action(before, {"type": "surface"})
		h.scene.call("_play_outcome_sounds", ground)
		h.scene.call("_render_board_state", after, {"surface_feedback_events": ground})
		h._finish(before)
	h._begin("trap")
	var before: Dictionary = h._state()
	var traps: Array[Dictionary]
	traps.append({"element": "fire", "tile": Vector2i(3, 3), "pos": Vector2i(3, 3)})
	h.router.begin_player_action(before, {"type": "move"})
	h._invoke("_animate_player_ground_result", [before, before, traps, {}])
	h._finish(before)

static func _ui(h: SceneTree) -> void:
	h.scene.set("_animation_lock", false)
	h.scene.call("_reset_card_resolution")
	h._begin("input/illegal_target_selected")
	h.scene.call("_on_card_pressed", 2)
	h.scene.call("_on_board_tile_clicked", Vector2i(-1, -1))
	h._finish(h._state())
	h.scene.call("_reset_card_resolution")
	h._begin("input/card_hover")
	h._invoke("_on_card_hover_started", [0])
	h._finish(h._state())
	h._begin("input/card_select")
	h._invoke("_on_card_pressed", [0])
	h._finish(h._state())
	h.scene.call("_reset_card_resolution")
	h._begin("input/card_drag")
	h._invoke("_on_card_drag_started", [0, Vector2(500, 900)])
	h._finish(h._state())
	h.scene.call("_cancel_drag_play")
	h.scene.call("_reset_card_resolution")
	var state: Dictionary = h._state()
	state["card_plays_remaining"] = 0
	state["card_plays"] = 0
	h.scene.set("_combat_state", state)
	for method: String in ["_on_card_pressed", "_on_card_drag_started"]:
		h._begin("input/invalid/" + method)
		h._invoke(method, [999])
		h._finish(state)
	MotionFixture._install_fixture(h.scene, false)
	h._begin("input/illegal_target")
	h.scene.call("_on_card_pressed", 1)
	h.scene.call("_on_board_tile_clicked", Vector2i(-1, -1))
	h._finish(h._state())
	h.scene.call("_reset_card_resolution")
	h._begin("input/map_hover")
	var node := MapNode.new()
	node.actionable = true
	h.scene.add_child(node)
	h.router.bind_map_hover(node)
	h.clock.mark("map_hover_input", [{"source": "res://scripts/section_map_node.gd", "function": "_ready", "line": 29}])
	node.mouse_entered.emit()
	h._finish(h._state())
	node.free()
	h._begin("input/defiance")
	state = h._state()
	state["defiance_event_revision"] = int(state.get("defiance_event_revision", 0)) + 1
	h.scene.set("_combat_state", state)
	h._invoke("_refresh_relic_bar", [])
	h._finish(state)

static func _movement(h: SceneTree) -> void:
	for type: String in ["player", "crawler", "warden", "tharokh"]:
		h._begin("walk/" + type)
		var before: Dictionary = h._state()
		var key: String = "player" if type == "player" else "enemy_1"
		var unit: Dictionary = before["player"] if type == "player" else before["enemies"][0]
		unit["type"] = type
		var path: Array[Vector2i]
		path.assign([unit["pos"], unit["pos"] + Vector2i(0, 1)])
		if type == "tharokh": path.append(unit["pos"] + Vector2i(1, 1))
		h.walk_actor = key
		var rendered_unit: Dictionary = h.scene.call("_animation_actor_unit", before, key)
		h.walk_goal = h.scene.get("board_view").world_position_for_unit_origin(rendered_unit, path[1])
		for destination: Vector2i in path.slice(1):
			h.walk_goals[h.scene.get("board_view").draw_tile_for_unit_origin(rendered_unit, destination)] = h.scene.get("board_view").world_position_for_unit_origin(rendered_unit, destination)
		h._invoke("_animate_actor_along_path", [before, key, path, {}])
		if type == "tharokh" and h.events.filter(func(e: Dictionary) -> bool: return e["cue"] == "dragon.wings").size() != path.size() - 1:
			h.failures.append("Dragon must request wings on each movement segment")
		h._finish(before)
	for kind: String in ["item", "equipment"]:
		h._begin("pickup/" + kind)
		var before: Dictionary = h._state()
		before["loot"] = [{"id": "fixture", "kind": kind, "card_id": "crimson_draught", "equipment_id": "ward_kite", "claimed": false, "pos": Vector2i(3, 3)}]
		var after: Dictionary = before.duplicate(true)
		after["loot"][0]["claimed"] = true
		h._invoke("_animate_board_pickup_acquisitions", [before, after])
		h._finish(before)
	h._begin("player/push")
	var before: Dictionary = h._state()
	var after: Dictionary = before.duplicate(true)
	after["enemies"][0]["pos"] += Vector2i(0, 1)
	h._invoke("_animate_player_action_step", [before, after, "spark", {"type": "push", "range": 5, "amount": 1}, before["enemies"][0]["pos"]])
	h._finish(before)

static func _run_contexts(h: SceneTree) -> void:
	var engine := Run.new()
	var run_state: Dictionary = engine.create_new_run(410, Store.default_data())
	for id: String in Data.omens():
		var kind: String = str(Data.omen_def(id).get("kind", ""))
		if kind not in ["blessing", "bane"]: continue
		h._begin("context/omen/" + kind)
		h.router.run_context(run_state)
		run_state = Omens.add(run_state, id)
		h.scene.set("_run_state", run_state)
		h._invoke("_update_ambient_sfx_for_context", ["room"])
		h._finish(h._state())

		if kind == "bane": break
	h._begin("input/event_choose")
	h._invoke("_on_section_map_event", ["embers"])
	h._finish(h._state())
	var fixture: Dictionary = ShopFixture._scavenger_fixture(engine)
	var shop: Dictionary = fixture["state"]
	shop["current_room"] = fixture["coord"]
	shop["mode"] = "room"
	shop = engine.set_held_embers(shop, 1000)
	shop["equipment_inventory"] = ["ward_kite"]
	h.scene.set("_run_state", shop)
	var offers: Array = engine.merchant_offer_ids(shop, Run.MERCHANT_SCAVENGER)
	h._begin("input/shop_buy")
	h._invoke("_on_merchant_buy_pressed", [Run.MERCHANT_SCAVENGER, str(offers[0])])
	h._finish(h._state())
	h._begin("input/shop_sell")
	h._invoke("_on_merchant_sell_pressed", [Run.MERCHANT_SCAVENGER, "ward_kite"])
	h._finish(h._state())
	run_state = engine.create_new_run(410, Store.default_data())
	run_state["mode"] = "room"
	h.scene.set("_run_state", run_state)
	h.scene.set("_animation_lock", false)
	var moves: Array = engine.available_moves(run_state)
	if not moves.is_empty():
		h._begin("input/map_select")
		h._invoke("_on_map_view_room_selected", [moves[0]])
		h._finish(h._state())

static func _ambience(h: SceneTree) -> void:
	# The production context hook chooses section variants; the shared hall bed
	# is exercised here and inherited beds separately through the real router.
	for biome: String in ["stone", "tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"]:
		h._begin("context/" + biome)
		var state: Dictionary = h.scene.get("_run_state").duplicate(true)
		state["section_map_version"] = 1
		state["map_sections"] = [{"boss_id": biome}]
		state["rooms"] = {"0,0": {"section_index": 0}}
		state["current_room"] = Vector2i.ZERO
		h.scene.set("_run_state", state)
		h.scene.set("_active_ambient_sfx_id", "")
		h.bank.stop_loop(true)
		h._invoke("_update_ambient_sfx_for_context", ["room"])
		h._finish(h._state())

static func _branches(h: SceneTree) -> void:
	MotionFixture._install_fixture(h.scene, false)
	for index: int in range(12):
		h._begin("enemy/vocal/%d" % index)
		var state: Dictionary = h._state()
		# Choose an eligible input seed for this probabilistic branch. Preserve
		# the production RNG and 30% rule; prior fixture action counts vary with
		# combat speed and must not make a registered cue disappear from proof.
		var seed_probe := RandomNumberGenerator.new()
		var fixture_seed: int = index
		while true:
			seed_probe.seed = fixture_seed + int(h.router.get("_action_serial")) + 1 + "enemy_1".hash()
			if seed_probe.randf() < h.router.BEAST_VOCAL_CHANCE: break
			fixture_seed += 1
		state["seed"] = fixture_seed
		h.router.begin_enemy_action(state, {"kind": "melee", "damage": 3, "actor_key": "enemy_1"}, {"type": "crawler", "id": 1})
		h.scene.call("_render_board_state", state, {"effect": {"kind": "melee"}, "effect_progress": 0.1})
		h._finish(state)
	h._begin("enemy/eclipse")
	var state: Dictionary = h._state()
	var eclipse: Dictionary = {"kind": "umbra_eclipse", "enemy_type": "noctyrax"}
	h.router.begin_enemy_action(state, eclipse, {"type": "noctyrax", "id": 9})
	h._invoke("_play_timed_animation_frames", [66, 1.0 / 60.0, func(frame: int) -> void:
		h.scene.call("_render_board_state", state, {"effect": eclipse, "effect_progress": float(frame) / 66.0})
	])
	h._finish(state)
	for loss: bool in [false, true]:
		h._begin("dragon/area/" + str(loss))
		state = h._state()
		var after: Dictionary = state.duplicate(true)
		if loss: after["player"]["hp"] -= 6
		state["enemies"][0]["type"] = "tharokh"
		state["enemies"][0]["intent"] = {"id": "sync_fixture", "actions": []}
		var step: Dictionary = {"kind": "aoe", "actor_key": "enemy_1", "actor_name": "Tharokh", "action_type": "terrain_burst", "element": "earth", "from": state["enemies"][0]["pos"], "to": state["player"]["pos"], "tiles": [state["player"]["pos"]], "hp_loss": 6 if loss else 0}
		var original: Dictionary = state.duplicate(true)
		h._invoke("_animate_enemy_phase_steps", [state, [step]])
		h._finish(original)
	h._begin("dragon/breath")
	state = h._state()
	state["enemies"][0]["type"] = "tharokh"
	state["enemies"][0]["intent"] = {"id": "sync_fixture", "actions": []}
	var breath: Dictionary = {"kind": "aoe", "action_type": "ranged", "intent_id": "bedrock_breath", "actor_key": "enemy_1", "actor_name": "Tharokh", "element": "earth", "from": state["enemies"][0]["pos"], "to": state["player"]["pos"], "tiles": [state["player"]["pos"]]}
	var before_breath: Dictionary = state.duplicate(true)
	h._invoke("_animate_enemy_phase_steps", [state, [breath]])
	h._finish(before_breath)
	for geometry: String in ["meteor", "utility"]:
		h._begin("dragon/" + geometry)
		state = h._state()
		h.router.set("_dragons", {})
		state["enemies"][0]["type"] = "zekarion" if geometry == "meteor" else "vaeloryx"
		state["enemies"][0]["intent"] = {"id": "sync_fixture", "actions": []}
		var step: Dictionary = {"kind": "lightning_strikes" if geometry == "meteor" else "block", "actor_key": "enemy_1", "actor_name": "Dragon", "element": "lightning", "from": state["enemies"][0]["pos"], "to": state["player"]["pos"], "tiles": [state["player"]["pos"]], "amount": 3}
		var original: Dictionary = state.duplicate(true)
		h._invoke("_animate_enemy_phase_steps", [state, [step]])
		if h.events.filter(func(e: Dictionary) -> bool: return e["cue"] == "dragon.roar" and e["result"] == "played").size() != 1:
			h.failures.append("First-action " + geometry + " must present one roar")
		h._finish(original)
	for missing: String in ["hidden", "special", "enemy_type"]:
		h._begin("dragon/fallback/" + missing)
		state = h._state()
		h.router.set("_dragons", {})
		var step: Dictionary = {"kind": "aoe", "enemy_type": "tharokh", "action_type": "terrain_burst", "actor_key": "enemy_1"}
		if missing == "hidden": step["hidden_by_umbra"] = true
		elif missing == "special": step["en05_after"] = {}
		else: step.erase("enemy_type")
		h.router.begin_enemy_action(state, step, {"type": "tharokh", "id": 1})
		h.scene.call("_render_board_state", state, {})
		if h.events.filter(func(e: Dictionary) -> bool: return e["cue"] == "dragon.roar" and e["result"] == "played").size() != 1:
			h.failures.append("First-action fallback must roar immediately: " + missing)
		h._finish(state)
	h._begin("trap/hero_hurt")
	state = h._state()
	var after: Dictionary = state.duplicate(true)
	after["player"]["hp"] -= 6
	h.router.begin_player_action(state, {"type": "move"})
	h.router.trap([{"element": "fire"}])
	h.scene.call("_render_board_state", after, {"trap_effects": [{"element": "fire"}], "impact_actor_keys": ["player"]})
	h._finish(state)
	h._begin("deck/consume")
	state = h._state()
	after = state.duplicate(true)
	after["deck"]["cycles"] += 1
	after["deck"]["burned"] = ["spark"]
	h.router.baseline(state)
	h.scene.call("_consume_pending_card_draw_sfx", after)
	h.scene.call("_render_board_state", after, {})
	h._finish(state)
	h._begin("enemy/push")
	state = h._state()
	state["enemies"][0]["intent"] = {"id": "sync_fixture", "actions": []}
	var step: Dictionary = {"kind": "push", "actor_key": "enemy_1", "from": Vector2i(5, 4), "to": Vector2i(2, 4), "damage": 0, "amount": 1}
	h._invoke("_animate_enemy_phase_steps", [state, [step]])
	h._finish(state)

static func _veil(h: SceneTree) -> void:
	for label: String in ["Fade", "Ambush"]:
		h._begin("enemy/veil/" + label)
		var state: Dictionary = h._state()
		state["enemies"][0]["type"] = "veilbound_acolyte"
		state["enemies"][0]["intent"] = {"id": "sync_fixture", "actions": []}
		var after: Dictionary = state.duplicate(true)
		after["enemies"][0]["pos"] += Vector2i(0, 1)
		var step: Dictionary = {"kind": "melee" if label == "Ambush" else "move", "action_type": "melee" if label == "Ambush" else "veil_blink", "en03_veil": true, "actor_key": "enemy_1", "from": state["enemies"][0]["pos"], "to": after["enemies"][0]["pos"], "label": label, "blink_after": after, "en03_after": after}
		h._invoke("_animate_enemy_phase_steps", [state, [step]])
		var blink_frames: int = h.clock.frames.filter(func(f: Dictionary) -> bool: return f["shown"].get("effect", {}).get("kind", "") == "blink").size()
		var blink_requests: int = h.events.filter(func(e: Dictionary) -> bool: return e["cue"] == "move.blink").size()
		h.silence_rows.append({"scenario": h.scenario, "visual": "enemy Veil blink", "frames": blink_frames, "requests": blink_requests, "other_cues": h.events.map(func(e: Dictionary) -> String: return e["cue"])})
		if blink_frames == 0 or blink_requests != 0: h.failures.append("Veil %s must render its blink without a blink cue" % label)
		h._finish(state)
