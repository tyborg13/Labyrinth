extends "res://tests/combat_hud_buttons_test.gd"

const OUTPUT: String = "user://probes/combat_hud_buttons"
const REFERENCE: String = "user://combat_hud_master_reference"

var _reference_pass: bool = false
var _reference_images: Dictionary = {}
var _reference_rects: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("COMBAT HUD BUTTONS PROBE requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	call_deferred("_run")

func _run() -> void:
	var master_source: String = _git_show("master:scripts/run_scene.gd")
	var master_scene: String = _git_show("master:scenes/run_scene.tscn")
	if master_source.is_empty() or master_scene.is_empty():
		_finish()
		return
	var revision: Array = []
	_expect(OS.execute("git", PackedStringArray(["rev-parse", "master"]), revision) == 0 and not revision.is_empty(), "Master reference must identify its revision")
	if not revision.is_empty():
		print("HUD MASTER REFERENCE: ", str(revision[0]).strip_edges())
	var master_script_path: String = _store_master_script("scripts/run_scene.gd", master_source)
	if _failed:
		_finish()
		return
	var scene_file := FileAccess.open(REFERENCE + "/run_scene.tscn", FileAccess.WRITE)
	scene_file.store_string(master_scene.replace("res://scripts/run_scene.gd", master_script_path))
	scene_file.close()
	_reference_pass = true
	await _exercise_source(REFERENCE + "/run_scene.tscn")
	if _failed:
		_finish()
		return
	_reference_pass = false
	await _exercise_source("res://scenes/run_scene.tscn")
	_finish()

func _git_show(object: String) -> String:
	var output: Array = []
	var result: int = OS.execute("git", PackedStringArray(["show", object]), output)
	_expect(result == 0 and not output.is_empty(), "Master reference source must come from local git")
	return str(output[0]) if result == 0 and not output.is_empty() else ""

func _store_master_script(relative_path: String, source: String) -> String:
	var dependencies := RegEx.new()
	dependencies.compile('preload\\("(res://[^"\\n]+)"\\)')
	for dependency: RegExMatch in dependencies.search_all(source):
		var path: String = dependency.get_string(1)
		if not FileAccess.file_exists(path):
			var relative: String = path.trim_prefix("res://")
			var replacement: String = _store_master_script(relative, _git_show("master:" + relative))
			source = source.replace(path, replacement)
	var target: String = REFERENCE + "/" + relative_path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	var file := FileAccess.open(target, FileAccess.WRITE)
	_expect(file != null, "Isolated master dependency must save")
	if file != null:
		file.store_string(source)
		file.close()
	return target

func _capture(label: String) -> void:
	# Random ambient motes must not drift through the master comparison region.
	var motes := _header_instance.find_child("AtmosphereMotes", true, false) as CanvasItem
	if motes != null:
		motes.visible = false
	await _settle()
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == SIZE, "HUD captures must be native 1920x1080 SubViewport images")
	if image == null:
		return
	var prefix: String = "master" if _reference_pass else "restored"
	_expect(image.save_png("%s/%s_%s.png" % [OUTPUT, prefix, label]) == OK, "HUD capture must save")
	var cluster: Rect2 = (_header_instance.get("stats_label") as Control).get_global_rect()
	for key: String in ["_section_map_hud_button", "loadout_button", "grimoire_button", "menu_button"]:
		var button := _header_instance.get(key) as Control
		if button.is_visible_in_tree():
			cluster = cluster.merge(button.get_global_rect())
	var rect := Rect2i(cluster.grow(4.0))
	if _reference_pass:
		_reference_images[label] = image.get_region(rect)
		_reference_rects[label] = rect
		return
	_expect(rect == _reference_rects.get(label), "Restored %s cluster must have master's exact geometry" % label)
	if rect != _reference_rects.get(label):
		return
	var reference := _reference_images[label] as Image
	var actual: Image = image.get_region(rect)
	var differing: int = 0
	for y: int in range(rect.size.y):
		for x: int in range(rect.size.x):
			if actual.get_pixel(x, y) != reference.get_pixel(x, y):
				differing += 1
	print("HUD MASTER PIXEL COMPARISON: %s differing=%d/%d" % [label, differing, rect.size.x * rect.size.y])
	_expect(differing == 0, "Restored %s top-right cluster must match the master capture pixel-for-pixel" % label)

func _finish() -> void:
	print(ProjectSettings.globalize_path(OUTPUT))
	print("COMBAT HUD BUTTONS PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
