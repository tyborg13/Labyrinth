extends RefCounted

## Independent registration oracle. It never asks the texture-origin lookup or
## centre-correction methods under test to construct their expected values.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Source = preload("res://scripts/protagonist_cutout/renderer.gd")
const SAMPLE_PHASE: float = 0.37
const EPSILON_PX: float = 0.001

static func run(board: Control, state: Dictionary, base: Dictionary, expect: Callable) -> void:
	var actor: Dictionary = {}
	for unit: Dictionary in board._visible_units():
		if unit["type"] == "frostglass_lancer": actor = unit.duplicate(); break
	expect.call(not actor.is_empty(), "Travel fixture has a visible Lancer")
	if actor.is_empty(): return
	var origin: Vector2 = board.world_position_for_unit_origin(actor, actor["pos"])
	for direction: Vector2i in [Vector2i(1, 0), Vector2i(0, -1)]:
		var shown: Dictionary = base.duplicate(true)
		var target: Vector2 = board.world_position_for_unit_origin(actor, actor["pos"] + direction)
		Action.movement_frame(shown, str(actor["type"]), str(actor["key"]), origin, target, direction, SAMPLE_PHASE, false)
		_measure(board, state, actor, shown, "move/" + str(direction), expect)
	# Match contact_actions' pre-contact lunge submission: the authored drive
	# lives inside the rig; it must not acquire a second whole-texture translation.
	var lunge: Dictionary = base.duplicate(true)
	var phase: float = float(Action.data_for(str(actor["type"]))["clips"]["lunge"]["contact"]) * 0.5
	lunge["maquette_explicit_clip"] = true
	lunge[str(actor["type"]) + "_motion"] = {actor["key"]: {"clip": "lunge", "phase": phase, "direction": state["player"]["pos"] - actor["pos"]}}
	_measure(board, state, actor, lunge, "lunge", expect)
	# A warmed centre must also reject an in-place logical tile change, even
	# when the caller has not submitted a new snapshot yet.
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, base)
	board._unit_center(actor)
	actor["pos"] += Vector2i(1, 0)
	var raw: Vector2 = board.world_position_for_unit_origin(actor, actor["pos"])
	var expected: Vector2 = _raw_padded_rect(board, actor, raw).position
	expect.call(board._unit_center(actor).distance_to(raw + expected.round() - expected) < EPSILON_PX, "Warmed centre rejects an in-place tile change")
	print("FIX18 TRAVEL: sampled move in two facings and authored lunge")

static func _raw_padded_rect(board: Control, unit: Dictionary, origin: Vector2) -> Rect2:
	var rest: Rect2 = board._unit_draw_rect_for_center(unit, origin)
	var geometry: Dictionary = board.unit_cutout_renderer(unit).canvas_geometry()
	return Rect2(rest.position - rest.size * geometry["offset"] / Source.SOURCE_SIZE, rest.size * Vector2(geometry["size"]) / Source.SOURCE_SIZE)

static func _measure(board: Control, state: Dictionary, actor: Dictionary, shown: Dictionary, label: String, expect: Callable) -> void:
	var original: Dictionary = shown.duplicate(true)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	var renderer: Node = board.unit_cutout_renderer(actor)
	renderer.set_process(false)
	var motion: Dictionary = original[str(actor["type"]) + "_motion"][actor["key"]]
	var snapshot: Dictionary = renderer.snapshot()
	expect.call(snapshot["shown_clip"] == motion["clip"] and is_equal_approx(snapshot["phase"], motion["phase"]), label + ": retained renderer presents the real clip sample")
	expect.call(shown == original, label + ": authored presentation is immutable")
	var raw_center: Vector2 = original.get("unit_world_positions", {}).get(actor["key"], board.world_position_for_unit_origin(actor, actor["pos"]))
	var texture_origin: Vector2 = original.get("unit_texture_origins", {}).get(actor["key"], raw_center)
	var expected: Rect2 = _raw_padded_rect(board, actor, texture_origin)
	var correction: Vector2 = expected.position.round() - expected.position
	expected.position = expected.position.round()
	expect.call(correction.length() > EPSILON_PX, label + ": correction negative control is nonzero")
	var tile: Vector2i = board._effective_unit_tile(actor)
	var layer: Control = board._scene_render_layers_by_tile[tile]
	var drawn: Dictionary = {}
	for candidate: Dictionary in layer._units_by_draw_tile_cache.get(tile, []):
		if candidate["key"] == actor["key"]: drawn = candidate; break
	expect.call(not drawn.is_empty(), label + ": retained renderer submits the actor")
	if drawn.is_empty(): return
	var center: Vector2 = layer._unit_center(drawn)
	var actual: Rect2 = layer._unit_texture_draw_rect(drawn, center)
	expect.call(actual.position.distance_to(expected.position) < EPSILON_PX and actual.size.distance_to(expected.size) < EPSILON_PX, "FIX18 TRAVEL TEXTURE ORIGIN " + label)
	expect.call(center.distance_to(raw_center + correction) < EPSILON_PX, "FIX18 TRAVEL BODY CORRECTION " + label)
	var hud_found: bool = false
	for entry: Dictionary in layer._hud_layout_entries_cache:
		if entry["actor_key"] != actor["key"]: continue
		hud_found = true
		expect.call((entry["center"] as Vector2).distance_to(raw_center + correction) < EPSILON_PX, "FIX18 TRAVEL HUD CORRECTION " + label)
		expect.call((entry["center"] as Vector2).distance_to(center) < EPSILON_PX, label + ": body and HUD share one correction")
	expect.call(hud_found, label + ": retained HUD entry exists")
