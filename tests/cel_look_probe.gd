extends SceneTree

## Load a verified fixture copy into the production scene. --measure is the
## headless timing path; the native path captures exactly 1920x1080 at 100%.
const Assets = preload("res://scripts/asset_loader.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Cel = preload("res://scripts/cel_look.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_UI_SCALE: float = 1.0
const PROOF_SETTLE_SECONDS: float = 0.5
const PROOF_PROP_KINDS := ["campfire_bonfire", "relic_chest"]
var started: int

func _initialize() -> void:
	started = Time.get_ticks_usec()
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _arg(flag: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(flag)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _run() -> void:
	var measure: bool = OS.get_cmdline_user_args().has("--measure")
	if DisplayServer.get_name() == "headless" and not measure:
		push_error("CEL_PROOF requires tools/visual_probe_runner.py --no-headless")
		quit(1)
		return
	var save_path: String = _arg("--save-path")
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		push_error("CEL_PROOF requires --save-path from INSPECTION_FIXTURE_RESULT")
		quit(1)
		return
	Store.set_run_storage_path(save_path)
	var state: Dictionary = Store.load_saved_run()
	# Do not let the scene write back to the owner's certified fixture.
	Store.set_run_storage_path("user://cel_proof_run.save")
	Store.set_storage_path("user://cel_proof_profile.json")
	Settings.set_storage_path("user://cel_proof_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_UI_SCALE
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	# Render into a fixed 1920x1080 viewport like the other native probes; the OS may not grant the window that size.
	var canvas := SubViewport.new()
	canvas.size = PROOF_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var load_started: int = Time.get_ticks_usec()
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	scene.call("_load_run_state", state)
	await process_frame
	var board: Control = scene.get("board_view")
	var manifest: Dictionary = board.call("_initial_texture_manifest")
	await Assets.prepare_textures_for(scene, manifest, func() -> void: await process_frame)
	print("CEL_FIXTURE_TIMING " + JSON.stringify({"mode": Cel.mode, "startup_ms": load_started / 1000.0, "proof_bootstrap_ms": (load_started - started) / 1000.0,
		"scene_and_load_ms": (Time.get_ticks_usec() - load_started) / 1000.0, "texture_paths": manifest.size()}))
	if OS.get_cmdline_user_args().has("--props"):
		_install_proof_props(board)
	var view: String = _arg("--view")
	if view.is_empty(): view = "board"
	if not await _prepare_view(scene, view):
		quit(1)
		return
	if not measure:
		await create_timer(PROOF_SETTLE_SECONDS).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		var output: String = _arg("--output")
		if output.is_empty(): output = "user://probes/cel_look/" + Cel.mode + ".png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
		var image: Image = canvas.get_texture().get_image()
		if image.get_size() != PROOF_SIZE or image.save_png(output) != OK:
			push_error("CEL_PROOF capture size/write failed")
			quit(1)
			return
		print("CEL_PROOF_CAPTURE " + ProjectSettings.globalize_path(output))
		print(ProjectSettings.globalize_path(output))
	print("CEL_FIXTURE_LOADED " + Cel.mode)
	scene.queue_free()
	await process_frame
	quit(0)

func _prepare_view(scene: Node, view: String) -> bool:
	# Exercise the production UI; a wrong fixture fails instead of yielding a
	# plausible capture of a different screen. Also runs in --measure mode.
	if view != "dialogue" and bool(scene.get("_dialogue_active")):
		scene.call("_close_dialogue")
	if view == "equipment":
		scene.call("_open_character_overlay", "equipment")
	elif view == "dialogue":
		scene.call("_maybe_auto_trigger_room_dialogue")
		if not bool(scene.get("_dialogue_active")):
			# The start-room boon can suppress automatic narration. Stage that
			# room's authored NPC dialogue through the same production factory.
			var state: Dictionary = scene.get("_run_state")
			var engine: RefCounted = scene.get("_run_engine")
			var room: Dictionary = engine.call("room_metadata", state, state.get("current_room", Vector2i.ZERO))
			var dialogue: Dictionary = (scene.get("_dialogue_engine") as RefCounted).call("build_room_dialogue", room, state, scene.get("_progression"))
			scene.call("_start_dialogue", dialogue)
		if bool(scene.get("_dialogue_active")):
			scene.call("_complete_current_dialogue_line")
	await process_frame
	var valid: bool = false
	match view:
		"board": valid = (scene.get("board_view") as Control).is_visible_in_tree()
		"fight":
			var strip: Control = scene.get("_turn_order_panel")
			valid = str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat" and strip != null and strip.is_visible_in_tree()
		"pre_battle":
			var panel: Control = scene.get("_pre_battle_panel")
			valid = panel != null and panel.is_visible_in_tree()
		"equipment":
			var scrim: Control = scene.get("_upgrade_scrim")
			valid = scrim != null and scrim.is_visible_in_tree() and str(scene.get("_progression_overlay_mode")) == "equipment"
		"dialogue":
			var portrait: TextureRect = scene.get("_dialogue_portrait")
			valid = bool(scene.get("_dialogue_active")) and portrait != null and portrait.is_visible_in_tree() and portrait.texture is AtlasTexture
	if not valid:
		push_error("CEL_CAPTURE_VIEW invalid fixture/view: " + view)
		return false
	print("CEL_CAPTURE_VIEW %s mode=%s verified" % [view, Cel.mode])
	return true

func _install_proof_props(board: Control) -> void:
	# Debug-only staging on unoccupied floor. Never persisted or used by play.
	var state: Dictionary = board.get("combat_state")
	var occupied: Dictionary = {}
	occupied[state.get("player", {}).get("pos", Vector2i(-1, -1))] = true
	for collection: String in ["enemies", "terrain", "traps"]:
		for entry: Dictionary in state.get(collection, []): occupied[entry.get("pos")] = true
	var props: Array = []
	var grid: Array = state.get("grid", [])
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, grid[y].size() - 1):
			var tile := Vector2i(x, y)
			if occupied.has(tile) or str(grid[y][x]) not in ["stone", "ember"]: continue
			props.append({"kind": PROOF_PROP_KINDS[props.size()], "tile": tile})
			if props.size() == PROOF_PROP_KINDS.size(): break
		if props.size() == PROOF_PROP_KINDS.size(): break
	assert(props.size() == PROOF_PROP_KINDS.size(), "Proof has clear floor for campfire and chest")
	var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	presentation["scene_props"] = props
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
