extends "res://tools/qa107/layout_sweep.gd"
## Keep real bosses and play/deal paths, with a deterministic starter hand.

const ROOMS := {"tharokh": ["dragon", {"dragon_id": "tharokh", "dragon_depth": 4}],
	"zekarion": ["dragon", {"dragon_id": "zekarion", "dragon_depth": 20}],
	"guardian": ["guardian", {"guardian_id": "craghide"}],
	"warband": ["warband", {"warband_biome": "earth", "warband_tier": 2}]}
const HAND := ["quick_stab", "brace", "pale_spark", "waning_pulse", "quick_stab", "brace"]
const SLOT: int = 1
const EPSILON: float = 2.0
const LEFT := ["_combat_objective_hud", "_battlefield_rule_hud", "_play_meter", "_movement_meter", "_movement_undo_button"]
const RIGHT := ["_pass_preview_overlay", "draw_pile", "discard_pile"]

func _initialize() -> void:
	OS.set_environment("QA107_STATE", "reach_exit")
	OS.set_environment("QA107_HOVER", "")
	super._initialize()

func _extra_fixtures() -> void:
	var builder := Fixtures.new()
	for room: String in ROOMS:
		var fixture: Array = ROOMS[room]
		var run: Dictionary = builder.make(fixture[0], run_seed, fixture[1])
		if run.is_empty():
			errors.append(room + ": " + builder.census_error)
			continue
		await _visit_hand(room, run)
	builder.free()

func _visit_hand(room: String, run: Dictionary) -> void:
	var deck: Dictionary = run["combat_state"]["deck"]
	deck["hand"] = preload("res://scripts/typed_arrays.gd").strings(HAND)
	await _enter_scene("res://scenes/run_scene.tscn")
	scene.set("_progression", run["progression"])
	scene._load_run_state(run)
	scene._close_dialogue()
	await settle()
	await _frames(SETTLE_FRAMES)
	var fan: HandFanContainer = scene.hand_box
	var center: float = fan.get("_fight_center_x")
	var count: int = fan.get_child_count()
	await _receipt(room, "resting")
	await scene._on_card_pressed(SLOT)
	await _check_transition(room, "select", center)
	if scene._selected_card_index != SLOT: errors.append(room + ": Brace did not select")
	await _receipt(room, "selected")
	scene._cancel_card_selection()
	await _check_transition(room, "cancel", center)
	if fan.emphasized_index() != -1: errors.append(room + ": selection did not clear")
	await _receipt(room, "cancelled")
	await scene._on_card_pressed(SLOT)
	await scene._on_confirm_card_play_pressed()
	await settle()
	await _frames(SETTLE_FRAMES)
	if fan.get_child_count() >= count: errors.append(room + ": confirmed Brace did not leave hand")
	await _receipt(room, "played")
	var previous_turn: int = scene._combat_state["turn"]
	var previous_draws: int = scene.card_draw_revision(scene._combat_state)
	await scene._on_pass_turn_pressed()
	await settle()
	await _frames(SETTLE_FRAMES)
	if scene._combat_state["turn"] <= previous_turn or scene.card_draw_revision(scene._combat_state) <= previous_draws:
		errors.append(room + ": Pass did not reach a replenished hand")
	await _receipt(room, "drawn")

func _check_transition(room: String, operation: String, center: float) -> void:
	var fan: HandFanContainer = scene.hand_box
	var peak: float = 0.0
	for frame: int in range(SETTLE_FRAMES):
		peak = maxf(peak, absf(float(fan.get("_fight_center_x")) - center))
		await process_frame
	if peak > EPSILON: errors.append(room + "/" + operation + ": hand centre moved %.2f" % peak)
	print("QA113 HAND TRANSITION %s/%s center_delta=%.3f" % [room, operation, peak])

func _receipt(room: String, phase: String) -> void:
	var fan: HandFanContainer = scene.hand_box
	var previous: Control
	var previous_rect := Rect2()
	var largest_gap: float = 0.0
	var overlap: float = 0.0
	var fields: Array = LEFT + RIGHT
	var layers: Dictionary = {}
	for field: String in fields:
		var node: Control = scene.get(field)
		if is_instance_valid(node) and node.is_visible_in_tree(): layers[field] = Check.bounds(node, root)
	var card_rects: Array = []
	for index: int in range(fan.get_child_count()):
		var card: Control = scene._hand_card_control(index)
		if not is_instance_valid(card) or not card.is_visible_in_tree(): continue
		var rect: Rect2 = Check.bounds(card, root)
		card_rects.append(Check.rect_data(rect))
		if previous != null:
			var common_y: float = (maxf(previous_rect.position.y, rect.position.y) + minf(previous_rect.end.y, rect.end.y)) * 0.5
			var left: Vector2 = _horizontal_card_span(previous, common_y)
			var right: Vector2 = _horizontal_card_span(card, common_y)
			largest_gap = maxf(largest_gap, right.x - left.y)
		previous = card
		previous_rect = rect
		var badge: Control = card.get_node_or_null("TimeCostBadge")
		var occupied: Rect2 = rect.merge(Check.bounds(badge, root)) if badge != null and badge.is_visible_in_tree() else rect
		for hud: Rect2 in layers.values():
			var hit: Rect2 = hud.intersection(occupied)
			if hit.has_area(): overlap = maxf(overlap, minf(hit.size.x, hit.size.y))
	var key: String = room + "/" + phase
	if largest_gap > EPSILON or overlap > EPSILON or card_rects.is_empty():
		errors.append("%s: gap %.2f HUD overlap %.2f cards %d" % [key, largest_gap, overlap, card_rects.size()])
	var row: Dictionary = {"case": key, "cards": card_rects, "hud": layers, "count": card_rects.size(),
		"center": fan.get("_fight_center_x"), "gap": largest_gap, "hud_overlap": overlap}
	states += 1
	print("QA113 HAND ", JSON.stringify(row))
	record("qa113_hand", row)
	if native:
		var surfaces: Array[Node]
		await snapshot("hand-" + key, "", {}, surfaces)

func _horizontal_card_span(card: Control, y: float) -> Vector2:
	var transform: Transform2D = card.get_global_transform_with_canvas()
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(card.size.x, 0.0), card.size, Vector2(0.0, card.size.y)])
	var span := Vector2(INF, -INF)
	for index: int in range(corners.size()):
		var start: Vector2 = transform * corners[index]
		var end: Vector2 = transform * corners[(index + 1) % corners.size()]
		if y < minf(start.y, end.y) or y > maxf(start.y, end.y) or is_equal_approx(start.y, end.y): continue
		var x: float = lerpf(start.x, end.x, inverse_lerp(start.y, end.y, y))
		span.x = minf(span.x, x)
		span.y = maxf(span.y, x)
	return span
