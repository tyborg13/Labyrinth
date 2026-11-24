extends SceneTree

const Fixture = preload("res://tools/gfix49/roost_fixture.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const RulesView = preload("res://scripts/battlefield_rule_view.gd")

const CAPTURE_SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const LOAD_SETTLE_SECONDS: float = 0.28
const OUTPUT_DIR: String = "user://probes/gfix49"

var _canvas: SubViewport
var _scene: Node
var _dry_run: bool
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_dry_run = OS.get_cmdline_user_args().has("--dry-run")
	if not _dry_run and DisplayServer.get_name() == "headless":
		printerr("GFIX-49 native capture requires a window. Use --dry-run for the headless scene check.")
		quit(1)
		return
	root.size = CAPTURE_SIZE
	root.content_scale_size = CAPTURE_SIZE
	Settings.set_storage_path("user://gfix49_probe_settings.json")
	Progression.set_storage_path("user://gfix49_probe_profile.json")
	Progression.set_run_storage_path("user://gfix49_probe_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_canvas = SubViewport.new()
	_canvas.size = CAPTURE_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	var display := TextureRect.new()
	display.texture = _canvas.get_texture()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_canvas.add_child(_scene)
	await process_frame
	var run: Dictionary = Fixture.build(Run.new(), Combat.new())
	_scene.call("_load_run_state", run)
	await process_frame
	await process_frame
	if bool(_scene.get("_dialogue_active")): _scene.call("_close_dialogue")
	await create_timer(LOAD_SETTLE_SECONDS).timeout
	var opening: Dictionary = _scene.get("_combat_state")
	var west: Vector2i = opening["player"]["pos"]
	var east: Vector2i = Fixture.east(opening)
	_check_view(west, Vector2i.RIGHT)
	await _capture("01_gust_before_step.png")
	# Both clicks use the live board input path and commit ordinary movement.
	await _scene.call("_on_board_tile_clicked", west)
	await _scene.call("_on_board_tile_clicked", east)
	await process_frame
	_check_view(east, Vector2i.LEFT)
	await _capture("02_gust_after_step.png")
	_scene.queue_free()
	await process_frame
	for failure: String in _failures: printerr("GFIX-49 FAIL: ", failure)
	print("GFIX-49 NATIVE %s: %s (%d failures)" % ["DRY RUN" if _dry_run else "CAPTURE", "PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _check_view(hero: Vector2i, axis: Vector2i) -> void:
	var board: Control = _scene.get("board_view")
	var hud: Control = _scene.get("_battlefield_rule_hud")
	var arrow: Control = hud.get("_arrow")
	var actual: Vector2i = board.combat_state["player"]["pos"]
	var wind: Dictionary = WindView.forecast(board)
	var forecast: Dictionary = RulesView.BattlefieldRules.forecast(RulesView._engine(), board.combat_state)
	var threats: Array = board.presentation.get("threats_at_rest", {}).get("threats", [])
	_check(actual == hero, "board submitted the committed hero tile %s" % hero)
	_check(wind.get("wind", {}).get("direction") == axis and forecast.get("direction") == axis, "board and shared forecast face %s" % axis)
	_check(arrow.visible and arrow.get("heading") == WindView.screen_direction(axis), "battlefield HUD arrow faces %s" % axis)
	_check(wind.get("displacement_paths", []).any(func(path: Array) -> bool: return path == [hero, hero + axis]), "board telegraphs the hero's one-tile landing")
	_check(threats.any(func(threat: Dictionary) -> bool: return threat.get("key") == RulesView.THREAT_KEY and threat["tiles"].has(hero)), "board draws the Gust threat tile")
	print("GFIX-49 NATIVE STATE hero=%s wind=%s arrow=%s" % [actual, wind.get("wind", {}).get("direction"), arrow.get("heading")])

func _capture(filename: String) -> void:
	if _dry_run: return
	await RenderingServer.frame_post_draw
	var image: Image = _canvas.get_texture().get_image()
	var path: String = OUTPUT_DIR.path_join(filename)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if image == null or image.get_size() != CAPTURE_SIZE or image.save_png(path) != OK:
		_failures.append("capture failed for " + filename)
		return
	print(ProjectSettings.globalize_path(path))

func _check(condition: bool, failure: String) -> void:
	if not condition: _failures.append(failure)
