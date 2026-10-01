extends SceneTree

## Real-renderer proof for the wave-3 keyword HUD: player Retaliate/Quicken/
## next-attack badges, active Rite badges in the relic bar, Quickened Time and
## next-attack damage in the hand, and a Rite card's rules text.
## Run: python3 tools/visual_probe_runner.py tests/card_keywords_w3_probe.gd --task-id card-pool-overhaul-w3 --no-headless --expect-size 1920x1080 --min-images 3

const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Suite = preload("res://tests/suites/card_keywords_w3_suite.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/card_keywords_w3"
const ART_BY_FIXTURE: Dictionary = {
	"w3_fx_rite_noon": "res://assets/art/cards/guiding_flare.png",
	"w3_fx_rite_pyre": "res://assets/art/cards/rite_of_the_pyre.png",
	"w3_fx_rite_thorns": "res://assets/art/cards/thorn_crown_pact.png",
	"w3_fx_slow_guard": "res://assets/art/cards/brace.png",
	"w3_fx_strike": "res://assets/art/cards/quick_stab.png",
	"w3_fx_lightning_chain": "res://assets/art/cards/spark_dart.png",
	"w3_fx_retaliate": "res://assets/art/cards/brace.png",
}

var scene: Node
var canvas: SubViewport
var failed: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Store.set_storage_path("user://w3_profile.json")
	Store.set_run_storage_path("user://w3_run.save")
	Settings.set_storage_path("user://w3_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Suite._install_fixtures()
	for card_id: String in ART_BY_FIXTURE.keys():
		(Data.cards()[card_id] as Dictionary)["art_path"] = ART_BY_FIXTURE[card_id]
	(Data.cards()["w3_fx_rite_noon"] as Dictionary)["description"] = "Rite: you radiate radius-2 Light, and your attacks deal 2 more to enemies in Light."
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
	var run_state: Dictionary = engine.create_new_run(9421, profile)
	run_state["mode"] = "combat"
	run_state["pre_battle_pending"] = false
	run_state["current_room"] = Vector2i(1, 0)
	var state: Dictionary = Suite._state(combat, Vector2i(5, 4))
	state["room_name"] = "Keyword Proving Ground"
	state = Suite._play(combat, state, "w3_fx_rite_pyre")
	state = Suite._play(combat, state, "w3_fx_rite_thorns")
	state = Suite._play(combat, state, "w3_fx_retaliate_riders")
	state = Suite._play(combat, state, "w3_fx_buff")
	state = Suite._play(combat, state, "w3_fx_quicken")
	var deck: Dictionary = state["deck"] as Dictionary
	deck["hand"] = ["w3_fx_rite_noon", "w3_fx_slow_guard", "w3_fx_strike", "w3_fx_lightning_chain", "w3_fx_retaliate"]
	state["deck"] = deck
	run_state["rooms"]["1,0"]["type"] = "combat"
	run_state["current_room_layout"] = {"name": "Keyword Proving Ground", "type": "combat", "grid": state["grid"], "npcs": [], "exits": []}
	run_state["combat_state"] = state
	await _load(run_state)
	await _capture("keywords_combat_hud")
	var grid: Node = scene.get("_relic_icon_grid") as Node
	var rite_badges: Array[Control] = []
	for child: Node in grid.get_children():
		if str(child.get_meta("rite_card_id", "")) != "":
			rite_badges.append(child as Control)
	expect(rite_badges.size() == 2, "Both active Rites appear in the relic bar")
	if rite_badges.size() == 2:
		var first_art: TextureRect = rite_badges[0].find_child("RiteArt", true, false) as TextureRect
		var second_art: TextureRect = rite_badges[1].find_child("RiteArt", true, false) as TextureRect
		expect(first_art != null and second_art != null and first_art.texture != second_art.texture, "Each active Rite badge shows its own card painting")
		expect(rite_badges[0].find_child("RiteMark", true, false) != null, "Each Rite badge carries the shared Rite mark")
	var slow: Node = _hand_card("w3_fx_slow_guard")
	expect(slow != null and int((slow.call("_display_card_def") as Dictionary).get("time", 0)) == 4, "The hand shows the Quickened Time")
	if not rite_badges.is_empty():
		await _tooltip(rite_badges[1], "rite_tooltip")
	if slow != null:
		var badge: Control = slow.get("_time_badge") as Control
		expect(badge != null and str(badge.tooltip_text).contains("Quickened: -2"), "The Time badge explains the Quicken discount")
		if badge != null:
			await _tooltip(slow as Control, "quickened_time_tooltip", badge.tooltip_text)
	print("CARD KEYWORDS W3 PROOF: ", "PASS" if failed == 0 else "FAIL")
	Suite._remove_fixtures()
	canvas.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _hand_card(id: String) -> Node:
	for child: Node in (scene.get("hand_box") as Node).get_children():
		var card: Node = scene.call("_card_widget_descendant", child)
		if card != null and str(card.get("card_id")) == id:
			return card
	return null

func _tooltip(source: Control, label: String, text: String = "") -> void:
	var tip: Control = source.call("_make_custom_tooltip", text if not text.is_empty() else source.tooltip_text) as Control
	if tip == null:
		expect(false, "Tooltip control for %s" % label)
		return
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	scene.add_child(overlay)
	overlay.add_child(tip)
	tip.position = Vector2(620, 160)
	await _capture(label)
	expect(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(tip.get_global_rect()), "Tooltip %s is entirely on-screen" % label)
	overlay.queue_free()
	await process_frame

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
