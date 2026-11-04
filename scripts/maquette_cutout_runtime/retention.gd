extends Node

const Construction = preload("construction.gd")
var previous_families := PackedStringArray()
var current_families := PackedStringArray()
var next_families := PackedStringArray()
var current_key: Array = []
var next_key: Array = []
var generation: int = -1
var complete: bool = false

static func for_scene(scene: Node) -> Node:
	var found: Node = scene.get_node_or_null("MaquetteRoomPreparation")
	if found != null: return found
	var window: Node = load("res://scripts/maquette_cutout_runtime/retention.gd").new()
	window.name = "MaquetteRoomPreparation"
	window.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(window)
	return window

static func room_key(state: Dictionary) -> Array:
	return [state.get("seed", 0), state.get("current_room", Vector2i.ZERO)]

func current(state: Dictionary, families: PackedStringArray) -> void:
	var key: Array = room_key(state)
	if current_key != key:
		previous_families = current_families
		current_key = key
		current_families = families
	else:
		for family: String in families:
			if not current_families.has(family): current_families.append(family)
	retain()

func request(state: Dictionary, revision: int) -> void:
	if generation == revision: return
	generation = revision
	next_key = room_key(state)
	next_families = PackedStringArray()
	complete = false
	retain()

func commit() -> void:
	if current_key != next_key: previous_families = current_families
	current_key = next_key
	current_families = next_families
	next_families = PackedStringArray()
	retain()

func retain() -> void:
	var families: PackedStringArray = previous_families.duplicate()
	for group: PackedStringArray in [current_families, next_families]:
		for family: String in group:
			if not families.has(family): families.append(family)
	Construction.retain_for(get_instance_id(), families)

func _exit_tree() -> void:
	Construction.release_owner(get_instance_id())
