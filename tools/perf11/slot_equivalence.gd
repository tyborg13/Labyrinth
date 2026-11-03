extends SceneTree
## On-demand proof against the whole original factory, not a permanent guard.
## The two frozen clocks also allow native pixel comparison of retained rigs.
const Candidate = preload("res://scripts/turn_order_landing_strip.gd")
const Portrait = preload("res://scripts/maquette_cutout_runtime/portrait.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const TARGET_RECT := Rect2(850, 650, 250, 352)
const ADVANCE_SECONDS: float = 0.31
const SETTLE_FRAMES: int = 3
const CAPTURE_CASES: Array = ["initial", "exchange", "reduced", "hidden"]
var output: String = ""
var reference: Script
var candidate: Script = Candidate
var capture: bool = false
var failures: Array[String]
var comparisons: int = 0
var retention_hits: int = 0
var cpu_samples: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--check-only"):
		var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/perf11/slot_proof.json"))
		assert(contract["min_images"] == 8 and contract["expected_sizes"] == ["1920x1080"] and contract["required_images"].size() == 8)
		print("PERF11 PIXEL PROOF CONTRACT: PASS (8 captures; 1920x1080; UI scale 100%)")
		quit(0)
		return
	for index: int in range(args.size()):
		if args[index] == "--reference": reference = load(args[index + 1])
		if args[index] == "--candidate": candidate = load(args[index + 1])
		if args[index] == "--output-dir": output = args[index + 1]
		if args[index] == "--capture": capture = true
	call_deferred("_run")

func _run() -> void:
	if reference == null or output.is_empty() or (capture and DisplayServer.get_name() == "headless"):
		push_error("Supply --reference and --output-dir; --capture requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Settings.set_storage_path(output.path_join("settings.json"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	for identity: String in Presentation.CREATURES:
		await _identity(identity)
	var file := FileAccess.open(output.path_join("equivalence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"comparisons": comparisons, "retention_hits": retention_hits, "failures": failures, "native_pixels": capture, "cpu_samples": cpu_samples}, "\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print("PERF11 STRIP EQUIVALENCE: %s (%d comparisons; %d retained slots; %d failures; native pixels %s)" % ["PASS" if failures.is_empty() else "FAIL", comparisons, retention_hits, failures.size(), capture])
	quit(0 if failures.is_empty() else 1)

func _identity(identity: String) -> void:
	var views: Array[SubViewport]
	var strips: Array[Control]
	var targets: Array[Control]
	for script: Script in [reference, candidate]:
		var view := SubViewport.new()
		view.size = SIZE
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
		var target := Control.new()
		target.position = TARGET_RECT.position
		target.size = TARGET_RECT.size
		view.add_child(target)
		targets.append(target)
		var strip: Control = script.new()
		# Drive the protected portrait clock explicitly, identically on both sides.
		strip.process_mode = Node.PROCESS_MODE_DISABLED
		view.add_child(strip)
		strips.append(strip)
	var old_slot: Node
	for mutation: String in ["initial", "unchanged", "exchange", "reduced", "hidden", "reveal", "remove", "act_again", "restore", "detach"]:
		var entries: Array[Dictionary] = _entries(identity, mutation)
		var reduced: bool = mutation == "reduced"
		for index: int in range(strips.size()):
			var strip: Control = strips[index]
			if mutation == "detach":
				views[index].remove_child(strip)
				views[index].add_child(strip)
			var started: int = Time.get_ticks_usec()
			strip.call("present", entries, 1, targets[index], null, _portrait_path, Callable(), reduced)
			cpu_samples.append({"identity": identity, "case": mutation, "candidate": index == 1, "usec": Time.get_ticks_usec() - started})
		var label: String = identity + "/" + mutation
		_check(_snapshot(strips[0]) == _snapshot(strips[1]), label + ": exact control/rig snapshot immediately after present")
		if mutation == "exchange":
			_check(old_slot in strips[1].get_children(), label + ": compatible portrait actually reused")
			retention_hits += 1
		if mutation == "initial": old_slot = strips[1].get_node("LandingStripSlot_0")
		for strip: Control in strips:
			for renderer: Node in strip.find_children("MaquettePortraitRenderer", "", true, false): renderer.call("_process", ADVANCE_SECONDS)
		_check(_snapshot(strips[0]) == _snapshot(strips[1]), label + ": identical advanced portrait clock")
		comparisons += 2
		if capture and identity == "burrow_grub" and mutation in CAPTURE_CASES:
			for frame: int in range(SETTLE_FRAMES): await process_frame
			await RenderingServer.frame_post_draw
			var before: Image = views[0].get_texture().get_image()
			var after: Image = views[1].get_texture().get_image()
			_check(before.get_size() == SIZE and after.get_size() == SIZE, label + ": capture size")
			_check(before.get_data() == after.get_data(), label + ": native pixels")
			_check(before.save_png(output.path_join(mutation + "_before.png")) == OK, label + ": save before")
			_check(after.save_png(output.path_join(mutation + "_after.png")) == OK, label + ": save after")
	for view: SubViewport in views: view.free()
	await process_frame

func _entries(identity: String, mutation: String) -> Array[Dictionary]:
	var active: Dictionary = {"kind": "player", "actor_key": "player", "active": true, "type": "player", "team": "player"}
	var hero: Dictionary = {"kind": "player", "actor_key": "player", "projected": true, "type": "player", "team": "player", "eta": 19, "time": 19, "seq": 1}
	var enemy: Dictionary = {"kind": "enemy", "actor_key": "enemy_1", "type": identity, "team": "enemy", "eta": 10, "time": 10, "seq": 2}
	var second: Dictionary = enemy.duplicate(true)
	second.merge({"actor_key": "enemy_2", "eta": 21, "time": 21, "seq": 3}, true)
	if mutation == "hidden": enemy["hidden_by_umbra"] = true
	if mutation in ["exchange", "reduced"]: enemy["eta"] = 22; enemy["time"] = 22
	var result: Array[Dictionary]
	if mutation == "act_again": result.assign([active, hero, second])
	elif mutation == "remove": result.assign([active, enemy, hero])
	elif mutation in ["exchange", "reduced"]: result.assign([active, second, hero, enemy])
	else: result.assign([active, enemy, hero, second])
	return result

func _portrait_path(entry: Dictionary) -> String:
	var type: String = str(entry.get("type", ""))
	return Portrait.rest_path(type) if Presentation.handles(type) else "res://assets/art/icons/umbra_presence.png"

func _snapshot(node: Node) -> Array:
	var values: Array = [str(node.name), node.get_class()]
	if node is CanvasItem: values.append([node.visible, node.modulate, node.self_modulate, node.z_index, node.z_as_relative, node.top_level])
	if node is Control: values.append([node.position, node.size, node.custom_minimum_size, node.scale, node.rotation, node.pivot_offset, node.mouse_filter])
	if node is Node2D: values.append(node.transform)
	if node is TextureRect:
		var texture: Texture2D = node.texture
		values.append([node.expand_mode, node.stretch_mode, node.flip_h, node.flip_v, _texture_key(texture)])
	if node is Label:
		values.append([node.text, node.horizontal_alignment, node.vertical_alignment, node.get_theme_font_size("font_size"), node.get_theme_color("font_color"), node.get_theme_color("font_outline_color"), node.get_theme_constant("outline_size")])
	if node.name == "MaquettePortraitRenderer":
		var state: Dictionary = node.call("snapshot")
		state.erase("texture_id")
		values.append(state)
	if node.has_meta("turn_order_entry"): values.append(node.get_meta("turn_order_entry"))
	if node.has_meta("chevron_color"): values.append(node.get_meta("chevron_color"))
	if node.has_meta("landing_strip_role"): values.append(node.get_meta("landing_strip_role"))
	for child: Node in node.get_children(): values.append(_snapshot(child))
	return values

func _texture_key(texture: Texture2D) -> Variant:
	if texture == null: return null
	if texture is AtlasTexture: return [texture.region, texture.margin, texture.filter_clip, _texture_key(texture.atlas)]
	if texture is ViewportTexture: return "retained-portrait-viewport"
	if texture is GradientTexture2D: return [texture.width, texture.height, texture.fill, texture.fill_from, texture.fill_to, texture.gradient.offsets, texture.gradient.colors]
	return texture.resource_path

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
