extends RefCounted

const Assets = preload("res://scripts/asset_loader.gd")
const Encounter = preload("res://scripts/encounter_asset_preparation.gd")
const Rooms = preload("res://scripts/room_asset_preparation.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")

var _revision: int = 0
var _preparing_coord: Vector2i = Graph.INVALID
var _selected_coord: Vector2i = Graph.INVALID
var _selected_input: Dictionary = {}
var _selected_move: Dictionary = {}

# Speculate only into the ordinary resource caches and the existing hidden
# shop. Neither the generated destination nor its RNG/receipts is committed.
# Arrival always uses the canonical transition and synchronous fallback; there
# is no readiness wait and no change to the authored door/map animation.
func schedule(scene: Node) -> void:
	cancel()
	_prepare.call_deferred(scene, _revision, scene._encounter_preparation_generation)

func cancel() -> void:
	_revision += 1
	_preparing_coord = Graph.INVALID
	_selected_coord = Graph.INVALID
	_selected_input = {}
	_selected_move = {}

# The map owns its existing lantern walk. Compute the selected transition in
# that window on an owned snapshot; the commit and its checkpoint keep their
# original ordering and never await this work.
func prioritize(scene: Node, coord: Vector2i) -> void:
	var continue_art: bool = _preparing_coord == coord
	if not continue_art: cancel()
	_prepare_selected.call_deferred(scene, coord, _revision, scene._encounter_preparation_generation, continue_art)

func take_selected_move(state: Dictionary, coord: Vector2i) -> Dictionary:
	if coord != _selected_coord or _selected_move.is_empty() or _selected_input != state: return {}
	var result: Dictionary = {"previous": _selected_input, "destination": _selected_move}
	_selected_move = {}
	return result

func _selected_active(scene: Variant, coord: Vector2i, revision: int, generation: int) -> bool:
	return _active(scene, revision, generation) and scene._large_map_view.activation_coord == coord

func _prepare_selected(scene: Node, coord: Vector2i, revision: int, generation: int, continue_art: bool) -> void:
	var alive: Callable = _selected_active.bind(scene, coord, revision, generation)
	if not bool(alive.call()): return
	var frame: Callable = Shutdown.present_preparation.bind(scene.get_tree())
	await frame.call()
	await Assets.wait_for_preparation_slice(frame, alive)
	if not bool(alive.call()): return
	var started: int = Time.get_ticks_usec()
	var state: Dictionary = scene._run_state.duplicate(true)
	var destination: Dictionary = scene._run_engine.move_to_pre_battle(state, coord)
	scene._record_runtime_performance_phase("room_move_prepare_selected", started)
	Assets.count_preparation_work(started)
	if destination.get("current_room") != coord: return
	_selected_input = state
	_selected_coord = coord
	_selected_move = destination
	if continue_art: return
	var room: Dictionary = scene._run_engine.room_metadata(destination, coord)
	var kind: String = str(room.get("type", ""))
	var textures: Dictionary = Rooms.texture_manifest(scene.board_view, destination, room)
	if kind == "scavenger": textures.merge(Encounter.state_texture_manifest(scene, destination))
	await _prepare_presentation(scene, kind, destination, textures, frame, alive)

func _active(scene: Variant, revision: int, generation: int) -> bool:
	return (
		is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion()
		and not scene._leaving_tree and not Assets.preparation_is_stopping(scene.get_tree().root)
		and revision == _revision and generation == scene._encounter_preparation_generation
		and str(scene._run_state.get("mode", "")) == "room" and not scene._animation_lock
		and is_instance_valid(scene._large_map_scrim) and scene._large_map_scrim.visible
	)

func _prepare(scene: Node, revision: int, generation: int) -> void:
	if not _active(scene, revision, generation): return
	var frame: Callable = Shutdown.present_preparation.bind(scene.get_tree())
	var alive: Callable = _active.bind(scene, revision, generation)
	# Let the map's existing opening frame complete before any speculative work.
	await frame.call()
	if not bool(alive.call()): return
	var state: Dictionary = scene._run_state
	for coord: Vector2i in scene._run_engine.available_moves(state):
		if not bool(alive.call()) or not is_same(state, scene._run_state): return
		if scene._large_map_view.activation_coord != Graph.INVALID: return
		if not scene._guided_tutorial_map_room_allowed(coord): continue
		var room: Dictionary = scene._run_engine.room_metadata(state, coord)
		if Graph.modern(state) and room.get("type") == "mystery": room["type"] = room["mystery_type"]
		var kind: String = str(room.get("type", ""))
		var started: int = Time.get_ticks_usec()
		var textures: Dictionary = Rooms.texture_manifest(scene.board_view, state, room)
		var destination: Dictionary = {}
		if kind in ["treasure", "scavenger"]:
			destination = scene._run_engine.move_to_room(state, coord)
			if kind == "treasure":
				textures.merge(Rooms.texture_manifest(scene.board_view, destination, room))
			else:
				textures.merge(Encounter.state_texture_manifest(scene, destination))
		elif kind in ["guardian", "boss"]:
			var roster: Array[Dictionary]
			var boss: String = str(room.get("boss_id", ""))
			if kind == "boss":
				roster.append({"type": boss})
			else:
				for type: String in Guardians.enemy_types(boss): roster.append({"type": type})
			textures.merge(Encounter.state_texture_manifest(scene, state, {"enemies": roster}))
		scene._record_runtime_performance_phase("nonfight_destination_resources", started)
		Assets.count_preparation_work(started)
		_preparing_coord = coord
		await _prepare_presentation(scene, kind, destination, textures, frame, alive)
		if revision != _revision: return
		_preparing_coord = Graph.INVALID
		await frame.call()

func _prepare_presentation(scene: Node, kind: String, destination: Dictionary, textures: Dictionary, frame: Callable, alive: Callable) -> void:
	await Rooms.prepare_merchant_rig_for(scene, kind, textures, frame, alive)
	if not bool(alive.call()): return
	await Rooms.prepare_art_for(scene.get_tree().root, textures, frame, alive)
	await Assets.wait_for_preparation_slice(frame, alive)
	if not bool(alive.call()): return
	Rooms.prepare_overlay(scene, kind)
	if kind == "scavenger": await Encounter.prepare_hidden_shop_for(scene, destination, frame, alive)
