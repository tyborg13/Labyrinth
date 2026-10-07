extends SceneTree
const Hud = preload("res://scripts/combat_objective_hud.gd")
const Reference = preload("res://tests/fixtures/objective_glyph_reference.gd")
const Glyphs = preload("res://scripts/ui_glyph_preparation.gd")
const Rules = preload("res://scripts/combat_objective_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

var _errors: Array[String]
var _checks: int = 0
var _cases: int = 0
var _pixels: Array[Dictionary]
var _native: bool
var _presented: int = 0
var _active: bool = true
var _owner: Variant
var _boundary_action: String = ""
var _boundary_executed: bool = false
var _boundary_saw_outline: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_native = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1920, 1080)
	await process_frame
	if _native: await _settle_window()
	_visibility_contract()
	for state: Dictionary in _states():
		await _case(state)
	for action: String in ["cancel", "combat", "detach", "free"]:
		await _ownership_case(action)
	await _frame()
	await _frame()
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Preparation must retain no orphan owners or canvases")
	print("OBJECTIVE GLYPH RESULT: " + JSON.stringify({"cases": _cases, "checks": _checks, "errors": _errors, "pixel_differences": _pixels, "native": _native, "presented": _presented, "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if _errors.is_empty() else 1)

func _visibility_contract() -> void:
	var scene := preload("res://scripts/run_scene.gd").new()
	scene._animation_lock = true
	scene._run_state = {"mode": "combat"}
	var grid: Array
	for y: int in range(9):
		var row: Array
		for x: int in range(9): row.append("stone")
		grid.append(row)
	var enemies: Array[Dictionary]
	enemies.append({"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 9, "max_hp": 12})
	enemies.append({"id": 2, "type": "harrier", "pos": Vector2i(5, 4), "hp": 4, "max_hp": 7})
	var finite_counts: Dictionary = {}
	for type: String in [Rules.KILL_ALL, Rules.KILL_LEADER]:
		for stage: String in ["absent", "clear", "eclipse"]:
			for player_pos: Vector2i in [Vector2i(0, 0), Vector2i(3, 4), Vector2i(4, 4)]:
				var state: Dictionary = {"objective": {"type": type, "leader_id": 1}, "grid": grid, "player": {"pos": player_pos}, "enemies": enemies}
				if stage != "absent": state["umbra"] = {"stage": stage, "light_sources": []}
				scene._combat_state = state
				var before: Dictionary = state.duplicate(true)
				var expected: Dictionary = scene._combat_objective_hud_state()
				var actual: Dictionary = preload("res://scripts/encounter_asset_preparation.gd").opening_objective_hud_state(scene, state)
				_check(actual == expected, "Future preparation must match the actual committed opening HUD, including Umbra visibility")
				_check(state == before and scene._combat_state == before, "Visibility preparation must not mutate authoritative snapshots")
				if actual.has("visible_enemy_ids"):
					finite_counts[(actual["visible_enemy_ids"] as Array).size()] = true
					(actual["visible_enemy_ids"] as Array).append(-999)
					_check(state == before, "Prepared visibility list must be independently owned")
				else: _check(is_same(actual, state), "Unfiltered opening HUD must retain the original snapshot")
	_check(finite_counts.has(0) and finite_counts.has(1) and finite_counts.has(2), "Actual Umbra fixture must cover zero, one and multiple known foes and concealed/visible leader")
	scene.free()

func _states() -> Array[Dictionary]:
	var states: Array[Dictionary]
	var enemies: Array[Dictionary]
	enemies.append({"id": 1, "type": "crawler", "hp": 9, "max_hp": 12})
	enemies.append({"id": 2, "type": "harrier", "hp": 4, "max_hp": 7})
	enemies.append({"id": 3, "type": "cinder_ooze", "hp": 0, "max_hp": 8})
	for type: String in [Rules.KILL_ALL, Rules.KILL_LEADER, Rules.SURVIVE, Rules.REACH_EXIT]:
		var state: Dictionary = {"objective": {"type": type, "leader_id": 1, "target_clock": 46, "next_reinforcement_clock": 16, "exits": [{"target_tile": Vector2i(7, 4)}, {"target_tile": Vector2i(4, 1)}]}, "enemies": enemies, "initiative_clock": 7}
		states.append(state)
		for visible: Array in [[], [1], [1, 2], [2]]:
			var filtered: Dictionary = state.duplicate(true)
			filtered["visible_enemy_ids"] = visible.duplicate()
			states.append(filtered)
	# Pick an actual guardian/dragon identity whose authored title exceeds the
	# intro's fixed band, rather than changing production copy to force a case.
	var longest: String = ""
	var longest_length: int = 0
	for id: String in GameData.enemies():
		var candidate: Dictionary = {"type": Rules.KILL_LEADER, "leader_type": id, "leader_id": 1}
		var title: String = Rules.title_for_objective(candidate)
		if title.length() > longest_length:
			longest = id
			longest_length = title.length()
	states.append({"objective": {"type": Rules.KILL_LEADER, "leader_type": longest, "leader_id": 1}, "enemies": enemies, "long_title_case": true})
	states.append({"objective": {}, "enemies": enemies})
	return states

func _case(state: Dictionary) -> void:
	var views: Array[SubViewport]
	var pair: Array[Control]
	for original: bool in [false, true]:
		var view := SubViewport.new()
		view.size = Vector2i(1920, 1080)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
		var hud: Control = Reference.new() if original else Hud.new()
		hud.hide()
		view.add_child(hud)
		_private_fonts(hud)
		pair.append(hud)
	await _frame()
	var before: Dictionary = state.duplicate(true)
	var hud_before: Dictionary = _snapshot(pair[0])
	var fonts_before: Dictionary = _font_properties(pair[0])
	var jobs: Array[Dictionary] = pair[0].opening_glyph_preparation_jobs(state)
	_active = true
	_owner = pair[0]
	await Glyphs.prepare_jobs_for(pair[0], jobs, _present, _alive)
	_check(state == before, "Preparation must not mutate input state")
	_check(_snapshot(pair[0]) == hud_before, "Preparation must not mutate hidden labels, geometry or presentation state")
	_check(_font_properties(pair[0]) == fonts_before, "Preparation must preserve actual font resources and parameters")
	var prepared_cache: Dictionary = _cache(pair[0])
	var server: TextServer = TextServerManager.get_primary_interface()
	for job: Dictionary in jobs:
		var cached: PackedInt32Array = server.call("font_get_glyph_list", job["rid"], job["size"])
		_check(cached.has(int(job["index"])), "Actual native cache must contain every prepared font RID/size/stroke/glyph before first draw")
	for hud: Control in pair:
		hud.set_combat_state(state)
		hud.set_hud_rect(Rect2(20, 630, 350, 96))
	if bool(state.get("long_title_case", false)):
		_check(pair[0]._intro_title_font_size(1.0) < Hud.INTRO_TITLE_FONT_SIZE, "Actual long guardian/dragon title must exercise width fitting")
	if not (state["objective"] as Dictionary).is_empty():
		for progress: float in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]:
			for hud: Control in pair:
				hud.prepare_intro(Rect2(20, 630, 350, 96), Vector2(1920, 1080))
				hud.intro_phase = "appearing"
				hud.modulate = Color.WHITE
				hud._intro_text_stack.modulate = Color.WHITE
				hud._set_intro_font_progress(progress)
				hud._set_intro_shadow_progress(progress)
				hud.scale = Vector2.ONE * lerpf(Hud.INTRO_START_SCALE, Hud.INTRO_POP_SCALE, progress)
			await _compare(pair, views, "appearing %.2f" % progress)
		for progress: float in [0.0, 0.25, 0.55, 0.82, 1.0]:
			for hud: Control in pair:
				hud.intro_phase = "traveling"
				hud.scale = Vector2.ONE * lerpf(Hud.INTRO_POP_SCALE, 1.0, progress)
				hud.position = Vector2(785, 254.4).lerp(Vector2(20, 630), progress)
				hud._intro_text_stack.scale = Vector2.ONE * lerpf(1.0, Hud.INTRO_TEXT_TARGET_SCALE, progress)
				hud._intro_text_stack.modulate.a = 1.0 - progress
				hud._set_intro_chrome_progress(progress)
				hud._set_intro_content_progress(progress)
				hud._set_intro_shadow_progress(1.0 - progress)
			await _compare(pair, views, "travel %.2f" % progress)
		for hud: Control in pair:
			hud.prepare_intro(Rect2(20, 630, 350, 96), Vector2(1920, 1080))
			hud.scale = Vector2.ONE * Hud.INTRO_POP_SCALE
			hud.modulate = Color.WHITE
			hud._set_intro_font_progress(1.0)
			hud._set_intro_shadow_progress(1.0)
			hud._intro_text_stack.modulate = Color.WHITE
			hud.intro_phase = "reduced_hold"
		await _compare(pair, views, "reduced hold")
	for hud: Control in pair: hud._finish_intro(Rect2(20, 630, 350, 96))
	await _compare(pair, views, "settled")
	_check(_cache(pair[0]) == prepared_cache, "Authored poses and settled first native draws must add no unprepared bitmap size/stroke/glyph cache entries")
	if _cases == 0 and _native:
		views[0].get_texture().get_image().save_png("user://objective_glyph_actual.png")
		print("OBJECTIVE GLYPH IMAGE: " + ProjectSettings.globalize_path("user://objective_glyph_actual.png"))
	for view: SubViewport in views: view.queue_free()
	_owner = null
	_cases += 1
	await _frame()
	await _frame()

func _compare(pair: Array[Control], views: Array[SubViewport], label: String) -> void:
	await _frame()
	await _frame()
	_check(_snapshot(pair[0]) == _snapshot(pair[1]), "Complete original and prepared HUD state must match: " + label)
	if _cases == 0 and _native and label == "appearing 1.00":
		views[0].get_texture().get_image().save_png("user://objective_glyph_intro_actual.png")
		print("OBJECTIVE GLYPH IMAGE: " + ProjectSettings.globalize_path("user://objective_glyph_intro_actual.png"))
	if _native and views[0].get_texture().get_image().get_data() != views[1].get_texture().get_image().get_data():
		_pixels.append({"case": _cases, "pose": label})
		_check(false, "Native original and prepared pixels must match exactly: " + label)

func _private_fonts(hud: Control) -> void:
	for label: Label in hud.find_children("*", "Label", true, false):
		label.add_theme_font_override("font", label.get_theme_font("font").duplicate(true))

func _font_properties(hud: Control) -> Dictionary:
	var result: Dictionary = {}
	for label: Label in hud.find_children("*", "Label", true, false):
		var font: Font = label.get_theme_font("font")
		# Native bitmap cache storage is the intended output of preparation;
		# source font data and rendering parameters must remain unchanged.
		var properties: Dictionary = {}
		for entry: Dictionary in font.get_property_list():
			if not (int(entry["usage"]) & PROPERTY_USAGE_STORAGE) or str(entry["name"]) == "data" or str(entry["name"]).begins_with("cache/"): continue
			properties[entry["name"]] = font.get(entry["name"])
		result[str(hud.get_path_to(label))] = properties.duplicate(true)
	return result

func _cache(hud: Control) -> Dictionary:
	var result: Dictionary = {}
	var server: TextServer = TextServerManager.get_primary_interface()
	for label: Label in hud.find_children("*", "Label", true, false):
		for rid: RID in label.get_theme_font("font").get_rids():
			var sizes: Dictionary = {}
			for size: Vector2i in server.font_get_size_cache_list(rid):
				var indices: PackedInt32Array = server.call("font_get_glyph_list", rid, size)
				indices.sort()
				sizes[str(size)] = indices
			result[str(rid.get_id())] = sizes
	return result

func _snapshot(node: Node) -> Dictionary:
	var result: Dictionary = {"class": node.get_class()}
	if node is Control:
		var control: Control = node as Control
		for key: String in ["position", "size", "scale", "pivot_offset", "visible", "mouse_filter", "z_index", "modulate", "self_modulate", "tooltip_text"]: result[key] = control.get(key)
	if node is Label:
		var label: Label = node as Label
		result["text"] = label.text
		result["font_size"] = label.get_theme_font_size("font_size")
		for key: String in ["outline_size", "shadow_offset_x", "shadow_offset_y", "shadow_outline_size"]: result[key] = label.get_theme_constant(key)
		for key: String in ["font_color", "font_outline_color", "font_shadow_color"]: result[key] = label.get_theme_color(key)
	if node is TextureRect: result["texture"] = (node as TextureRect).texture
	if node.has_method("opening_glyph_preparation_jobs"):
		for key: String in ["_presentation_signature", "intro_active", "intro_phase", "intro_chrome_progress", "intro_content_progress", "intro_shadow_progress"]: result[key] = node.get(key)
	var children: Array[Dictionary]
	for child: Node in node.get_children(): children.append(_snapshot(child))
	result["children"] = children
	return result

func _ownership_case(action: String) -> void:
	var hud := Hud.new()
	hud.hide()
	root.add_child(hud)
	_private_fonts(hud)
	# Cold real private font bitmaps guarantee native work before suspension.
	var state: Dictionary = _states()[0]
	var jobs: Array[Dictionary] = hud.opening_glyph_preparation_jobs(state)
	_owner = hud
	_active = true
	_boundary_action = action
	_boundary_executed = false
	_boundary_saw_outline = false
	await Glyphs.prepare_jobs_for(hud, jobs, _present, _alive)
	_check(_boundary_executed, "Real native objective glyph work must suspend before each owner change: " + action)
	_check(_boundary_saw_outline, "Ownership case must cross actual native outline rasterization: " + action)
	if action != "free":
		if action == "detach": root.add_child(hud)
		hud.set_combat_state(state)
		_check(hud._title.text == Rules.title_for_objective(state["objective"]).to_upper(), "Canceled work must preserve synchronous original fallback")
		hud.free()
	else: _check(not is_instance_valid(hud), "Freed owner must end glyph work safely")
	_owner = null
	_boundary_action = ""
	_active = true
	_cases += 1
	await _frame()
	await _frame()

func _alive() -> bool:
	return _active and is_instance_valid(_owner) and _owner.is_inside_tree()

func _present() -> void:
	_presented += 1
	if not _boundary_action.is_empty() and not _boundary_executed:
		_boundary_executed = true
		var server: TextServer = TextServerManager.get_primary_interface()
		for label: Label in _owner.find_children("*", "Label", true, false):
			for rid: RID in label.get_theme_font("font").get_rids():
				for size: Vector2i in server.font_get_size_cache_list(rid):
					if size.y > 0 and not (server.call("font_get_glyph_list", rid, size) as PackedInt32Array).is_empty(): _boundary_saw_outline = true
		match _boundary_action:
			"cancel", "combat": _active = false
			"detach": _owner.get_parent().remove_child(_owner)
			"free": _owner.free()
	await _frame()

func _frame() -> void:
	if _native: await RenderingServer.frame_post_draw
	else: await process_frame

func _settle_window() -> void:
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 5000
	while stable < 20 and Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1920, 1080) or DisplayServer.window_get_size(root.get_window_id()) != Vector2i(1920, 1080):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1920, 1080)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			stable = 0
		else: stable += 1
		await create_timer(0.05).timeout
	_check(stable == 20, "Native window must settle at 1920x1080 and 100% scale for one second")

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok: _errors.append("case%d: %s" % [_cases, message])
