extends SceneTree
## Production retained-layer captures; run only via the native visual runner.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/helpers/enemy_strike_fixture.gd")
const EnemyTrail = preload("res://scripts/enemy_strike_trail.gd")
const Points = preload("res://scripts/enemy_strike_points.gd")
const SIZE := Vector2i(1920,1080)
const OUTPUT: String = "user://probes/enemy_strike_trail"
const PHASES: Array = [0.40,0.42,0.48]
const DIRECTIONS: Dictionary = {"front":Vector2i(0,1),"rear":Vector2i(0,-1),"front_mirror":Vector2i(1,0),"rear_mirror":Vector2i(-1,0)}
const CASES: Array = [
	["harrier",""], ["crawler",""], ["warden",""], ["chainbound_gaoler",""],
	["ashen_reaver","guardian_area"], ["storm_cantor",""], ["craghide",""],
	["zekarion",""], ["tharokh","area"], ["lightning_wisp",""], ["warden","push"],
	["frostglass_lancer","thrust"], ["frostglass_lancer","advance"], ["acolyte",""]]
var _surface: SubViewport
var _board: Control
var _errors: Array[String]
var _captures: Array[Dictionary]

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Enemy strike trail probe requires a real renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	Settings.set_storage_path("user://enemy_strike_trail_settings.json")
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
	for entry: Array in CASES:
		for view: String in DIRECTIONS:
			for progress: float in PHASES:
				await _capture(entry[0],entry[1],view,progress)
	await _capture("crawler","","front",0.42,true)
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[1920,1080],"ui_scale":1.0,"captures":_captures,"errors":_errors},"\t"))
	file.close()
	_board.queue_free()
	await process_frame
	for error: String in _errors: push_error(error)
	print("ENEMY STRIKE TRAIL PROBE RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(0 if _errors.is_empty() else 1)

func _capture(type: String, variant: String, view: String, progress: float, reduced: bool = false) -> void:
	var state: Dictionary = Fixture.state(type,DIRECTIONS[view])
	var effect: Dictionary = Fixture.effect(type,state,variant)
	var element: String = "lightning" if type in ["lightning_wisp","storm_cantor","zekarion"] else "ice" if type == "frostglass_lancer" else "earth" if type == "tharokh" else "fire" if type == "ashen_reaver" else "none"
	effect["element"] = element
	_board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation(type,state,effect,progress,reduced))
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var source: Dictionary = EnemyTrail.actor(_board,effect)
	var renderer: Node = _board.unit_cutout_renderer(source)
	_expect(is_instance_valid(renderer),"Production cutout exists: " + type)
	_expect(renderer.facing == ("rear" if view.begins_with("rear") else "front") and renderer.mirrored == view.ends_with("mirror"),"Capture uses its requested facing and mirror: " + label_for_view(type,variant,view))
	var layer_count: int = 0
	if variant == "area":
		var layers: Dictionary = _board.get("_scene_front_effect_render_layers_by_tile")
		for tile: Vector2i in effect["tiles"]:
			var layer: Control = layers.get(tile)
			_expect(is_instance_valid(layer),"Physical area retains target depth layer")
			if is_instance_valid(layer):
				var light: Node2D = layer.get("_strike_trail_layer")
				_expect(is_instance_valid(light),"Each physical target owns additive rake light")
				if is_instance_valid(light):
					_expect(not light.get("_batches").is_empty(),"Area target has luminous rake geometry")
					layer_count += 1
	else:
		var layer: Control = _board.get("_effects_render_layer")
		var light: Node2D = layer.get("_strike_trail_layer")
		_expect(is_instance_valid(light),"Production effects layer owns enemy light")
		if is_instance_valid(light):
			_expect((light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,"Enemy trail uses additive material")
			_expect(light.get("_batches").is_empty() if reduced else not light.get("_batches").is_empty(),"Enemy geometry matches reduced-motion setting")
			layer_count = 1
	var label: String = "%s%s_%s_%03d%s" % [type,"_"+variant if not variant.is_empty() else "",view,roundi(progress*100),"_reduced" if reduced else ""]
	var pixels: Image = _surface.get_texture().get_image()
	_expect(pixels.get_size() == SIZE,"Capture is 1920x1080")
	_expect(pixels.save_png(OUTPUT.path_join(label+".png")) == OK,"Frame saves: " + label)
	var body: Rect2 = _board.call("_unit_draw_rect_for_center",source,_board.call("_unit_center",source))
	var crop := Rect2i(Vector2i(body.get_center()-Vector2(250,250)),Vector2i(500,500))
	var boundary: float = Points.contact(effect)
	var window: Vector2 = Vector2(0.30,0.60) if variant == "area" else Points.window_for(Points.settings(type,effect),boundary)
	_captures.append({"file":label+".png","enemy_type":type,"variant":variant,"view":view,"progress":progress,"element":element,"contact":boundary,"window":[window.x,window.y],
		"kind":"rake" if variant == "area" else Points.settings(type,effect)["kind"],"reduced":reduced,"light_layers":layer_count,
		"crop":[crop.position.x,crop.position.y,crop.size.x,crop.size.y],"clip":renderer.clip,"clip_phase":renderer.phase})

func _expect(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message): _errors.append(message)

func label_for_view(type: String, variant: String, view: String) -> String:
	return "%s/%s/%s" % [type,variant,view]
