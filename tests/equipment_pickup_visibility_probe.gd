extends SceneTree

const CombatBoardViewScript = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://equipment_pickup_visibility_probe"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.size = Vector2i(960, 680)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	var board: Control = CombatBoardViewScript.new()
	board.size = Vector2(960.0, 680.0)
	root.add_child(board)
	await process_frame
	board.call("set_combat_state", _probe_state())
	await process_frame
	await create_timer(0.22).timeout
	await _save_root_screenshot("%s/equipment_pickup_visibility.png" % OUTPUT_DIR)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _probe_state() -> Dictionary:
	return {
		"name": "Equipment Pickup Visibility Probe",
		"room_coord": Vector2i(7, -2),
		"grid": _probe_grid(),
		"player": {
			"pos": Vector2i(2, 4),
			"hp": 30,
			"max_hp": 30,
			"block": 0,
			"stoneskin": 0
		},
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(6, 3),
			"hp": 90,
			"max_hp": 90,
			"block": 0,
			"intent": {}
		}],
		"loot": [{
			"id": "probe_equipment",
			"kind": "equipment",
			"equipment_id": "iron_cleaver",
			"pos": Vector2i(4, 3)
		}, {
			"id": "probe_vial",
			"kind": "healing_vial",
			"amount": 4,
			"pos": Vector2i(5, 4)
		}, {
			"id": "probe_shield",
			"kind": "rusty_shield",
			"amount": 5,
			"pos": Vector2i(3, 4)
		}],
		"terrain": [],
		"traps": []
	}

func _probe_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
	]

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(output_path))

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
