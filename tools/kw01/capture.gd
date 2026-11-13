extends SceneTree
## kw-01 proof: resume a certified inspection save (reward, scavenger or
## graftwright), hover one card trigger with a real pointer motion, and save
## the rest and hover frames at 1920x1080. Usage (after --):
##   --manifest <inspection.json> --case <name> --index <n> [--out <dir>]

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)

var canvas: SubViewport
var out_dir: String = "/private/tmp/labyrinth_codex/kw-01/captures"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _arg(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_arg("--manifest", "")))
	var case_name: String = _arg("--case", "case")
	var index: int = int(_arg("--index", "0"))
	out_dir = _arg("--out", out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var run_id: String = manifest["run_id"]
	var home: String = manifest["verification"]["godot_home_root"]
	var source: String = home.path_join(run_id).path_join("Library/Application Support/Escape the Umbra Parallel " + run_id)
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	DirAccess.copy_absolute(source.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json"))
	DirAccess.copy_absolute(source.path_join("current_run.save"), ProjectSettings.globalize_path("user://current_run.save"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(canvas)
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	for frame: int in range(90): await process_frame
	await create_timer(2.5).timeout
	var triggers: Array[Control] = []
	_collect(scene, triggers)
	triggers.sort_custom(func(a: Control, b: Control) -> bool: return a.get_global_rect().position.x < b.get_global_rect().position.x)
	print("KW01 %s triggers=%d" % [case_name, triggers.size()])
	_motion(Vector2(40, 40))
	await create_timer(0.4).timeout
	await _save(case_name + "_rest")
	if triggers.is_empty():
		print("KW01 %s: no card triggers found" % case_name)
		quit(1)
		return
	var trigger: Control = triggers[clampi(index, 0, triggers.size() - 1)]
	# The post-combat reveal restores card input when its sequence ends.
	for wait: int in range(80):
		if trigger.mouse_filter != Control.MOUSE_FILTER_IGNORE: break
		await create_timer(0.1).timeout
	print("KW01 %s trigger_mouse_filter=%d" % [case_name, trigger.mouse_filter])
	_motion(trigger.get_global_rect().get_center())
	# The capture SubViewport's pushed motion reaches only the board layer, so
	# deliver the trigger's standard hover signal directly (real play gets it
	# from the GUI). This proves layout and layering, not hit testing.
	trigger.mouse_entered.emit()
	await create_timer(0.9).timeout
	var hovered: Control = canvas.gui_get_hovered_control()
	print("KW01 %s hovered_control=%s trigger_rect=%s entries=%d" % [case_name, str(hovered.get_path()) if hovered != null else "-", str(trigger.get_global_rect()), preload("res://scripts/card_keyword_hover.gd").entries_for(_source_for(trigger)).size()])
	var stack: Control = scene.find_child("CardFocusTooltipStack", true, false) as Control
	var shown: bool = stack != null and stack.visible
	print("KW01 %s hover=%s stack_visible=%s stack_rect=%s panels=%d" % [case_name, trigger.name, shown, str(stack.get_global_rect()) if stack != null else "-", stack.get_child_count() if stack != null else 0])
	await _save(case_name + "_hover")
	quit(0 if shown else 1)

func _source_for(trigger: Control) -> Control:
	if trigger.has_method("display_summary_rows"): return trigger
	for child: Node in trigger.find_children("*", "", true, false):
		if child.has_method("display_summary_rows"): return child as Control
	return trigger

func _collect(node: Node, into: Array[Control]) -> void:
	if node is Control and node.has_meta("card_keyword_hover") and (node as Control).is_visible_in_tree(): into.append(node)
	for child: Node in node.get_children(): _collect(child, into)

func _motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	canvas.push_input(motion)

func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	image.save_png(out_dir.path_join(label + ".png"))
	print("KW01 saved " + out_dir.path_join(label + ".png"))
