extends "res://tests/lethal_preview_probe.gd"

const Cases = preload("res://tests/suites/destruction_preview_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")

const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_OUTPUT: String = "user://probes/ux_05_destruction_preview/1920x1080_ui100"
const SETTLE_FRAMES: int = 5

var logic_only: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	logic_only = OS.get_cmdline_user_args().has("--logic-only")
	ProgressionStore.set_storage_path("user://ux05_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://ux05_probe_run.save")
	SettingsStore.set_storage_path("user://ux05_probe_settings.json")
	ProgressionStore.clear_saved_run()
	root.size = PROOF_SIZE
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_OUTPUT))
	var viewport := SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	for stage: String in ["clear", "heart"]:
		for case: String in ["crate_confirmation", "trap_trigger", "illusion_consumed", "lethal_pull", "two_actions", "consumed_fire"]:
			var instance: Node = packed.instantiate()
			viewport.add_child(instance)
			await _settle()
			instance.set("_settings", settings.duplicate(true))
			var state: Dictionary = Cases.pull_fixture() if case == "lethal_pull" else Cases.fixture()
			state["umbra"]["stage"] = stage
			var card_id: String = "vacuum_line" if case == "lethal_pull" else "shattered_reflection" if case == "illusion_consumed" else "whirlwind_slash"
			if case == "consumed_fire":
				state["terrain"] = []
				state["traps"] = []
				Ground.place(state, Cases.SURFACE_TILE, "fire")
			state["deck"]["hand"] = [card_id, "brace"]
			state["deck"]["draw"] = []
			state["current_actor"] = {"kind": "player", "key": "player"}
			instance.call("_reset_card_resolution")
			var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
			run["mode"] = "combat"
			run["combat_state"] = state
			run["current_room_layout"] = state
			instance.set("_run_state", run)
			instance.set("_combat_state", state)
			instance.set("_animation_lock", false)
			instance.call("_mark_combat_preview_state_changed")
			instance.call("_refresh_ui")
			await _settle()
			var committed: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
			if case in ["two_actions", "consumed_fire"]:
				# Test-only action lists exercise a pending second choice and consumed
				# ground without changing production cards or their authored text.
				var actions: Array = Data.card_def(card_id)["actions"].duplicate(true)
				if case == "two_actions": actions.append(Cases.FOLLOWUP_ACTION)
				else: actions = [Cases.DETONATE_ACTION]
				var preview: Dictionary = instance.call("_card_preview_from_state", card_id, state, actions, 0)
				await instance.call("_begin_card_preview", 0, preview)
				if case == "consumed_fire": instance.call("_on_board_tile_hovered", Cases.SURFACE_TILE)
				if case == "two_actions": instance.call("_on_board_tile_hovered", Cases.FOLLOWUP_TARGET)
			else:
				await instance.call("_on_card_pressed", 0)
				if case == "illusion_consumed": instance.call("_on_board_tile_hovered", Cases.ILLUSION_TILE)
				if case == "lethal_pull": instance.call("_on_board_tile_hovered", Cases.PULL_START)
			await _settle()
			_hide_log(instance)
			await _set_lethal_marker_frame(instance, false, CombatBoardView.LETHAL_DEATH_MARK_PULSE_SECONDS * 0.25)
			var board: Control = instance.get("board_view")
			_expect(instance.get("_combat_state") == committed, case + " must leave live combat unchanged")
			_assert_case(instance, board, case)
			if not logic_only: await _save_screenshot(viewport, PROOF_OUTPUT.path_join(stage + "_" + case + ".png"), PROOF_SIZE)
			instance.queue_free()
			await process_frame
	viewport.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(PROOF_OUTPUT))
	for failure: String in _failures: push_error(failure)
	print("DESTRUCTION PREVIEW PROBE: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _assert_case(instance: Node, board: Control, case: String) -> void:
	var losses: Dictionary = board.call("_damage_preview_map")
	var shown: Dictionary = board.get("combat_state")
	var presentation: Dictionary = board.get("presentation")
	match case:
		"crate_confirmation", "two_actions":
			_expect(Ground.terrain_is_live(shown["terrain"][0]), case + " keeps the crate drawn")
			_expect(bool((losses.get("terrain_ux05_crate", {}) as Dictionary).get("lethal", false)), case + " marks the crate lethal")
			_expect(int(board.call("_health_bar_fill_hp", shown["terrain"][0], losses.get("terrain_ux05_crate", {}))) == 0, case + " empties the crate HP bar")
			if case == "two_actions":
				_expect(int(instance.get("_pending_action_index")) == 1, "Two-action capture stops before the second choice")
			else: _expect(bool(instance.call("_pending_card_requires_confirmation")), "Crate capture is a targetless confirmation")
		"trap_trigger":
			_expect((shown.get("traps", []) as Array).size() == 1, "Trap remains drawn")
			_expect((presentation.get("trap_trigger_previews", []) as Array).size() == 1, "Trap keeps the existing trigger highlight")
			_expect(bool((losses.get("trap_ux05_trap", {}) as Dictionary).get("lethal", false)), "Consumed trap receives a death mark")
		"illusion_consumed":
			var marked: bool = false
			for unit: Dictionary in board.call("_build_visible_units"):
				if unit.get("key") == "illusion_1": marked = bool(board.call("_unit_is_preview_lethal", unit)) and int(board.call("_health_bar_fill_hp", unit, losses.get("illusion_1", {}))) == 0
			_expect(marked, "Illusion body, empty HP bar, and death mark remain visible")
		"lethal_pull":
			var marked: int = 0
			for unit: Dictionary in board.call("_build_visible_units"):
				if bool(board.call("_unit_is_preview_lethal", unit)): marked += 1
			_expect(marked == 2, "Lethal pull marks both original and destination ghost")
		"consumed_fire":
			_expect(Ground.has_surface(shown, Cases.SURFACE_TILE, "fire"), "Consumed fuel remains drawn")
			_expect(not (presentation.get("focus_tiles", []) as Array).is_empty(), "Detonation blast uses existing AoE overlay")

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await process_frame
	if not logic_only:
		RenderingServer.force_draw(true)
		await process_frame
