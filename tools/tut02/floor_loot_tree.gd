extends SceneTree

const Prompt = preload("res://scripts/contextual_combat_prompt.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES: int = 5
const OUTPUT: String = "res://.godot/tut02/floor_loot"

func _initialize() -> void:
	_compare.call_deferred()

func _compare() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	root.add_child(viewport)
	var prompt := Prompt.new()
	viewport.add_child(prompt)
	prompt.configure(Tutorial.phase_definition(Tutorial.PHASE_FLOOR_LOOT))
	for _frame: int in range(LAYOUT_FRAMES):
		await process_frame
	var rows: Array[Dictionary]
	_snapshot(prompt.get("_callout"), "callout", rows)
	var baseline: bool = OS.get_cmdline_user_args().has("--record-before")
	var path: String = OUTPUT.path_join("before.json" if baseline else "after.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("TUT-02 FLOOR LOOT TREE: FAIL writing " + path)
		quit(1)
		return
	var snapshot: String = JSON.stringify(rows, "\t") + "\n"
	file.store_string(snapshot)
	file.close()
	print(ProjectSettings.globalize_path(path))
	var matches: bool = baseline or snapshot == FileAccess.get_file_as_string(OUTPUT.path_join("before.json"))
	print("TUT-02 FLOOR LOOT TREE: %s (%d controls, SHA-256 %s)" % [
		"BASELINE" if baseline else ("MATCH" if matches else "FAIL"), rows.size(), snapshot.sha256_text(),
	])
	quit(0 if matches else 1)

func _snapshot(control: Control, path: String, rows: Array[Dictionary]) -> void:
	var row: Dictionary = {
		"path": path, "class": control.get_class(), "visible": control.is_visible_in_tree(),
		"rect": str(control.get_global_rect()), "minimum_size": str(control.get_combined_minimum_size()),
		"modulate": str(control.modulate), "mouse_filter": control.mouse_filter,
	}
	if control is BoxContainer:
		row["separation"] = control.get_theme_constant("separation")
	if control is Label or control is Button:
		row["text"] = control.text
		row["font"] = control.get_theme_font("font").resource_path
		row["font_size"] = control.get_theme_font_size("font_size")
		row["font_color"] = str(control.get_theme_color("font_color"))
	if control is ColorRect:
		row["color"] = str(control.color)
	rows.append(row)
	for child: Node in control.get_children():
		if child is Control:
			_snapshot(child, "%s/%d" % [path, child.get_index()], rows)
