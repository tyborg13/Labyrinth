extends SceneTree
## The live-code receipts below are independent of the warmup recipe manifest.
## Signals for native Label, Sprite2D and MeshInstance2D inspect their inputs
## on NOTIFICATION_DRAW. GDScript submissions record their actual arguments.

const Warm = preload("res://scripts/canvas_pipeline_prewarm.gd")
const LiveBoard = preload("live_board_shapes.gd")
const Sample = preload("res://scripts/canvas_pipeline_sample.gd")
const Atmosphere = preload("res://scripts/combat_atmosphere.gd")
const Menu = preload("res://scenes/main_menu.tscn")
const Run = preload("res://scenes/run_scene.tscn")
const RNG_SEED := 165
const RECT := ["rect", {"textured": false}]
const TEXTURE_RECT := ["texture_rect", {"textured": true}]
const PATCH := ["nine_patch", {"textured": true, "has_margins": true}]
const FLAT_POLYGON := ["polygon", {"uv": false, "textured": false, "per_vertex_color": false, "clip": false}]
const COLOUR_POLYGON := ["polygon", {"uv": false, "textured": false, "per_vertex_color": true, "clip": false}]
const UV_POLYGON := ["polygon", {"uv": true, "textured": true, "per_vertex_color": true, "clip": false}]
const UV_SOLID_POLYGON := ["polygon", {"uv": true, "textured": true, "per_vertex_color": false, "clip": false}]
const AA_LINE := ["polyline", {"antialias": true, "wide": true, "uv": false}]
const STROKE_LINE := ["polyline", {"antialias": false, "wide": true, "uv": false}]
const LIVE := {
	# menu_run_transition.begin: ordinary outline + bitmap glyph rects, and shade.
	"loading stone text": [["glyph_quads", {"msdf": false, "outline": true}]],
	"loading shade": [RECT],
	# section_map_panel._build_ui / section_map_canvas._draw.
	"section map fog": [RECT],
	"section map routes": [AA_LINE, FLAT_POLYGON],
	"opening dialogue portrait clip": [TEXTURE_RECT],
	# combat_board_view._draw_static_board_contents, _draw_world_texture,
	# _draw_floor_contact_shading, _unit_shadow_draw_mesh,
	# _flush_ambient_particle_batch, and _draw_move_path_gradient_disc.
	"board cel colour rectangles": [RECT],
	"board cel textured polygons": [UV_POLYGON],
	"board cel colour polygons": [COLOUR_POLYGON],
	"board cel ambient mesh": [["mesh", {"uv": true, "color": true, "indexed": true, "position_2d": false, "textured": true, "primitive": Mesh.PRIMITIVE_TRIANGLES}]],
	"board cel primitive": [["primitive", {"vertices": 3, "uv": false, "textured": false}]],
	# _draw_floor_tile and _draw_floor_contact_shading under cache_bake_material.
	"board floor bake backdrop": [RECT],
	"board floor bake tile art": [UV_SOLID_POLYGON],
	"board floor composite": [TEXTURE_RECT],
	"board atmosphere": [RECT],
	# CardFrameReflection, RarityGemGlow, _soft_texture_glow and the hand cache.
	"card frame reflection": [PATCH],
	"card rarity gem": [RECT],
	"card action context glow": [TEXTURE_RECT],
	"card hand cache composite": [TEXTURE_RECT],
	"card drawing in hand cache": [PATCH],
	# targeted_tile_highlight._draw and the board silhouette Sprite2Ds.
	"board targeting ink": [RECT],
	"board unit occlusion and team ink": [TEXTURE_RECT],
	# PortraitMask._draw, turn_order_portrait_clip.refresh and coverage.update.
	"turn-order polygon clip": [["polygon", {"uv": false, "textured": false, "per_vertex_color": false, "clip": true}], TEXTURE_RECT],
	"turn-order portrait ink": [TEXTURE_RECT],
	"turn-order portrait coverage": [FLAT_POLYGON],
	"board surface particles": [["mesh", {"uv": true, "color": false, "indexed": true, "position_2d": true, "textured": true, "primitive": Mesh.PRIMITIVE_TRIANGLES}]],
	"board electric surface": [["mesh", {"uv": true, "color": true, "indexed": true, "position_2d": true, "textured": false, "primitive": Mesh.PRIMITIVE_TRIANGLES}]],
	# PixelFxLines.StrokeDrawing, PixelFxLayer composite and StrikeTrailFx.draw.
	"pixel trail geometry": [STROKE_LINE, RECT],
	"pixel trail composite": [TEXTURE_RECT],
	"strike trail additive triangles": [["triangle_array", {"uv": false, "textured": false, "indexed": true}]],
	# CPUParticles2D::_update_mesh_texture/set_amount/_notification — 4.6.1.
	"atmosphere additive particles": [["multimesh", {"uv": true, "color": true, "indexed": true, "position_2d": true, "textured": true, "primitive": Mesh.PRIMITIVE_TRIANGLES, "instance_2d": true, "instance_color": true, "instance_custom": true}]],
	"enemy shadow dissolve": [TEXTURE_RECT],
	"wisp straight alpha conversion": [TEXTURE_RECT],
}

var _failures: Array[String]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Warm.VIEWPORT_SIZE
	root.add_child(viewport)
	var texture := Sample.texture_for_samples()
	var recipes := Warm.Recipes.for_phase(Warm.Recipes.Phase.LOADING_COVER, true)
	var actual: Dictionary = {}
	var live := LIVE.duplicate()
	var shadow := LiveBoard.shadow_format(texture)
	var floor := LiveBoard.floor_formats()
	live["board cel shadow mesh"] = [shadow["command"]]
	live["board floor bake shade and grid"] = floor
	var shadow_exact := false
	seed(RNG_SEED)
	var control := Atmosphere.build_motes(1)
	var expected_seed := control.seed
	control.free()
	seed(RNG_SEED)
	for recipe: Dictionary in recipes:
		var name: String = recipe["name"]
		var commands: Array = []
		var item := Sample.build(recipe, texture, func(command: String, format: Dictionary) -> void: commands.append([command, format]))
		actual[name] = commands
		if item == null:
			_failures.append(name + " had no cached sample")
			continue
		if name == "board cel shadow mesh":
			shadow_exact = item.mesh.surface_get_format(0) == shadow["flags"] and item.material.shader == shadow["shader"]
		viewport.add_child(item)
	await process_frame
	await process_frame
	var after := Atmosphere.build_motes(1)
	var actual_seed := after.seed
	after.free()
	if expected_seed != actual_seed: _failures.append("Warmup advanced global RNG")
	print("PERF165 RNG: %s control=%d after_warmup=%d" % ["PASS" if expected_seed == actual_seed else "FAIL", expected_seed, actual_seed])
	var submitted_floor: Array = actual.get("board floor bake shade and grid", [])
	var floor_exact := not floor.is_empty() and _same_formats(floor, submitted_floor)
	if not shadow_exact: _failures.append("Warm shadow mesh format or shader differs from the live mesh")
	print("PERF165 LIVE BOARD FORMATS: %s (shadow_flags=%d; floor_formats=%d)" % [
		"PASS" if shadow_exact and floor_exact else "FAIL", shadow["flags"], floor.size()])
	for name: String in live:
		if not _same_formats(live[name], actual.get(name, [])):
			_failures.append("%s expected %s, submitted %s" % [name, live[name], actual.get(name)])
	if actual.size() != live.size(): _failures.append("Recipe count changed without live command coverage")
	for failure: String in _failures: push_error(failure)
	print("PERF165 COMMAND SHAPES: %s (%d recipes; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", actual.size(), _failures.size()])
	viewport.free()
	quit(0 if _failures.is_empty() else 1)

func _same_formats(expected: Array, actual: Array) -> bool:
	if expected.size() != actual.size(): return false
	var remaining := actual.duplicate()
	for command: Array in expected:
		var index := remaining.find(command)
		if index < 0: return false
		remaining.remove_at(index)
	return true
