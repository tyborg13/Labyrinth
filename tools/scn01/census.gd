extends SceneTree
## Boot the real Continue checkpoint inside the capture viewport. The driver
## supplies the certified files emitted by tools/inspection_fixture.gd.

const StageState = preload("res://tools/scn02/stage_state.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const TITLE_UNLOCKED_DEPTH: int = 1
const InputPath = preload("census_input.gd")
const Geometry = preload("census_geometry.gd")
const SETTLE_MSEC: int = 6000
const STABLE_FRAMES: int = 2
const HEADLESS_FPS: int = 60
const MAX_LAYOUT_DIAGNOSTICS: int = 8

var _viewport: Viewport
var _screen: Control
var _headless: bool
var _capture_tree: Node
var _options: Dictionary
var _result: Dictionary = {"settle_frames": 0, "observed_frames": 0, "capped": false}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_options = _parse_args()
	_headless = DisplayServer.get_name() == "headless"
	if _options.is_empty() or _headless != _options.has("--dry-run"):
		_finish("Expected matching headless/dry-run mode and census arguments.")
		return
	if Runtime.apply_from_environment().is_empty():
		_finish("Census requires a task-local Godot user directory.")
		return
	if OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_finish("Census requires LABYRINTH_CEL_LOOK=all.")
		return
	for pair: Array in [
		["--save", Store.DEFAULT_RUN_STORAGE_PATH],
		["--profile", Store.DEFAULT_STORAGE_PATH],
		["--settings", Settings.DEFAULT_STORAGE_PATH],
	]:
		if DirAccess.copy_absolute(_options[pair[0]], ProjectSettings.globalize_path(pair[1])) != OK:
			_finish("Could not install the inspection fixture's %s." % pair[0])
			return
	var settings: Dictionary = Settings.load_settings()
	settings["ui_scale"] = float(_options.get("--ui-scale", "1.0"))
	if not Settings.save_settings(settings):
		_finish("Could not persist the isolated UI scale setting.")
		return

	var shot: Dictionary = JSON.parse_string(_options["--shot"])
	var from_menu: bool = shot.get("entry") == "menu"
	if from_menu and not _prepare_menu_profile(shot):
		_finish("Could not seed the isolated menu profile.")
		return
	var dimensions: PackedStringArray = str(_options["--size"]).split("x")
	var size := Vector2i(int(dimensions[0]), int(dimensions[1]))
	if _headless:
		Engine.max_fps = HEADLESS_FPS
		# The dummy display does not submit frames on its own. Production
		# continuations still await post-draw for hand hover and enemy playback.
		process_frame.connect(_submit_headless_frame)
	_result["settle_basis"] = "visible_ui_layout"
	if size == Vector2i(1280, 800) or _options.has("--root-window"):
		# Use the shipping Window's stretch calculation and input pipeline.
		# The dummy display uses the same Window code with an explicit size.
		_viewport = root
		root.mode = Window.MODE_WINDOWED
		root.size = size
		root.content_scale_factor = settings["ui_scale"]
		if not _headless:
			await process_frame
		if root.size != size:
			_finish("Window size is %s, expected %s." % [root.size, size])
			return
	else:
		var camera := SubViewport.new()
		camera.name = "CensusViewport"
		camera.gui_embed_subwindows = true
		camera.size = size
		camera.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d")) as Viewport.MSAA
		camera.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(camera)
		_viewport = camera
	_capture_tree = _viewport

	if from_menu:
		var menu: PackedScene = load("res://scenes/main_menu.tscn")
		_screen = menu.instantiate() as Control
		if _viewport != root and shot.get("state") in ["loading", "opening", "first_room"]:
			# The shipping loader sets SceneTree.current_scene, whose parent
			# must be the root Window. Capture still uses the SubViewport.
			root.content_scale_size = size
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
			root.add_child(_screen)
		else:
			_viewport.add_child(_screen)
	else:
		var packed: PackedScene = load("res://scenes/run_scene.tscn")
		_screen = packed.instantiate() as Control
		if not _prepare_checkpoint():
			_screen.free()
			_finish("Could not prepare the isolated checkpoint.")
			return
		# MainMenu sets the same marker before instantiating RunScene. RunScene
		# consumes it and loads, repairs and presents the checkpoint itself.
		root.set_meta("labyrinth_resume_saved_run", true)
		_viewport.add_child(_screen)
		if not _screen.call("has_installed_run"):
			_finish("RunScene did not load the saved checkpoint.")
			return
		var run: Dictionary = _screen.get("_run_state")
		_result["run_seed"] = run.get("seed")
		_result["mode"] = run.get("mode")
		if run.get("mode") != _options["--mode"]:
			_finish("Continue opened %s instead of fixture mode %s." % [run.get("mode"), _options["--mode"]])
			return

	var input := InputPath.new(self, _viewport, _screen, shot)
	var error: String = await input.reach()
	if not error.is_empty():
		_finish(error)
		return

	_screen = input._screen
	_capture_tree = input.capture_tree()
	if input.needs_popup_wait():
		await input.wait_for_tooltip()
	var dialogue: Control
	if _options.has("--rects"):
		var overlay := _screen.find_child("DialogueOverlay", true, false) as Control
		if overlay != null and overlay.is_visible_in_tree() and _screen.get("_dialogue_active"):
			dialogue = overlay
	var image: Image = await _settle(input, dialogue)
	var capture_mode: String = str(shot.get("capture_mode", _options["--mode"] if not from_menu else "room"))
	if _screen.has_method("has_installed_run"):
		var run: Dictionary = _screen.get("_run_state")
		_result["run_seed"] = run.get("seed")
		_result["mode"] = run.get("mode")
	else:
		_result["mode"] = "menu"
	if not input.matches() or (_screen.has_method("has_installed_run") and _result["mode"] != capture_mode):
		_finish("Requested screen state was absent at the capture boundary.")
		return
	if shot.get("scenario") in ["reward", "campfire", "treasure", "scavenger"]:
		_result["stage_state"] = StageState.read(_screen)
	if dialogue != null and not bool(_screen.get("_dialogue_text_complete")):
		_finish("Dialogue text was still revealing at the capture boundary.")
		return
	_result["geometry"] = Geometry.viewport_geometry(_viewport)
	_result["layout_hits"] = Geometry.layout_hits(_viewport, str(shot["shot"]), _capture_tree)
	if _options.has("--rects"):
		_result["control_rects"] = Geometry.control_rects(_viewport, _capture_tree)
		if dialogue != null and dialogue.is_visible_in_tree():
			_result["dialogue_paint_rects"] = Geometry.dialogue_paint_rects(dialogue, _viewport.get_stretch_transform())
	if shot.get("state") == "loading":
		await input.release_loading()
	if _headless:
		_finish("")
		return
	if image == null or image.is_empty() or image.get_size() != size:
		_finish("The capture viewport did not render the requested %s image." % size)
		return
	var path: String = _options["--png"]
	if image.save_png(path) != OK:
		_finish("Could not save %s." % path)
		return
	print(path)
	_finish("")


func _prepare_menu_profile(shot: Dictionary) -> bool:
	root.set_meta(InitialGraph.SEED_OVERRIDE, int(shot["seed"]))
	var profile: Dictionary = Store.load_data()
	if shot.get("state") == "chronicle":
		var chronicle_fixture: Script = load("res://tests/chronicle_probe.gd")
		profile = chronicle_fixture.seeded_profile()
	else:
		profile[Store.UMBRA_DEPTH_UNLOCKED_KEY] = TITLE_UNLOCKED_DEPTH
	return Store.save_data(profile)


func _prepare_checkpoint() -> bool:
	var state: Dictionary = Store.load_saved_run()
	if state.is_empty(): return false
	var changed: bool = false
	var notice: String = str(state.get("notice", ""))
	if notice.begins_with("Inspection fixture:"):
		state["notice"] = ""
		changed = true
	# Normal restore only recovers a terminal run while its profile settlement
	# is pending. Give a bare terminal fixture the identity a live run has.
	if _options["--mode"] in ["victory", "defeat"] and Store.completion_run_id(state).is_empty():
		state = _screen.call("_ensure_run_analytics_metadata", state)
		changed = true
	return not changed or Store.save_run_state(state)


func _submit_headless_frame() -> void:
	RenderingServer.force_draw(false)


func _settle(input: RefCounted, dialogue: Control) -> Image:
	var deadline: int = Time.get_ticks_msec() + SETTLE_MSEC
	var previous: Variant = null
	var image: Image
	while true:
		if _headless:
			await process_frame
		else:
			await RenderingServer.frame_post_draw
		_result["observed_frames"] += 1
		var sample: Variant = null
		var matched: bool = input.matches() and (dialogue == null or bool(_screen.get("_dialogue_text_complete")))
		input.hold_enemy_frame()
		var tweens_running: bool = _has_running_tweens()
		# SceneTree exposes running tweens, but no binding owner. Checking all
		# of them also covers overlays that are siblings of their animated UI.
		# Use the same layout boundary in both modes. Ambient board pixels
		# can change forever after Controls and animation tweens are stable.
		if matched and not tweens_running:
			var scene: Dictionary = {}
			_visible_scene(_capture_tree, scene)
			sample = scene
		_result["settle_frames"] = 0 if sample == null else (STABLE_FRAMES if sample == previous else 1)
		var stable: bool = int(_result["settle_frames"]) >= STABLE_FRAMES
		var expired: bool = Time.get_ticks_msec() >= deadline
		if not _headless and matched and (stable or expired):
			image = _viewport.get_texture().get_image()
		if stable:
			break
		if expired:
			_result["capped"] = true
			if _headless and sample is Dictionary and previous is Dictionary:
				var changed := PackedStringArray()
				for path: NodePath in sample:
					if sample[path] != previous.get(path): changed.append(str(path))
				print("Unstable layout (%d nodes): %s" % [changed.size(), ", ".join(changed.slice(0, MAX_LAYOUT_DIAGNOSTICS))])
			break
		previous = sample
	return image


func _has_running_tweens() -> bool:
	for tween: Tween in get_processed_tweens():
		if tween.is_running():
			return true
	return false


func _visible_scene(node: Node, snapshot: Dictionary) -> void:
	# The dummy renderer cannot supply pixels. Compare the visible controls'
	# layout and content. Game-world ambient sprites continue to animate.
	if node.name in [&"RelicChoiceSparkle", &"DialogueContinueDiamond"]:
		return # Continuous cosmetic motion, independent of control layout.
	if (node is CanvasItem and not node.is_visible_in_tree()) or (node is Window and not node.visible):
		return
	if node is Control:
		var state: Array = [node.get_global_transform_with_canvas(), node.size]
		if node is Label or node is RichTextLabel or node is Button:
			state.append(node.text)
		if node is Label or node is RichTextLabel:
			state.append(node.visible_characters)
		if node is BaseButton:
			state.append([node.button_pressed, node.disabled])
		snapshot[node.get_path()] = state
	for child: Node in node.get_children():
		_visible_scene(child, snapshot)


func _parse_args() -> Dictionary:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var parsed: Dictionary = {}
	var index: int = 0
	while index < args.size():
		var flag: String = args[index]
		index += 1
		if flag in ["--dry-run", "--root-window", "--rects"]:
			parsed[flag] = true
		elif index < args.size() and flag in ["--save", "--profile", "--settings", "--mode", "--size", "--png", "--shot", "--ui-scale"]:
			parsed[flag] = args[index]
			index += 1
		else:
			return {}
	for flag: String in ["--save", "--profile", "--settings", "--mode", "--png", "--shot"]:
		if not parsed.has(flag):
			return {}
	if parsed.get("--size") not in ["1920x1080", "1280x800"] or not JSON.parse_string(parsed["--shot"]) is Dictionary:
		return {}
	if parsed.get("--ui-scale", "1.0") not in ["1.0", "1.15"]:
		return {}
	return parsed


func _finish(error: String) -> void:
	_result["ok"] = error.is_empty()
	_result["error"] = error
	print("CENSUS_RESULT %s" % JSON.stringify(_result))
	# The title can still be warming RunScene after layout has settled.
	# Collect its production threaded request before the engine stops.
	while not SceneLoads.drain_for_shutdown(self):
		await process_frame
	quit(0 if error.is_empty() else 1)
