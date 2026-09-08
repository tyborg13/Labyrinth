extends "res://tests/all_surface_performance_workload.gd"

# Optional, separate native workload. Do not append these phases to the original
# frame-comparison workload. Caller: await run(probe, instance, sampler), then
# replace its old instance with final_instance() before continuing or freeing it.
# run() returns JSON-safe measurements; final_instance() returns the live Node.
# The probe owns private persistence, the native window and frame-post-draw clock.
const Data = preload("res://scripts/game_data.gd")
const CombatLogic = preload("res://scripts/combat_engine.gd")
const EndRecap = preload("res://scripts/run_end_recap_overlay.gd")
const Settings = preload("res://scripts/settings_store.gd")
const NEXT_RUN_SEED: int = 84217
const ACTION_GUARD_FRAMES: int = 1800
const RUN_PATH: String = "res://scenes/run_scene.tscn"
const TITLE_PATH: String = "res://scenes/main_menu.tscn"
const PROFILE_FIELDS: Array = [
	"embers", "level", "skill_ids", "moltshards", "moltshard_award_ids",
	"progression_revision", "run_counter", "rested_at_fire", "recovery_marker",
	"run_bests", "last_run_result", "completed_run_results",
]
const LOADOUT_FIELDS: Array = [
	"mode", "equipped_equipment", "equipment_inventory", "attuned_magic_cards",
	"magic_inventory", "item_inventory", "equipped_items", "reward_cards",
	"deck_cards", "player_hp", "player_max_hp", "held_embers",
]

var _remaining_errors: Array[String]
var _next_run: Node
var _scene_failed: bool = false
var _transition_started_usec: int = 0
var _transition_phases: Array[Dictionary]
var _transition_profile: Dictionary = {}


func run(probe: SceneTree, instance: Node, sampler: Node) -> Dictionary:
	_probe = probe
	_instance = instance
	_sampler = sampler
	_phases.clear()
	_remaining_errors.clear()
	_check(is_instance_valid(instance) and instance.is_inside_tree(), "Remaining workload needs a live run scene")
	if not is_instance_valid(instance):
		return _report()
	# The runtime benchmark adds its initial scene manually. Give actual scene
	# changes ownership of that scene instead of leaving it alive behind the menu.
	_probe.current_scene = instance
	_probe.root.set_meta("labyrinth_performance_probe_seed", NEXT_RUN_SEED)
	await _settings_and_piles()
	await _large_inventory()
	await _curator_reservation()
	if not await _embrace_and_restart():
		return _report()
	for outcome: String in ["victory", "defeat"]:
		if not await _terminal_and_restart(outcome):
			return _report()
	return _report()


func final_instance() -> Node:
	return _instance if is_instance_valid(_instance) else null


func _report() -> Dictionary:
	return {
		"schema_version": 1,
		"workload_id": "remaining_native_surfaces_and_scene_routes_v1",
		"viewport": "1920x1080",
		"ui_scale": 1.0,
		"cpu_profile": OS.get_environment("LABYRINTH_PERF_CPU_PROFILE"),
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"sample_boundary": "RenderingServer.frame_post_draw",
		"phases": _phases,
		"semantic_errors": _remaining_errors.duplicate(),
		"final_instance_valid": is_instance_valid(_instance),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"live_nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"focus_observations": _probe.get("_focus_observation_count"),
		"unfocused_observations": _probe.get("_unfocused_observation_count"),
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_remaining_errors.append(message)
	super._check(condition, message)


func _phase(action: Callable, minimum_frames: int) -> Dictionary:
	await _probe.call("_settle_render_frames", 3)
	var source: Node = _instance
	_check(is_instance_valid(source), "Ordinary phase must retain its run scene")
	if not is_instance_valid(source):
		return {}
	source.call("set_runtime_performance_instrumentation_enabled", true)
	var compilations_before: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS)
	_sampler.call("begin")
	var started_usec: int = Time.get_ticks_usec()
	action.call()
	var handler_ms: float = float(Time.get_ticks_usec() - started_usec) / 1000.0
	var frames: int = 0
	while is_instance_valid(source) and (frames < minimum_frames or _run_action_busy(source)):
		await _probe.call("_await_render_frame")
		frames += 1
		if frames >= ACTION_GUARD_FRAMES:
			_check(false, "Remaining surface action must settle before the deadlock guard")
			break
	var finished_usec: int = Time.get_ticks_usec()
	var result: Dictionary = _probe.call("_sampler_phase_result", _sampler.call("finish"))
	result["handler_ms"] = handler_ms
	# The fixed sample floor is a frame-pacing window, not action latency.
	result["sample_window_ms"] = float(finished_usec - started_usec) / 1000.0
	result["canvas_pipeline_compilations"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS) - compilations_before
	_check(is_instance_valid(source), "Only a lifecycle phase may replace the run scene")
	_capture_source_profiles(source, result)
	return result


func _run_action_busy(source: Node) -> bool:
	for field: String in [
		"_animation_lock", "_merchant_trade_animation_active",
		"_loadout_acquisition_in_progress", "_campfire_choice_action_pending",
		"_relic_claim_in_progress", "_equipment_swap_animation_active",
		"_item_swap_animation_active", "_magic_drag_release_in_progress",
		"_reward_intro_in_progress", "_frame_sliced_ui_refresh_active",
	]:
		if bool(source.get(field)):
			return true
	var recap: Control = source.get("_run_end_recap") as Control
	if is_instance_valid(recap) and recap.visible:
		if recap.is_processing():
			return true
		# Active denotes the retained final transform, not a running tween.
		if bool(source.get("_run_end_board_reframe_active")) and float(source.get("_run_end_board_reframe_progress")) < 0.9999:
			return true
	return false


func _capture_source_profiles(source: Variant, result: Dictionary) -> void:
	if not is_instance_valid(source) or not source.has_method("runtime_performance_instrumentation_snapshot"):
		return
	result["stage_profile"] = source.call("runtime_performance_instrumentation_snapshot")
	result["stage_frame_profile"] = source.call("runtime_performance_frame_instrumentation_snapshot")
	source.call("set_runtime_performance_instrumentation_enabled", false)


func _scene_phase(name: String, action: Callable, ready: Callable) -> Dictionary:
	_probe.call("_phase_log", name)
	await _probe.call("_settle_render_frames", 3)
	var source: Node = _probe.current_scene
	var result: Dictionary = {}
	var exit_callback: Callable = func() -> void: _capture_source_profiles(source, result)
	if is_instance_valid(source):
		if source.has_method("set_runtime_performance_instrumentation_enabled"):
			source.call("set_runtime_performance_instrumentation_enabled", true)
		source.tree_exiting.connect(exit_callback, CONNECT_ONE_SHOT)
	_scene_failed = false
	var compilations_before: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS)
	_sampler.call("begin")
	var started_usec: int = Time.get_ticks_usec()
	action.call()
	var handler_ms: float = float(Time.get_ticks_usec() - started_usec) / 1000.0
	var frames: int = 0
	var stable_frames: int = 0
	var usable_at_usec: int = 0
	while stable_frames < 3 and not _scene_failed:
		await _probe.call("_await_render_frame")
		frames += 1
		if bool(ready.call()):
			if stable_frames == 0:
				usable_at_usec = Time.get_ticks_usec()
			stable_frames += 1
		else:
			stable_frames = 0
			usable_at_usec = 0
		if frames >= ACTION_GUARD_FRAMES:
			_scene_failed = true
			_check(false, name + " must reach its usable destination before the deadlock guard")
	var finished_usec: int = Time.get_ticks_usec()
	var sampled: Dictionary = _probe.call("_sampler_phase_result", _sampler.call("finish"))
	result.merge(sampled, true)
	result["handler_ms"] = handler_ms
	result["sample_window_ms"] = float(finished_usec - started_usec) / 1000.0
	if usable_at_usec > 0 and not _scene_failed:
		result["completion_ms"] = float(usable_at_usec - started_usec) / 1000.0
	result["canvas_pipeline_compilations"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS) - compilations_before
	result["destination_ready"] = not _scene_failed and bool(ready.call())
	if is_instance_valid(source):
		if source.tree_exiting.is_connected(exit_callback):
			source.tree_exiting.disconnect(exit_callback)
		_capture_source_profiles(source, result)
	_phases[name] = result
	return result


func _settings_and_piles() -> void:
	if str((_instance.get("_run_state") as Dictionary).get("mode", "")) != "combat":
		_probe.call("_install_stress_combat", _instance, "specialists")
	_instance.call("_close_dialogue")
	_instance.call("_cancel_card_selection")
	await _probe.call("_settle_render_frames", 12)
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var combat_before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	var settings_before: Dictionary = Settings.load_settings().duplicate(true)
	await _measure("remaining/settings/menu_open", func() -> void: _click(_instance.get("menu_button")), 18)
	var settings_button: Button = _button_with_exact_text(_instance.get("_menu_dialog"), "Settings")
	await _measure("remaining/settings/open", func() -> void: _click(settings_button), 24)
	_check((_instance.get("_settings_panel") as Control).visible, "Settings must open from the public menu")
	_check(not (_instance.get("_menu_dialog") as Control).visible, "Settings must replace the menu body")
	await _probe.call("_save_root_screenshot", "remaining_settings.png")
	await _measure("remaining/settings/back", func() -> void: _click(_instance.find_child("SettingsBackButton", true, false)), 18)
	_check((_instance.get("_menu_dialog") as Control).visible and not (_instance.get("_settings_panel") as Control).visible, "Settings Back must restore the menu")
	await _measure("remaining/settings/menu_close", func() -> void: _click(_button_with_exact_text(_instance.get("_menu_dialog"), "Close")), 18)
	_check(not (_instance.get("_menu_scrim") as Control).visible, "Closing the menu must restore combat")
	_check(Settings.load_settings() == settings_before, "Settings inspection must preserve persisted settings")
	_check(not (_instance.get("burn_pile") as Control).is_visible_in_tree(), "The legacy Exhaust HUD control must remain intentionally hidden")
	for kind: String in ["draw", "discard", "draw"]:
		var prefix: String = "remaining/pile/%s_%d" % [kind, _phases.size()]
		var pile: Control = _instance.get(kind + "_pile") as Control
		var expected_ids: Array = _pile_ids_oracle(combat_before, kind)
		var phase: Dictionary = await _measure(prefix + "/open", func() -> void: _click(pile), 24)
		_check((_instance.get("_pile_scrim") as Control).visible and str(_instance.get("_active_pile_kind")) == kind, "Pile click must open the requested pile")
		var actual_ids: Array = _displayed_pile_ids()
		_check(actual_ids == expected_ids, "Pile presentation must preserve every card and its public order: " + kind)
		phase["card_ids"] = actual_ids
		if kind == "burn":
			_check((_instance.get("_pile_dialog_title") as Label).text == "Exhaust Pile", "Burned cards must use the Exhaust title")
		if kind == "draw":
			await _probe.call("_save_root_screenshot", "remaining_draw_pile_%d.png" % _phases.size())
		var close: Button = (_instance.get("_pile_dialog") as Control).find_child("CloseButton", true, false) as Button
		await _measure(prefix + "/close", func() -> void: _click(close), 12)
		_check(not (_instance.get("_pile_scrim") as Control).visible, "Pile Close must restore combat")
		_check((_instance.get("_run_state") as Dictionary) == before, "Settings and pile inspection must preserve committed run state")
		_check((_instance.get("_combat_state") as Dictionary) == combat_before, "Settings and pile inspection must preserve committed combat")


func _pile_ids_oracle(combat: Dictionary, kind: String) -> Array:
	var deck: Dictionary = combat.get("deck", {}) as Dictionary
	var ids: Array = (deck.get("burned" if kind == "burn" else kind, []) as Array).duplicate()
	if kind != "draw":
		ids.reverse()
		return ids
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_name: String = str(Data.card_def(str(a)).get("name", str(a)))
		var b_name: String = str(Data.card_def(str(b)).get("name", str(b)))
		return str(a) < str(b) if a_name == b_name else a_name < b_name
	)
	return ids


func _displayed_pile_ids() -> Array:
	var ids: Array = []
	var host: Control = _instance.get("_pile_dialog_cards") as Control
	for child: Node in host.get_children():
		if not child is Control or not (child as Control).visible:
			continue
		for entry: Dictionary in _instance.get("_pile_dialog_card_pool") as Array:
			if entry.get("button") == child:
				ids.append(str((entry.get("widget") as Control).get("card_id")))
				break
	return ids


func _large_inventory() -> void:
	var state: Dictionary = _engine.create_new_run(NEXT_RUN_SEED, Tutorial.complete_tutorial(ProgressionStore.default_data()))
	var equipped: Dictionary = state.get("equipped_equipment", {}) as Dictionary
	var gear: Array = []
	for id: String in Data.equipment_ids():
		if not equipped.values().has(id) and not Data.equipment_slot(id).is_empty():
			gear.append(id)
	gear.sort()
	if gear.size() > 24:
		gear.resize(24)
	var magic: Array = []
	var attuned: Array = state.get("attuned_magic_cards", []) as Array
	var pools: Dictionary = Data.reward_card_pool_by_rarity("", true)
	for rarity: String in Data.CARD_RARITY_TIERS:
		for id: String in pools.get(rarity, []):
			if not attuned.has(id) and not magic.has(id):
				magic.append(id)
	magic.sort()
	if magic.size() > 64:
		magic.resize(64)
	_check(gear.size() >= 12 and magic.size() >= 32, "Large inventory fixture must exceed both visible inventory areas")
	_check(attuned.size() == Data.magic_loadout_limit(), "Large inventory fixture must preserve all six starter magic slots")
	state["equipment_inventory"] = gear
	state["magic_inventory"] = magic
	state["reward_cards"] = magic.duplicate()
	state["item_inventory"] = Data.item_card_ids()
	await _install(state)
	await _measure("remaining/inventory/open", func() -> void: _click(_instance.get("loadout_button")), 30)
	await _scroll_inventory("EquipmentInventoryPanel", "remaining/inventory/gear")
	var ordered_gear: Array = _instance.call("_equipment_inventory_ids")
	if ordered_gear.is_empty():
		_check(false, "Large gear inventory must expose an equip target")
		return
	var chosen_id: String = str(ordered_gear[0])
	var tile: Control = (_instance.get("_equipment_inventory_tiles") as Dictionary).get(chosen_id) as Control
	_check(is_instance_valid(tile) and tile.is_visible_in_tree(), "Large gear inventory must expose its live first row")
	if not is_instance_valid(tile):
		return
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var expected: Dictionary = _engine.equip_equipment(before, chosen_id)
	_check(expected.get("equipped_equipment") != before.get("equipped_equipment"), "Gear oracle must actually replace a slot")
	var phase: Dictionary = await _measure("remaining/inventory/equip", func() -> void: _probe.call("_routed_left_click", tile, tile.size * 0.5, true), 60)
	_assert_persisted_state_fields(expected, phase, LOADOUT_FIELDS)
	await _probe.call("_save_root_screenshot", "remaining_large_gear.png")
	await _measure("remaining/inventory/magic_tab", func() -> void: _click(_instance.find_child("CharacterMagicTab", true, false)), 30)
	await _scroll_inventory("MagicInventoryPanel", "remaining/inventory/magic")
	var source: Control = (_instance.get("_magic_inventory_tiles") as Dictionary).get(0) as Control
	var destination: Control = (_instance.get("_magic_attuned_tiles") as Dictionary).get(0) as Control
	_check(is_instance_valid(source) and is_instance_valid(destination), "Attunement must expose both live drag endpoints")
	if not is_instance_valid(source) or not is_instance_valid(destination):
		return
	before = (_instance.get("_run_state") as Dictionary).duplicate(true)
	expected = _engine.swap_magic_card(before, 0, 0)
	_check(expected.get("attuned_magic_cards") != before.get("attuned_magic_cards"), "Magic oracle must change the attuned card")
	phase = await _measure("remaining/inventory/attune_drag", func() -> void: _routed_drag(source, destination), 45)
	_assert_persisted_state_fields(expected, phase, LOADOUT_FIELDS)
	_check(not bool(_instance.get("_magic_drag_release_in_progress")), "Attunement must finish releasing its drag")
	await _probe.call("_save_root_screenshot", "remaining_large_magic.png")
	await _measure("remaining/inventory/close", func() -> void: _click(_instance.find_child("CloseCharacterOverlay", true, false)), 18)


func _scroll_inventory(panel_name: String, prefix: String) -> void:
	var panel: Control = _instance.find_child(panel_name, true, false) as Control
	var scrolls: Array = panel.find_children("*", "ScrollContainer", true, false) if is_instance_valid(panel) else []
	_check(not scrolls.is_empty(), panel_name + " must expose a scrolling inventory")
	if scrolls.is_empty():
		return
	var scroll: ScrollContainer = scrolls[0] as ScrollContainer
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	_check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, panel_name + " must overflow its viewport")
	await _measure(prefix + "/scroll_down", func() -> void: _routed_wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN, 12), 18)
	_check(scroll.scroll_vertical > 0, "Wheel input must move the large inventory: " + panel_name)
	await _measure(prefix + "/scroll_up", func() -> void: _routed_wheel(scroll, MOUSE_BUTTON_WHEEL_UP, 24), 18)
	_check(scroll.scroll_vertical == 0, "Reverse wheel input must return to the visible first inventory row")
	_check((_instance.get("_run_state") as Dictionary) == before, "Inventory scrolling must preserve committed state")


func _routed_wheel(control: Control, button: MouseButton, count: int) -> void:
	var viewport: Viewport = control.get_viewport()
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	_motion(control)
	for index: int in range(count):
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = button
			event.factor = 1.0
			event.pressed = pressed
			viewport.push_input(event, true)


func _routed_drag(source: Control, destination: Control) -> void:
	var viewport: Viewport = source.get_viewport()
	var start: Vector2 = source.get_global_transform_with_canvas() * (source.size * 0.5)
	var finish: Vector2 = destination.get_global_transform_with_canvas() * (destination.size * 0.5)
	_motion(source)
	var press := InputEventMouseButton.new()
	press.position = start
	press.global_position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	viewport.push_input(press, true)
	var previous: Vector2 = start
	for fraction: float in [0.35, 0.7, 1.0]:
		var point: Vector2 = start.lerp(finish, fraction)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = point - previous
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(motion, true)
		previous = point
	var release := InputEventMouseButton.new()
	release.position = finish
	release.global_position = finish
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	viewport.push_input(release, true)


func _curator_reservation() -> void:
	var fixture: Dictionary = _route_fixture("treasure")
	_check(not fixture.is_empty(), "Curator fixture needs reachable generated treasure")
	if fixture.is_empty():
		return
	var profile: Dictionary = (fixture["state"]["progression"] as Dictionary).duplicate(true)
	profile["level"] = 5
	profile["skill_ids"] = ["quick_wits", "discerning_eye", "deferred_choice", "curators_patience"]
	fixture["state"] = _engine.apply_progression_update(fixture["state"], profile)
	await _enter_route_fixture(fixture, "remaining/curator")
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var offers: Array = before.get("pending_relics", []) as Array
	_check(offers.size() >= 2, "Curator requires two unowned relic choices")
	if offers.size() < 2:
		return
	var chosen: String = str(offers[0])
	var deferred: String = str(offers[1])
	var expected: Dictionary = _engine.claim_relic(before, chosen, deferred)
	await _measure("remaining/curator/open_choice", func() -> void: _click(_instance.find_child("RelicChoice_" + chosen, true, false)), 18)
	_check((_instance.get("_skill_choice_scrim") as Control).visible, "Curator must expose its deferred-relic choice")
	var option: Button = _choice_button("Save " + str(Data.relic_def(deferred).get("name", deferred)))
	_check(option != null, "Curator must expose the second offered relic by name")
	await _probe.call("_save_root_screenshot", "remaining_curator_choice.png")
	var phase: Dictionary = await _measure("remaining/curator/claim_and_reserve", func() -> void: _click(option), 90)
	_assert_persisted_state_fields(expected, phase, ["mode", "pending_relics", "relics", "player_hp", "player_max_hp", "defiance_capacity", "defiance_remaining", "skill_state"])
	var actual: Dictionary = _instance.get("_run_state") as Dictionary
	_check((actual.get("relics", []) as Array).has(chosen) and not (actual.get("relics", []) as Array).has(deferred), "Curator must grant only the selected relic")
	_check(str((actual.get("skill_state", {}) as Dictionary).get("pending_relic", "")) == deferred, "Curator must preserve the second relic for the next offer")
	_check(not (_instance.get("_skill_choice_scrim") as Control).visible, "Curator commit must close its choice dialog")


func _enter_route_fixture(fixture: Dictionary, prefix: String) -> void:
	await _install(fixture["state"])
	var destination: Vector2i = fixture["destination"]
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var expected: Dictionary = _engine.move_to_pre_battle(before, destination)
	await _measure(prefix + "/map_open", func() -> void: _key(KEY_M), 12)
	var map: Control = _instance.get("_large_map_view") as Control
	var point: Vector2 = map.call("_coord_position", destination)
	_check(map.call("_coord_at_point", point) == destination, "Routed map target must identify the generated room")
	var phase: Dictionary = await _measure(prefix + "/enter", func() -> void: _probe.call("_routed_left_click", map, point), 60)
	_assert_state_fields(expected, phase, ["mode", "current_room", "current_room_layout", "turns_spent", "held_embers", "pending_relics"])
	_instance.call("_close_dialogue")
	await _probe.call("_settle_render_frames", 6)


func _embrace_and_restart() -> bool:
	var fixture: Dictionary = _route_fixture("campfire")
	_check(not fixture.is_empty(), "Embrace fixture needs reachable generated campfire")
	if fixture.is_empty():
		return false
	await _enter_route_fixture(fixture, "remaining/embrace")
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var expected_profile: Dictionary = ProgressionStore.mark_rested_at_fire(ProgressionStore.set_embers(before["progression"], _engine.held_embers(before)))
	var bar: Control = _instance.get("_relic_choice_bar") as Control
	_check(bar.get_child_count() == 3 and str(before.get("mode", "")) == "campfire", "Embrace must start on the three-choice campfire surface")
	if bar.get_child_count() != 3:
		return false
	await _probe.call("_save_root_screenshot", "remaining_campfire_before_embrace.png")
	var choice: Control = bar.get_child(1) as Control
	var phase: Dictionary = await _scene_phase("remaining/embrace/to_title", func() -> void: _click(choice), _title_ready)
	if not bool(phase.get("destination_ready", false)):
		return false
	_assert_title_profile(expected_profile, phase)
	await _probe.call("_save_root_screenshot", "remaining_embrace_title.png")
	return await _start_from_title("remaining/embrace/new_run")


func _terminal_fixture(outcome: String) -> Dictionary:
	var profile: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
	profile["run_counter"] = 5
	var seed: int = 8841 if outcome == "victory" else 8842
	var state: Dictionary = _engine.create_new_run(seed, profile)
	var coord := Vector2i(RunEngine.MAX_DEPTH, 0) if outcome == "victory" else Vector2i(4, 0)
	var room: Dictionary = _engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	if outcome == "victory":
		room["type"] = "boss"
		room["depth"] = RunEngine.MAX_DEPTH
	state["rooms"]["%d,%d" % [coord.x, coord.y]] = room
	state["current_room"] = coord
	state["mode"] = "combat"
	state["held_embers"] = 64 if outcome == "victory" else 47
	state["unbanked_embers"] = state["held_embers"]
	var stats: Dictionary = CombatLogic.normalized_run_stats({"enemies_killed": 14, "damage_dealt": 124, "damage_received": 31})
	state["run_stats"] = stats.duplicate(true)
	var layout: Dictionary = _engine.call("_combat_layout_for_room", room, Vector2i(1, 0), state)
	var combat_engine := CombatLogic.new()
	var combat: Dictionary = combat_engine.create_combat(seed, layout, _engine.call("_player_snapshot", state))
	combat["run_stats"] = stats.duplicate(true)
	if outcome == "victory":
		combat = _victory_combat_state(combat)
	else:
		combat["player"]["hp"] = 0
	state["combat_state"] = combat
	var terminal: Dictionary = _engine.finish_combat(state, combat)
	_check(str(terminal.get("mode", "")) == outcome, "Terminal fixture must reach " + outcome + " through finish_combat without overriding its outcome")
	_check(not bool(terminal.get("debug_boss_run", false)), "Terminal proof must exercise ordinary progression persistence")
	return terminal


func _terminal_and_restart(outcome: String) -> bool:
	var terminal: Dictionary = _terminal_fixture(outcome)
	if str(terminal.get("mode", "")) != outcome:
		return false
	var profile: Dictionary = (terminal["progression"] as Dictionary).duplicate(true)
	var held: int = _engine.held_embers(terminal)
	var recorded: Dictionary = ProgressionStore.record_run_result(profile, RunEngine.run_result_id(terminal), EndRecap.result_stats(terminal))
	var expected_profile: Dictionary = recorded["data"]
	if outcome == "victory":
		expected_profile = ProgressionStore.set_embers(expected_profile, held)
	else:
		expected_profile = ProgressionStore.record_lost_embers(expected_profile, held, terminal["current_room"], int(terminal["run_index"]))
	var expected_state: Dictionary = _engine.clear_held_embers(terminal)
	expected_state["progression"] = expected_profile.duplicate(true)
	expected_state["run_result"] = recorded["result"].duplicate(true)
	var expected_model: Dictionary = EndRecap.build_model(expected_state, expected_profile, outcome, held)
	_check(ProgressionStore.save_data(profile), "Terminal fixture profile must save outside timing")
	_check(ProgressionStore.save_run_state(terminal), "Terminal resume fixture must save outside timing")
	_instance.set("_progression", profile)
	var prefix: String = "remaining/" + outcome
	var phase: Dictionary = await _measure(prefix + "/terminal_resume_presentation", func() -> void:
		_instance.call("_load_run_state", terminal)
		_instance.call("_close_dialogue")
	, 24)
	_assert_state_fields(expected_state, phase, ["mode", "game_over", "victory", "current_room", "player_hp", "player_max_hp", "held_embers", "unbanked_embers", "run_result"])
	_assert_profile_fields(expected_profile, phase)
	var recap: Control = _instance.get("_run_end_recap") as Control
	_check(is_instance_valid(recap) and recap.visible, "Terminal resume must present its outcome recap")
	if not is_instance_valid(recap):
		return false
	_check(recap.call("recap_model") == expected_model, "Recap labels and statistics must match the terminal engine/progression oracle")
	phase["recap_model"] = recap.call("recap_model")
	if outcome == "victory":
		var settled_state: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
		for retry_index: int in range(2):
			phase = await _measure(prefix + "/settled_resume_%d" % retry_index, func() -> void:
				_instance.call("_load_run_state", settled_state)
				_instance.call("_persist_grimoire_progression_from_run")
			, 24)
			_assert_profile_fields(expected_profile, phase)
			_assert_state_fields(expected_state, phase, ["mode", "held_embers", "unbanked_embers", "run_result"])
			_check(recap.call("recap_model") == expected_model, "A settled victory retry must retain its banked amount and exactly-once result model")
	await _probe.call("_save_root_screenshot", "remaining_%s_recap.png" % outcome)
	var button: Button = recap.find_child("MainMenuButton", true, false) as Button
	phase = await _scene_phase(prefix + "/to_title", func() -> void: _click(button), _title_ready)
	if not bool(phase.get("destination_ready", false)):
		return false
	_assert_title_profile(expected_profile, phase)
	await _probe.call("_save_root_screenshot", "remaining_%s_title.png" % outcome)
	return await _start_from_title(prefix + "/new_run")


func _title_ready() -> bool:
	var scene: Node = _probe.current_scene
	if not is_instance_valid(scene) or scene.scene_file_path != TITLE_PATH:
		return false
	var button: Button = scene.get_node_or_null("MenuColumn/StartButton") as Button
	return is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and not _probe.root.gui_disable_input and not _cursor_loading()


func _cursor_loading() -> bool:
	var cursor: Node = _probe.root.get_node_or_null("CursorFeedback")
	return is_instance_valid(cursor) and cursor.has_method("is_loading") and bool(cursor.call("is_loading"))


func _assert_title_profile(expected: Dictionary, phase: Dictionary) -> void:
	_check(_title_ready(), "Scene exit must reach an interactive title screen")
	_check(ProgressionStore.load_saved_run().is_empty(), "Embrace or terminal Main Menu must clear the saved run")
	_assert_profile_fields(expected, phase)
	var menu: Node = _probe.current_scene
	var resume: Button = menu.get_node_or_null("MenuColumn/ContinueButton") as Button
	_check(is_instance_valid(resume) and resume.disabled, "Title must disable Continue after the run has ended")


func _start_from_title(name: String) -> bool:
	var profile: Dictionary = ProgressionStore.load_data().duplicate(true)
	var prepared: Dictionary = ProgressionStore.prepare_for_new_run(profile)
	var expected: Dictionary = _engine.create_new_run(NEXT_RUN_SEED, prepared)
	_next_run = null
	_transition_phases.clear()
	_transition_profile.clear()
	var phase: Dictionary = await _scene_phase(name, func() -> void:
		var menu: Node = _probe.current_scene
		var button: Button = menu.get_node_or_null("MenuColumn/StartButton") as Button
		_check(is_instance_valid(button) and not button.disabled, "Title must expose New Run")
		_transition_started_usec = Time.get_ticks_usec()
		_click(button)
		var transition: Node = _probe.root.get_node_or_null("MenuRunTransition")
		_check(is_instance_valid(transition), "Public New Run must create its loading transition")
		if not is_instance_valid(transition):
			_scene_failed = true
			return
		_check(_probe.root.gui_disable_input, "Public New Run must lock input while loading")
		_transition_phases.append({"phase": "loading", "at_ms": 0.0})
		transition.connect("phase_changed", _on_transition_phase)
		transition.connect("finished", func(destination: Node) -> void:
			_next_run = destination
			_transition_profile = transition.call("performance_snapshot")
		)
		transition.connect("failed", func() -> void:
			_scene_failed = true
			_check(false, "Public New Run transition must finish successfully")
		)
	, _new_run_ready)
	phase["phase_changes"] = _transition_phases.duplicate(true)
	phase["transition_profile"] = _transition_profile.duplicate(true)
	if not bool(phase.get("destination_ready", false)) or not is_instance_valid(_next_run):
		return false
	_instance = _next_run
	_probe.call("_set_candidate_batching_enabled", _instance)
	_assert_persisted_state_fields(expected, phase, ["seed", "run_index", "current_room", "mode", "equipped_equipment", "attuned_magic_cards", "equipment_inventory", "magic_inventory", "item_inventory", "equipped_items", "held_embers", "player_hp", "player_max_hp", "deck_cards"])
	_assert_profile_fields(prepared, phase)
	_check((_instance.get("_run_state") as Dictionary).get("run_index") == int(profile.get("run_counter", 0)) + 1, "New Run must advance the persisted run counter exactly once")
	await _probe.call("_save_root_screenshot", name.replace("/", "_") + "_ready.png")
	return true


func _on_transition_phase(phase: StringName) -> void:
	_transition_phases.append({"phase": str(phase), "at_ms": float(Time.get_ticks_usec() - _transition_started_usec) / 1000.0})
	if phase == &"revealing":
		var transition: Node = _probe.root.get_node_or_null("MenuRunTransition")
		var destination: Node = transition.get("destination") if is_instance_valid(transition) else null
		_check(is_instance_valid(destination) and bool(destination.call("initial_presentation_is_ready")), "New Run must prepare its presentation before reveal")


func _new_run_ready() -> bool:
	return is_instance_valid(_next_run) and _probe.current_scene == _next_run and _next_run.scene_file_path == RUN_PATH and not _probe.root.gui_disable_input and bool(_next_run.call("initial_presentation_is_ready")) and not _cursor_loading()


func _assert_persisted_state_fields(expected: Dictionary, phase: Dictionary, fields: Array) -> void:
	_assert_state_fields(expected, phase, fields)
	var saved: Dictionary = ProgressionStore.load_saved_run()
	_check(not saved.is_empty(), "Committed action must preserve a resumable private save")
	var saved_semantics: Dictionary = {}
	for field: String in fields:
		_check(expected.has(field) and saved.has(field), "Persisted oracle field must exist: " + field)
		_check(saved.get(field) == expected.get(field), "Persisted action must match engine oracle: " + field)
		saved_semantics[field] = saved.get(field)
	phase["persisted_semantics"] = saved_semantics


func _assert_profile_fields(expected: Dictionary, phase: Dictionary) -> void:
	var actual: Dictionary = ProgressionStore.load_data()
	# Profiles use JSON storage, which decodes numeric members as floats.
	# Compare both sides in that representation, including nested markers.
	var serialized_expected: Dictionary = JSON.parse_string(JSON.stringify(expected))
	var serialized_actual: Dictionary = JSON.parse_string(JSON.stringify(actual))
	var semantics: Dictionary = {}
	for field: String in PROFILE_FIELDS:
		_check(expected.has(field) and actual.has(field), "Profile oracle field must exist: " + field)
		_check(serialized_actual.get(field) == serialized_expected.get(field), "Persisted progression must match its public oracle: %s actual=%s expected=%s" % [field, str(actual.get(field)), str(expected.get(field))])
		semantics[field] = actual.get(field)
	phase["progression_semantics"] = semantics
	phase["expected_progression_semantics"] = expected.duplicate(true)


func _button_with_exact_text(host: Node, label: String) -> Button:
	if not is_instance_valid(host):
		return null
	for node: Node in host.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == label and button.is_visible_in_tree():
			return button
	return null
