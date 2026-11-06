extends RefCounted

const Assets = preload("res://scripts/asset_loader.gd")
const Events = preload("res://scripts/event_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Encounter = preload("res://scripts/encounter_asset_preparation.gd")
const Rooms = preload("res://scripts/room_asset_preparation.gd")

var _revision: int = 0

# Speculate only into the ordinary resource caches and the existing hidden
# shop. Neither the generated destination nor its RNG/receipts is committed.
# Arrival always uses the canonical transition and synchronous fallback; there
# is no readiness wait and no change to the authored door/map animation.
func schedule(scene: Node) -> void:
	_revision += 1
	_prepare.call_deferred(scene, _revision, scene._encounter_preparation_generation)

func cancel() -> void:
	_revision += 1

func _active(scene: Variant, revision: int, generation: int) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and revision == _revision and generation == scene._encounter_preparation_generation and str(scene._run_state.get("mode", "")) == "room" and not scene._animation_lock and is_instance_valid(scene._large_map_scrim) and scene._large_map_scrim.visible

func _prepare(scene: Node, revision: int, generation: int) -> void:
	if not _active(scene, revision, generation): return
	var frame: Callable = Rooms.present_frame.bind(scene.get_tree())
	var alive: Callable = _active.bind(scene, revision, generation)
	# Let the map's existing opening frame complete before any speculative work.
	await frame.call()
	if not bool(alive.call()): return
	var state: Dictionary = scene._run_state.duplicate(true)
	for coord: Vector2i in scene._run_engine.available_moves(state):
		if not bool(alive.call()): return
		var room: Dictionary = scene._run_engine.room_metadata(state, coord)
		var kind: String = str(room.get("mystery_type", "")) if str(room.get("type", "")) == "mystery" else str(room.get("type", ""))
		if kind not in ["event", "treasure", "scavenger", "campfire"]: continue
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		var textures: Dictionary = {}
		var destination: Dictionary = {}
		if kind == "event":
			# select_event reads only ordered persistent inputs and a private seeded
			# RNG. No choice previews are built here; qa-59 owns their preparation.
			var selection: Dictionary = state.duplicate(false)
			selection["current_room"] = coord
			var id: String = str(room["event_id"]) if room.has("event_id") else Events.select_event(selection)
			textures[Events.art_path(id)] = false
		elif kind == "campfire":
			for path: String in [scene.CAMPFIRE_CHOICE_LINGER_ICON_PATH, scene.CAMPFIRE_CHOICE_EMBRACE_ICON_PATH, scene.CAMPFIRE_CHOICE_STRENGTH_ICON_PATH, scene.CAMPFIRE_CHOICE_PURGE_ICON_PATH]: textures[path] = false
		else:
			destination = scene._run_engine.move_to_room(state, coord)
			if kind == "treasure":
				for id: String in destination.get("pending_relics", []):
					var path: String = str(Data.relic_def(id).get("icon_path", ""))
					if not path.is_empty(): textures[path] = false
			else:
				textures = Encounter.state_texture_manifest(scene, destination)
		scene._record_runtime_performance_phase("nonfight_destination_resources", started)
		await frame.call()
		if not bool(alive.call()): return
		await Assets.prepare_textures_for(scene.get_tree().root, textures, frame, alive)
		if not bool(alive.call()): return
		if kind == "scavenger":
			await Encounter.prepare_hidden_shop_for(scene, destination, frame, alive)
			if not bool(alive.call()): return
		await frame.call()
