extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const CardWidgetScript = preload("res://scripts/card_widget.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://ready_wave_probe"
const FRAME_SIZE: Vector2i = Vector2i(980, 420)
const CARD_SIZE: Vector2i = Vector2i(150, 214)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_ready_wave_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_ready_wave_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_ready_wave()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_ready_wave() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(9401, ProgressionStore.default_data()))
	await process_frame
	await process_frame
	var combat_state: Dictionary = _ready_wave_combat_state()
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room_layout"] = _ready_wave_layout()
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_queue_hand_ready_wave", "probe_player_turn_start")
	instance.call("_refresh_ui")
	await process_frame
	await _save_wave_frame(instance, "%s/ready_wave_00_queued.png" % OUTPUT_DIR)
	await create_timer(0.10).timeout
	await process_frame
	await _save_wave_frame(instance, "%s/ready_wave_01_first_card.png" % OUTPUT_DIR)
	await create_timer(0.08).timeout
	await process_frame
	await _save_wave_frame(instance, "%s/ready_wave_02_stagger.png" % OUTPUT_DIR)
	instance.queue_free()
	await process_frame

func _ready_wave_combat_state() -> Dictionary:
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(9401, _ready_wave_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace", "lantern_shot"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "brace", "lantern_shot"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	return combat_state

func _ready_wave_layout() -> Dictionary:
	return {
		"name": "Ready Wave Probe",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": _probe_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 100,
			"max_hp": 100,
			"block": 0
		}],
		"loot": [],
		"traps": [],
		"terrain": []
	}

func _probe_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
	]

func _save_wave_frame(instance: Node, output_path: String) -> void:
	var samples: Array[Dictionary] = _ready_wave_samples(instance)
	if samples.is_empty():
		push_error("Ready-wave probe did not find hand cards to sample.")
		return
	var image := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("17110e"))
	_fill_rect(image, Rect2i(Vector2i(0, 300), Vector2i(FRAME_SIZE.x, 120)), Color("251a14"))
	_fill_rect(image, Rect2i(Vector2i(42, 42), Vector2i(FRAME_SIZE.x - 84, 28)), Color("4b3220"))
	_fill_rect(image, Rect2i(Vector2i(42, 76), Vector2i(FRAME_SIZE.x - 84, 10)), Color("d6a24c"))
	for index: int in range(samples.size()):
		_draw_wave_sample(image, samples[index], index, samples.size())
	image.save_png(output_path)

func _ready_wave_samples(instance: Node) -> Array[Dictionary]:
	var hand_box: Node = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var widgets: Array[Control] = _card_widgets_under(hand_box)
	var samples: Array[Dictionary] = []
	for widget: Control in widgets:
		samples.append({
			"card_id": str(widget.get("card_id")),
			"scale": widget.scale.x,
			"lift": -widget.position.y,
			"playable": bool(widget.get_meta("ready_wave_playable", false)),
			"active": bool(widget.get_meta("ready_wave_active", false)),
			"order": int(widget.get_meta("ready_wave_order", -1)),
			"delay": float(widget.get_meta("ready_wave_delay", -1.0))
		})
	return samples

func _card_widgets_under(node: Node) -> Array[Control]:
	var widgets: Array[Control] = []
	if node == null:
		return widgets
	if node.get_script() == CardWidgetScript:
		widgets.append(node as Control)
	for child: Node in node.get_children():
		widgets.append_array(_card_widgets_under(child))
	return widgets

func _draw_wave_sample(image: Image, sample: Dictionary, index: int, total: int) -> void:
	var stride: int = 205
	var start_x: int = int((FRAME_SIZE.x - (stride * (total - 1) + CARD_SIZE.x)) * 0.5)
	var scale: float = clampf(float(sample.get("scale", 1.0)), 0.94, 1.08)
	var lift: float = clampf(float(sample.get("lift", 0.0)), -8.0, 24.0)
	var size := Vector2i(int(round(float(CARD_SIZE.x) * scale)), int(round(float(CARD_SIZE.y) * scale)))
	var x: int = start_x + index * stride - int((size.x - CARD_SIZE.x) * 0.5)
	var y: int = 150 - int(round(lift * 4.5)) - int((size.y - CARD_SIZE.y) * 0.5)
	var active: bool = bool(sample.get("active", false))
	var playable: bool = bool(sample.get("playable", false))
	var glow_pad: int = 15 if active else 8
	var glow_color: Color = Color("e8ad46") if playable else Color("4b4038")
	if active:
		_fill_rect(image, Rect2i(Vector2i(x - glow_pad, y - glow_pad), Vector2i(size.x + glow_pad * 2, size.y + glow_pad * 2)), glow_color)
	else:
		_fill_rect(image, Rect2i(Vector2i(x - glow_pad, y - glow_pad), Vector2i(size.x + glow_pad * 2, size.y + glow_pad * 2)), Color("5a3f24") if playable else Color("302a27"))
	_fill_rect(image, Rect2i(Vector2i(x, y), size), Color("eadcc3") if playable else Color("5d554e"))
	_fill_rect(image, Rect2i(Vector2i(x + 8, y + 8), Vector2i(size.x - 16, 30)), Color("4d2f1e") if playable else Color("302b28"))
	_fill_rect(image, Rect2i(Vector2i(x + 12, y + 50), Vector2i(size.x - 24, 78)), Color("b66a3d") if active else Color("876043"))
	_fill_rect(image, Rect2i(Vector2i(x + 12, y + 142), Vector2i(size.x - 24, size.y - 154)), Color("6a5039") if playable else Color("39332f"))
	var order: int = int(sample.get("order", -1))
	if order >= 0:
		var marker_width: int = 24 + order * 18
		_fill_rect(image, Rect2i(Vector2i(x + 14, y + size.y - 24), Vector2i(marker_width, 8)), Color("ffe08c"))

func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var left: int = clampi(rect.position.x, 0, image.get_width())
	var top: int = clampi(rect.position.y, 0, image.get_height())
	var right: int = clampi(rect.position.x + rect.size.x, 0, image.get_width())
	var bottom: int = clampi(rect.position.y + rect.size.y, 0, image.get_height())
	for y: int in range(top, bottom):
		for x: int in range(left, right):
			image.set_pixel(x, y, color)

func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
