extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Chronicle = preload("res://scripts/chronicle_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const OpeningBoon = preload("res://scripts/opening_boon_rules.gd")
const DragonInspection = preload("res://tools/dragon_boss_inspection.gd")
const ChronicleProbe = preload("res://tests/chronicle_probe.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

const OPTIONS := {"dragon_id": "iskaldra", "dragon_depth": 4}
const DAMAGE: int = 20
const SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const SETTLE_FRAMES: int = 4
const OUTPUT_DIR: String = "user://pol88/1920x1080"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Store.set_storage_path("user://pol88_profile.json")
	Store.set_run_storage_path("user://pol88_run.save")
	Settings.set_storage_path("user://pol88_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = UI_SCALE
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = SIZE
	root.content_scale_factor = UI_SCALE
	root.size = SIZE
	call_deferred("_run")

func _run() -> void:
	var profile: Dictionary = Store.default_data()
	if not Store.save_data(profile):
		_fail("Could not save the isolated probe profile.")
		return
	var terminal: Dictionary = _terminal_run(profile)
	if terminal.get("mode") != "defeat" or terminal.get("run_stats", {}).get("killer", {}) != {"enemy_type": OPTIONS["dragon_id"], "intent_id": "", "damage": DAMAGE}:
		_fail("Expected an Iskaldra defeat with 20 damage and no intent.")
		return
	var canvas: SubViewport = ChronicleProbe.create_capture_viewport(root)
	canvas.msaa_2d = root.msaa_2d
	var scene: Control = RUN_SCENE.instantiate()
	canvas.add_child(scene)
	await process_frame
	scene.set("_progression", profile)
	scene.call("_load_run_state", terminal)
	await process_frame

	var recap: Control = scene.get("_run_end_recap")
	if not is_instance_valid(recap) or not recap.is_visible_in_tree():
		_fail("The terminal state did not show the defeat recap.")
		return
	recap.call("skip_presentation")
	scene.call("_seek_run_end_board_reframe", 1.0)
	await _settle()
	var expected: String = "Felled by an Iskaldra, the Rime Tyrant" if OS.get_cmdline_user_args().has("--release") else "Felled by Iskaldra, the Rime Tyrant"
	var cause: Label = recap.find_child("OutcomeCause", true, false)
	var recap_text: String = "%s, %d damage." % [expected, DAMAGE]
	if not is_instance_valid(cause) or not cause.is_visible_in_tree() or cause.text != recap_text:
		_fail("Recap cause did not match: " + recap_text)
		return
	if not _capture(canvas, "iskaldra_defeat_recap.png"):
		return
	print("POL88 RECAP: " + cause.text)

	var button: Button = recap.find_child("ChronicleButton", true, false)
	button.pressed.emit()
	await _settle()
	var panel: Control = recap.get_node("RunEndChronicle")
	var records: Array = panel.get("records")
	var selected: int = int(panel.get("selected_index"))
	var installed: Dictionary = scene.get("_run_state")
	var subline: RichTextLabel = panel.find_child("ChronicleSubline", true, false)
	if not panel.is_visible_in_tree() or records.size() != 1 or selected != 0 or records[0].get("run_id") != RunEngine.run_result_id(installed) or records[0].get("killer_text") != expected:
		_fail("The Chronicle did not select the recorded Iskaldra defeat.")
		return
	if not is_instance_valid(subline) or not subline.is_visible_in_tree() or not subline.get_parsed_text().ends_with(expected):
		_fail("The selected Chronicle detail did not end with: " + expected)
		return
	if not _capture(canvas, "iskaldra_chronicle.png"):
		return
	print("POL88 CHRONICLE: " + subline.get_parsed_text())
	canvas.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless":
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("POL88 ISKALDRA PROBE PASS")
	quit()

func _terminal_run(profile: Dictionary) -> Dictionary:
	var engine := RunEngine.new()
	var combat := CombatEngine.new()
	var run: Dictionary = engine.create_new_run(DragonInspection.seed_for_options(OPTIONS), profile)
	run = DragonInspection.build(engine, combat, run, OPTIONS)
	Chronicle.enter_room(run, Graph.room(run, run["current_room"]))
	var battle: Dictionary = run["combat_state"]
	var dragon: Dictionary = battle["enemies"][0]
	if dragon.get("type") != OPTIONS["dragon_id"]:
		return {}
	# Stage an intentless hit to reproduce the reported recap through the real
	# lethal damage, terminal settlement and Chronicle recording paths.
	battle[RunEngine.DEFIANCE_REMAINING_KEY] = 0
	battle["player"]["hp"] = DAMAGE
	battle["damage_context"] = {"actor_kind": "enemy", "actor_id": dragon["id"], "source_kind": "direct_attack", "enemy_type": dragon["type"]}
	battle = combat._damage_player(battle, DAMAGE, true, false)
	return OpeningBoon.leave_heirloom(engine.finish_combat(run, battle), "")

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _capture(canvas: SubViewport, filename: String) -> bool:
	if canvas.size != SIZE or not is_equal_approx(root.content_scale_factor, UI_SCALE) or not is_equal_approx(float(Settings.load_settings()["ui_scale"]), UI_SCALE):
		_fail("Expected a 1920x1080 viewport at 100% UI scale.")
		return false
	if DisplayServer.get_name() == "headless":
		return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var screenshot: Image = canvas.get_texture().get_image()
	if screenshot == null or screenshot.get_size() != SIZE or screenshot.save_png(OUTPUT_DIR.path_join(filename)) != OK:
		_fail("Could not save the 1920x1080 capture " + filename)
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	print("POL88 ISKALDRA PROBE FAIL")
	quit(1)
