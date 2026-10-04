extends "res://tests/aoe_targeting_preview_probe.gd"

# Reuse the production-scene setup/capture machinery; no alternate UI surface.
const U3 = preload("res://tests/suites/relic_u3_suite.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const U3_OUTPUT := "user://probes/relic_u3"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://relic_u3_probe_profile.json")
	ProgressionStore.set_run_storage_path("user://relic_u3_probe_run.save")
	SettingsStore.set_storage_path("user://relic_u3_probe_settings.json")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(U3_OUTPUT))
	_run_u3.call_deferred()

func _run_u3() -> void:
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	instance.set("_settings", settings)
	_resolve_contextual_prompts(instance)
	var combat := CombatEngine.new()
	var state: Dictionary = U3.fixture(combat, ["masons_plumb", "siege_ram_totem", "millstone_fob"], [U3.enemy(1, Vector2i(4, 4))])
	Terrain.raise_outcrop(combat, state, Vector2i(6, 4), 3, {"actor_kind": "player"})
	await _install_u3(instance, state)
	await _arm_printed_card(instance)
	_hover_tile(instance, Vector2i(4, 4))
	await _settle()
	var presentation: Dictionary = instance.get_node(BOARD_PATH).get("presentation")
	_expect(presentation.get("collision_markers", []).size() == 1, "Mason probe shows its collision marker")
	_expect(presentation.get("displacement_paths", []).size() == 1, "Mason probe shows the Updraft path")
	_expect(presentation.get("damage_preview", {}).has("enemy_1"), "Mason probe shows enemy damage")
	var delays: Dictionary = instance.call("_turn_order_stagger_preview_delays")
	_expect(int(delays.get(1, 0)) == 4, "Mason/Siege probe shows four Stagger on the turn rail")
	await _save_screenshot("%s/01_mason_siege_millstone.png" % U3_OUTPUT)
	state = U3.fixture(combat, ["battering_yoke"], [U3.enemy(1, Vector2i(3, 4)), U3.enemy(2, Vector2i(5, 4)), U3.enemy(3, Vector2i(6, 4))])
	state["grid"][4][7] = "wall"
	await _install_u3(instance, state)
	await _arm_printed_card(instance)
	_hover_tile(instance, Vector2i(3, 4))
	await _settle()
	presentation = instance.get_node(BOARD_PATH).get("presentation")
	_expect(presentation.get("collision_markers", []).size() == 3, "Yoke probe shows original and both knock-on collision markers")
	await _save_screenshot("%s/02_battering_yoke_chain.png" % U3_OUTPUT)
	state = U3.fixture(combat, ["breaking_wheel"], [U3.enemy(1, Vector2i(4, 4)), U3.enemy(2, Vector2i(5, 4))])
	Surface.place(state, Vector2i(4, 4), "ice")
	await _install_u3(instance, state)
	await _arm_printed_card(instance)
	_hover_tile(instance, Vector2i(4, 4))
	await _settle()
	presentation = instance.get_node(BOARD_PATH).get("presentation")
	_expect(int(presentation.get("surface_status_preview", {}).get("enemy_1", {}).get("freeze", 0)) == 1, "Wheel probe shows the existing Frozen preview badge")
	await _save_screenshot("%s/03_breaking_wheel_freeze.png" % U3_OUTPUT)
	# The required Ice capture remains one PNG; additionally assert the same
	# production forecast and badge path for Electrified's two Shock riders.
	state = U3.fixture(combat, ["breaking_wheel"], [U3.enemy(1, Vector2i(4, 4)), U3.enemy(2, Vector2i(5, 4))])
	Surface.place(state, Vector2i(4, 4), "electrified")
	await _install_u3(instance, state)
	await _arm_printed_card(instance)
	_hover_tile(instance, Vector2i(4, 4))
	await _settle()
	var board: Control = instance.get_node(BOARD_PATH)
	presentation = board.get("presentation")
	for key: String in ["enemy_1", "enemy_2"]:
		_expect(int(presentation.get("surface_status_preview", {}).get(key, {}).get("shock", 0)) == 1, "Wheel forecasts Shock on %s" % key)
		var unit: Dictionary = state["enemies"][0 if key == "enemy_1" else 1].duplicate(true)
		unit["key"] = key
		var badges: Array = board.call("_unit_status_badges", unit)
		_expect(badges.any(func(badge: Dictionary) -> bool: return str(badge.get("icon", "")) == "shock" and str(badge.get("count_text", "")) == "→"), "Wheel uses the existing Shock preview badge on %s" % key)

	state = U3.fixture(combat, ["recoil_plates"], [U3.enemy(1, Vector2i(8, 4))], [], Vector2i(9, 4))
	state["enemies"][0]["intent"] = {"id": "shove", "name": "Shove", "actions": [{"type": "melee", "damage": 0, "range": 1, "push": 2}]}
	await _install_u3(instance, state)
	instance.call("_on_board_tile_hovered", Vector2i(8, 4))
	await _settle()
	presentation = instance.get_node(BOARD_PATH).get("presentation")
	_expect(presentation.get("collision_markers", []).size() == 1 and int(presentation.get("collision_markers", [{}])[0].get("damage", 0)) == 2, "Recoil intent cue shows reduced collision damage")
	await _save_screenshot("%s/04_recoil_enemy_intent.png" % U3_OUTPUT)
	for failure: String in _failures:
		push_error(failure)
	print(ProjectSettings.globalize_path(U3_OUTPUT))
	print("RELIC U3 PROBE TEST RESULT: PASS" if _failures.is_empty() else "RELIC U3 PROBE TEST RESULT: FAIL (%d failures)" % _failures.size())
	instance.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _install_u3(instance: Node, state: Dictionary) -> void:
	await _install_combat_fixture(instance, "updraft", 73113)
	state["room_name"] = "Relic Collision Proof"
	state["deck"]["hand"] = ["updraft"]
	state["deck"]["draw"] = []
	state["deck"]["discard"] = []
	state["deck"]["burned"] = []
	var run_state: Dictionary = instance.get("_run_state").duplicate(true)
	var layout: Dictionary = run_state.get("current_room_layout", {}).duplicate(true)
	layout["grid"] = state["grid"]
	layout["name"] = "Relic Collision Proof"
	layout["enemies"] = state["enemies"]
	layout["terrain"] = state["terrain"]
	layout["player_start"] = state["player"]["pos"]
	run_state["current_room_layout"] = layout
	run_state["relics"] = state["relics"]
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	await _settle()
