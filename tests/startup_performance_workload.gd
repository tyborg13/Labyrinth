extends RefCounted

const ProgressionStore = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SEED: int = 84217
var _probe: SceneTree
var _started_usec: int
var _phase_changes: Array[Dictionary]
var _destination: Node
var _transition_profile: Dictionary

func run(probe: SceneTree, sampler: Node) -> Dictionary:
	_probe = probe
	ProjectSettings.set_setting("telemetry/performance/section_instrumentation_enabled", bool(probe.call("_section_instrumentation_enabled")))
	var mode: String = OS.get_environment("LABYRINTH_RUNTIME_PERF_STARTUP_MODE")
	mode = "continue" if mode == "continue" else "new"
	var progression: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
	_check(ProgressionStore.save_data(progression), "Private startup profile must save")
	var engine := RunEngine.new()
	var expected: Dictionary = engine.create_new_run(SEED, progression)
	# Resume the same saved UI fixtures through the actual public menu loader.
	# Direct _load_run_state probes measure synchronous fixture installation;
	# they do not include this production preparation/loading lifecycle.
	var saved_surface: String = OS.get_environment("LABYRINTH_RUNTIME_PERF_STARTUP_SAVED_SURFACE")
	if not saved_surface.is_empty():
		_check(mode == "continue" and saved_surface in ["shop", "reward"], "Saved-surface startup requires public Continue and a supported fixture")
		var flow = load("res://tests/ui_flow_performance_workload.gd").new()
		flow._probe = probe
		expected = flow._scavenger_state(engine) if saved_surface == "shop" else flow._reward_state()
		expected["progression"] = Tutorial.complete_tutorial(expected["progression"])
		expected["notice"] = ""
		expected["grimoire_notice"] = ""
		expected["grimoire_unread"] = []
		# These flow fixtures deliberately alter loadout/reward fields. Normalize
		# them through the same canonical save repair before asserting preservation.
		expected = engine.repair_loaded_run_state(expected)
		progression = expected["progression"]
		_check(ProgressionStore.save_data(progression), "Saved-surface startup profile must save")
	var large_inventory: bool = OS.get_environment("LABYRINTH_RUNTIME_PERF_STARTUP_LARGE_INVENTORY") == "1"
	if large_inventory:
		_check(mode == "continue", "Large inventory startup must use the public saved Continue path")
		expected = _large_inventory_state(expected)
	if mode == "continue":
		_check(ProgressionStore.save_run_state(expected), "Continue fixture must save")
	else:
		ProgressionStore.clear_saved_run()
	probe.root.set_meta("labyrinth_performance_probe_seed", SEED)
	probe.root.set_meta("labyrinth_trace_load_status", true)
	if not OS.get_environment("LABYRINTH_RUNTIME_PERF_LOAD_REQUEST_DELAY_FRAMES").is_empty():
		probe.root.set_meta("labyrinth_load_request_delay_frames", int(OS.get_environment("LABYRINTH_RUNTIME_PERF_LOAD_REQUEST_DELAY_FRAMES")))
	# Settle the launch fullscreen/windowed transition before timing menu creation.
	# The public button measurement starts from a stable, already visible menu.
	await probe.call("_settle_probe_window")
	await probe.call("_settle_render_frames", 3)
	sampler.call("begin")
	var boot_started: int = Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	var menu: Control = packed.instantiate() as Control
	probe.root.add_child(menu)
	probe.current_scene = menu
	await probe.call("_settle_render_frames", 12)
	var menu_boot: Dictionary = probe.call("_sampler_phase_result", sampler.call("finish"))
	menu_boot["completion_ms"] = float(Time.get_ticks_usec() - boot_started) / 1000.0
	await probe.call("_save_root_screenshot", "startup_%s_menu.png" % mode)
	await probe.call("_settle_render_frames", 3)
	sampler.call("begin")
	_started_usec = Time.get_ticks_usec()
	var button: Button = menu.get_node("MenuColumn/ContinueButton" if mode == "continue" else "MenuColumn/StartButton") as Button
	_check(button.is_visible_in_tree() and not button.disabled, "Startup must expose enabled public " + mode + " button")
	var handler_ms: float = probe.call("_routed_left_click", button, button.size * 0.5)
	var transition: Node = probe.root.get_node_or_null("MenuRunTransition")
	_check(transition != null, "Public startup must create the loading transition")
	if transition == null: return {}
	_phase_changes.append({"phase": "loading", "at_ms": float(Time.get_ticks_usec() - _started_usec) / 1000.0})
	transition.connect("phase_changed", _phase_changed)
	transition.connect("finished", func(destination: Node) -> void:
		_destination = destination
		_transition_profile = transition.call("performance_snapshot")
	)
	_check(probe.root.gui_disable_input, "Loading must lock ordinary GUI input")
	var frames: int = 0
	while _destination == null and frames < 1800:
		await probe.call("_await_render_frame")
		frames += 1
	_check(_destination != null, "Startup must finish before its deadlock guard")
	await probe.call("_await_render_frame")
	var start: Dictionary = probe.call("_sampler_phase_result", sampler.call("finish"))
	start["handler_ms"] = handler_ms
	start["completion_ms"] = float(Time.get_ticks_usec() - _started_usec) / 1000.0
	start["phase_changes"] = _phase_changes
	start["transition_profile"] = _transition_profile
	if _destination != null:
		_check(probe.current_scene == _destination, "Startup must commit the run as current scene")
		_check(not probe.root.gui_disable_input, "Ready run must restore GUI input")
		_check(bool(_destination.call("initial_presentation_is_ready")), "Loading reveal must wait for presentation readiness")
		var actual: Dictionary = _destination.get("_run_state") as Dictionary
		var semantics: Dictionary = {}
		for field: String in ["seed", "current_room", "mode", "equipped_equipment", "attuned_magic_cards", "held_embers", "player_hp", "player_max_hp", "equipment_inventory", "magic_inventory", "item_inventory", "equipped_items"]:
			_check(actual.get(field) == expected.get(field), "Startup state must match deterministic run oracle: " + field)
			semantics[field] = actual.get(field)
		start["semantics"] = semantics
		var board: Node = _destination.get("board_view")
		var board_startup: Dictionary = {"main": board.get("_startup_performance_timings")}
		for layer: Node in board.call("_retained_render_layers"):
			board_startup[str(layer.name)] = layer.get("_startup_performance_timings")
		start["board_startup_profile"] = board_startup
		start["board_initial_render_profile"] = board.call("render_instrumentation_snapshot")
		start["stage_profile"] = _destination.call("runtime_performance_instrumentation_snapshot")
		start["stage_frame_profile"] = _destination.call("runtime_performance_frame_instrumentation_snapshot")
		if saved_surface == "shop":
			var shop: Control = _destination.get("_scavenger_shop_view") as Control
			_check(is_instance_valid(shop) and shop.is_visible_in_tree(), "Public Continue must show the actual saved merchant")
			_check((_destination.get("_run_state") as Dictionary).get("rooms") == expected["rooms"], "Saved merchant stock and room state must be preserved")
		elif saved_surface == "reward":
			_check((_destination.get("_run_state") as Dictionary).get("pending_reward") == expected["pending_reward"], "Public Continue must preserve the actual saved reward offer")
		_check(not ProgressionStore.load_saved_run().is_empty(), "Startup must persist its run")
		await probe.call("_settle_render_frames", 3)
		_destination.call("set_runtime_performance_instrumentation_enabled", bool(probe.call("_section_instrumentation_enabled")))
		board.call("set_submission_performance_instrumentation_enabled", bool(probe.call("_section_instrumentation_enabled")))
		board.call("reset_render_instrumentation")
		sampler.call("begin")
		await probe.call("_settle_render_frames", 90)
		start["ready_idle"] = probe.call("_sampler_phase_result", sampler.call("finish"))
		start["ready_idle_stage_profile"] = _destination.call("runtime_performance_instrumentation_snapshot")
		start["ready_idle_frame_profile"] = _destination.call("runtime_performance_frame_instrumentation_snapshot")
		start["ready_idle_board_profile"] = board.call("render_instrumentation_snapshot")
		start["ready_idle_board_submission"] = board.call("submission_performance_instrumentation_snapshot")
		await probe.call("_save_root_screenshot", "startup_%s_ready.png" % mode)
		if large_inventory:
			_destination.call("_close_dialogue")
			_destination.call("_close_large_map")
			for character_mode: String in ["equipment", "magic"]:
				await probe.call("_settle_render_frames", 3)
				if OS.get_environment("LABYRINTH_PERF_CHARACTER_CACHE_DIAGNOSTIC") == "1":
					start["prepared_character_cache_diagnostic_only_" + character_mode] = _character_cache_diagnostic(character_mode)
				sampler.call("begin")
				var target: Control = _destination.get("loadout_button") if character_mode == "equipment" else _destination.find_child("CharacterMagicTab", true, false)
				_check(is_instance_valid(target) and target.is_visible_in_tree(), "Public Continue must expose its actual Character " + character_mode + " control")
				if not is_instance_valid(target): return {}
				var open_ms: float = probe.call("_routed_left_click", target, target.size * 0.5)
				await probe.call("_settle_render_frames", 30)
				var phase: Dictionary = probe.call("_sampler_phase_result", sampler.call("finish"))
				phase["handler_ms"] = open_ms
				phase["stage_profile"] = _destination.call("runtime_performance_instrumentation_snapshot")
				start["large_inventory_" + character_mode] = phase
				_check(_destination.get("_progression_overlay_mode") == character_mode and bool(_destination.get("_upgrade_scrim").visible), "Public Continue must open its actual saved Character " + character_mode)
				_check(_destination.get("_run_state").get("equipped_equipment") == expected["equipped_equipment"] and _destination.get("_run_state").get("magic_inventory") == expected["magic_inventory"], "Opening must preserve the saved loadout")
				await probe.call("_save_root_screenshot", "startup_continue_large_" + character_mode + ".png")
	return {"schema_version": 1, "workload_id": "cold_process_public_menu_%s_v1" % mode, "saved_surface": saved_surface, "viewport": "1920x1080", "ui_scale": 1.0, "cpu_profile": OS.get_environment("LABYRINTH_PERF_CPU_PROFILE"), "renderer": RenderingServer.get_video_adapter_name(), "sample_boundary": "RenderingServer.frame_post_draw", "menu_boot": menu_boot, "run_start": start, "static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "focus_observations": probe.get("_focus_observation_count"), "unfocused_observations": probe.get("_unfocused_observation_count")}

func _character_cache_diagnostic(mode: String) -> Dictionary:
	var pool: RefCounted = _destination.get("_character_inventory_rows")
	var result: Dictionary = {"available_modes": pool._views.keys()}
	var view: Dictionary = pool._views.get(mode, {})
	if view.is_empty(): return result
	var bindings: Dictionary = {}
	var current: Dictionary = _destination.call("_character_view_job", _destination.get("_upgrade_dialog"), mode, bindings, Callable(_destination, "_character_view_key"))
	var input: Dictionary = view["input"]
	result["key_differences"] = []
	for field: String in current:
		if input.get(field) != current[field]: result["key_differences"].append(field)
	result["profile_differences"] = {}
	var old_profile: Dictionary = input["header"][1]
	var current_profile: Dictionary = current["header"][1]
	for field: String in current_profile:
		if old_profile.get(field) != current_profile[field]: result["profile_differences"][field] = {"prepared": old_profile.get(field), "ready": current_profile[field]}
	result["header_differences"] = []
	for index: int in range(current["header"].size()):
		if input["header"][index] != current["header"][index]: result["header_differences"].append(index)
	result["can_retain"] = _destination.call("_character_view_can_retain", view["node"], mode)
	result["first_transient_rejection"] = _character_transient_rejection(view["node"])
	return result

func _character_transient_rejection(node: Node) -> String:
	if node is Control and not bool(_destination.call("_character_row_can_retain", node)): return str(node.get_path())
	for child: Node in node.get_children():
		var path: String = _character_transient_rejection(child)
		if not path.is_empty(): return path
	return ""

func _phase_changed(phase: StringName) -> void:
	_phase_changes.append({"phase": str(phase), "at_ms": float(Time.get_ticks_usec() - _started_usec) / 1000.0})
	if phase == &"revealing":
		var transition: Node = _probe.root.get_node_or_null("MenuRunTransition")
		var destination: Node = transition.get("destination") if transition != null else null
		_check(destination != null and bool(destination.call("initial_presentation_is_ready")), "Reveal phase must have a ready destination")

func _check(condition: bool, message: String) -> void:
	_probe.call("_expect", condition, message)

# Same current-content large pack used by the remaining-surface workload, now
# loaded through its actual saved public Continue route in a cold process.
func _large_inventory_state(state: Dictionary) -> Dictionary:
	const Data = preload("res://scripts/game_data.gd")
	var result: Dictionary = state.duplicate(true)
	var gear: Array = []
	var equipped: Dictionary = result.get("equipped_equipment", {})
	for id: String in Data.equipment_ids():
		if not equipped.values().has(id) and not Data.equipment_slot(id).is_empty(): gear.append(id)
	gear.sort()
	if gear.size() > 24: gear.resize(24)
	var magic: Array = []
	var attuned: Array = result.get("attuned_magic_cards", [])
	var pools: Dictionary = Data.reward_card_pool_by_rarity("", true)
	for rarity: String in Data.CARD_RARITY_TIERS:
		for id: String in pools.get(rarity, []):
			if not attuned.has(id) and not magic.has(id): magic.append(id)
	magic.sort()
	if magic.size() > 64: magic.resize(64)
	result["equipment_inventory"] = gear
	result["magic_inventory"] = magic
	result["reward_cards"] = magic.duplicate()
	result["item_inventory"] = Data.item_card_ids()
	return result
