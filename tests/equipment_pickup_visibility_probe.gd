extends SceneTree

const CombatBoardViewScript = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://equipment_pickup_visibility_probe"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const GEOMETRY_OUTPUT_FILES := {
	"min": "11_zoom_min_geometry.png",
	"default": "12_zoom_default_geometry.png",
	"max": "13_zoom_max_geometry.png"
}
const GEOMETRY_COLORS := {
	"player": Color("55d8ff"),
	"bone_ward_charm": Color("ffad4d"),
	"crimson_draught": Color("72e08d"),
	"equipment": Color("d59cff")
}
const GEOMETRY_LABELS := {
	"player": "PLAYER",
	"bone_ward_charm": "BONE-WARD CHARM",
	"crimson_draught": "CRIMSON DRAUGHT",
	"equipment": "EQUIPMENT"
}

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_DISABLED))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardViewScript.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	await process_frame
	var state: Dictionary = _probe_state()
	board.call("set_combat_state", state)
	var navigation: Dictionary = board.call("navigation_snapshot") as Dictionary
	await _capture_zoom(viewport, board, state, float(navigation.get("min_zoom", 0.0)), "min", "01_zoom_min.png")
	await _capture_zoom(viewport, board, state, float(navigation.get("zoom", 0.0)), "default", "02_zoom_default.png")
	await _capture_zoom(viewport, board, state, float(navigation.get("max_zoom", 0.0)), "max", "03_zoom_max.png")
	if _errors.is_empty():
		print("EQUIPMENT PICKUP VISIBILITY PROBE: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
	print("EQUIPMENT PICKUP VISIBILITY PROBE: FAIL (%d errors)" % _errors.size())
	quit(1)

func _capture_zoom(viewport: SubViewport, board: Control, state: Dictionary, zoom: float, zoom_slot: String, file_name: String) -> void:
	board.call("set_navigation_zoom", zoom, board.size * 0.5)
	board.queue_redraw()
	for _frame: int in range(3):
		await process_frame
	var dynamic_layer: Control = board.get("_dynamic_render_layer") as Control
	_expect(dynamic_layer != null and dynamic_layer.is_inside_tree(), "Pickup proof needs the live DynamicRenderLayer that owns the rendered actors and pickups")
	if dynamic_layer == null:
		return
	var geometry: Dictionary = _pickup_and_actor_geometry(dynamic_layer, state)
	var parent_geometry: Dictionary = _pickup_and_actor_geometry(board, state)
	_verify_dynamic_layer_geometry(geometry, parent_geometry, zoom)
	var widths: Dictionary = {}
	for object_id: String in ["player", "crimson_draught", "bone_ward_charm", "equipment"]:
		var rect: Rect2 = geometry.get(object_id, Rect2()) as Rect2
		widths[object_id] = rect.size.x
		_expect(rect.size.x > 0.0, "%s should have a non-empty rendered geometry bound at %.2fx zoom" % [object_id, zoom])
	print(
		"PICKUP ZOOM GEOMETRY: zoom=%.2f player=%.2f vial=%.2f shield=%.2f equipment=%.2f" % [
			zoom,
			float(widths.get("player", 0.0)),
			float(widths.get("crimson_draught", 0.0)),
			float(widths.get("bone_ward_charm", 0.0)),
			float(widths.get("equipment", 0.0))
		]
	)
	var snapshots: Dictionary = get_meta("zoom_geometry", {}) as Dictionary
	snapshots[zoom_slot] = widths
	set_meta("zoom_geometry", snapshots)
	if snapshots.size() == 3:
		_verify_zoom_geometry(snapshots)
	await _save_viewport_screenshot(viewport, "%s/%s" % [OUTPUT_DIR, file_name])
	await _save_geometry_overlay(
		viewport,
		geometry,
		zoom,
		"%s/%s" % [OUTPUT_DIR, str(GEOMETRY_OUTPUT_FILES.get(zoom_slot, "%s_geometry.png" % zoom_slot))]
	)

func _save_geometry_overlay(viewport: SubViewport, geometry: Dictionary, zoom: float, output_path: String) -> void:
	var overlay := Control.new()
	overlay.name = "PickupGeometryQaOverlay"
	overlay.size = Vector2(VIEWPORT_SIZE)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1000
	overlay.draw.connect(_draw_geometry_overlay.bind(overlay, geometry.duplicate(true), zoom))
	viewport.add_child(overlay)
	overlay.queue_redraw()
	await process_frame
	await process_frame
	await _save_viewport_screenshot(viewport, output_path)
	overlay.queue_free()
	await process_frame

func _draw_geometry_overlay(overlay: Control, geometry: Dictionary, zoom: float) -> void:
	var font: Font = load("res://fonts/LabyrinthCrumble-Text.tres") as Font
	if font == null:
		_expect(false, "Geometry overlay should load its QA label font")
		return
	_draw_geometry_header(overlay, font, zoom)
	var player_rect: Rect2 = geometry.get("player", Rect2()) as Rect2
	var player_width: float = maxf(0.001, player_rect.size.x)
	for object_id: String in ["player", "bone_ward_charm", "crimson_draught", "equipment"]:
		var rect: Rect2 = geometry.get(object_id, Rect2()) as Rect2
		var color: Color = GEOMETRY_COLORS.get(object_id, Color.WHITE) as Color
		var ratio: float = rect.size.x / player_width
		overlay.draw_rect(rect, Color(color.r, color.g, color.b, 0.10), true)
		overlay.draw_rect(rect.grow(1.0), color, false, 2.0, true)
		_draw_geometry_label(
			overlay,
			font,
			rect,
			"%s  %.2f px  |  %.3f/player" % [str(GEOMETRY_LABELS.get(object_id, object_id.to_upper())), rect.size.x, ratio],
			color
		)

func _draw_geometry_header(overlay: Control, font: Font, zoom: float) -> void:
	var text: String = "RENDER GEOMETRY  |  BOARD ZOOM %.2f" % zoom
	var font_size: int = 22
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var label_rect := Rect2(Vector2(20.0, 20.0), text_size + Vector2(18.0, 10.0))
	overlay.draw_rect(label_rect, Color(0.02, 0.02, 0.025, 0.92), true)
	overlay.draw_rect(label_rect, Color("f3e3bb"), false, 1.0, true)
	overlay.draw_string(
		font,
		label_rect.position + Vector2(9.0, label_rect.size.y - 7.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color("f3e3bb")
	)

func _draw_geometry_label(overlay: Control, font: Font, source_rect: Rect2, text: String, color: Color) -> void:
	var font_size: int = 18
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var label_size: Vector2 = text_size + Vector2(12.0, 8.0)
	var label_position := Vector2(
		clampf(source_rect.position.x, 4.0, float(VIEWPORT_SIZE.x) - label_size.x - 4.0),
		source_rect.position.y - label_size.y - 5.0
	)
	if label_position.y < 4.0:
		label_position.y = minf(float(VIEWPORT_SIZE.y) - label_size.y - 4.0, source_rect.end.y + 5.0)
	var label_rect := Rect2(label_position, label_size)
	overlay.draw_line(source_rect.position, Vector2(label_rect.position.x + 6.0, label_rect.end.y), color, 1.0, true)
	overlay.draw_rect(label_rect, Color(0.02, 0.02, 0.025, 0.88), true)
	overlay.draw_rect(label_rect, color, false, 1.0, true)
	overlay.draw_string(
		font,
		label_rect.position + Vector2(6.0, label_rect.size.y - 6.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color("fff8e8")
	)

func _pickup_and_actor_geometry(render_layer: Control, state: Dictionary) -> Dictionary:
	var player_unit: Dictionary = {}
	for unit_var: Variant in render_layer.call("_visible_units") as Array:
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("role", "")) == "player":
			player_unit = unit_var as Dictionary
			break
	var geometry: Dictionary = {"player": render_layer.call("_unit_draw_rect", player_unit) as Rect2}
	for loot_var: Variant in state.get("loot", []) as Array:
		var loot: Dictionary = loot_var as Dictionary
		var texture: Texture2D = render_layer.call("_loot_texture", loot) as Texture2D
		geometry[str(loot.get("card_id", loot.get("kind", "")))] = render_layer.call("_loot_rect_for_tile", loot.get("pos", Vector2i.ZERO), texture, loot) as Rect2
	return geometry

func _verify_dynamic_layer_geometry(dynamic_geometry: Dictionary, parent_geometry: Dictionary, zoom: float) -> void:
	for object_id: String in ["player", "crimson_draught", "bone_ward_charm", "equipment"]:
		var dynamic_rect: Rect2 = dynamic_geometry.get(object_id, Rect2()) as Rect2
		var parent_rect: Rect2 = parent_geometry.get(object_id, Rect2()) as Rect2
		_expect(
			is_equal_approx(dynamic_rect.size.x, parent_rect.size.x) and is_equal_approx(dynamic_rect.size.y, parent_rect.size.y),
			"DynamicRenderLayer %s geometry must match the parent at %.2fx zoom so visible board actors and pickups scale together" % [object_id, zoom]
		)

func _verify_zoom_geometry(snapshots: Dictionary) -> void:
	var min_widths: Dictionary = snapshots.get("min", {}) as Dictionary
	var default_widths: Dictionary = snapshots.get("default", {}) as Dictionary
	var max_widths: Dictionary = snapshots.get("max", {}) as Dictionary
	for object_id: String in ["crimson_draught", "bone_ward_charm", "equipment"]:
		var min_width: float = float(min_widths.get(object_id, 0.0))
		var default_width: float = float(default_widths.get(object_id, 0.0))
		var max_width: float = float(max_widths.get(object_id, 0.0))
		_expect(min_width < default_width and default_width < max_width, "%s should grow monotonically in real renderer geometry across min/default/max zoom" % object_id)
		var min_ratio: float = min_width / maxf(0.001, float(min_widths.get("player", 0.0)))
		var default_ratio: float = default_width / maxf(0.001, float(default_widths.get("player", 0.0)))
		var max_ratio: float = max_width / maxf(0.001, float(max_widths.get("player", 0.0)))
		_expect(is_equal_approx(min_ratio, default_ratio) and is_equal_approx(default_ratio, max_ratio), "%s should keep its screen-size proportion relative to the player across zoom" % object_id)

func _probe_state() -> Dictionary:
	return {
		"name": "Equipment Pickup Visibility Probe",
		"room_coord": Vector2i(7, -2),
		"grid": _probe_grid(),
		"player": {
			"pos": Vector2i(2, 4),
			"hp": 30,
			"max_hp": 30,
			"block": 0,
			"stoneskin": 0
		},
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(6, 3),
			"hp": 90,
			"max_hp": 90,
			"block": 0,
			"intent": {}
		}],
		"loot": [{
			"id": "probe_equipment",
			"kind": "equipment",
			"equipment_id": "iron_cleaver",
			"pos": Vector2i(4, 3)
		}, {
			"id": "probe_vial",
			"kind": "item", "card_id": "crimson_draught",
			"pos": Vector2i(5, 4)
		}, {
			"id": "probe_shield",
			"kind": "item", "card_id": "bone_ward_charm",
			"pos": Vector2i(3, 4)
		}],
		"terrain": [],
		"traps": []
	}

func _probe_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
	]

func _save_viewport_screenshot(viewport: SubViewport, output_path: String) -> void:
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == VIEWPORT_SIZE, "%s should capture at the focused 1920x1080 proof size" % output_path)
	if image != null:
		_expect(image.save_png(ProjectSettings.globalize_path(output_path)) == OK, "Probe should save %s" % output_path)

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
