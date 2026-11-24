extends SceneTree

const Baker = preload("res://scripts/protagonist_cutout/gear_rest_baker.gd")
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const GameData = preload("res://scripts/game_data.gd")
const Progression = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const FRAME_SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const SETTLE_FRAMES: int = 8
const PROOF_EQUIPMENT := {"weapon": "war_maul", "offhand": "ward_kite"}
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	if ParallelRuntime.current_namespace().is_empty() or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		push_error("Use tools/gfix55/native.sh to run the isolated cel-look proof.")
		quit(1)
		return
	var headless: bool = DisplayServer.get_name() == "headless"
	var baseline: bool = OS.get_environment("GFIX55_BASELINE") == "1"
	var output: String = OS.get_environment("GFIX55_OUTPUT")
	var signature: String = _save_fixture()
	_check(Baker.cached(signature) == null, "Fixture starts without a cached gear rest texture")

	var surface := SubViewport.new()
	surface.size = FRAME_SIZE
	surface.world_2d = World2D.new()
	surface.disable_3d = true
	surface.msaa_2d = root.msaa_2d
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	surface.add_child(scene)
	root.set_meta("labyrinth_resume_saved_run", true)
	# Enter the saved fight synchronously while root is adding this subtree.
	root.add_child(surface)
	var board: Control = scene.get("board_view")
	var renderer: Node = board.get("_protagonist_renderer")
	_check(scene.call("has_installed_run") and not (board.get("combat_state") as Dictionary).is_empty(), "RunScene._ready installs the saved fight")
	_check(is_equal_approx(float(scene.get("_settings")["ui_scale"]), UI_SCALE), "Run scene applies 100% UI scale")
	_check(renderer.call("snapshot")["gear"] == signature and renderer.call("offhand_kind") == "shield", "Live rig has the saved maul and shield")
	var fallback: Texture2D = Baker.cached(Gear.signature({}))
	_check(renderer.call("rest_texture") == fallback, "Board starts with the static rest fallback")
	_check(Baker._jobs.has(signature) == (not headless), "Native boot requests the uncached signature in _ready")
	if not headless and Baker._jobs.has(signature):
		var boot_job: Node = Baker._jobs[signature]
		_check(not boot_job.is_inside_tree(), "The busy root has not attached the job during _ready")
		_check(Baker.request(self, signature, PROOF_EQUIPMENT) == boot_job, "A second caller shares the pending boot bake")

	for frame: int in range(SETTLE_FRAMES):
		await process_frame
		if not headless: await RenderingServer.frame_post_draw

	var rest: Texture2D = renderer.call("rest_texture")
	var readbacks: int = Baker._readbacks.get(signature, 0)
	var pending: Variant = Baker._jobs.get(signature)
	if headless:
		_check(rest == fallback and not Baker._jobs.has(signature) and readbacks == 0, "Dummy renderer keeps the static fallback and skips the bake")
	elif baseline:
		_check(rest == fallback and readbacks == 0, "Release keeps the static fallback after the bake should have completed")
		_check(is_instance_valid(pending) and not pending.is_inside_tree(), "Release retains the unattached job")
		_check(Baker.request(self, signature, PROOF_EQUIPMENT) == pending, "Release returns the same dead job on a later request")
	else:
		_check(rest != fallback and readbacks == 1 and Baker.cached(signature) == rest, "Boot produced exactly one cached gear rest texture")
		_check(rest != null and rest.has_meta("gear_rest_image") and not Baker._jobs.has(signature), "Boot released the completed bake job")
		var baked_image: Image = rest.get_meta("gear_rest_image", null) if rest != null and rest.has_meta("gear_rest_image") else null
		_check(baked_image != null and baked_image.get_used_rect().has_area(), "Baked rest contains visible pixels")
	_check(board.get("_unit_textures").get("player") == rest, "Board uses the renderer's rest texture as its static source")
	var draws_live_rig: bool = false
	for unit: Dictionary in board.call("_visible_units"):
		if unit["key"] == "player":
			draws_live_rig = board.call("_texture_for_unit", unit) == renderer.call("texture")
			break
	_check(draws_live_rig, "Board draws the live geared rig")
	if not headless:
		var image: Image = surface.get_texture().get_image()
		var png: String = output.path_join("board.png")
		_check(image != null and image.get_size() == FRAME_SIZE and image.save_png(png) == OK, "Save the exact 1920x1080 board capture")
		print(png)

	print("GFIX55 BOOT PATH: %s, 1920x1080, UI 100%%, gear %s, readbacks %d, pending %s" % [
		"headless" if headless else "release" if baseline else "fixed", signature, readbacks, Baker._jobs.has(signature)])
	surface.queue_free()
	await process_frame
	for failure: String in _failures: push_error(failure)
	print("GFIX55 %s: %s" % ["DRY RUN" if headless else "NATIVE PROOF", "PASS" if _failures.is_empty() else "FAIL"])
	quit(0 if _failures.is_empty() else 1)

func _save_fixture() -> String:
	Settings.set_storage_path("user://gfix55-settings.json")
	Progression.set_storage_path("user://gfix55-profile.json")
	Progression.set_run_storage_path("user://gfix55-run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = UI_SCALE
	_check(Settings.save_settings(settings), "Save isolated proof settings")
	var profile: Dictionary = Tutorial.dismiss_tutorial(Progression.default_data())
	for prompt: String in Tutorial.prompt_ids():
		profile = Tutorial.resolve_progression(profile, prompt)
	_check(Progression.save_data(profile), "Save isolated proof profile")
	var run: Dictionary = RunEngine.new().create_debug_boss_run(profile)
	run["debug_boss_run"] = false
	var equipped: Dictionary = run["equipped_equipment"]
	equipped.merge(PROOF_EQUIPMENT, true)
	run["collected_equipment"] = equipped.values()
	run["deck_cards"] = GameData.compile_deck_cards(equipped, run["attuned_magic_cards"], run["equipped_items"])
	_check(Progression.save_run_state(run), "Save the geared combat checkpoint")
	return Gear.signature(equipped)

func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
