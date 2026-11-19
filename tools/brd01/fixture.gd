extends RefCounted

const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Router = preload("res://scripts/input_router.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Dragon = preload("res://tools/dragon_boss_inspection.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const RunScene = preload("res://scenes/run_scene.tscn")

const SEED_START: int = 7262026
const DRAGON_DEPTH: int = 4
const ENTRANCE := Vector2i.RIGHT
const DESKTOP := Vector2i(1920, 1080)
const DECK := Vector2i(1280, 800)
const SETTLE_FRAMES: int = 3
const CARDS := {
	"move": "guarded_step",
	"attack": "skybolt",
	"targetless": "stone_plate",
	"summon": "mirror_image",
}
const FILLER: String = "stone_plate"

static func encounter(kind: String) -> Dictionary:
	var seed: int = Dragon.seed_for_options({"seed": SEED_START, "dragon_id": "tharokh", "dragon_depth": DRAGON_DEPTH})
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(seed, Tutorial.dismiss_tutorial(Store.default_data()))
	var room: Dictionary
	for candidate: Dictionary in state["rooms"].values():
		if candidate.get("type") != kind: continue
		if kind == "boss" and candidate.get("boss_id") != "tharokh": continue
		room = candidate
		break
	if room.is_empty(): return {}
	# Enter the actual generated room through the same factory as Battle.
	state["current_room"] = room["coord"]
	room["revealed"] = true
	room["visited"] = true
	state["current_room_layout"] = engine._display_layout_for_room(seed, room, ENTRANCE)
	state["mode"] = Run.MODE_PRE_BATTLE
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = ENTRANCE
	return engine.begin_pre_battle_combat(state)

static func mount(tree: SceneTree, viewport: Viewport, state: Dictionary, ui_scale: float) -> Control:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = false
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Store.save_data(state["progression"])
	if not Store.save_run_state(state): return null
	tree.root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Control = RunScene.instantiate()
	viewport.add_child(scene)
	return scene

static func set_hand(scene: Control, source: Dictionary, card: String, count: int) -> void:
	var state: Dictionary = source.duplicate(true)
	var hand: Array = [card]
	for index: int in range(1, count): hand.append(FILLER)
	state["deck"]["hand"] = hand
	scene.set("_combat_state", state)
	(scene.get("_run_state") as Dictionary)["combat_state"] = state
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")

static func settle(tree: SceneTree, frames: int = SETTLE_FRAMES) -> void:
	for frame: int in range(frames): await tree.process_frame

static func ready_for_input(scene: Control) -> bool:
	var budget: RefCounted = scene.get("_board_hud_budget")
	return not budget.key.is_empty() and int(scene.get("_hand_layout_pending_revision")) < 0 and not bool(scene.get("_animation_lock"))

static func controller_button(scene: Control, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	await scene.call("_handle_controller_input", event)

static func coordinates(board: Control, hero_tile: Vector2i) -> Dictionary:
	var viewport: Viewport = board.get_viewport()
	var local_to_output: Transform2D = viewport.get_final_transform() * board.get_global_transform_with_canvas()
	var nav: Dictionary = board.call("navigation_snapshot")
	var tile: Vector2 = board.call("world_position_for_tile", hero_tile)
	var origin: Vector2 = board.call("_board_origin")
	var camera: Camera2D = viewport.get_camera_2d()
	var layer: CanvasLayer = board.get_parent() as CanvasLayer
	return {
		"canvas_position": _point(local_to_output.origin),
		"canvas_x": _point(local_to_output.x),
		"canvas_y": _point(local_to_output.y),
		"canvas_size": _point(board.size),
		"canvas_layer_offset": _point(layer.offset),
		"camera": null if camera == null else {
			"position": _point(camera.global_position), "offset": _point(camera.offset), "zoom": _point(camera.zoom),
		},
		"screen_origin": _point(local_to_output * origin),
		"hero_tile_screen": _point(local_to_output * tile),
		"tile_width": board.call("_tile_width"),
		"zoom": nav["zoom"],
		"pan": _point(nav["pan"]),
		"visual_top_offset": board.get("_board_layout_cache_visual_top_offset"),
	}

static func _point(value: Vector2) -> Array[float]:
	var point: Array[float] = [value.x, value.y]
	return point
