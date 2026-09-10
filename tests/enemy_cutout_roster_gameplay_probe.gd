extends SceneTree

## Integration proof for the combined roster. Every intent runs through the
## actual Pass Turn handler, resolver and wall-clock animation scheduler.
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://probes/enemy_cutout_roster"
const ACTORS := {
	"crawler": "crawler", "acolyte": "acolyte", "harrier": "harrier",
	"cinder_ooze": "cinder_ooze", "cinder_droplet": "cinder_droplet",
	"bile_bloomer": "bile_bloomer", "chainbound_gaoler": "gaoler",
	"grave_surgeon": "grave_surgeon", "frostglass_lancer": "frostglass",
	"tharokh": "tharokh", "vyraketh": "vyraketh", "vaeloryx": "vaeloryx",
	"iskaldra": "iskaldra", "noctyrax": "noctyrax", "zekarion": "zekarion",
	"veilbound_acolyte": "veilbound_acolyte", "lightning_wisp": "lightning_wisp"
}
var _instance: Node
var _board: Control
var _viewport: SubViewport
var _errors: Array[String]
var _manifest: Dictionary = {"size": [1920,1080], "ui_scale": 1.0, "native": true, "clock": "production wall clock", "clips": [], "facings": [], "errors": []}
var _active_type: String = ""
var _observer_type: String = ""

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	ProgressionStore.set_storage_path("user://roster_progression.json")
	ProgressionStore.set_run_storage_path("user://roster_run.save")
	ProgressionStore.clear_saved_run()
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	var actor_types: Array = ACTORS.keys()
	for actor_index: int in range(actor_types.size()):
		_active_type = str(actor_types[actor_index])
		_observer_type = str(actor_types[(actor_index + 1) % actor_types.size()])
		var intents: Array = GameData.enemy_def(_active_type)["intents"]
		await _fixture(intents[0])
		await _inspect_facings()
		for intent: Dictionary in intents:
			await _fixture(intent)
			await _pass_and_record(_active_type + "_" + str(intent["id"]), false)
		# Reduced motion must keep both newly registered actors and outcome rules.
		await _fixture(intents[0], true)
		await _pass_and_record(_active_type + "_reduced", true)
		print("ROSTER NATIVE PROOF: completed " + _active_type)
		_write_manifest()
	await _verify_death()
	_manifest["errors"] = _errors
	_write_manifest()
	for error: String in _errors:
		push_error(error)
	print("ENEMY CUTOUT ROSTER GAMEPLAY TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _fixture(intent: Dictionary, reduced: bool = false) -> void:
	_instance.call("_cancel_drag_play")
	_instance.call("_reset_card_resolution")
	var hand: Array = ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var grid: Array = []
	for y: int in range(10):
		var row: Array = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 9 else "stone")
		grid.append(row)
	var definition: Dictionary = GameData.enemy_def(_active_type)
	var footprint: Array = definition.get("footprint", [1,1])
	var has_move: bool = false
	var has_melee: bool = false
	for action: Dictionary in intent.get("actions", []):
		has_move = has_move or str(action.get("type", "")) == "move_toward"
		has_melee = has_melee or str(action.get("type", "")) == "melee"
	var separation: int = 0 if has_melee and not has_move else 1
	var player_tile := Vector2i(4, 4 + int(footprint[1]) + separation)
	var layout: Dictionary = {"name": "Combined Enemy Cutout Trial", "coord": Vector2i(4,3), "type": "combat", "grid": grid,
		"player_start": player_tile, "enemies": [
			{"id":1,"type":_active_type,"pos":Vector2i(4,4),"hp":100,"max_hp":100,"block":0},
			{"id":2,"type":_observer_type,"pos":Vector2i(7,4),"hp":50,"max_hp":100,"block":0}],
		"traps": [], "terrain": [], "element": "none"}
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(260910, layout, {"hp":200,"max_hp":200,"deck_cards":hand.duplicate(),"relics":[],"hand_size":5,"heal_bonus":0})
	state["enemies"][0]["intent"] = intent.duplicate(true)
	for entry: Dictionary in state["turn_queue"]:
		entry["time"] = 1 if int(entry.get("enemy_id", -1)) == 1 else 1000
	state["deck"] = {"hand": hand.duplicate(), "draw": [], "discard": [], "burned": []}
	state["current_actor"] = {"kind":"player","key":"player"}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["traps"] = []
	state["terrain"] = []
	state = combat.normalize_player_movement_pool(state)
	var progression: Dictionary = (_instance.get("_progression") as Dictionary).duplicate(true)
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run.merge({"mode":"combat", "current_room":layout["coord"], "current_room_layout":layout,
		"combat_state":state.duplicate(true), "progression":progression.duplicate(true)}, true)
	_instance.set("_progression", progression)
	_instance.set("_run_state", run)
	var settings: Dictionary = (_instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = reduced
	settings["ui_scale"] = 1.0
	_instance.set("_settings", settings)
	_instance.call("_sync_combat_state_from_run")
	_instance.set("_animation_lock", false)
	_instance.call("_refresh_ui")
	Input.warp_mouse(Vector2(960,86))
	await _settle()
	_check(not _snapshot(_active_type, 1).is_empty(), "Primary cutout exists: " + _active_type)
	_check(not _snapshot(_observer_type, 2).is_empty(), "Mixed observer cutout exists: " + _observer_type)

func _inspect_facings() -> void:
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	var points: Array[Vector2i]
	points.assign([Vector2i(4,8), Vector2i(8,4), Vector2i(4,2), Vector2i(2,4)])
	var expected: Array = [["front",false], ["front",true], ["rear",false], ["rear",true]]
	for index: int in range(points.size()):
		state["player"]["pos"] = points[index]
		_instance.call("_render_board_state", state, {}, true)
		await _settle()
		var sample: Dictionary = _snapshot(_active_type,1)
		_check(sample.get("facing") == expected[index][0] and sample.get("mirrored") == expected[index][1], _active_type + " combined facing " + str(index))
		await _still(_active_type + "_facing_" + str(index))
		_manifest["facings"].append({"actor":_active_type,"direction":index,"snapshot":sample})

func _pass_and_record(label: String, reduced: bool) -> void:
	var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	var engine := CombatEngine.new()
	var resolved: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))
	var expected: Dictionary = resolved["state"]
	var primary_texture: int = int(_snapshot(_active_type,1).get("texture_id",0))
	var observer_texture: int = int(_snapshot(_observer_type,2).get("texture_id",0))
	_check(primary_texture != 0 and observer_texture != 0 and primary_texture != observer_texture, label + " owns distinct mixed-actor textures")
	var started: int = Time.get_ticks_usec()
	var phases: Dictionary = {}
	var samples: Array[Dictionary]
	var captures: Dictionary = {}
	_instance.call("_on_pass_turn_pressed")
	while Time.get_ticks_usec() - started < 15000000:
		await process_frame
		var sample: Dictionary = _snapshot(_active_type,1)
		var observer: Dictionary = _snapshot(_observer_type,2)
		_check(int(sample.get("texture_id",0)) == primary_texture, label + " retains the primary texture")
		_check(int(observer.get("texture_id",0)) == observer_texture, label + " retains the observer texture")
		var clip: String = str(sample.get("clip", "missing"))
		var action: String = str(sample.get("action", ""))
		phases[clip + ":" + action] = true
		if reduced:
			_check(clip == "rest", label + " retains reduced-motion still art")
		var presentation: Dictionary = _board.get("presentation")
		var effect: Dictionary = presentation.get("effect", {})
		var progress: float = float(presentation.get("effect_progress",0.0))
		samples.append({"seconds": float(Time.get_ticks_usec()-started)/1000000.0, "animation":sample,
			"effect":effect.duplicate(true),"progress":progress,"player_hp":(_board.get("combat_state") as Dictionary).get("player",{}).get("hp",0)})
		var stage: String = ""
		if not captures.has("motion") and clip not in ["idle", "rest", "missing"]:
			stage = "motion"
		elif not captures.has("contact") and not effect.is_empty() and progress >= 0.5 and progress < 0.9:
			stage = "contact"
		if not stage.is_empty():
			await _still(label + "_" + stage)
			captures[stage] = true
		if not bool(_instance.get("_animation_lock")):
			break
	_check(not bool(_instance.get("_animation_lock")), label + " returns input before timeout")
	var after: Dictionary = _instance.get("_combat_state")
	for key: String in ["hp","pos","expose","poison","burn","bleed","freeze","shock"]:
		_check(after.get("player",{}).get(key,0) == expected.get("player",{}).get(key,0), label + " preserves player " + key)
	for key: String in ["initiative_clock","terrain","traps","umbra"]:
		_check(after.get(key) == expected.get(key), label + " preserves " + key)
	_check((after.get("enemies",[]) as Array).size() == (expected.get("enemies",[]) as Array).size(), label + " preserves summons and actor count")
	for index: int in range(mini((after.get("enemies",[]) as Array).size(),(expected.get("enemies",[]) as Array).size())):
		for key: String in ["hp","pos","block","footprint"]:
			_check(after["enemies"][index].get(key) == expected["enemies"][index].get(key), label + " preserves enemy " + str(index) + " " + key)
	await _still(label + "_settled")
	_manifest["clips"].append({"label":label,"reduced":reduced,"phases":phases.keys(),"samples":samples,
		"player_hp":after.get("player",{}).get("hp",0),"seconds":float(Time.get_ticks_usec()-started)/1000000.0})

func _verify_death() -> void:
	# Exercise the consolidated padded-source lookup on every converted type.
	for actor: String in ACTORS:
		_active_type = actor
		_observer_type = "warden"
		await _fixture(GameData.enemy_def(actor)["intents"][0])
		var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var dying: Dictionary = state["enemies"][0].duplicate(true)
		dying.merge({"key":"enemy_1","role":"enemy","death_animation":true,"death_progress":0.45},true)
		var texture: Texture2D = _board.call("_texture_for_unit",dying)
		state["enemies"][0]["hp"] = 0
		_instance.call("_render_board_state",state,{"death_animation_units":[dying]},true)
		await _settle()
		_check(_board.call("_enemy_shadow_dissolve_source_texture",dying) == texture, actor + " death retains its cutout source")
		var effects: Dictionary = _board.get("_enemy_shadow_dissolve_effects_by_key")
		_check(effects.has("enemy_1"), actor + " has the existing dissolve effect")
		if effects.has("enemy_1"):
			_check((effects["enemy_1"].call("source_rect") as Rect2).is_equal_approx(_board.call("_unit_texture_draw_rect",dying,_board.call("_unit_center",dying))), actor + " death preserves padded source registration")
		await _still(actor + "_death")
		_instance.call("_render_board_state",state,{},true)
		await _settle()
		_check(_snapshot(actor,1).is_empty(), actor + " releases its removed renderer")

func _snapshot(actor: String, id: int) -> Dictionary:
	var method: String = str(ACTORS.get(actor,actor)) + "_animation_snapshot"
	return _board.call(method,"enemy_%d" % id)

func _still(label: String) -> void:
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))

func _settle() -> void:
	for frame: int in range(5):
		await process_frame
	await create_timer(0.10).timeout

func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)

func _write_manifest() -> void:
	_manifest["errors"] = _errors
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest,"\t"))
