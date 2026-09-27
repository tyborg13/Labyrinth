extends SceneTree

# Resolver-backed visual addendum: counterplay removes all announced area tiles.
# Normal/reduced playback must preserve the cast but invent no target impact.
const Suite = preload("res://tests/suites/dragon_area_presentation_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Profile = preload("res://scripts/dragon_presentation.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT: String = "user://probes/dragon_canceled_area"
var scene: Node
var canvas: SubViewport
var failures: Array[String]
var witnesses: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://canceled_area_profile.json")
	Store.set_run_storage_path("user://canceled_area_run.save")
	Settings.set_storage_path("user://canceled_area_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	Suite.run(_expect)
	for boss_id: String in ["vyraketh","tharokh"]:
		var fixture: Dictionary = Suite.canceled_case(boss_id)
		var state: Dictionary = fixture["run"]["combat_state"]
		var result: Dictionary = Combat.new().resolve_enemy_turn_with_steps(state,0)
		for reduced: bool in [false,true]:
			var mode: Dictionary = settings.duplicate(true)
			mode["reduced_motion"] = reduced
			scene.call("_load_run_state",fixture["run"].duplicate(true))
			await process_frame
			await process_frame
			if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
			scene.set("_settings",mode)
			scene.call("_set_show_all_enemy_intents",true)
			var prefix: String = boss_id+("_reduced" if reduced else "_normal")
			await _capture(prefix+"_canceled_warning")
			await _play_and_capture(state,result,fixture["action"],prefix,reduced)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("witnesses.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"witnesses":witnesses},"  "))
	print("DRAGON CANCELED AREA PRESENTATION: ","PASS" if failures.is_empty() else "FAIL",failures)
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _play_and_capture(before: Dictionary, result: Dictionary, action: String, prefix: String, reduced: bool) -> void:
	var done: Dictionary = {"done":false}
	var display: Dictionary = before.duplicate(true)
	var captured: bool = false
	var image: Image
	_play(display,result["steps"],done)
	while not bool(done["done"]):
		await RenderingServer.frame_post_draw
		var board: Node = scene.get("board_view")
		var shown: Dictionary = board.get("presentation")
		var effect: Dictionary = shown.get("effect",{})
		if str(effect.get("action_type",""))!=action or captured: continue
		var progress: float = float(shown.get("effect_progress",0.0))
		if not reduced and (progress < .60 or progress > .82): continue
		captured = true
		var tiles: Array[Vector2i] = Profile.tiles(effect)
		var depth: Array = board.call("_elemental_scene_depth_tiles_for_presentation",shown)
		var player_tile: Vector2i = before["player"]["pos"]
		_expect(tiles.is_empty(),prefix+" has no invented target impacts")
		_expect(not depth.has(player_tile),prefix+" does not render an elemental effect at the safe player tile")
		_expect(int((board.get("combat_state") as Dictionary)["player"]["hp"])==int(before["player"]["hp"]),prefix+" retains player HP at the impact boundary")
		var boss_id: String = str(before["enemies"][0]["type"])
		var snapshot: Dictionary = board.call(boss_id+"_animation_snapshot",str(effect["actor_key"]))
		if reduced: _expect(snapshot.get("clip","")=="rest",prefix+" uses a still rig")
		image = canvas.get_texture().get_image()
		witnesses.append({"image":prefix+"_cast_without_impact","action":action,"progress":progress,"reduced_motion":reduced,"effect_tiles":tiles,"depth_tiles":depth,"safe_player_tile":player_tile,"hp":before["player"]["hp"],"snapshot":snapshot})
	_expect(captured,prefix+" captures the actual canceled cast")
	_expect(int(display["player"]["hp"])==int(result["state"]["player"]["hp"]),prefix+" settled animation retains resolver HP")
	if image != null: _save(prefix+"_cast_without_impact",image)

func _play(state: Dictionary, steps: Array, done: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps",state,steps)
	done["done"] = true

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_save(name,canvas.get_texture().get_image())

func _save(name: String, image: Image) -> void:
	_expect(image.get_size()==Vector2i(1920,1080),"1920x1080 native image: "+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = OUTPUT.path_join(name+".png")
	_expect(image.save_png(path)==OK,"Saved "+name)
	print(ProjectSettings.globalize_path(path))

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
