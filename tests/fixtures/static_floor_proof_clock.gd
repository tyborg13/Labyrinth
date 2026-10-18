extends RefCounted

# Proof inputs only. Keep the production animation, roster and redraw paths.
const ACTOR_SECONDS: float = 0.0
const BOARD_SECONDS: float = 2.0
const AMBIENT_SECONDS: float = 12.0

static func freeze(board: Control) -> Array[Node]:
	# A fresh board has no damage/healing history. Finish only these transient
	# bars through their real clock before comparing complete, actor-inclusive pixels.
	var health: RefCounted = board.get("health_ghost_tracker")
	if health != null:
		health.advance(health.HOLD_SECONDS + health.DRAIN_SECONDS + health.HEAL_FLASH_SECONDS)
	var actors: Array[Node]
	_freeze_tree(board, actors)
	var treatment: RefCounted = board.get("_art_treatment")
	if treatment != null:
		treatment.set("_clock", AMBIENT_SECONDS)
		treatment.call("_update_flicker")
		treatment.call("_apply_materials")
	return actors

static func _freeze_tree(node: Node, actors: Array[Node]) -> void:
	# Persistent actors process independently of the owning board. Merely
	# disabling their processing preserves whatever pose they had already reached.
	node.set_process(false)
	node.set_physics_process(false)
	if node.get("_idle_elapsed") != null:
		node.set("_idle_elapsed", BOARD_SECONDS)
	if node.get("_idle_seconds") != null and node.has_method("_apply_pose"):
		node.set("_idle_seconds", ACTOR_SECONDS)
		node.call("_apply_pose")
		actors.append(node)
	for child: Node in node.get_children():
		_freeze_tree(child, actors)

static func pixels_equal(actual: Image, expected: Image) -> bool:
	return actual.get_size() == expected.get_size() and actual.get_format() == expected.get_format() and actual.get_data() == expected.get_data()
