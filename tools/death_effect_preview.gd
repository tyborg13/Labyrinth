extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "res://tmp/death_effect_preview_frames"
const FRAME_COUNT: int = 105
const FPS: float = 30.0

func _initialize() -> void:
	ProgressionStore.set_storage_path("user://death_effect_preview_progression.json")
	ProgressionStore.set_run_storage_path("user://death_effect_preview_run.save")
	AnalyticsStore.set_storage_dir("user://death_effect_preview_analytics")
	AnalyticsStore.clear_storage()
	ProgressionStore.clear_saved_run()

	_prepare_output_dir()
	var scene: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	await _move_to_combat_room(instance)
	_force_defeat(instance)
	await process_frame
	await process_frame

	for frame: int in range(FRAME_COUNT):
		await _save_frame(frame)
		await create_timer(1.0 / FPS).timeout

	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _move_to_combat_room(instance: Node) -> void:
	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	var combat_coord: Vector2i = Vector2i.ZERO
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			combat_coord = coord
			break
	if combat_coord == Vector2i.ZERO:
		return
	await instance.call("_on_map_view_room_selected", combat_coord)
	await create_timer(0.75).timeout
	await process_frame

func _force_defeat(instance: Node) -> void:
	var run_engine: RunEngine = instance.get("_run_engine")
	var run_state: Dictionary = instance.get("_run_state")
	var combat_state: Dictionary = instance.get("_combat_state")
	if combat_state.is_empty():
		run_state["mode"] = "defeat"
		run_state["game_over"] = true
		run_state["player_hp"] = 0
		instance.call("_load_run_state", run_state)
		return
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 0
	combat_state["player"] = player
	var defeat_state: Dictionary = run_engine.finish_combat(run_state, combat_state)
	instance.call("_load_run_state", defeat_state)

func _prepare_output_dir() -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _save_frame(frame: int) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	var output_path: String = "%s/frame_%03d.png" % [OUTPUT_DIR, frame]
	image.save_png(output_path)
