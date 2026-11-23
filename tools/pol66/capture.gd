extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const LinkSamples = preload("link_samples.gd")
const FocusInputs = preload("focus_inputs.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

const FOCUS_IDS := ["quick_wits", "living_shadow", "open_sky"]
const MIXED_STATE_OWNED_IDS := ["quick_wits", "rehearsed_escape"]
const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SETTLE_SECONDS: float = 0.08

var _headless: bool
var _before: bool
var _output_dir: String
var _failures: int
var _checks: int

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or args[0] not in ["before", "after"] or Runtime.apply_from_environment().is_empty():
		printerr("Usage: capture.gd -- before|after OUTPUT_DIR FIXTURE_DIR (task-local HOME required)")
		quit(1)
		return
	_before = args[0] == "before"
	_headless = DisplayServer.get_name() == "headless"
	_output_dir = args[1]
	if _headless:
		# RunScene awaits post-draw for some continuations even with the dummy display.
		process_frame.connect(_submit_headless_frame)
	for dimensions: Vector2i in SIZES:
		await _capture_size(dimensions, args[2])
	print("POL66 %s %s: %s (%d checks, %d failures)" % [
		args[0], "HEADLESS" if _headless else "RENDERER",
		"PASS" if _failures == 0 else "FAIL", _checks, _failures,
	])
	quit(int(_failures > 0))

func _capture_size(dimensions: Vector2i, fixture_dir: String) -> void:
	if not _install_fixture(fixture_dir):
		return
	var size_label: String = "%dx%d" % [dimensions.x, dimensions.y]
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d")) as Viewport.MSAA
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen := RUN_SCENE.instantiate()
	root.set_meta("labyrinth_resume_saved_run", true)
	viewport.add_child(screen)
	_expect(screen.call("has_installed_run") and (screen.get("_run_state") as Dictionary).get("mode") == "combat",
		"The census combat fixture restored through Continue")
	await _settle()
	screen.call("_open_character_overlay", "skills")
	await _settle()
	var tree := screen.get("_skill_tree_view") as SkillTreeView
	_expect(is_instance_valid(tree) and tree.is_visible_in_tree(), "Character Skills is visible at %s" % size_label)
	if is_instance_valid(tree):
		_expect(tree.node_count() == SkillTreeLibrary.visible_ids().size(), "Every skill is visible at %s" % size_label)
		_expect(tree.owned_skill_ids().is_empty(), "The capture uses the unlearned census tree")
		var baseline_geometry: String = _geometry_signature(tree)
		print("POL66 GEOMETRY %s: %d routes, %d nodes, %d bridges, %s" % [
			size_label, tree.connection_count(), tree.node_count(), tree.bridged_connection_pairs().size(), baseline_geometry,
		])
		var samples := LinkSamples.new(_expect, _before)
		for focus: String in FOCUS_IDS:
			tree.focus_skill(focus)
			await _settle()
			_expect(tree.focused_skill_id() == focus, "%s focus is visible at %s" % [focus, size_label])
			_expect(_geometry_signature(tree) == baseline_geometry, "%s preserves geometry at %s" % [focus, size_label])
			if _headless:
				samples.sample(tree, focus, size_label)
			else:
				await RenderingServer.frame_post_draw
				_save_png(viewport, dimensions, "%s_%s" % [size_label, focus])
		if _headless:
			samples.check_confirmation(tree)
			tree.configure({"owned_ids": MIXED_STATE_OWNED_IDS, "focused_id": "open_sky"})
			_expect(tree.call("_link_state", "quick_wits", "rehearsed_escape") == SkillTreeView.STATE_OWNED, "Mixed fixture has an unrelated learned link")
			_expect(tree.call("_link_state", "quick_wits", "makeshift_tool") == SkillTreeView.STATE_AVAILABLE, "Mixed fixture has an unrelated available link")
			samples.sample(tree, "open_sky", size_label + "-mixed")
			tree.configure({"owned_ids": [], "focused_id": "open_sky"})
			# The public view defaults to a valid skill. Exercise the defensive
			# no-focus style in isolation, without creating a new UI state.
			tree.set("_focused_id", "")
			tree.call("_refresh_links")
			samples.sample(tree, "", size_label)
			if not _before:
				await FocusInputs.new(_expect).check(tree, size_label)
		samples.release()
	viewport.queue_free()
	await process_frame

func _install_fixture(fixture_dir: String) -> bool:
	for path: String in [Store.DEFAULT_RUN_STORAGE_PATH, Store.DEFAULT_STORAGE_PATH, Settings.DEFAULT_STORAGE_PATH]:
		var installed: bool = DirAccess.copy_absolute(fixture_dir.path_join(path.get_file()), ProjectSettings.globalize_path(path)) == OK
		_expect(installed, "Install census fixture %s into isolated user storage" % path)
		if not installed:
			return false
	var settings: Dictionary = Settings.load_settings()
	settings["ui_scale"] = 1.0
	var saved: bool = Settings.save_settings(settings)
	_expect(saved, "Set the capture UI scale to 100%")
	return saved

func _geometry_signature(tree: SkillTreeView) -> String:
	var rail := tree.get("_link_layer") as SkillTreeView.SkillLinkLayer
	var links: Dictionary
	for link: Dictionary in rail.links:
		links[link["sort_key"]] = [link["points"], link["bridge_gaps"]]
	links.sort()
	var rects: Dictionary
	for skill_id: String in SkillTreeLibrary.visible_ids():
		rects[skill_id] = tree.node_for_skill(skill_id).get_global_rect()
	return var_to_str([links, rects, tree.bridge_assignment_signature()]).sha256_text()

func _save_png(viewport: SubViewport, dimensions: Vector2i, name: String) -> void:
	var image: Image = viewport.get_texture().get_image()
	var path: String = _output_dir.path_join(name + ".png")
	var saved: bool = image != null and image.get_size() == dimensions and image.save_png(path) == OK
	_expect(saved, "Capture %s" % path)
	if saved:
		print(path)

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame

func _submit_headless_frame() -> void:
	RenderingServer.force_draw(false)

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("POL66 FAIL: " + message)
