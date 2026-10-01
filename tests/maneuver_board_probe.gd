extends SceneTree

## Real-renderer proof for wave-4 family B on the combat board: player self-flag
## and Crystal Mantle badges, a Petrified enemy (badge and turn-order Skips
## marker), a Cyclone Seal hover forecast (radius focus, straight paths, ghosts,
## collision marker) and a targetless Gale Ward confirmation with its paths.
## Run: python3 tools/visual_probe_runner.py tests/maneuver_board_probe.gd --task-id card-pool-overhaul-w4b --no-headless --expect-size 1920x1080 --min-images 3

const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Suite = preload("res://tests/suites/maneuver_suite.gd")
const ManeuverRules = preload("res://scripts/maneuver_rules.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/maneuver_board"
const ART_BY_FIXTURE: Dictionary = {
	"w4b_cyclone_seal": "res://assets/art/cards/cyclone_seal.png",
	"w4b_gale_ward": "res://assets/art/cards/gale_ward.png",
	"w4b_bottled_gale": "res://assets/art/cards/bottled_gale.png",
	"w4b_petrify": "res://assets/art/cards/raise_stone.png",
	"w4b_windbreak": "res://assets/art/cards/brace.png",
}

var scene: Node
var canvas: SubViewport
var failed: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Store.set_storage_path("user://w4b_profile.json")
	Store.set_run_storage_path("user://w4b_run.save")
	Settings.set_storage_path("user://w4b_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Suite._install_fixtures()
	for card_id: String in ART_BY_FIXTURE.keys():
		(Data.cards()[card_id] as Dictionary)["art_path"] = ART_BY_FIXTURE[card_id]
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var combat := Combat.new()
	var engine := Run.new()
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	var run_state: Dictionary = engine.create_new_run(9431, profile)
	run_state["mode"] = "combat"
	run_state["pre_battle_pending"] = false
	run_state["current_room"] = Vector2i(1, 0)
	var state: Dictionary = Suite._state(combat, [Suite._enemy(1, Vector2i(6, 5)), Suite._enemy(2, Vector2i(7, 5)), Suite._enemy(3, Vector2i(4, 2)), Suite._enemy(4, Vector2i(2, 7))], Vector2i(2, 5))
	state["room_name"] = "Maneuver Proving Ground"
	state = Suite._resolve(combat, state, "w4b_crystal_mantle")
	state = Suite._resolve(combat, state, "w4b_petrify", [Vector2i(2, 7)])
	ManeuverRules.gain_flag(state, {"flag": "anchored"}, "Windbreak")
	ManeuverRules.gain_flag(state, {"flag": "fire_immune_turn"}, "Cinder Trail")
	var deck: Dictionary = state["deck"] as Dictionary
	deck["hand"] = ["w4b_cyclone_seal", "w4b_gale_ward", "w4b_petrify", "w4b_windbreak", "w4b_bottled_gale"]
	deck["draw"] = ["w4b_gale_ward", "w4b_gale_ward"]
	state["deck"] = deck
	run_state["rooms"]["1,0"]["type"] = "combat"
	run_state["current_room_layout"] = {"name": "Maneuver Proving Ground", "type": "combat", "grid": state["grid"], "npcs": [], "exits": []}
	run_state["combat_state"] = state
	await _load(run_state)
	await _capture("maneuver_hud")
	var live: Dictionary = scene.get("_combat_state") as Dictionary
	expect(int((live.get("player", {}) as Dictionary).get("frost_armor", 0)) == 2, "The hero carries two Mantle layers")
	expect(ManeuverRules.is_petrified(Suite._unit(live, 4)), "The far enemy is Petrified")
	var skip_badge: Node = scene.find_child("PetrifiedSkipBadge", true, false)
	expect(skip_badge != null, "The turn order marks the Petrified enemy's skipped activation")
	# Cyclone Seal hover: radius focus, straight pull paths, ghosts and the collision.
	var preview: Dictionary = scene.call("_card_preview_for_index", 0)
	await scene.call("_begin_card_preview", 0, preview)
	scene.call("_on_board_tile_hovered", Vector2i(4, 5))
	scene.call("_refresh_stage_view")
	await _capture("cyclone_seal_hover")
	var hovered: Dictionary = scene.call("_active_card_preview")
	var presentation: Dictionary = scene.call("_preview_presentation", hovered)
	expect((presentation.get("displacement_paths", []) as Array).size() >= 3, "Hover draws each pulled enemy's straight path")
	expect((presentation.get("collision_markers", []) as Array).size() == 1, "Hover marks the pull collision")
	expect((presentation.get("focus_tiles", []) as Array).size() > 9, "Hover focuses the radius-3 area")
	scene.call("_cancel_card_selection")
	await process_frame
	# Gale Ward: targetless, shown on its resolved board with its push paths.
	var adjacent: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	adjacent["enemies"][0]["pos"] = Vector2i(3, 5)
	scene.set("_combat_state", adjacent)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await process_frame
	var gale: Dictionary = scene.call("_card_preview_for_index", 1)
	await scene.call("_begin_card_preview", 1, gale)
	scene.call("_refresh_stage_view")
	await _capture("gale_ward_confirmation")
	expect(bool(scene.call("_pending_card_requires_confirmation")), "Gale Ward waits for confirmation")
	var confirmation: Dictionary = {}
	scene.call("_append_confirmation_force_preview", confirmation)
	expect(not (confirmation.get("displacement_paths", []) as Array).is_empty(), "The confirmation board shows the push path")
	print("MANEUVER BOARD PROOF: ", "PASS" if failed == 0 else "FAIL")
	Suite._remove_fixtures()
	canvas.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _load(state: Dictionary) -> void:
	Store.save_data(state["progression"])
	Store.save_run_state(state)
	scene.set("_progression", state["progression"])
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")):
		scene.call("_close_dialogue")
	scene.call("_close_large_map")
	for i: int in range(8):
		await process_frame

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	expect(image.get_size() == Vector2i(1920, 1080), "Native 1920x1080 proof")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = "%s/%s.png" % [OUTPUT, label]
	expect(image.save_png(path) == OK, "PNG saved")
	print(ProjectSettings.globalize_path(path))

func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
