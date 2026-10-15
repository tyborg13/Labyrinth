extends SceneTree

const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Spell = preload("res://scripts/elemental_spell_fx.gd")
const SurfaceDependencies = preload("res://scripts/board_surface_render_dependencies.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/pixel_fx_fixture.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Metrics = preload("res://tests/pixel_fx_benchmark_metrics.gd")
const TRANSFORM_FIXTURE: Dictionary = {
	"position": Vector2(37.25, 19.75), "scale": Vector2(1.17, 1.17),
	"point": Vector2(200, 200), "size": 100.0, "progress": 0.38,
}
const BOUNDS_FIXTURE: Dictionary = {
	"point": Vector2(700, 600), "size": 200.0,
	"phases": [0.0, 0.03, 0.18, 0.38, 0.58, 0.82, 0.96, 1.0],
	"release_lift": Vector2(0, 80), "travel_offset": Vector2(300, 80), "floor_offset": Vector2(300, 0),
}
const FLOOR_EPSILON: float = 0.0001
var _errors: Array[String]
var _checks: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_data_and_quantizer()
	_benchmark_verdict()
	await _line_submission_lifetime()
	await _board_integration()
	await _blend_and_transforms()
	await _geometry_bounds()
	Pixel.review_enabled_override = null
	for error: String in _errors:
		push_error(error)
	print("PIXEL FX TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _errors.is_empty() else "FAIL", _checks, _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _data_and_quantizer() -> void:
	var data: Dictionary = Pixel.style()
	_expect(data["pixel_style_enabled"] == true, "Review style defaults on")
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Pixel.STYLE_PATH))
	var alpha_floor: float = authored["alpha_floor"]
	var alpha_bias: float = authored["alpha_bias"]
	_expect(data == authored, "Runtime style reads the director data without substitutions")
	_expect(alpha_floor >= 0.0 and alpha_floor <= 1.0 and alpha_bias >= 0.0 and alpha_bias <= 1.0, "Valid director alpha parameters")
	_expect(is_equal_approx(Pixel.luminance(Color.RED), 0.299) and is_equal_approx(Pixel.luminance(Color.GREEN), 0.587) and is_equal_approx(Pixel.luminance(Color.BLUE), 0.114), "CPU luminance pins Rec.601 weights")
	_expect(Pixel.QUANTIZE.code.contains("vec3(0.299, 0.587, 0.114)"), "GPU luminance pins Rec.601 weights")
	var expected_half: int = 0
	for threshold: int in Pixel.BAYER:
		expected_half += int(0.5 >= alpha_floor and 0.5 > float(threshold) / 16.0 + alpha_bias)
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
				_expect(Pixel.quantize(Color(1, 1, 1, alpha_floor - FLOOR_EPSILON), cell, element).a == 0.0, "No alpha below the floor survives")
		_expect(opaque == expected_half, "Half-alpha Bayer population is derived from director floor/bias")
		_expect(Pixel.quantize(Color(1, 1, 1, alpha_floor - FLOOR_EPSILON), Vector2i.ZERO, element).a == 0.0, "Low-threshold cell just under the floor is transparent")
		_expect(Pixel.quantize(Color(1, 1, 1, alpha_floor + FLOOR_EPSILON), Vector2i.ZERO, element).a == float(alpha_floor + FLOOR_EPSILON > alpha_bias), "Low-threshold cell just over the floor follows Bayer threshold")
	_expect(Pixel.quantize(Color(1, 1, 1, 0.5 + alpha_bias), Vector2i(1, 0), "fire").a == 0.0, "Alpha comparison is strictly greater than threshold")
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
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	await _settle()
	_idle_surface_nodes(board)
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
						_expect(run["element"] == element , "%s retains its original normal blend" % element)
						_expect(run["grid"] == 2 and run["resolution"].x < 960 and run["resolution"].y < 540, "1080p crops the half-resolution target to its geometry box")
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
	viewport.size = Fixture.SIZE
	await _settle()
	await _dragon_and_trap_integration(board, state)
	await _surface_depth(board, state)
	await _surface_ramps(board, state)
	await _line_paths(board)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	await _settle()
	for host: Control in board._retained_render_layers():
		var pixel: Node2D = host.get("_pixel_fx_layer")
		if is_instance_valid(pixel):
			_expect(pixel.snapshot().is_empty(), "Cleared effects leave no retained pixels")
	_idle_surface_nodes(board)
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
			pixel.submit(element, Spell.impact, [element, TRANSFORM_FIXTURE["point"], TRANSFORM_FIXTURE["size"], TRANSFORM_FIXTURE["progress"], 1.0, false, false], Transform2D.IDENTITY, Spell.pixel_bounds(Spell.impact, [element, TRANSFORM_FIXTURE["point"], TRANSFORM_FIXTURE["size"], TRANSFORM_FIXTURE["progress"], 1.0, false, false]))
		pixel.finish()
		await _settle()
		var runs: Array[Dictionary] = pixel.snapshot()
		_expect(runs.size() == 5, "Element changes keep separate ordered layers")
		var grid: int = Pixel.grid_px(height)
		_expect((source.get_global_transform_with_canvas() * pixel.transform).is_equal_approx(Transform2D(0.0, Vector2.ONE * grid, 0.0, Vector2.ZERO)), "Board zoom and fractional pan cannot move the screen grid")
		for index: int in range(runs.size()):
			_expect(runs[index]["element"] == Fixture.ELEMENTS[index], "Element source order retained")
			_expect(runs[index]["grid"] == grid, "Resized host recomputes grid")
			var run: Dictionary = (pixel.get("_runs") as Array)[index]
			var origin: Vector2 = (run["composite"] as Sprite2D).position
			_expect(origin == origin.floor(), "Crop starts on the screen cell grid")
			_expect((run["composite"].material as ShaderMaterial).get_shader_parameter("cell_origin") == origin, "Bayer phase follows screen origin when crops move")
			var screen: Transform2D = source.get_global_transform_with_canvas()
			var composite_screen: Transform2D = screen * pixel.transform * run["composite"].transform
			var raw_screen: Transform2D = run["viewport"].global_canvas_transform
			_expect((composite_screen * raw_screen).is_equal_approx(screen), "Cropped drawing and composite reconstruct the original transform")
	# A physical resize with a fixed logical size exercises viewport stretch,
	# which a plain SubViewport.size test does not cover.
	viewport.size_2d_override = Fixture.SIZE
	viewport.size_2d_override_stretch = true
	viewport.size = Vector2i(3840, 2160)
	pixel.begin(source)
	pixel.submit("fire", Spell.impact, ["fire", TRANSFORM_FIXTURE["point"], 100.0, 0.38, 1.0, false, false], Transform2D.IDENTITY, Spell.pixel_bounds(Spell.impact, ["fire", TRANSFORM_FIXTURE["point"], 100.0, 0.38, 1.0, false, false]))
	pixel.finish()
	await _settle()
	var stretch: Transform2D = viewport.get_stretch_transform()
	_expect(stretch.get_scale() == Vector2(2, 2) and pixel.snapshot()[0]["grid"] == 4, "size_2d_override stretch uses physical height")
	_expect((stretch * source.get_global_transform_with_canvas() * pixel.transform).is_equal_approx(Transform2D(0.0, Vector2.ONE * 4, 0.0, Vector2.ZERO)), "Stretch, board zoom and pan cancel on the screen grid")
	_expect(viewport.size_changed.is_connected(source.queue_redraw), "Resize hook invalidates source draw commands")
	pixel.begin(source)
	pixel.finish()
	_expect(pixel.snapshot().is_empty(), "Unused targets are released")
	viewport.queue_free()
	await process_frame


func _geometry_bounds() -> void:
	# Only the editor/debug engine exposes command bounds. Production cropping
	# uses the portable analytical boxes and never calls this debug API.
	var viewport := SubViewport.new()
	viewport.size = Fixture.SIZE
	root.add_child(viewport)
	var source := Node2D.new()
	viewport.add_child(source)
	var samples: Array[Dictionary]
	var at: Vector2 = BOUNDS_FIXTURE["point"]
	var size: float = BOUNDS_FIXTURE["size"]
	for element: String in Fixture.ELEMENTS:
		for reduced: bool in [false, true]:
			for front: bool in [false, true]:
				for phase: float in BOUNDS_FIXTURE["phases"]:
					var cases: Array = [
						[Spell.floor_light, [element, at, size, 1.0]],
						[Spell.ground, [element, at, size, phase, 1.0]],
						[Spell.impact, [element, at, size, phase, 1.0, reduced, front]],
						[Spell.release, [element, at - BOUNDS_FIXTURE["release_lift"], at, size, phase, 1.0]],
						[Spell.travel, [element, at - BOUNDS_FIXTURE["travel_offset"], at, at - BOUNDS_FIXTURE["floor_offset"], at, size, phase, 1.0]],
					]
					for sample: Array in cases:
						var drawing := Pixel.Drawing.new()
						source.add_child(drawing)
						drawing.commands.append({"draw": sample[0], "args": sample[1], "transform": Transform2D.IDENTITY})
						drawing.queue_redraw()
						samples.append({"drawing": drawing, "bounds": Spell.pixel_bounds(sample[0], sample[1]), "label": "%s %s %.2f reduced=%s front=%s" % [element, (sample[0] as Callable).get_method(), phase, reduced, front]})
	await _settle()
	var nonempty: int = 0
	for sample: Dictionary in samples:
		var actual: Rect2 = RenderingServer.debug_canvas_item_get_rect(sample["drawing"].get_canvas_item())
		if actual.has_area():
			nonempty += 1
			_expect((sample["bounds"] as Rect2).grow(0.001).encloses(actual), "Geometry bounds contain %s: actual=%s box=%s" % [sample["label"], actual, sample["bounds"]])
	_expect(nonempty > 0, "Bounds regression inspected actual renderer command geometry")
	viewport.queue_free()
	await process_frame

func _surface_depth(board: Control, state: Dictionary) -> void:
	for kind: String in ["conduction", "ice_break", "painted", "rubble_break", "electrified_break", "collision"]:
		var sample: Dictionary = Fixture.surface_sample(kind)
		board.call("set_combat_state", sample["state"], [], [], Vector2i(-1, -1), "", "", {}, {}, sample["presentation"])
		await _settle()
		if kind == "conduction":
			var expected: Array[Vector2i] = SurfaceDependencies.changed_tiles({}, sample["presentation"], {"effect": true})
			for tile: Vector2i in board.get("_scene_render_layers_by_tile"):
				var owner: Control = (board.get("_scene_render_layers_by_tile") as Dictionary)[tile]
				var layer: Node2D = owner.get("_surface_feedback_pixel_layer")
				_expect((is_instance_valid(layer) and not layer.snapshot().is_empty()) == expected.has(tile), "Conduction allocates pixel targets only on its exact floor-path owners")
		var host: Control = (board.get("_scene_render_layers_by_tile") as Dictionary)[Fixture.TARGET]
		var base: Node2D = host.get("_surface_base_drawing")
		var feedback: Node2D = host.get("_surface_feedback_pixel_layer")
		_expect(base.show_behind_parent and feedback.show_behind_parent and base.get_index() < feedback.get_index(), "%s ground < feedback < parent props/units" % kind)
		var required_ground: String = "_surface_electric_layer" if kind == "conduction" or kind == "electrified_break" else "_surface_ice_layer"
		_expect(is_instance_valid(host.get(required_ground)) and (host.get(required_ground) as CanvasItem).visible, "%s fixture includes visible retained ground" % kind)
		_expect(not feedback.snapshot().is_empty(), "%s submits pixel-styled feedback" % kind)
		for field: String in ["_surface_ice_layer", "_surface_fire_layer", "_surface_electric_layer", "_surface_rubble_layer"]:
			var retained: CanvasItem = host.get(field)
			if is_instance_valid(retained) and retained.visible:
				_expect(retained.show_behind_parent and retained.get_index() < base.get_index(), "%s retained ground remains below feedback" % kind)
		var ended: Dictionary = sample["presentation"].duplicate(true)
		ended["surface_feedback_progress"] = 1.0
		ended["effect_progress"] = 1.0
		board.call("set_combat_state", sample["state"], [], [], Vector2i(-1, -1), "", "", {}, {}, ended)
		await _settle()
		_idle_surface_nodes(board)
	var fan: Dictionary = Fixture.dragon_fan_effect()
	_expect((fan["tiles"] as Array).size() == 12, "Benchmark fan has twelve tiles")
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"effect": fan, "effect_progress": 0.62})
	await _settle()
	var pixels: int = 0
	var layer_count: int = 0
	for tile: Vector2i in fan["tiles"]:
		for mapping: Dictionary in [board.get("_scene_back_effect_render_layers_by_tile"), board.get("_scene_front_effect_render_layers_by_tile")]:
			var host: Control = mapping[tile]
			var layer: Node2D = host.get("_pixel_fx_layer")
			_expect(is_instance_valid(layer) and not layer.snapshot().is_empty(), "Twelve-tile fan reaches every tile's front/back pixel pass")
			if not is_instance_valid(layer): continue
			for run: Dictionary in layer.snapshot():
				var resolution: Vector2i = run["resolution"]
				pixels += resolution.x * resolution.y
				layer_count += 1
	_expect(layer_count >= 24 and pixels < layer_count * 960 * 540 / 2, "Fan cropped targets use less than half the former full-screen texels")
	print("PIXEL FX FAN TARGETS: %d layers, %d cropped texels (%d full-screen texels)" % [layer_count, pixels, layer_count * 960 * 540])
	var telegraphs: Control = board.get("_effects_telegraph_render_layer")
	var effects: Control = board.get("_effects_render_layer")
	_expect(telegraphs.get_index() < effects.get_index(), "Telegraphs precede effect composites and labels")
	var action: Control = board.get("_action_floor_render_layer")
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"trap_effects": [{"element": "fire", "pos": Fixture.TARGET}, {"element": "ice", "pos": Fixture.TARGET}], "effect_progress": 0.52})
	await _settle()
	# The headless board has no imported trap textures; inject a debug-only
	# texture through the same production lookup to exercise native ordering.
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var textures: Array[Texture2D]
	textures.append(ImageTexture.create_from_image(image))
	(action.get("_trap_activation_frames") as Dictionary)["fire"] = textures
	(action.get("_trap_activation_frames") as Dictionary)["ice"] = textures
	action.queue_redraw()
	await _settle()
	var pixel: Node2D = action.get("_pixel_fx_layer")
	var runs: Array = pixel.get("_runs")
	var raw: Array = pixel.get("_raw_drawings")
	_expect(pixel.show_behind_parent and raw.size() == 2 and runs.size() >= 2, "Trap activation textures retain native ordered slots")
	if raw.size() == 2 and runs.size() >= 2:
		_expect(runs[0]["composite"].get_index() < raw[0].get_index() and raw[0].get_index() < runs[1]["composite"].get_index() and runs[1]["composite"].get_index() < raw[1].get_index(), "Each trap activation follows its own pixels and precedes the next trap")

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)

func _idle_surface_nodes(board: Control) -> void:
	var count: int = board.find_children("SurfaceGround", "", true, false).size() + board.find_children("SurfaceFeedbackPixels", "", true, false).size()
	_expect(count == 0, "Idle board has zero SurfaceGround/SurfaceFeedbackPixels nodes after creation and after feedback")

func _surface_ramps(board: Control, state: Dictionary) -> void:
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Pixel.STYLE_PATH))["surface_ramps"]
	for surface: String in ["fire", "ice", "water", "electrified", "rubble"]:
		_expect((Pixel.style()["ramps"] as Dictionary).has(mapping[surface]), "Surface mapping names an existing ramp")
		var primary: Dictionary = Fixture.effect("fire" if surface == "water" else mapping[surface])
		var events: Array[Dictionary] = preload("res://scripts/combat_outcome_feedback.gd").prepare([{"kind": "surface_created", "surface": surface, "tile": Fixture.TARGET}], primary)
		_expect(str(events[0]["feedback_element"]).is_empty(), "Prepared primary-covered surface fixture suppresses its duplicate impact")
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"effect": primary, "effect_progress": 0.62, "surface_feedback_events": events, "surface_feedback_progress": 0.38})
		await _settle()
		var host: Control = (board.get("_scene_render_layers_by_tile") as Dictionary)[Fixture.TARGET]
		var runs: Array = host.get("_surface_feedback_pixel_layer").snapshot()
		_expect(runs.size() == 1 and runs[0]["element"] == mapping[surface], "Covered %s glow uses its data-mapped surface ramp" % surface)

func _line_paths(board: Control) -> void:
	for kind: String in ["conduction", "chain", "tether", "lightning"]:
		var sample: Dictionary = Fixture.surface_sample("conduction")
		if kind == "lightning":
			sample = {"state": Fixture.combat_state(), "presentation": Fixture.presentation("lightning", 0.62)}
		elif kind != "conduction":
			sample = Fixture.line_sample(kind)
		board.call("set_combat_state", sample["state"], [], [], Vector2i(-1, -1), "", "", {}, {}, sample["presentation"])
		await _settle()
		var strokes: int = 0
		for node: Node in board.find_children("LineCells", "", true, false):
			for run: Dictionary in node.get_parent().get_parent().get("_runs"):
				var drawing: Pixel.Drawing = run["drawing"]
				if drawing.line_canvas == node and not drawing.line_canvas.strokes.is_empty():
					_expect(drawing.line_canvas.drawn_frame == drawing.drawn_frame, "%s core and original primitives submit in the same frame" % kind)
			for stroke: Dictionary in node.get("strokes"):
				strokes += 1
				var points: PackedVector2Array = stroke["points"]
				var vertices: PackedVector2Array = stroke["vertices"]
				_expect(points.size() == vertices.size() and points.size() > 1, "%s sends authored vertices, not CPU-rasterized cells" % kind)
				for index: int in range(points.size()):
					_expect(points[index] == vertices[index].floor() + Vector2(0.5, 0.5), "%s retains every zigzag vertex on the screen cell grid" % kind)
				_expect((stroke["core"] as Color).a >= float(Pixel.style()["alpha_floor"]) or (stroke["halo"] as Color).a >= float(Pixel.style()["alpha_floor"]), "%s retains only visible core/halo strokes" % kind)
				_expect(node.get("viewport") != null, "%s reaches its low-resolution GPU target" % kind)
		_expect(strokes > 0, "%s production path uses pixel line rendering" % kind)

func _line_submission_lifetime() -> void:
	# Current-frame vertices are the only per-layer storage. The removed LRU
	# and _cached_quads accounting cannot silently retain idle geometry.
	_expect(not FileAccess.file_exists("res://scripts/pixel_fx_line_batch.gd"), "CPU mesh cache and its stale accounting are removed")
	var viewport := SubViewport.new()
	viewport.size = Fixture.SIZE
	root.add_child(viewport)
	var source := Node2D.new()
	viewport.add_child(source)
	var pixel := Pixel.new()
	source.add_child(pixel)
	var points := PackedVector2Array([Vector2(100.25, 200.75), Vector2(250.5, 180.25), Vector2(300.75, 220.5)])
	var floor_alpha: float = float(Pixel.style()["alpha_floor"])
	for alpha: float in [floor_alpha - FLOOR_EPSILON, floor_alpha, floor_alpha + FLOOR_EPSILON]:
		pixel.begin(source)
		pixel.submit("lightning", Pixel.draw_line_command, [points, Color(1, 1, 1, alpha), Color(1, 1, 1, 0)], Transform2D.IDENTITY)
		pixel.finish()
		await _settle()
		var lines: Node2D = pixel.get_node("QuantizedPixels/LineCells")
		_expect((lines.get("strokes") as Array).size() == int(alpha >= floor_alpha), "Core ends below alpha_floor, including before the animation's last frame")
		_expect((lines.get("viewport") != null) == (alpha >= floor_alpha), "Invisible line strokes allocate no target")
	# Retain a non-line run: finish/draw must release the previous line target.
	pixel.begin(source)
	pixel.submit("lightning", _draw_plain_pixel_fixture, [], Transform2D.IDENTITY)
	pixel.finish()
	await _settle()
	var lines: Node2D = pixel.get_node("QuantizedPixels/LineCells")
	_expect((lines.get("strokes") as Array).is_empty() and lines.get("viewport") == null and lines.get_child_count() == 0, "A non-line frame releases all old line vertices and GPU nodes")
	pixel.begin(source)
	pixel.finish()
	await _settle()
	_expect(pixel.snapshot().is_empty() and pixel.find_children("LinePixels", "", true, false).is_empty(), "Empty finish releases all line targets")
	# Parsed ramps are shared globally, bounded by authored ramp identities.
	for index: int in range(100): Pixel.ramp_for("unknown_%d" % index)
	_expect((Pixel._ramps as Dictionary).size() <= (Pixel.style()["ramps"] as Dictionary).size(), "Fallback names cannot grow the shared parsed-ramp cache")
	viewport.queue_free()
	await process_frame

func _draw_plain_pixel_fixture(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(10, 10, 20, 20), Color.WHITE)

func _benchmark_verdict() -> void:
	var phases: Dictionary = {}
	for index: int in range(180):
		var phase: float = Metrics.unique_progress(index, 180)
		_expect(phase > 0.0 and phase < 1.0 and not phases.has(phase), "CPU benchmark advances through unique live progress values")
		phases[phase] = true
	for index: int in range(45):
		_expect(not phases.has((float(index) + 0.25) / 45), "CPU sample phases are disjoint from warmup")
	_expect(Metrics.submission_verdict({"paired_delta": {"median_ms": 0.3, "p95_ms": 1.0}}, 0.3, 1.0)["passed"], "CPU median/p95 boundary passes")
	_expect(not Metrics.submission_verdict({"paired_delta": {"median_ms": 0.2, "p95_ms": 1.01}}, 0.3, 1.0)["passed"], "CPU gate catches a tail regression even when the median passes")
	_expect(not Metrics.submission_verdict({"paired_delta": {"median_ms": 0.31, "p95_ms": 0.7}}, 0.3, 1.0)["passed"], "CPU gate catches a median regression")
	var samples: Dictionary = {"off": [], "on": []}
	for index: int in range(180):
		samples["off"].append({"gpu": 2.0})
		samples["on"].append({"gpu": 2.45})
	var gpu: Dictionary = Metrics.summarize(samples, "gpu")
	_expect(Metrics.gpu_verdict(gpu, 180, 1.0, true)["passed"], "180/180 valid summed GPU samples pass despite zero-cost child targets")
	for index: int in range(18): samples["on"][index]["gpu"] = 0.0
	gpu = Metrics.summarize(samples, "gpu")
	_expect(Metrics.gpu_verdict(gpu, 180, 1.0, true)["passed"], "Exactly 90% nonzero samples pass")
	_expect(gpu["paired_delta"]["samples"] == 162 and is_equal_approx(gpu["paired_delta"]["median_ms"], 0.45), "Missing samples cannot skew the paired median")
	samples["on"][18]["gpu"] = 0.0
	_expect(not Metrics.gpu_verdict(Metrics.summarize(samples, "gpu"), 180, 1.0, true)["valid_samples"], "Fewer than 90% nonzero samples fail")
	for index: int in range(180): samples["on"][index]["gpu"] = 0.0
	_expect(not Metrics.gpu_verdict(Metrics.summarize(samples, "gpu"), 180, 1.0, true)["passed"], "Completely missing queries fail without an empty-stats error")
	for index: int in range(180): samples["on"][index]["gpu"] = 3.01
	gpu = Metrics.summarize(samples, "gpu")
	_expect(not Metrics.gpu_verdict(gpu, 180, 1.0, true)["passed"], "Valid timestamps still fail a >1 ms 1080p paired median")
	_expect(Metrics.gpu_verdict(gpu, 180, 1.0, false)["passed"], "4K remains report-only")
