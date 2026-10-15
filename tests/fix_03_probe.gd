extends SceneTree

const Suite = preload("res://tests/suites/fix_03_suite.gd")
const TokenCanvas = preload("res://tests/helpers/fix_03_token_canvas.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const OUTPUT: String = "user://fix_03_probe"
const SIZE := Vector2i(1920, 1080)
const PROOF_SEED: int = 20261015
const PROOF_LEVEL: int = 4
const SETTLE_FRAMES: int = 3
const ICON_PIXEL_RANGE: float = 0.1
var _failed: bool = false
var _check_only: bool = false
var _viewport: SubViewport

func _initialize() -> void:
	Parallel.apply_from_environment()
	_check_only = OS.get_cmdline_user_args().has("--check-only")
	if DisplayServer.get_name() == "headless" and not _check_only:
		push_error("FIX-03 PROBE requires a real renderer; use --check-only for headless contract validation")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://fix_03_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://fix_03_profile.json")
	Store.set_run_storage_path("user://fix_03_run.save")
	var profile: Dictionary = Store.default_data()
	profile["level"] = PROOF_LEVEL
	profile["skill_ids"] = ["long_dawn", "sunpath", "dawnbrand"]
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(profile)
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene: Control = RUN_SCENE.instantiate()
	_viewport.add_child(scene)
	await _settle()
	var states: Array[Dictionary] = Suite.skill_states()
	for index: int in range(states.size()):
		var combat: Dictionary = states[index]
		var run: Dictionary = Run.new().create_new_run(PROOF_SEED, profile)
		run["mode"] = "combat"
		run["combat_state"] = combat
		run["current_room"] = Vector2i(1, 0)
		run["current_room_layout"] = Suite.SkillFixture._room()
		scene._progression = run["progression"]
		scene._load_run_state(run)
		scene._close_dialogue()
		await _settle()
		_expect(is_equal_approx(Typography.ui_scale(scene), 1.0), "UI scale is 100%")
		if not scene._skill_status_popover.visible:
			scene._toggle_skill_status_popover()
		await _settle()
		var status: String = "SPENT" if index == 1 else "WAITING"
		for skill: String in ["sunpath", "dawnbrand"]:
			var tile: Button = scene._skill_status_tiles.get(skill) as Button
			_expect(tile != null and tile.is_visible_in_tree() and tile.get_meta("skill_status") == status, "%s displays %s (owned=%s, tile=%s)" % [skill, status, scene._selected_skill_ids_for_hud(), str(tile)])
			if index == 1 and tile != null:
				tile.grab_focus()
				await _settle()
				_expect(tile.has_focus(), skill + " retains keyboard/controller focus")
				_expect(scene._skill_status_detail_status.text == "SPENT", skill + " detail visibly reads SPENT")
				await _capture("02_spent_sunpath_focus" if skill == "sunpath" else "03_spent_dawnbrand_focus")
		if index != 1:
			await _capture("01_waiting" if index == 0 else "04_next_turn_waiting")
	scene.queue_free()
	await process_frame
	var canvas := TokenCanvas.new()
	canvas.size = Vector2(SIZE)
	_viewport.add_child(canvas)
	await _settle()
	if not _check_only:
		await RenderingServer.frame_post_draw
		for entry: Dictionary in Suite.token_cases():
			var found: bool = false
			for drawn: Dictionary in canvas.drawn_icons:
				if drawn["case"] == entry["name"] and drawn["icon"] == entry["icon"]:
					found = true
					_expect(drawn["loaded"], entry["name"] + " draws its loaded icon")
					_assert_icon_pixels(_viewport.get_texture().get_image(), drawn["rect"], entry["name"])
			_expect(found, entry["name"] + " reaches the production icon draw path")
	await _capture("05_all_fixed_tokens")
	canvas.queue_free()
	_viewport.queue_free()
	await process_frame
	print("FIX-03 PROBE %s: %s (5 states, 1920x1080, UI scale 100%%)" % ["CONTRACT" if _check_only else "RENDER", "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame

func _capture(label: String) -> void:
	if _check_only:
		return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == SIZE, label + " has native dimensions")
	if image == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = "%s/%s.png" % [OUTPUT, label]
	_expect(image.save_png(path) == OK, label + " saves")
	print("FIX-03 CAPTURE: " + ProjectSettings.globalize_path(path))

func _assert_icon_pixels(image: Image, rect: Rect2, label: String) -> void:
	var low: float = 1.0
	var high: float = 0.0
	var pixels := Rect2i(rect)
	for y: int in range(pixels.position.y, pixels.end.y):
		for x: int in range(pixels.position.x, pixels.end.x):
			var value: float = image.get_pixel(x, y).get_luminance()
			low = minf(low, value)
			high = maxf(high, value)
	_expect(high - low > ICON_PIXEL_RANGE, label + " has visible icon pixels")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
