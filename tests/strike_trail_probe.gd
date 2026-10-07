extends SceneTree
## Frozen production board/effect checkpoints. Capture only with the native
## visual_probe_runner; --check-only through godot_task_runner parses this file.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/helpers/strike_trail_fixture.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/strike_trail"
const PHASES: Array = [0.36, 0.40, 0.42, 0.46, 0.52]
const DIRECTIONS: Dictionary = {"front": Vector2i(0, 1), "rear": Vector2i(0, -1),
	"front_mirror": Vector2i(1, 0), "rear_mirror": Vector2i(-1, 0)}
var _surface: SubViewport
var _board: Control
var _errors: Array[String]
var _captures: Array[Dictionary]

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Strike trail probe requires a real renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	Settings.set_storage_path("user://strike_trail_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_surface = SubViewport.new()
	_surface.size = SIZE
	_surface.disable_3d = true
	_surface.world_2d = World2D.new()
	_surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_surface)
	_board = Board.new()
	_board.size = Vector2(SIZE)
	_surface.add_child(_board)
	await process_frame
	_board.set_process(false)
	for motion: String in Fixture.LOADOUTS:
		for view: String in DIRECTIONS:
			for progress: float in PHASES:
				await _capture(motion, view, progress)
	await _capture("sword", "front", 0.42, "fire")
	await _capture("thrust", "rear", 0.42, "ice")
	await _capture("sword", "front", 0.42, "ice", true)
	for progress: float in [0.14, 0.19, 0.20, 0.62, 0.63, 0.78]:
		await _capture("thrust", "front", progress)
	await _capture("sword", "front", 0.42, "none", false, true)
	var manifest := {"size": [1920, 1080], "ui_scale": 1.0, "captures": _captures, "errors": _errors}
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	_board.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print("STRIKE TRAIL PROBE RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(0 if _errors.is_empty() else 1)

func _capture(motion: String, view: String, progress: float, element: String = "none",
		echo: bool = false, reduced: bool = false) -> void:
	var direction: Vector2i = DIRECTIONS[view]
	var state: Dictionary = Fixture.state(direction)
	var from: Vector2i = state["player"]["pos"]
	if echo:
		from += Vector2i(-1, 0)
		state["illusions"] = [{"id": 1, "pos": from, "hp": 1, "max_hp": 1, "block": 0}]
	var effect: Dictionary = {"kind": "melee", "protagonist_melee": not echo, "illusion_echo": echo,
		"protagonist_weapon_motion": motion, "from": from, "to": state["enemies"][0]["pos"], "element": element, "seed": 11}
	var presentation: Dictionary = {"effect": effect, "effect_progress": progress, "reduced_motion": reduced,
		"equipped_equipment": {"weapon": Fixture.LOADOUTS[motion]}, "board_backdrop_visible": true,
		"protagonist_motion": {} if echo else {"clip": "attack", "phase": progress, "direction": direction}}
	_board.set_combat_state(state, [], [], Vector2i(-1,-1), "", "", {}, {}, presentation)
	# Let the retained effects child and cutout viewport complete their updates.
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var layer: Control = _board.get("_effects_render_layer")
	var light: Node2D = layer.get("_strike_trail_layer")
	_expect(is_instance_valid(light), "Production effects layer owns additive light")
	if is_instance_valid(light):
		_expect((light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Production trail uses additive material")
		if reduced:
			_expect(light.get("_batches").is_empty(), "Reduced motion has no light geometry")
	var label: String = "%s_%s_%03d_%s%s%s" % [motion, view, roundi(progress * 100.0), element, "_echo" if echo else "", "_reduced" if reduced else ""]
	var pixels: Image = _surface.get_texture().get_image()
	_expect(pixels.get_size() == SIZE, "Capture is exactly 1920x1080")
	_expect(pixels.save_png(OUTPUT.path_join(label + ".png")) == OK, "Frame saves: " + label)
	var unit: Dictionary = {"type": "player", "key": "player", "role": "player", "pos": state["player"]["pos"]}
	var body: Rect2 = _board.call("_unit_draw_rect_for_center", unit, _board.world_position_for_tile(unit["pos"]))
	var crop := Rect2i(Vector2i(body.get_center() - Vector2(180,180)), Vector2i(360,360))
	if echo:
		crop.position = Vector2i(_board.world_position_for_tile(effect["to"]) - Vector2(180,180))
	var renderer: Node = _board.get("_protagonist_renderer")
	var rig: Node2D = renderer.rigs[renderer.facing]
	if not echo and not reduced:
		_expect(renderer.clip == ("attack_" + motion if motion in ["heavy", "stab", "thrust", "lash"] else "attack"), "Production pose follows motion: " + motion)
		var expected_phase: float = renderer.attack_pose_phase(progress) if motion in ["sword", "bow", "repeater"] else progress
		_expect(is_equal_approx(renderer.phase, expected_phase), "Production clip and trail share effect progress")
	_captures.append({"file": label + ".png", "crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y],
		"motion": motion, "view": view, "progress": progress, "element": element, "echo": echo, "reduced": reduced,
		"weapon_z": rig._gear_base_parts["weapon_r"]["node"].z_index,
		"grip_visible": rig._gear_layers.grip.visible, "clip": renderer.clip, "clip_phase": renderer.phase})

func _expect(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
