extends "res://tests/perf/hover_board_reference.gd"

var overlay_commands: Array = []
var torch_commands: Array = []
var _record_torches: bool = false

func _draw_overlay_render_layer() -> void:
	overlay_commands.clear()
	super._draw_overlay_render_layer()

func _draw_tile_overlays(tile: Vector2i) -> void:
	overlay_commands.append(preload("res://tests/perf/hover_draw_manifest.gd").tile(self, tile).duplicate(true))
	super._draw_tile_overlays(tile)

func _draw_foreground_render_layer() -> void:
	torch_commands.clear()
	super._draw_foreground_render_layer()

func _draw_pillar_torch_ember_motes(tiles: Array[Vector2i], units: Array[Dictionary]) -> void:
	_record_torches = true
	super._draw_pillar_torch_ember_motes(tiles, units)
	_record_torches = false

func _draw_ambient_particle_sprite(texture: Texture2D, point: Vector2, draw_size: Vector2, rotation: float, alpha: float, modulate: Color = Color.WHITE) -> void:
	if _record_torches: torch_commands.append(["sprite", preload("res://tests/perf/hover_draw_manifest.gd").texture(texture), point, draw_size, rotation, alpha, modulate])
	super._draw_ambient_particle_sprite(texture, point, draw_size, rotation, alpha, modulate)

func _draw_ambient_particle_trail(texture: Texture2D, point: Vector2, velocity: Vector2, draw_size: Vector2, alpha: float, element_id: String) -> void:
	if _record_torches: torch_commands.append(["trail", preload("res://tests/perf/hover_draw_manifest.gd").texture(texture), point, velocity, draw_size, alpha, element_id])
	super._draw_ambient_particle_trail(texture, point, velocity, draw_size, alpha, element_id)
