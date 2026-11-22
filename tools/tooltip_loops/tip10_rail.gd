extends RefCounted
## A recorder camera places the production rail beside the plain-floor patch.
## Its rows, art, clock numerals and transition still come from the game.
const GAP: float = 8.0
const INSET: float = 12.0
const ASPECT: float = 282.0 / 168.0

# Production rail layout also relays out the combat dock. It restores these
# controls after the general board mask, including in deferred layout passes.
static func mask_dock(scene: Node) -> void:
	for control: Control in _dock_controls(scene): control.hide()

static func stray_dock_is_visible(scene: Node) -> bool:
	return _dock_controls(scene).any(func(control: Control) -> bool: return control.is_visible_in_tree())

static func _dock_controls(scene: Node) -> Array[Control]:
	var controls: Array[Control]
	for property: String in ["_play_meter", "_movement_meter", "_movement_undo_button", "_enemy_intent_toggle_button"]:
		var control: Control = scene.get(property)
		if control != null: controls.append(control)
	return controls

static func crop(scene: Node, board_crop: Rect2i) -> Rect2i:
	var rail: Control = scene.get("_turn_order_bar")
	var anchor: Control = scene.get("_turn_order_anchor")
	var frame := Rect2(board_crop)
	var segment := Rect2()
	for slot: Control in portrait_slots(scene).values():
		var bounds: Rect2 = slot.get_global_rect()
		segment = segment.merge(bounds) if segment.has_area() else bounds
	segment.position -= rail.global_position
	var rail_position := Vector2(frame.end.x + GAP, frame.get_center().y - segment.get_center().y)
	var segment_bounds := Rect2(rail_position + Vector2(0.0, segment.position.y), Vector2(rail.size.x, segment.size.y))
	var bounds: Rect2 = frame.merge(segment_bounds.grow(INSET))
	anchor.set_meta("tip10_capture_position", rail_position)
	place(scene)
	var width: float = maxf(bounds.size.x, bounds.size.y * ASPECT)
	var size := Vector2(width, width / ASPECT)
	return Rect2i(Rect2(bounds.get_center() - size * 0.5, size))

static func place(scene: Node) -> void:
	mask_dock(scene)
	var anchor: Control = scene.get("_turn_order_anchor")
	if not anchor.has_meta("tip10_capture_position"): return
	var rail: Control = scene.get("_turn_order_bar")
	var position: Vector2 = anchor.get_meta("tip10_capture_position")
	anchor.global_position += position - rail.global_position
	var pair: Array = portrait_slots(scene).values()
	for slot: Control in rail.get_children(): slot.visible = pair.has(slot)

static func portrait_slots(scene: Node) -> Dictionary:
	var rail: Control = scene.get("_turn_order_bar")
	var slots: Dictionary = {}
	for slot: Control in rail.get_children():
		var key: String = slot.get_meta("turn_order_actor_key", "")
		var role: String = slot.get_meta("turn_order_animation_role", "")
		if key.begins_with("player:") and role == "projected" and not slots.has("player"): slots["player"] = slot
		if key.begins_with("enemy:") and role == "scheduled" and not slots.has("enemy"): slots["enemy"] = slot
	return slots
