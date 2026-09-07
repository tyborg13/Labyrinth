extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Floor = preload("res://scripts/board_surface_presentation.gd")
const ChainFeedback = preload("res://scripts/chain_attack_feedback.gd")
const Aim = preload("res://scripts/surface_aim_flow.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var text: String = Icons.plain_text_for_tokens(Icons.tokens_for_action({"type": "surface", "surface": "ice", "range": 4}))
	assert("Ice" in text)
	assert("Fire" in Floor.tooltip({"surfaces": {"1,1": {"elemental": "fire", "rubble": true}}}, Vector2i.ONE))
	assert("Rubble" in Floor.tooltip({"surfaces": {"1,1": {"elemental": "fire", "rubble": true}}}, Vector2i.ONE))
	var native_hits: Array = [
		{"kind": "actor", "from": Vector2i(2, 2), "to": Vector2i(2, 2), "state": {"revision": 1}},
		{"kind": "actor", "from": Vector2i(3, 2), "to": Vector2i(3, 2), "state": {"revision": 2}},
		{"kind": "relay", "from": Vector2i(3, 2), "to": Vector2i(4, 2), "state": {"revision": 3}},
		{"kind": "conduction", "from": Vector2i(4, 2), "to": Vector2i(5, 2), "state": {"revision": 4}},
		{"kind": "conduction", "from": Vector2i(4, 2), "to": Vector2i(5, 3), "state": {"revision": 5}},
	]
	var beats: Array = ChainFeedback._presentation_beats(native_hits)
	assert(beats.size() == 3, "Native AoE and one component each share one beat, with one intervening relay")
	assert(int(beats[0]["state"]["revision"]) == 2 and int(beats[2]["state"]["revision"]) == 5)
	var scene := Scene.new()
	assert(not scene.call("_has_electrical_trace", native_hits.slice(0, 2)), "Native AoE never invents Chain lightning")
	assert(scene.call("_has_electrical_trace", native_hits))
	var leaving_ice: Array[Vector2i]
	leaving_ice.assign([Vector2i.ONE, Vector2i(2, 1)])
	assert(scene.call("_preview_path_hits_lookup", leaving_ice, {Vector2i.ONE: true}), "Leaving Ice must resolve Chill departure in previews")
	var analytics = preload("res://scripts/analytics_store.gd")
	var combat := preload("res://scripts/combat_engine.gd").new()
	await _test_board_surface_cancel(combat)
	_test_detonate_card_damage(scene, combat)
	_test_action_step_damage(scene, combat)
	analytics.set_storage_dir("user://surface_presentation_analytics")
	analytics.clear_storage()
	_test_rubble_stop_presentation(scene, combat)
	_test_shared_damage_preview(scene, combat)
	_test_hidden_movement_preview(scene, combat)
	_test_hidden_attack_preview(scene, combat)
	_test_opaque_preview_outcomes(combat)
	var state: Dictionary = preload("res://tests/suites/chain_attack_suite.gd").fixture(combat)
	state["analytics"] = {"combat_id": "surface_dedupe_proof"}
	var ground = preload("res://scripts/board_surface_rules.gd")
	ground.place(state, Vector2i(3, 4), "fire", {"card_id": "proof_card", "player_card": true})
	scene.call("_analytics_flush_surface_events", state)
	scene.call("_analytics_flush_surface_events", state)
	var events: Array = analytics.load_all_events()
	assert(events.size() == 1, "Repeated committed snapshots emit each ground event once")
	assert(int(events[0]["rules_version"]) == 5)
	assert(str(events[0]["payload"]["source"]["card_id"]) == "proof_card")
	ground.remove(state, Vector2i(3, 4), "fire", "detonate")
	scene.call("_analytics_flush_surface_events", state)
	assert(analytics.load_all_events().size() == 2, "Later events append without replaying the prior action")
	scene.free()
	var resumed := Scene.new()
	resumed.call("_analytics_flush_surface_events", state)
	assert(analytics.load_all_events().size() == 2, "Reopening the same combat retains durable deduplication")
	resumed.free()
	_test_legacy_surface_event_versions(combat)
	print("TEST RESULT: PASS board surface presentation")
	quit()

func _test_legacy_surface_event_versions(combat: RefCounted) -> void:
	var analytics = preload("res://scripts/analytics_store.gd")
	analytics.set_storage_dir("user://surface_presentation_legacy_analytics")
	analytics.clear_storage()
	var state: Dictionary = preload("res://tests/suites/chain_attack_suite.gd").fixture(combat)
	state["analytics"] = {"combat_id": "legacy_surface_tail_proof"}
	state["surface_event_legacy_rules_version"] = 4
	state["surface_events"] = [
		{"sequence": 1, "kind": "create", "surface": "fire"},
		{"sequence": 2, "kind": "remove", "surface": "electrified", "rules_version": 4}
	]
	state["surface_event_sequence"] = 2
	preload("res://scripts/board_surface_rules.gd").place(state, Vector2i(3, 4), "fire")
	var scene := Scene.new()
	scene.call("_analytics_flush_surface_events", state)
	scene.call("_analytics_flush_surface_events", state)
	var events: Array = analytics.load_all_events()
	assert(events.size() == 3, "Legacy tail and new event each flush once")
	for index: int in range(events.size()):
		var expected: int = 4 if index < 2 else 5
		assert(int(events[index].get("rules_version", 0)) == expected, "Surface event context retains the producer's rules version")
		assert(int(events[index]["payload"].get("rules_version", 0)) == expected, "Surface event payload retains the producer's rules version")
	scene.free()

func _test_board_surface_cancel(combat: RefCounted) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	root.add_child(view)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(scene)
	await create_timer(0.2).timeout
	var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = state
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_refresh_ui")
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var aim: RefCounted = scene.get("_surface_aim")
	aim.call("begin", "prismatic_instinct", false)
	await scene.call("_on_board_cancel_requested")
	assert(not aim.call("active"), "Board right-click/B must cancel Prismatic targeting")
	aim.call("begin", "confluence", true)
	aim.set("origin", Vector2i(3, 4))
	await scene.call("_on_board_cancel_requested")
	assert(not aim.call("active") and aim.get("origin") == Vector2i(-1, -1), "Board right-click/B must discard Confluence's selected source")
	assert(scene.get("_combat_state") == before, "Cancelling ground selection must not spend the ability or change the board")
	state["player"]["pos"] = Vector2i(3, 3)
	state["player"]["hp"] = 30
	state["player"]["max_hp"] = 100
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	state["relics"] = ["bloodglass_knife"]
	state["deck"]["hand"] = ["rekindle_edge"]
	preload("res://scripts/board_surface_rules.gd").place(state, Vector2i(4, 3), "fire")
	run["combat_state"] = state
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await scene.call("_on_card_pressed", 0)
	var strip: Node = scene.get("_action_step_tracker_steps")
	assert(strip.get_node("ActionStepChip1").get_meta("action_value_text") == "15", "Actual active strip uses modified melee damage")
	assert(strip.get_node("ActionStepChip2").get_meta("action_value_text") == "15", "Actual active strip uses modified Detonate damage")
	scene.call("_reset_card_resolution")
	state = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	run["combat_state"] = state
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	var replay_actions: Array = [
		{"type": "ranged", "range": 6, "damage": 99, "requires_surface": {"subject": "player", "surface": "fire"}},
		{"type": "ranged", "range": 6, "damage": 8},
		{"type": "ranged", "range": 6, "damage": 4}
	]
	var replay_targets: Array[Vector2i]
	replay_targets.assign([Vector2i(-1, -1), Vector2i(4, 3), Vector2i(4, 3)])
	await scene.call("_animate_player_card_resolution", state, "pale_spark", replay_actions, replay_targets)
	var rendered: Dictionary = (scene.get("board_view") as Node).get("combat_state")
	assert(int(rendered["enemies"][0]["hp"]) == 988, "An unavailable target slot cannot shift or omit the following attacks in actual animation replay")
	view.queue_free()
	await process_frame

func _test_detonate_card_damage(scene: Node, combat: RefCounted) -> void:
	var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	state["relics"] = ["bloodglass_knife"]
	state["player"]["max_hp"] = 100
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	var action: Dictionary = preload("res://scripts/game_data.gd").card_def("rekindle_edge")["actions"][1]
	for health: int in [30, 100]:
		state["player"]["hp"] = health
		var display: Dictionary = scene.call("_card_widget_display", "rekindle_edge", state)
		var expected: int = combat.final_damage_for_player_action(state, action)
		assert((str(display["summary_bbcode"])).contains("Detonate %d" % expected), "Detonate card values must reflect active and inactive conditional damage bonuses")
		var values: Array = scene.call("_action_step_damage_options", state, preload("res://scripts/game_data.gd").card_def("rekindle_edge")["actions"], [])
		assert(int(values[1]["final_damage"]) == expected, "Action strip and card agree for active and inactive conditional bonuses")

func _test_action_step_damage(scene: Node, combat: RefCounted) -> void:
	var actions: Array = [{"type": "move", "range": 2}, {"type": "ranged", "range": 6, "damage": 10}]
	for stage: String in ["eclipse", "clear"]:
		var damage_values: Array = []
		for dangerous: bool in [false, true]:
			var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
			state["umbra"]["stage"] = stage
			state["relics"] = ["bloodglass_knife"]
			state["enemies"][0]["pos"] = Vector2i(8, 6)
			state["player"]["hp"] = 55
			state["player"]["max_hp"] = 100
			state["player"]["block"] = 0
			state["player"]["stoneskin"] = 0
			state["traps"] = [{"pos": Vector2i(4, 3), "element": "earth", "damage": 10}] if dangerous else []
			scene.set("_combat_state", state)
			var actual_prefix: Dictionary = combat.apply_player_action(state, actions[0], Vector2i(4, 3))
			scene.set("_preview_combat_state", actual_prefix)
			var before: Dictionary = state.duplicate(true)
			var original_actions: Array = actions.duplicate(true)
			var values: Array = scene.call("_action_step_tracker_damage_options", {"mode": "selection", "actions": actions, "action_index": 1, "selected_targets": [Vector2i(4, 3)]})
			damage_values.append(values[1]["final_damage"])
			assert(state == before and actions == original_actions, "Step display cannot mutate combat or shared action definitions")
		assert(damage_values == ([10, 10] if stage == "eclipse" else [10, 17]), "Only a known trap may change a future Bloodglass damage value")
	# Legacy/synthetic first-attack effects use the engine's real consumption rule.
	var engine: RefCounted = scene.get("_combat_engine")
	var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	state["relics"] = ["tracker_first_attack_fixture"]
	var effects: Array[Dictionary]
	effects.append({"type": "first_attack_bonus", "value": 4})
	engine.set("_relic_effect_cache_key", "tracker_first_attack_fixture")
	engine.set("_relic_effect_cache", effects)
	scene.set("_combat_state", state)
	var strikes: Array = [{"type": "ranged", "range": 6, "damage": 10}, {"type": "ranged", "range": 6, "damage": 8}]
	var unresolved: Array = scene.call("_action_step_damage_options", state, strikes, [])
	assert(unresolved[0]["final_damage"] == 14 and unresolved[1]["final_damage"] == 8, "Unresolved sequence spends a one-shot attack bonus once")
	var skipped: Array = scene.call("_action_step_damage_options", state, strikes, [Vector2i(-1, -1)])
	assert(skipped[1]["final_damage"] == 12, "Skipping the first attack preserves its bonus for the next attack")
	var unavailable: Array = strikes.duplicate(true)
	unavailable[0]["requires_surface"] = {"subject": "player", "surface": "fire"}
	var unavailable_values: Array = scene.call("_action_step_damage_options", state, unavailable, [])
	assert(unavailable_values[1]["final_damage"] == 12, "An attack whose ground requirement fails cannot consume the forecast bonus")
	unavailable.append(strikes[0].duplicate(true))
	var placeholder_values: Array = scene.call("_action_step_damage_options", state, unavailable, [Vector2i(-1, -1), Vector2i(4, 3)])
	assert(placeholder_values[1]["final_damage"] == 12 and placeholder_values[2]["final_damage"] == 10, "An unavailable target placeholder cannot skip the next selected attack or duplicate its bonus")
	var selected: Array = scene.call("_action_step_damage_options", state, strikes, [Vector2i(4, 3)])
	var after: Dictionary = engine.call("apply_player_action", state, strikes[0], Vector2i(4, 3))
	assert(selected[1]["final_damage"] == engine.call("final_damage_for_player_action", after, strikes[1]), "Selected prefix does not consume completed modifiers twice")
	# A committed step may confirm a previously hidden HP change. Update only the
	# current and future values; completed values stay attached to their pre-state.
	state["relics"] = ["bloodglass_knife"]
	state["player"]["hp"] = 55
	state["player"]["max_hp"] = 100
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	scene.set("_combat_state", state)
	scene.call("_begin_action_step_resolution_tracker", "fixture", strikes, [])
	var confirmed: Dictionary = state.duplicate(true)
	confirmed["player"]["hp"] = 45
	scene.call("_set_action_step_resolution_index", 1, confirmed, [])
	var resolved_values: Array = scene.get("_action_step_resolution_damage_options")
	assert(resolved_values[0]["final_damage"] == 10 and resolved_values[1]["final_damage"] == 15, "Resolution preserves completed damage and updates the next step from its actual pre-state")
	scene.call("_clear_action_step_resolution_tracker")
	assert((scene.get("_action_step_resolution_damage_options") as Array).is_empty(), "Resolution display cache clears with its tracker")

func _test_rubble_stop_presentation(scene: Node, combat: RefCounted) -> void:
	var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	state["enemies"][0]["pos"] = Vector2i(7, 3)
	state["traps"] = [{"id": "presentation_earth", "pos": Vector2i(3, 3), "element": "earth", "damage": 0}]
	state["relics"] = ["pilgrim_boots"]
	state["player_movement_capacity"] = 3
	state["player_movement_remaining"] = 3
	var requested := Vector2i(5, 3)
	var action: Dictionary = combat.player_movement_action(state)
	var planned: Array = combat.path_for_player_action(state, action, requested)
	var grouped: Dictionary = combat.apply_player_movement(state, requested)
	var endpoint: Vector2i = grouped["player"]["pos"]
	assert(endpoint == Vector2i(4, 3) and int(grouped["player_movement_remaining"]) == 1)
	var shown: Array = scene.call("_resolved_movement_animation_path", state["player"]["pos"], endpoint, planned)
	assert(shown == [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)], "Grouped walk presentation stops on newly created Rubble before an unaffordable departure")
	var bent: Array = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)]
	assert(scene.call("_resolved_movement_animation_path", Vector2i(2, 2), Vector2i(3, 3), bent) == bent.slice(0, 3), "Early-stop trimming must preserve intermediate corners for player and enemy paths")
	assert(scene.call("_resolved_movement_animation_path", Vector2i(2, 2), Vector2i(2, 2), bent) == [Vector2i(2, 2)], "A stopped actor must not animate a zero-distance segment")
	var returning: Array = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 2)]
	assert(scene.call("_resolved_movement_animation_path", Vector2i(2, 2), Vector2i(2, 2), returning) == returning, "A resolved enemy route through a lit pocket must retain its outward and returning segments")

func _test_shared_damage_preview(scene: Node, combat: RefCounted) -> void:
	var ground = preload("res://scripts/board_surface_rules.gd")
	var target := Vector2i(3, 3)
	var action: Dictionary = {"type": "detonate", "damage": 6, "range": 4, "pattern": [[0, 0]], "element": "fire"}
	var analytics = preload("res://scripts/analytics_store.gd")
	var events_before: Array = analytics.load_all_events()
	for mode: String in ["exposed", "defended", "lethal", "safe", "paint"]:
		var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
		state["player"]["hp"] = 10
		state["player"]["max_hp"] = 10
		state["player"]["block"] = 0
		state["player"]["stoneskin"] = 0
		state["illusions"] = [{"id": 1, "pos": Vector2i(3, 2), "hp": 10, "max_hp": 10}]
		ground.place(state, target, "fire")
		if mode == "defended":
			state["player"]["block"] = 4
			state["player"]["stoneskin"] = 4
			state["illusions"][0]["block"] = 4
			state["illusions"][0]["stoneskin"] = 4
		elif mode == "lethal":
			state["player"]["hp"] = 2
			state["illusions"][0]["hp"] = 2
		elif mode == "safe":
			state["player"]["pos"] = Vector2i(1, 3)
			state["illusions"][0]["pos"] = Vector2i(1, 2)
		var tested_action: Dictionary = action if mode != "paint" else {"type": "surface", "surface": "fire", "range": 4, "pattern": [[0, 0]]}
		var tested_target: Vector2i = target if mode != "paint" else state["player"]["pos"]
		var before: Dictionary = state.duplicate(true)
		var actual: Dictionary = combat.apply_player_action(state, tested_action, tested_target)
		scene.set("_combat_state", state)
		scene.set("_hovered_board_tile", tested_target)
		scene.call("_mark_combat_preview_state_changed")
		var shown: Dictionary = {"effect": {}}
		scene.call("_append_surface_action_preview", shown, {"state": state, "action": tested_action, "target_tiles": [tested_target]})
		var losses: Dictionary = shown.get("damage_preview", {})
		var chips: Array = shown.get("friendly_damage_chips", [])
		if mode in ["safe", "paint"]:
			assert(not losses.has("player") and not losses.has("illusion_1") and chips.is_empty(), "Distant blasts and fresh placement must not invent friendly exposure")
		else:
			var after_units: Dictionary = scene.call("_surface_preview_units_by_key", actual)
			for key: String in ["player", "illusion_1"]:
				assert(losses.has(key), "Shared blasts must preview each friendly actor")
				for field: String in ["hp", "block", "stoneskin"]:
					assert(int(losses[key][field]) == maxi(0, int((after_units.get(key, {}) as Dictionary).get(field, 0))), "Friendly projected HP and defenses must match resolution")
				assert(bool(losses[key]["lethal"]) == (mode == "lethal"))
			assert(not chips.is_empty(), "Friendly exposure needs explicit danger chips, even when fully absorbed")
			assert(shown["effect"]["damage_preview"] == losses, "Effects must use the same cumulative damage preview")
			if mode == "defended":
				assert(int(losses["player"]["hp_loss"]) == 0 and chips.any(func(chip: Dictionary) -> bool: return "Block" in str(chip["label"]) or "Guard" in str(chip["label"])))
			if mode == "exposed":
				assert(int(losses["player"]["hp_loss"]) == 6 and int(losses["illusion_1"]["hp_loss"]) == 6 and int(losses["enemy_1"]["hp_loss"]) == 6)
		assert(state == before, "Aiming cannot mutate combat state")
	assert(analytics.load_all_events() == events_before, "Aiming cannot append analytics")

func _test_hidden_movement_preview(scene: Node, combat: RefCounted) -> void:
	for action_type: String in ["move", "blink"]:
		for stage: String in ["eclipse", "clear"]:
			var boards: Array[Dictionary]
			for dangerous: bool in [false, true]:
				var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
				state["enemies"][0]["pos"] = Vector2i(8, 6)
				state["umbra"]["stage"] = stage
				state["traps"] = [{"pos": Vector2i(4, 3), "element": "earth", "damage": 10}] if dangerous else []
				var target := Vector2i(4, 3)
				var action: Dictionary = {"type": action_type, "range": 2}
				assert(combat.valid_targets_for_player_action(state, action).has(target) == (action_type == "move" or stage == "clear"), "Blink requires a visible landing; walking may enter the unknown")
				assert(combat.is_tile_visible_to_player(state, target) == (stage == "clear"))
				assert(combat.is_tile_visible_to_player(state, Vector2i(3, 3)), "Hidden trap wake reaches visible ground in this fixture")
				scene.set("_combat_state", state)
				scene.set("_hovered_board_tile", target)
				scene.call("_mark_combat_preview_state_changed")
				var shown: Dictionary = {}
				scene.call("_append_surface_action_preview", shown, {"state": state, "action": action, "target_tiles": [target]})
				boards.append(shown)
			if stage == "eclipse":
				assert(boards[0] == boards[1] and boards[1].is_empty(), "Unknown traps must not leak damage, statuses, arcs, or even wake painted onto visible floor")
			else:
				assert(not (boards[1].get("damage_preview", {}) as Dictionary).get("player", {}).is_empty(), "Visible movement hazards still project their actual damage")

func _test_hidden_attack_preview(scene: Node, combat: RefCounted) -> void:
	var ground = preload("res://scripts/board_surface_rules.gd")
	for stage: String in ["eclipse", "clear"]:
		var boards: Array[Dictionary]
		for dangerous: bool in [false, true]:
			var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
			state["enemies"][0]["pos"] = Vector2i(8, 6)
			state["umbra"]["stage"] = stage
			state["illusions"] = [{"id": 1, "pos": Vector2i(4, 2), "hp": 10, "max_hp": 10}]
			ground.place(state, Vector2i(4, 1), "fire")
			state["traps"] = [{"pos": Vector2i(4, 3), "element": "air", "damage": 10}] if dangerous else []
			var action: Dictionary = {"type": "aoe", "damage": 3, "range": 3, "pattern": [[0, 0], [1, 0]], "rotate": false}
			var target := Vector2i(3, 3)
			assert(combat.is_tile_visible_to_player(state, target) and combat.valid_targets_for_player_action(state, action).has(target))
			scene.set("_combat_state", state)
			scene.set("_hovered_board_tile", target)
			scene.call("_mark_combat_preview_state_changed")
			var before: Dictionary = state.duplicate(true)
			var shown: Dictionary = {"effect": {"damage_preview": scene.call("_preview_damage_for_action", state, action, target)}}
			scene.call("_append_surface_action_preview", shown, {"state": state, "action": action, "target_tiles": [target]})
			assert(state == before, "Known-information projection cannot change the actual hidden world")
			boards.append(shown)
		if stage == "eclipse":
			assert(boards[0] == boards[1], "A visible AOE center must not disclose a hidden trap through friendly damage or surface feedback")
		else:
			assert(int(boards[1]["damage_preview"]["illusion_1"]["hp_loss"]) == 2, "Revealed trap and Fire must retain the accurate friendly contact forecast")
	# Limited Umbra still previews an entirely known shared blast.
	var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	state["umbra"]["stage"] = "eclipse"
	ground.place(state, Vector2i(3, 3), "fire")
	scene.set("_combat_state", state)
	scene.set("_hovered_board_tile", Vector2i(3, 3))
	scene.call("_mark_combat_preview_state_changed")
	var shown: Dictionary = {}
	scene.call("_append_surface_action_preview", shown, {"state": state, "action": {"type": "detonate", "damage": 6, "range": 4, "pattern": [[0, 0]], "element": "fire"}, "target_tiles": [Vector2i(3, 3)]})
	assert(int(shown["damage_preview"]["player"]["hp_loss"]) == 6 and not (shown["friendly_damage_chips"] as Array).is_empty(), "Known Detonate exposure stays visible within limited Umbra")

	# Omitted enemies cannot manufacture victory or suppress the follow-up blast.
	state["enemies"][0]["pos"] = Vector2i(8, 6)
	var projected: Dictionary = scene.call("_surface_preview_information_state", state)
	assert((projected["enemies"] as Array).is_empty() and combat.combat_outcome(projected).is_empty(), "No visible enemies is not a forecast victory")
	assert(not state.has("_preview_opaque_enemies"), "Preview-only outcome marker never enters actual state")
	var actions: Array[Dictionary]
	actions.append({"type": "surface", "surface": "fire", "range": 4})
	actions.append({"type": "detonate", "damage": 6, "target": "previous_target", "pattern": [[0, 0]], "element": "fire"})
	scene.set("_pending_actions", actions)
	scene.set("_pending_action_index", 0)
	scene.call("_mark_combat_preview_state_changed")
	shown = {}
	scene.call("_append_surface_action_preview", shown, {"state": state, "action": actions[0], "target_tiles": [Vector2i(3, 3)]})
	assert(int(shown["damage_preview"]["player"]["hp_loss"]) == 6, "Automatic Detonate still resolves with unseen opponents omitted")
	actions.clear()
	scene.set("_pending_actions", actions)
	scene.set("_pending_action_index", -1)

func _test_opaque_preview_outcomes(c: RefCounted) -> void:
	var normal: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(c)
	var empty: Dictionary = normal.duplicate(true)
	empty["enemies"] = []
	for room: String in ["combat", "boss"]:
		for objective: String in ["kill_all", "kill_leader"]:
			var actual: Dictionary = empty.duplicate(true)
			actual["room_type"] = room
			actual["objective"] = {"type":objective, "leader_id":1}
			assert(c.combat_outcome(actual)=="victory", "%s/%s unchanged empty actual victory" % [room,objective])
			actual["_preview_opaque_enemies"] = true
			assert(c.combat_outcome(actual)=="", "%s/%s missing unknown opponent is not victory" % [room,objective])
	for kind: String in ["boss", "leader", "kill_all"]:
		var known: Dictionary = normal.duplicate(true)
		known["_preview_opaque_enemies"] = true
		known["enemies"][0]["hp"] = 1
		known["objective"] = {"type":"kill_leader" if kind=="leader" else "kill_all", "leader_id":1}
		if kind == "boss":
			known["room_type"] = "boss"
			known["enemies"][0]["type"] = "vyraketh"
		elif kind == "leader":
			known["enemies"][0]["is_leader"] = true
		assert(c.combat_outcome(known)=="", "Known live %s remains incomplete" % kind)
		var before: Dictionary = known.duplicate(true)
		var after: Dictionary = c.apply_player_action(known,{"type":"ranged","damage":20,"range":5},Vector2i(4,3))
		assert(c.combat_outcome(after)==("" if kind=="kill_all" else "victory"), "Known %s killing attack respects opaque completion" % kind)
		assert(known==before, "Known %s preview resolution preserves its source" % kind)
	for opaque: bool in [false,true]:
		for clock_value: int in [9,10]:
			var survive: Dictionary = empty.duplicate(true)
			survive["objective"] = {"type":"survive","target_clock":10}
			survive["initiative_clock"] = clock_value
			survive["_preview_opaque_enemies"] = opaque
			assert(c.combat_outcome(survive)==("victory" if clock_value>=10 else ""), "Survive clock independent of opaque flag")
		for reached: bool in [false,true]:
			var exit_state: Dictionary = empty.duplicate(true)
			exit_state["objective"] = {"type":"reach_exit","exits":[{"target_tile":Vector2i(2,3)}]}
			exit_state["player"]["pos"] = Vector2i(2,3) if reached else Vector2i(3,3)
			exit_state["_preview_opaque_enemies"] = opaque
			assert(c.combat_outcome(exit_state)==("victory" if reached else ""), "Exit occupancy independent of opaque flag")
		for objective: String in ["kill_all","kill_leader","survive","reach_exit"]:
			var dead: Dictionary = empty.duplicate(true)
			dead["player"]["hp"] = 0
			dead["objective"] = {"type":objective,"target_clock":0,"exits":[{"target_tile":Vector2i(2,3)}]}
			dead["_preview_opaque_enemies"] = opaque
			assert(c.combat_outcome(dead)=="defeat", "Defeat wins over %s/opaque%s" % [objective,opaque])
	var scene := Scene.new()
	normal["umbra"]["stage"] = "heart"
	var original: Dictionary = normal.duplicate(true)
	var information: Dictionary = scene._surface_preview_information_state(normal)
	assert(information.get("_preview_opaque_enemies",false) and not normal.has("_preview_opaque_enemies") and normal==original, "Information projection creates marker only in its own deep copy")
	var actual_after: Dictionary = c.apply_player_action(normal,{"type":"block","amount":2})
	assert(not actual_after.has("_preview_opaque_enemies") and not normal.has("_preview_opaque_enemies"), "Actual action does not acquire preview marker")
	scene.free()
