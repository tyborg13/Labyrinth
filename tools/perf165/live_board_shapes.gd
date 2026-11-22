extends RefCounted
## Probe-only capture of the live board paths covered by the warmup. Godot's
## headless RenderingServer doesn't expose canvas command readback, so redirect
## the live floor methods' native calls to a recorder in an in-memory subclass.

const BOARD_PATH := "res://scripts/combat_board_view.gd"
const Board = preload(BOARD_PATH)
const SHADOW_BOX := Rect2(0, 0, 20, 20)
const SHADOW_POLYGON := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
const FLOOR_RECORDER := """
var formats: Array

func capture_colored_polygon(points: PackedVector2Array, colour: Color) -> void:
	capture_polygon(points, PackedColorArray([colour]))

func capture_polygon(points: PackedVector2Array, colours: PackedColorArray, uv := PackedVector2Array(), texture: Texture2D = null) -> void:
	_unique(["polygon", {"uv": not uv.is_empty(), "textured": texture != null, "per_vertex_color": colours.size() == points.size(), "clip": false}])

func capture_line(_from: Vector2, _to: Vector2, _colour: Color, width: float = -1.0, aa: bool = false) -> void:
	# RendererCanvasCull::canvas_item_add_line emits four-point primitives
	# for a nonnegative width, with additional primitives for AA feathers.
	_unique(["line", {"vertices": 4 if width >= 0.0 else 2, "antialias": aa, "uv": false}])

func capture_polyline(_points: PackedVector2Array, _colour: Color, width: float = -1.0, aa: bool = false) -> void:
	_unique(["polyline", {"antialias": aa, "wide": width > 0.0, "uv": false}])

func _unique(command: Array) -> void:
	if not formats.has(command): formats.append(command)
"""

static func shadow_format(texture: Texture2D) -> Dictionary:
	var board := Board.new()
	board._ensure_art_treatment()
	var polygons: Array = [{"hard": PackedVector2Array(SHADOW_POLYGON)}]
	var mesh: ArrayMesh = board._unit_shadow_draw_mesh(texture, SHADOW_BOX, "player", polygons, true)
	var flags: int = mesh.surface_get_format(0)
	var result := {"flags": flags, "shader": board.material.shader, "command": ["mesh", {
		"uv": bool(flags & Mesh.ARRAY_FORMAT_TEX_UV), "color": bool(flags & Mesh.ARRAY_FORMAT_COLOR),
		"indexed": bool(flags & Mesh.ARRAY_FORMAT_INDEX), "position_2d": bool(flags & Mesh.ARRAY_FLAG_USE_2D_VERTICES),
		"textured": false, "primitive": mesh.surface_get_primitive_type(0)}]}
	board.free()
	return result

static func floor_formats() -> Array:
	var script := GDScript.new()
	script.source_code = 'extends "%s"\n' % BOARD_PATH + FLOOR_RECORDER
	var source := FileAccess.get_file_as_string(BOARD_PATH)
	for method: String in ["_draw_floor_tile", "_draw_floor_tile_depth", "_draw_floor_contact_shading"]:
		var body := _method_source(source, method)
		if body.is_empty(): return []
		script.source_code += "\n" + body
	if script.reload() != OK: return []
	var board: Control = script.new()
	var grid: Array = [["floor", "pillar"], ["floor", "floor"]]
	board.combat_state = {"grid": grid}
	board._draw_floor_tile(grid, Vector2i.ZERO)
	var result: Array = board.formats
	board.free()
	return result

static func _method_source(source: String, method: String) -> String:
	var start := source.find("\nfunc " + method + "(")
	if start < 0: return ""
	var end := source.find("\nfunc ", start + 1)
	var body := source.substr(start + 1, end - start - 1)
	for draw: String in ["colored_polygon", "polygon", "line", "polyline"]:
		body = body.replace("draw_" + draw + "(", "capture_" + draw + "(")
	return body
