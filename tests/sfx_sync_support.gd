extends RefCounted

const Omens = preload("res://scripts/omen_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const MapNode = preload("res://scripts/section_map_node.gd")
const ShopFixture = preload("res://tests/suites/scavenger_shop_suite.gd")
const MotionFixture = preload("res://tests/suites/combat_motion_timing_suite.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")

static func run(h: SceneTree) -> void:
	_projectiles(h)
	_state_changes(h)
	_ground(h)
	_movement(h)
	_ui(h)
	_run_contexts(h)
	_ambience(h)
	_branches(h)

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
	h._begin("fatigue")
	var before: Dictionary = h._state()
	var fatigue: Array[Dictionary]
	fatigue.append({"damage": 1, "amount": 1})
	h._invoke("_animate_fatigue_damage", [before, fatigue])
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
		h.walk_actor = key
		var rendered_unit: Dictionary = h.scene.call("_animation_actor_unit", before, key)
		h.walk_goal = h.scene.get("board_view").world_position_for_unit_origin(rendered_unit, path[1])
		h._invoke("_animate_actor_along_path", [before, key, path, {}])
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
		state["seed"] = index
		h.router.begin_enemy_action(state, {"kind": "melee", "damage": 3, "actor_key": "enemy_1"}, {"type": "crawler", "id": 1})
		h.scene.call("_render_board_state", state, {"effect": {"kind": "melee"}, "effect_progress": 0.1})
		h._finish(state)
	h._begin("enemy/eclipse")
	var state: Dictionary = h._state()
	h.router.begin_enemy_action(state, {"kind": "umbra_eclipse"}, {"type": "noctyrax", "id": 9})
	h.scene.call("_render_board_state", state, {"effect": {"kind": "umbra_eclipse"}, "effect_progress": 0.1})
	h._finish(state)
	for loss: bool in [false, true]:
		h._begin("dragon/area/" + str(loss))
		state = h._state()
		var after: Dictionary = state.duplicate(true)
		if loss: after["player"]["hp"] -= 6
		h.router.begin_enemy_action(state, {"kind": "aoe", "element": "fire"}, {"type": "tharokh", "id": 9})
		h.scene.call("_render_board_state", state, {"effect": {"kind": "aoe"}, "effect_progress": 0.1})
		h.clock.step(h)
		h.scene.call("_render_board_state", after, {"effect": {"kind": "aoe"}, "effect_progress": 0.8, "impact_actor_keys": ["player"]})
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
