extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_ROOT: String = "user://enemy_shadow_dissolve_probe_v1"
const RESOLUTION: Vector2i = Vector2i(1920, 1080)
const CHECKPOINTS: Array[Dictionary] = [
	{"progress": 0.00, "file": "00_silhouette_hold.png"},
	{"progress": 0.18, "file": "18_umbra_takeover.png"},
	{"progress": 0.36, "file": "36_first_fractures.png"},
	{"progress": 0.54, "file": "54_shadow_breakup.png"},
	{"progress": 0.72, "file": "72_wisp_release.png"},
	{"progress": 0.88, "file": "88_last_fragments.png"},
	{"progress": 0.98, "file": "98_near_nothing.png"},
]

var _failed: bool = false
var _output_dir: String = ""


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.content_scale_size = RESOLUTION
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = RESOLUTION
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(RESOLUTION)
	_output_dir = "%s/%dx%d" % [OUTPUT_ROOT, RESOLUTION.x, RESOLUTION.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	_clear_probe_output(_output_dir)
	call_deferred("_capture_sequence")


func _capture_sequence() -> void:
	await process_frame
	var board: Control = CombatBoardView.new()
	board.position = Vector2.ZERO
	board.size = Vector2(RESOLUTION)
	root.add_child(board)
	await process_frame
	await process_frame
	board.call("_load_assets")
	var state: Dictionary = _probe_state()
	var source_units: Array[Dictionary] = _death_units_at_progress(0.0)
	for unit: Dictionary in source_units:
		if not bool(board.call("_unit_uses_procedural_shadow_dissolve", unit)):
			_fail("%s should resolve the unified procedural death path" % str(unit.get("type", "enemy")))
		if not (board.call("_unit_death_frames", unit) as Array).is_empty():
			_fail("%s should not load a runtime enemy death sheet" % str(unit.get("type", "enemy")))

	var captures: Array[Image] = []
	for checkpoint: Dictionary in CHECKPOINTS:
		var progress: float = float(checkpoint.get("progress", 0.0))
		var presentation := {
			"death_animation_units": _death_units_at_progress(progress),
			"board_backdrop_visible": false,
		}
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		await process_frame
		await process_frame
		await create_timer(0.045).timeout
		_assert_effect_nodes(board, progress, false)
		captures.append(await _capture(str(checkpoint.get("file", "death.png"))))

	var reduced_progress: float = 0.62
	board.call(
		"set_combat_state",
		state,
		[],
		[],
		Vector2i(-1, -1),
		"",
		"",
		{},
		{},
		{
			"death_animation_units": _death_units_at_progress(reduced_progress),
			"board_backdrop_visible": false,
			"reduced_motion": true,
		}
	)
	await process_frame
	await process_frame
	await create_timer(0.045).timeout
	_assert_effect_nodes(board, reduced_progress, true)
	captures.append(await _capture("reduced_motion_62_static_breakup.png"))

	if captures.size() == 8:
		var opening_change: float = _sampled_image_difference(captures[0], captures[3])
		var completion_change: float = _sampled_image_difference(captures[0], captures[6])
		if opening_change < 0.0025:
			_fail("Midpoint dissolve should visibly depart from the intact silhouettes")
		if completion_change < 0.0035:
			_fail("Near-complete dissolve should visibly clear the enemy silhouettes")
		_save_contact_sheet(captures, "enemy_shadow_dissolve_contact_sheet.png")
	else:
		_fail("Dissolve proof should capture seven motion checkpoints plus reduced motion")

	board.call("set_combat_state", state)
	if not (board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary).is_empty():
		_fail("Clearing the death presentation should release all shader effect nodes")
	board.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(_output_dir))
	quit(1 if _failed else 0)


func _probe_state() -> Dictionary:
	return {
		"name": "Enemy Shadow Dissolution Proof",
		"room_coord": Vector2i(12, -4),
		"grid": _probe_grid(),
		"player": {"pos": Vector2i(2, 5), "hp": 30, "max_hp": 30, "block": 0, "stoneskin": 0},
		"enemies": [],
		"loot": [],
		"terrain": [],
		"traps": [],
	}


func _death_units_at_progress(progress: float) -> Array[Dictionary]:
	return [
		{
			"key": "enemy_301",
			"id": 301,
			"role": "enemy",
			"type": "crawler",
			"name": "Tunnel Crawler",
			"pos": Vector2i(3, 4),
			"footprint": Vector2i.ONE,
			"hp": 10,
			"max_hp": 10,
			"death_animation": true,
			"death_progress": progress,
		},
		{
			"key": "enemy_302",
			"id": 302,
			"role": "enemy",
			"type": "grave_surgeon",
			"name": "Grave Surgeon",
			"pos": Vector2i(6, 4),
			"footprint": Vector2i.ONE,
			"hp": 18,
			"max_hp": 18,
			"death_animation": true,
			"death_progress": progress,
		},
		{
			"key": "enemy_303",
			"id": 303,
			"role": "enemy",
			"type": "noctyrax",
			"name": "Noctyrax, the Last Eclipse",
			"pos": Vector2i(8, 2),
			"footprint": Vector2i(2, 2),
			"hp": 150,
			"max_hp": 150,
			"death_animation": true,
			"death_progress": progress,
		},
	]


func _probe_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(12):
			row.append("wall" if x == 0 or y == 0 or x == 11 or y == 7 else "stone")
		grid.append(row)
	return grid


func _assert_effect_nodes(board: Control, expected_progress: float, reduced_motion: bool) -> void:
	var effects: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary
	if effects.size() != 3:
		_fail("Each of the three defeated silhouettes should own one effect node")
		return
	for actor_key: String in ["enemy_301", "enemy_302", "enemy_303"]:
		var effect: Control = effects.get(actor_key, null) as Control
		if effect == null:
			_fail("Missing dissolve effect node for %s" % actor_key)
			continue
		if not is_equal_approx(float(effect.call("dissolve_progress")), expected_progress):
			_fail("%s should receive progress %.2f" % [actor_key, expected_progress])
		if bool(effect.call("reduced_motion_enabled")) != reduced_motion:
			_fail("%s should receive the reduced-motion state" % actor_key)
		var source_rect: Rect2 = effect.call("source_rect") as Rect2
		var effect_rect: Rect2 = effect.call("expanded_rect") as Rect2
		if not effect_rect.encloses(source_rect) or effect_rect.size == source_rect.size:
			_fail("%s should expand its render canvas for silhouette-derived wisps" % actor_key)


func _capture(file_name: String) -> Image:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Enemy death proof should capture %s" % file_name)
		return Image.new()
	if image.get_size() != RESOLUTION:
		image.resize(RESOLUTION.x, RESOLUTION.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png(ProjectSettings.globalize_path("%s/%s" % [_output_dir, file_name]))
	if error != OK:
		_fail("Enemy death proof should save %s" % file_name)
	return image


func _save_contact_sheet(images: Array[Image], file_name: String) -> void:
	var columns: int = 4
	var rows: int = 2
	var cell_size := Vector2i(RESOLUTION.x / columns, RESOLUTION.y / rows)
	var sheet := Image.create_empty(RESOLUTION.x, RESOLUTION.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("120d18"))
	for index: int in range(mini(images.size(), columns * rows)):
		var frame: Image = images[index].duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, cell_size), Vector2i((index % columns) * cell_size.x, (index / columns) * cell_size.y))
	var error: Error = sheet.save_png(ProjectSettings.globalize_path("%s/%s" % [_output_dir, file_name]))
	if error != OK:
		_fail("Enemy death proof should save its contact sheet")


func _sampled_image_difference(first: Image, second: Image) -> float:
	if first == null or second == null or first.is_empty() or second.is_empty() or first.get_size() != second.get_size():
		return 0.0
	var total: float = 0.0
	var samples: int = 0
	for y: int in range(0, first.get_height(), 10):
		for x: int in range(0, first.get_width(), 10):
			var a: Color = first.get_pixel(x, y)
			var b: Color = second.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
			samples += 1
	return total / float(maxi(1, samples) * 4)


func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
