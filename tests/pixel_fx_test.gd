extends SceneTree

const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Spell = preload("res://scripts/elemental_spell_fx.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/pixel_fx_fixture.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const TRANSFORM_FIXTURE: Dictionary = {
	"position": Vector2(37.25, 19.75), "scale": Vector2(1.17, 1.17),
	"point": Vector2(200, 200), "size": 100.0, "progress": 0.38,
}
var _errors: Array[String]
var _checks: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_data_and_quantizer()
	await _board_integration()
	await _blend_and_transforms()
	Pixel.review_enabled_override = null
	for error: String in _errors:
		push_error(error)
	print("PIXEL FX TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _errors.is_empty() else "FAIL", _checks, _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _data_and_quantizer() -> void:
	var data: Dictionary = Pixel.style()
	_expect(data["pixel_style_enabled"] == true, "Review style defaults on")
	_expect(data["grid_px_at_1080"] == 2 and data["alpha_floor"] == 0.08 and data["alpha_bias"] == 0.0, "Director scalar data must be exact")
	_expect((data["ramps"] as Dictionary).size() == 6, "Five elements plus neutral")
	_expect(Pixel.grid_px(1080) == 2 and Pixel.grid_px(1440) == 3 and Pixel.grid_px(2160) == 4 and Pixel.grid_px(1) == 1, "Grid rounds and clamps at all required heights")
	for element: String in data["ramps"]:
		var ramp: PackedColorArray = Pixel.ramp_for(element)
		_expect(ramp.size() == 5, "%s five colors" % element)
		for index: int in range(ramp.size()):
			_expect(ramp[index].a == 1.0, "%s opaque ramp" % element)
			if index > 0:
				_expect(Pixel.luminance(ramp[index - 1]) < Pixel.luminance(ramp[index]), "%s strictly increasing luminance" % element)
		var seen: Dictionary = {}
		for x: int in range(256):
			var gray: float = float(x) / 255.0
			var output: Color = Pixel.quantize(Color(gray, gray, gray, 1.0), Vector2i(x, 0), element)
			_expect(ramp.has(output), "%s gradient stays exactly in the ramp" % element)
			seen[output] = true
			for candidate: Color in ramp:
				_expect(absf(Pixel.luminance(output) - gray) <= absf(Pixel.luminance(candidate) - gray) + 0.000001, "Nearest Rec.601 entry")
		_expect(seen.size() == 5, "%s gradient visits every ramp entry" % element)
		var opaque: int = 0
		for y: int in range(4):
			for x: int in range(4):
				var cell := Vector2i(x, y)
				var output: Color = Pixel.quantize(Color(0.5, 0.5, 0.5, 0.5), cell, element)
				opaque += int(output.a)
				_expect(output == Pixel.quantize(Color(0.5, 0.5, 0.5, 0.5), cell + Vector2i(4, 4), element), "Bayer phase repeats without time dependence")
				_expect(Pixel.quantize(Color(1, 1, 1, 0.079), cell, element).a == 0.0, "No alpha below the floor survives")
		_expect(opaque == 8, "Half alpha produces exactly eight opaque Bayer cells")
	_expect(Pixel.quantize(Color(1, 1, 1, 0.5), Vector2i(1, 0), "fire").a == 0.0, "Alpha comparison is strictly greater than threshold")
	_expect(Pixel.ramp_for("") == Pixel.ramp_for("neutral"), "Missing element uses neutral")
	var canvas := Node2D.new()
	_expect(not Pixel.route(canvas, "fire", Spell.impact, []), "Unregistered geometry probes remain raw")
	canvas.free()
	_expect(not Pixel.route(null, "fire", Spell.impact, []), "Zero-envelope null-canvas contract is preserved")

func _board_integration() -> void:
	var viewport := SubViewport.new()
	viewport.size = Fixture.SIZE
	root.add_child(viewport)
	var board := Board.new()
	board.size = Fixture.SIZE
	viewport.add_child(board)
	await process_frame
	var state: Dictionary = Fixture.combat_state()
	for element: String in Fixture.ELEMENTS:
		for reduced: bool in [false, true]:
			for aoe: bool in [false, true]:
				Pixel.review_enabled_override = true
				board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, Fixture.presentation(element, 0.62, reduced, aoe))
				await _settle()
				var back: Control = board._scene_back_effect_render_layers_by_tile[Fixture.TARGET]
				var unit: Control = board._scene_render_layers_by_tile[Fixture.TARGET]
				var front: Control = board._scene_front_effect_render_layers_by_tile[Fixture.TARGET]
				_expect(back.get_index() < unit.get_index() and unit.get_index() < front.get_index(), "%s retains back/unit/front order" % element)
				for host: Control in [back, front]:
					var pixel: Node2D = host.get("_pixel_fx_layer")
					_expect(is_instance_valid(pixel) and pixel.get_parent() == host, "%s pixel composite stays at the original tile depth" % element)
					if not is_instance_valid(pixel):
						continue
					var runs: Array[Dictionary] = pixel.snapshot()
					_expect(runs.size() == 1, "%s reduced=%s aoe=%s host=%s adjacent same-element commands share one layer: %s" % [element, reduced, aoe, host.name, runs])
					for run: Dictionary in runs:
						_expect(run["element"] == element and not run["additive"], "%s retains its original normal blend" % element)
						_expect(run["grid"] == 2 and run["resolution"] == Vector2i(960, 540), "1080p creates half-resolution layer")
						_expect(run["commands"] > 0 and run["drawn_frame"] == run["submitted_frame"], "Routing must draw geometry in the same process frame")
				Pixel.review_enabled_override = false
				board._queue_dynamic_redraw()
				await _settle()
				for host: Control in [back, front]:
					var pixel: Node2D = host.get("_pixel_fx_layer")
					_expect(pixel.snapshot().is_empty(), "Style off releases pixel layers and renders original geometry")
	Pixel.review_enabled_override = true
	# A physical viewport resize must refresh retained pixel layers even when
	# the board's logical Control size and its presentation stay unchanged.
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, Fixture.presentation("fire", 0.62))
	await _settle()
	viewport.size = Vector2i(2560, 1440)
	await _settle()
	var rear: Control = board._scene_back_effect_render_layers_by_tile[Fixture.TARGET]
	_expect((rear.get("_pixel_fx_layer").snapshot() as Array)[0]["grid"] == 3, "Viewport-only resize refreshes the retained screen grid")
	var source_material: Material = rear.material
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rear.material = additive_material
	rear.queue_redraw()
	await _settle()
	_expect((rear.get("_pixel_fx_layer").snapshot() as Array)[0]["additive"], "Production routing detects the source's additive material")
	rear.material = source_material
	await _dragon_and_trap_integration(board, state)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	await _settle()
	for host: Control in board._retained_render_layers():
		var pixel: Node2D = host.get("_pixel_fx_layer")
		if is_instance_valid(pixel):
			_expect(pixel.snapshot().is_empty(), "Cleared effects leave no retained pixels")
	viewport.queue_free()
	await process_frame

func _dragon_and_trap_integration(board: Control, state: Dictionary) -> void:
	var dragons: Dictionary = {"fire": "vyraketh", "ice": "iskaldra", "lightning": "zekarion", "air": "vaeloryx", "earth": "tharokh"}
	for element: String in Fixture.ELEMENTS:
		var effect: Dictionary = Fixture.effect(element, true)
		effect.erase("ground_burst")
		effect.erase("burst_tiles")
		effect["enemy_type"] = dragons[element]
		effect["action_type"] = "pull" if element == "air" else "ranged"
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"effect": effect, "effect_progress": 0.62})
		await _settle()
		for mapping: Dictionary in [board.get("_scene_back_effect_render_layers_by_tile"), board.get("_scene_front_effect_render_layers_by_tile")]:
			var host: Control = mapping[Fixture.TARGET]
			var runs: Array = host.get("_pixel_fx_layer").snapshot()
			_expect(runs.size() == 1 and runs[0]["element"] == element, "%s dragon presentation reaches its elemental pixel ramp at both depths" % element)
	var traps: Array = [{"element": "fire", "pos": Fixture.TARGET}, {"element": "ice", "pos": Fixture.TARGET}]
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"trap_effects": traps, "effect_progress": 0.52})
	await _settle()
	var host: Control = (board.get("_scene_back_effect_render_layers_by_tile") as Dictionary)[Fixture.TARGET]
	var pixel: Node2D = host.get("_pixel_fx_layer")
	var runs: Array = pixel.snapshot()
	_expect(runs.size() == 2 and runs[0]["element"] == "fire" and runs[1]["element"] == "ice", "Overlapping elements retain separate ramps in original submission order")
	for index: int in range(runs.size()):
		var element: String = str(runs[index]["element"])
		var style: String = host.call("_elemental_style_for_element", element)
		var ratio: float = host.call("_trap_elemental_scale_ratio", style)
		var ground: Vector2 = host.call("_tile_center", Fixture.TARGET)
		var expected := Transform2D(0.0, Vector2.ONE * ratio, 0.0, ground * (1.0 - ratio))
		var raw: Node2D = (pixel.get("_runs") as Array)[index]["drawing"]
		_expect(((raw.get("commands") as Array)[0]["transform"] as Transform2D).is_equal_approx(expected), "Trap scale/anchor reaches the original drawing unchanged")
	_expect((host.get("_pixel_fx_draw_transform") as Transform2D).is_equal_approx(Transform2D.IDENTITY), "Trap draw transform is reset after submission")

func _blend_and_transforms() -> void:
	var viewport := SubViewport.new()
	viewport.size = Fixture.SIZE
	root.add_child(viewport)
	var source := Node2D.new()
	source.position = TRANSFORM_FIXTURE["position"]
	source.scale = TRANSFORM_FIXTURE["scale"]
	viewport.add_child(source)
	var pixel := Pixel.new()
	source.add_child(pixel)
	for height: int in [1080, 1440, 2160]:
		viewport.size = Vector2i(height * 16 / 9, height)
		pixel.begin(source)
		for element: String in Fixture.ELEMENTS:
			for additive: bool in [false, true]:
				pixel.submit(element, Spell.impact, [element, TRANSFORM_FIXTURE["point"], TRANSFORM_FIXTURE["size"], TRANSFORM_FIXTURE["progress"], 1.0, false, false], Transform2D.IDENTITY, additive)
		pixel.finish()
		await _settle()
		var runs: Array[Dictionary] = pixel.snapshot()
		_expect(runs.size() == 10, "Element and blend changes keep separate ordered layers")
		var grid: int = Pixel.grid_px(height)
		_expect((source.get_global_transform_with_canvas() * pixel.transform).is_equal_approx(Transform2D(0.0, Vector2.ONE * grid, 0.0, Vector2.ZERO)), "Board zoom and fractional pan cannot move the screen grid")
		for index: int in range(runs.size()):
			_expect(runs[index]["element"] == Fixture.ELEMENTS[index / 2] and runs[index]["additive"] == bool(index % 2), "Mixed normal/additive source order retained")
			_expect(runs[index]["grid"] == grid, "Resized host recomputes grid")
	pixel.begin(source)
	pixel.finish()
	_expect(pixel.snapshot().is_empty(), "Unused targets are released")
	viewport.queue_free()
	await process_frame

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
