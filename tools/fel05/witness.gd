extends "res://tools/fel03/capture.gd"
## Observe production melee in the unchanged fel-01 playback, then freeze extra
## motions on the installed sample board to cover streaks and the Illusion arc.

const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Attack = preload("res://scripts/attack_fx_library.gd")
const Claws = preload("res://scripts/enemy_claw_marks.gd")
const Lines = preload("res://scripts/pixel_fx_lines.gd")
const AREA_PHASES := [0.0, Trail.CONTACT, 1.0]
const CLAW_GRIDS := [0.25, 0.5, 1.0]
const AREA_LABEL := "static reduced area mark"
const WIDTH_SAMPLES := [0.0, 0.25, 0.5, 0.75, 1.0]
const EXPECTED_RAMPS := {
	"none": "strike", "fire": "fire", "ice": "ice", "lightning": "lightning",
	"air": "air", "earth": "earth", "unknown": "neutral",
}
const EXPECTED_PALETTE := [Color8(255, 244, 220), Color8(255, 178, 92), Color8(150, 60, 20)]
const CASES := ["hero sweep", "streak", "enemy sweep", "claw marks", "Illusion arc", AREA_LABEL, "fire sweep", "lightning sweep"]
const STRIKE_RAMP := ["#4a1e0c", "#9a4616", "#e0862a", "#ffc65a", "#fff3d6"]
const STAR_AGES := [0.2, 0.5, 0.8]
const CARDINAL: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var _observed: Dictionary
var _failures: Dictionary
var _elemental_cards: Dictionary
var _sweep_body_seen: bool
var _separated_claws_seen: bool
var _checked_sweep_widths: bool
var _checked_streak_head: bool
var _visible_hero_smear: bool
var _visible_warden_smear: bool

func _initialize() -> void:
	_check(Trail.palette("none") == EXPECTED_PALETTE, "legacy neutral palette changed")
	var ramps: Dictionary = Pixel.style()["ramps"]
	_check(ramps.get("strike") == STRIKE_RAMP, "strike ramp matches authored swatches")
	var shape: Dictionary = Pixel.style()["trail_shape"]
	_check(shape["sweep_peak_cells"] == 5 and shape["smear_reach"] == 0.6 and shape["smear_near_cells"] == 2
		and shape["smear_near_coverage"] == 0.5 and shape["smear_far_coverage"] == 0.25, "authored smear and peak data")
	_audit_star()
	_audit_edge_on_reach()
	var map: Dictionary = Pixel.style().get("trail_ramps", {})
	for element: String in EXPECTED_RAMPS:
		_check(map.get(element, "neutral") == EXPECTED_RAMPS[element], "data mapping for " + element)
	super._initialize()

func _record_frame() -> void:
	super._record_frame()
	if _evidence == null: return
	var board: Control = _run_scene.board_view
	var effect: Dictionary = board.presentation.get("strike_trail_effect", board.presentation.get("effect", {}))
	var kind: String = _evidence._displayed_trail(board, effect, effect.get("protagonist_melee", false))
	match kind:
		"sweep":
			_audit(board, effect, "hero sweep" if effect.get("protagonist_melee", false) else "enemy sweep")
		"claw_marks":
			_audit(board, effect, "claw marks")

func _report(id: String, evidence: Evidence) -> bool:
	if not super._report(id, evidence): return false
	_find_elemental_cards()
	if id.begins_with("01-"):
		_freeze_hero("hero sweep", "sword", false, "none")
		_freeze_hero("streak", "stab", false, "ice")
		_freeze_hero("Illusion arc", "sword", true, "unknown")
		_freeze_hero("fire sweep", "sword", false, "fire")
		_freeze_hero("lightning sweep", "sword", false, "lightning")
		_audit_reduced_area(_run_scene.board_view)
	if id.begins_with("03-"):
		for label: String in CASES:
			_check(_observed.has(label), "missing " + label)
		_check(_sweep_body_seen, "Warden sweep has a visible inner row")
		_check(_separated_claws_seen, "renderable claw masks exercised")
		_check(_checked_sweep_widths, "observed a hero crescent at full contact")
		_check(_checked_streak_head, "observed a two-cell streak head")
		_check(_visible_hero_smear, "hero smear has Bayer-covered cells inside the hilt cap")
		_check(_visible_warden_smear, "Warden edge-on smear has Bayer-covered cells inside the hilt cap")
		print("FEL05 ELEMENTAL MELEE in sample decks: " + ("none" if _elemental_cards.is_empty() else str(_elemental_cards.keys())))
		print("FEL05 WITNESS %s cases=%d failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _observed.size(), _failures.size()])
		for problem: String in _failures: print("FEL05 WITNESS " + problem)
		if not _failures.is_empty():
			quit(1)
			return false
	return true

func _freeze_hero(label: String, motion: String, echo: bool, element: String) -> void:
	var board: Control = _run_scene.board_view
	var state: Dictionary = board.combat_state
	var from: Vector2i = state["player"]["pos"]
	var direction := Vector2i.RIGHT
	var effect := {"kind": "melee", "from": from, "to": from + direction,
		"protagonist_melee": not echo, "illusion_echo": echo,
		"protagonist_weapon_motion": motion, "element": element}
	var shown: Dictionary = board.presentation.duplicate()
	shown.erase("strike_trail_effect")
	shown.erase("strike_trail_progress")
	shown["effect"] = effect
	shown["effect_progress"] = Trail.CONTACT
	shown["protagonist_motion"] = {"clip": "attack", "phase": Trail.CONTACT, "direction": direction}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	_audit(board, effect, label)
	shown["effect"] = {}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)

func _audit(board: Control, effect: Dictionary, label: String) -> void:
	var owner: Control = board.get("_effects_render_layer")
	var layer: Node2D = owner.get("_strike_trail_layer")
	_audit_layer(layer, effect, label)

func _audit_layer(layer: Node2D, effect: Dictionary, label: String) -> void:
	if not is_instance_valid(layer) or (layer.get("_batches") as Array).is_empty(): return
	_observed[label] = true
	_check(layer.show_behind_parent, label + " paints below text")
	_check(not (layer.material is CanvasItemMaterial and layer.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD), label + " uses additive blending")
	if not layer.has_method("pixel_snapshot"):
		_check(false, label + " bypasses the pixel layer and submits glow geometry")
		return
	var sample: Dictionary = layer.call("pixel_snapshot")
	var element: String = str(effect.get("element", "none"))
	_check(sample.get("ramp") == EXPECTED_RAMPS.get(element, "neutral"), label + " uses the configured ramp")
	_check(sample.get("grid") == Pixel.grid_px(Checkpoint.VIEWPORT_SIZE.y), label + " uses the screen cell grid")
	_check(sample.get("commands") == 1, label + " routes through one pixel submission")
	_check(sample.get("glow") == false, label + " has only core geometry")
	var ramp: PackedColorArray = Pixel.ramp_for(EXPECTED_RAMPS.get(element, "neutral"))
	var swatches := PackedColorArray([ramp[2], ramp[2], ramp[2], ramp[3], ramp[4]])
	_check(sample.get("palette") == swatches, label + " can output only ramp steps 2–4")
	var grid := Transform2D(0.0, Vector2.ONE / float(sample["grid"]), 0.0, Vector2.ZERO)
	var to_cells: Transform2D = grid * layer.get_viewport().get_stretch_transform() * layer.get_global_transform_with_canvas()
	var floor_value: float = Pixel.style()["alpha_floor"]
	var bayer: PackedFloat32Array = Pixel.trail_thresholds()
	for batch: Dictionary in layer.get("_batches"):
		if batch.get("shape") in ["crescent", "streak"]:
			_check(sample.get("direct_cells") == true, label + " submits final cells without a second quantize pass")
			_audit_profile(batch, to_cells, floor_value, bayer, label)
		elif batch.get("shape") == "claws":
			_audit_claws(batch, to_cells, floor_value, bayer, ramp, label)

func _audit_profile(batch: Dictionary, to_cells: Transform2D, floor_value: float,
		bayer: PackedFloat32Array, label: String) -> void:
	var profile: Dictionary = Lines.trail_profile(batch, to_cells, floor_value, bayer, Pixel.style()["trail_shape"], true)
	var cells: Array[Vector2i] = profile["spine"]
	if cells.is_empty(): return
	var normals: Array[Vector2i] = profile["normals"]
	var widths: PackedInt32Array = profile["widths"]
	var bands: Array[Array] = profile["bands"]
	var painted: Dictionary
	for band: int in bands.size():
		for rect: Rect2i in bands[band]:
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					painted[Vector2i(x, y)] = band + 2
	for index: int in range(1, cells.size()):
		var step: Vector2i = (cells[index] - cells[index - 1]).abs()
		_check(maxi(step.x, step.y) == 1, label + " has a connected spine")
		if index >= 2 and widths[index - 1] == 1:
			var span: Vector2i = (cells[index] - cells[index - 2]).abs()
			_check(span != Vector2i.ONE or _manhattan(cells[index - 1] - cells[index - 2]) != 1
				or step.x + step.y != 1, label + " has no doubled one-cell corner")
	if batch["shape"] == "streak":
		_check(widths[-1] == 2 and painted.get(cells[-1]) == 4 and painted.get(cells[-1] + normals[-1]) == 3,
			"streak head has one light edge cell and one gold body cell")
		_checked_streak_head = true
		return
	var descending: bool = false
	for i: int in cells.size():
		_check(painted.get(cells[i]) == 4, label + " paints the outer edge on step 4")
		if i == 0: continue
		if widths[i] < widths[i - 1]: descending = true
		_check(not descending or widths[i] <= widths[i - 1], label + " has one width peak")
	var smear_count: int = _audit_smear(profile, float(batch["alpha"]), label, painted)
	if label == "hero sweep": _visible_hero_smear = _visible_hero_smear or smear_count > 0
	if label == "enemy sweep": _visible_warden_smear = _visible_warden_smear or smear_count > 0
	if label == "enemy sweep":
		_sweep_body_seen = _sweep_body_seen or painted.values().has(3)
	if label == "hero sweep" and not _checked_sweep_widths and is_equal_approx(batch["alpha"], 1.0) and cells.size() > 12:
		var observed: Array[int]
		var extent: int = cells.size() - 1
		for s: float in WIDTH_SAMPLES:
			var index: int = roundi(s * extent)
			observed.append(widths[index])
			_check(widths[index] == maxi(1, roundi(5.0 * sin(PI * float(index) / extent))),
				"hero sweep retains the authored five-cell profile")
		var center: int = roundi(0.5 * (cells.size() - 1))
		var center_inks: Array[int]
		for depth: int in widths[center]:
			center_inks.append(int(painted.get(cells[center] + normals[center] * depth, -1)))
		_check(center_inks == [4, 3, 3, 2, 2], "hero midpoint paints the five strike colours in order")
		_checked_sweep_widths = true
		print("FEL05 CRESCENT WIDTHS %s STRIKE STEPS %s" % [observed, center_inks])

func _audit_smear(profile: Dictionary, alpha: float, label: String, body: Dictionary) -> int:
	var allowed: Array[Dictionary] = [{}, {}]
	var spine: Array[Vector2i] = profile["spine"]
	var normals: Array[Vector2i] = profile["normals"]
	var widths: PackedInt32Array = profile["widths"]
	var reaches: Array[int] = profile["reaches"]
	var settings: Dictionary = Pixel.style()["trail_shape"]
	for i: int in spine.size():
		for depth: int in range(widths[i], reaches[i] + 1):
			var tier: int = 0 if depth - widths[i] < int(settings["smear_near_cells"]) else 1
			allowed[tier][spine[i] + normals[i] * depth] = true
	var count: int = 0
	var smear: Array[Array] = profile["smear"]
	for tier: int in smear.size():
		var coverage: float = alpha * float(settings["smear_near_coverage"] if tier == 0 else settings["smear_far_coverage"])
		for rect: Rect2i in smear[tier]:
			for x: int in range(rect.position.x, rect.end.x):
				for y: int in range(rect.position.y, rect.end.y):
					var cell := Vector2i(x, y)
					_check(allowed[tier].has(cell), label + " smear stays within its hilt reach and coverage tier")
					var threshold: float = float(Pixel.BAYER[(y & 3) * 4 + (x & 3)]) / 16.0
					if coverage > threshold and not body.has(cell): count += 1
	return count

func _audit_edge_on_reach() -> void:
	# The hilt vector is parallel to the edge-on stroke. A perpendicular
	# projection would leave no room for the specified smear.
	const BLADE_LENGTH: float = 20.0
	var batch := {"shape": "crescent", "points": PackedVector2Array([Vector2(0, 20), Vector2.ZERO]),
		"hilt": PackedVector2Array([Vector2(0, BLADE_LENGTH), Vector2(0, BLADE_LENGTH)]), "alpha": 1.0}
	var settings: Dictionary = Pixel.style()["trail_shape"]
	var profile: Dictionary = Lines.trail_profile(batch, Transform2D.IDENTITY, float(Pixel.style()["alpha_floor"]),
		Pixel.trail_thresholds(), settings, true)
	var reaches: Array[int] = profile["reaches"]
	_check(not reaches.is_empty(), "edge-on fixture produces a visible trail")
	for reach: int in reaches:
		_check(reach == 12, "edge-on smear caps at 60 percent of blade length")
	_check(_audit_smear(profile, 1.0, "edge-on fixture", {}) > 0, "edge-on fixture paints Bayer smear")

func _audit_star() -> void:
	var counts: Array[int]
	for age: float in STAR_AGES:
		var expected: Dictionary = {Vector2i.ZERO: 4}
		for axis: Vector2i in CARDINAL:
			expected[axis] = 4
			if age < 0.7: expected[axis * 2] = 3
			if age < 0.4: expected[axis * 3] = 2
		if age < 0.4:
			for x: int in [-1, 1]:
				for y: int in [-1, 1]:
					expected[Vector2i(x, y)] = 3
		var cells: Dictionary
		for i: int in Lines.trail_star_cell_count(age):
			var cell: Vector3i = Lines.TRAIL_STAR_CELLS[i]
			cells[Vector2i(cell.x, cell.y)] = cell.z
		_check(cells == expected, "contact star offsets and shades at age %.1f" % age)
		counts.append(cells.size())
	print("FEL05 STAR CELL COUNTS " + str(counts))

func _audit_claws(batch: Dictionary, to_cells: Transform2D, floor_value: float,
		bayer: PackedFloat32Array, ramp: PackedColorArray, label: String) -> void:
	var lanes: Array[Dictionary] = Claws.cells(batch, to_cells, floor_value, bayer)
	if lanes.is_empty() and label != AREA_LABEL: return
	_check(lanes.size() == 3, label + " paints three lanes")
	var occupied: Dictionary
	for lane: Dictionary in lanes:
		_check(_four_connected(lane), label + " lane is four-connected")
		for cell: Vector2i in lane:
			var ink: Color = lane[cell]
			_check(ink == ramp[3] or (label != AREA_LABEL and ink == ramp[4]), label + " uses the approved shades")
			for neighbor: Vector2i in Claws.NEIGHBORS:
				_check(not occupied.has(cell + neighbor), label + " lanes have an empty cell between them")
		occupied.merge(lane)
	if label == "claw marks":
		_separated_claws_seen = _separated_claws_seen or lanes.size() == 3
		if batch["alpha"] > 0.9:
			for scale: float in CLAW_GRIDS:
				var scaled := Transform2D(0.0, Vector2.ONE * scale, 0.0, Vector2.ZERO)
				_check_claw_spacing(Claws.cells(batch, scaled, floor_value, bayer))

func _check_claw_spacing(lanes: Array[Dictionary]) -> void:
	if lanes.is_empty(): return
	_check(lanes.size() == 3, "zoomed claw raster has three lanes")
	var occupied: Dictionary
	for lane: Dictionary in lanes:
		_check(_four_connected(lane), "zoomed claw raster is four-connected")
		for cell: Vector2i in lane:
			for neighbor: Vector2i in Claws.NEIGHBORS:
				_check(not occupied.has(cell + neighbor), "zoomed claw raster keeps one empty cell")
		occupied.merge(lane)

func _audit_reduced_area(board: Control) -> void:
	var target: Vector2i = board.combat_state["player"]["pos"]
	var depth_layers: Dictionary = board.get("_scene_front_effect_render_layers_by_tile")
	var owner: Control = depth_layers.get(target)
	_check(is_instance_valid(owner), "fixture has the target foreground painter")
	if not is_instance_valid(owner): return
	var previous: Dictionary = owner.presentation
	var shown: Dictionary = previous.duplicate()
	var effect := {"kind": "aoe", "enemy_type": "tharokh", "intent_id": "worldspine_claw",
		"from": target + Vector2i.RIGHT, "to": target, "tiles": [target], "element": "earth"}
	shown["effect"] = effect
	shown["reduced_motion"] = true
	owner.presentation = shown
	var static_pose: Array[Dictionary]
	var trail_layer: Node2D = owner.get("_strike_trail_layer")
	for phase: float in AREA_PHASES:
		shown["effect_progress"] = phase
		owner.call("_draw_elemental_scene_depth_pass", target, true)
		_audit_layer(trail_layer, effect, AREA_LABEL)
		var batches: Array[Dictionary] = trail_layer.get("_batches")
		if static_pose.is_empty():
			static_pose = batches.duplicate(true)
		_check(not static_pose.is_empty() and batches == static_pose, "reduced-motion area mark is static across the held effect")
	owner.presentation = previous
	owner.call("_draw_elemental_scene_depth_pass", target, true)
	_check((trail_layer.get("_batches") as Array).is_empty(), "static area mark clears when the effect ends")

func _four_connected(cells: Dictionary) -> bool:
	if cells.is_empty(): return false
	var stack: Array[Vector2i] = [cells.keys()[0]]
	var seen: Dictionary
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if seen.has(cell): continue
		seen[cell] = true
		for neighbor: Vector2i in Claws.NEIGHBORS:
			if neighbor != Vector2i.ZERO and cells.has(cell + neighbor) and not seen.has(cell + neighbor):
				stack.append(cell + neighbor)
	return seen.size() == cells.size()

func _manhattan(delta: Vector2i) -> int:
	return absi(delta.x) + absi(delta.y)

func _find_elemental_cards() -> void:
	var state: Dictionary = _run_scene._combat_state
	for cards: Variant in (state.get("deck", {}) as Dictionary).values():
		if not cards is Array: continue
		for card: Variant in cards:
			if not card is String: continue
			for action: Dictionary in _run_scene._card_def(card, state).get("actions", []):
				if Attack.protagonist_uses_melee_motion(action) and str(action.get("element", "none")) != "none":
					_elemental_cards[card] = true

func _check(condition: bool, message: String) -> void:
	if not condition: _failures[message] = true
