extends SceneTree

const Hud = preload("res://tests/suites/turn_clock_hud_suite.gd")
const Scene = preload("res://scenes/run_scene.tscn")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Data = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/mrg-11f"
const ENEMY_TYPE: String = "hoarfrost_seer"
const INTENT: String = "rime_bolt"
const ENEMY_OFFSETS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const INSPECTED_ENEMY: String = "enemy_2"
const SETTLE_FRAMES: int = 12

var _failures: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Store.set_storage_path("user://mrg-11f-preview-profile.json")
	Store.set_run_storage_path("user://mrg-11f-preview-run.save")
	Settings.set_storage_path("user://mrg-11f-preview-settings.json")
	var preferences: Dictionary = Settings.default_settings()
	preferences["ui_scale"] = 1.0
	preferences["reduced_motion"] = true
	Settings.save_settings(preferences)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node = Scene.instantiate()
	viewport.add_child(scene)
	await process_frame
	var engine: RefCounted = scene._combat_engine
	var state: Dictionary = _fixture(engine)
	await Hud._install(self, scene, state)
	var summary: Dictionary = scene._pass_preview_summary()
	var delay: int = int(summary.get("status_gains", {}).get("stagger", 0))
	_expect(delay == Keywords.STAGGER_TURN_CAP, "Pass displays the capped Stagger gain")
	scene._refresh_stage_view()
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	_expect(chip != null and not chip.disabled, "The production Pass chip is enabled")
	if chip != null:
		chip.mouse_entered.emit()
		var forecast_rows: Array = chip.get_meta("forecast_rows", [])
		var stagger_rows: Array = forecast_rows.filter(func(row: Dictionary) -> bool: return row.get("status_gain") == "stagger")
		_expect(stagger_rows.size() == 1 and stagger_rows[0]["parts"][0]["text"] == "+%d" % delay, "The Pass tooltip renders one capped Stagger row")
		await _capture(viewport, "pass_stagger")
		chip.mouse_exited.emit()

	var board: Control = scene.board_view
	var badges: Array = board.presentation.get("threats_at_rest", {}).get("badges", [])
	var inspected: Array = badges.filter(func(badge: Dictionary) -> bool: return badge.get("key") == INSPECTED_ENEMY)
	_expect(not inspected.is_empty() and inspected[0].get("secondary_icon") == "stagger" and inspected[0].get("secondary_number") == "0", "The second enemy's intent chip reports no further Stagger")
	var unit: Dictionary = scene._combat_state["enemies"][1]
	var rows: Array = board._move_rows_for_unit(unit, unit["intent"])
	var found: bool = false
	for row: Array in rows:
		for token: Dictionary in row:
			if token.get("icon") == "stagger" and token.get("value") == 0: found = true
	_expect(found, "The expanded intent reports no further Stagger")
	scene._on_turn_order_enemy_hovered(unit["pos"], INSPECTED_ENEMY)
	await _capture(viewport, "intent_stagger")
	scene._on_turn_order_enemy_unhovered(unit["pos"], INSPECTED_ENEMY)

	var scheduled: Dictionary = Committed.finish_player_activation(engine, scene._combat_state)
	var first: Dictionary = Committed.advance_one_activation(engine, scheduled, false)["state"]
	var rail: Array = engine.current_turn_order(first)
	var hero: Array = rail.filter(func(entry: Dictionary) -> bool: return entry.get("kind") == "player")
	_expect(not hero.is_empty() and scene._turn_order_tooltip(hero[0], 0).contains("Stagger +%d" % Keywords.STAGGER_TURN_CAP), "The queued hero's rail tooltip reports the capped delay")
	viewport.queue_free()
	for frame: int in range(SETTLE_FRAMES): await process_frame
	print("HERO STAGGER PREVIEW: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)

func _fixture(engine: RefCounted) -> Dictionary:
	var state: Dictionary = Hud.fixture(engine)
	var intent: Dictionary = engine._intent_by_id(Data.enemy_def(ENEMY_TYPE)["intents"], INTENT)
	var tile: Vector2i = state["player"]["pos"]
	for index: int in range(ENEMY_OFFSETS.size()):
		var enemy: Dictionary = state["enemies"][index]
		enemy["type"] = ENEMY_TYPE
		enemy["pos"] = tile + ENEMY_OFFSETS[index]
		enemy["intent"] = intent.duplicate(true)
		state["turn_queue"][index] = engine._enemy_actor_entry(state, enemy, index + 1, index + 1)
	Surfaces.place(state, tile, "ice")
	return state

func _capture(viewport: SubViewport, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(SETTLE_FRAMES): await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join(name + ".png")
	var capture: Image = viewport.get_texture().get_image()
	_expect(capture.get_size() == SIZE and capture.save_png(path) == OK, "Capture saved at 1920x1080")
	print(path)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	_failures += 1
	push_error(message)
