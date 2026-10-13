extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Rules = preload("res://scripts/chronicle_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const OUTPUT_DIR: String = "user://probes/chronicle/1920x1080"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const CAPTURE_SETTLE_FRAMES: int = 4
const CLICK_HOVER_SETTLE_FRAMES: int = 1
const OVERFLOW_SPELL_COUNT: int = 30
# Debug fixture values; the seven outcomes, dates, scores and paths are taken
# from the approved mockup. Build icons use existing production starter gear
# and seven existing relics because the source mockup leaves those IDs open.
const PROBE_RELIC_IDS := ["iron_lung", "ember_lens", "pilgrim_boots", "mirror_shard", "coffin_nails", "reinforced_shield", "iron_buckler"]
const MOCKUP_SPELLS := [["Cinderburst", 1], ["Frost Lance", 1], ["pale_spark", 1], ["chain_bolt", 1], ["Glacier Step", 1], ["waning_pulse", 1]]
var _failed: bool = false
var _menu: Control
var _canvas: SubViewport

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Store.set_storage_path("user://chronicle_probe_profile.json")
	Store.set_run_storage_path("user://chronicle_probe_run.save")
	Settings.set_storage_path("user://chronicle_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Store.clear_saved_run()
	Store.save_data(seeded_profile())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_run")

static func seeded_profile() -> Dictionary:
	var profile: Dictionary = Store.default_data()
	var specs := [
		["defeat", 2, "Rime Hall", "12 Oct", 41, 567, 2],
		["victory", 5, "", "11 Oct", 96, 1240, 1],
		["defeat", 4, "Tempest Spire", "11 Oct", 74, 902, 1],
		["embrace", 1, "Cinder Crown", "10 Oct", 28, 311, 0],
		["defeat", 0, "Worldspine Roots", "10 Oct", 12, 104, 0],
		["victory", 5, "", "9 Oct", 101, 1108, 0],
		["defeat", 3, "Hollow Gale", "8 Oct", 63, 688, 0]
	]
	var names := ["Worldspine Roots", "Cinder Crown", "Rime Hall", "Hollow Gale", "Tempest Spire", "Heart of the Umbra"]
	var dragons := ["tharokh", "vyraketh", "iskaldra", "vaeloryx", "zekarion", "noctyrax"]
	var gear: Array = GameData.starting_equipped_equipment().values()
	var relics: Array = []
	# Resolve only existing approved assets. Never synthesize placeholder icons.
	for id: String in PROBE_RELIC_IDS:
		if not GameData.relic_def(id).is_empty():
			relics.append(id)
	if relics.size() < 7:
		for id: String in GameData.relics():
			if relics.size() == 7:
				break
			if not relics.has(id):
				relics.append(id)
	var records: Array = []
	for index: int in range(specs.size()):
		var spec: Array = specs[index]
		var path: Array = []
		for section: int in range(int(spec[1]) + 1):
			path.append(["combat", "event", "combat", "combat", "treasure", "combat", "combat", "campfire", "boss"])
		if spec[0] == "embrace":
			path[-1] = ["combat", "event", "combat", "campfire"]
		elif spec[0] == "defeat":
			path[-1] = ["combat", "graftwright", "combat", "combat", "treasure", "combat", "combat"]
		if index == 0:
			path[0] = ["combat", "combat", "event", "combat", "treasure", "combat", "scavenger", "combat", "campfire", "boss"]
		var record: Dictionary = {
			"run_id": "chronicle-probe-%d" % index, "outcome": spec[0], "section_index": spec[1],
			"section_name": spec[2], "ended_at": spec[3], "run_seconds": int(spec[4]) * 60,
			"score_total": spec[5], "umbra_depth": spec[6], "room_index": path[-1].size(), "room_total": 11,
			"path": path, "section_names": names.slice(0, int(spec[1]) + 1), "dragon_ids": dragons.slice(0, int(spec[1]) + 1),
			"killer_text": Rules.killer_text({}, str(spec[0])), "gear": gear, "deck": MOCKUP_SPELLS,
			"relics": relics, "feats": []
		}
		if index == 0:
			record["killer_text"] = "Felled by a Frostglass Lancer's Glass Lunge"
			record["feats"] = [{"title": "Flawless", "detail": "Vyraketh"}, {"title": "Chain Reaction", "detail": "3 foes"}, {"title": "Overkill", "detail": "22 damage"}]
		records.append(record)
	profile[Store.CHRONICLE_RECORDS_KEY] = records
	profile[Store.CHRONICLE_TOTALS_KEY] = {"runs": 24, "escapes": 2, "best_score": 1240, "dragons_slain": 31, "deepest_depth": 3}
	return profile

func _run() -> void:
	_canvas = create_capture_viewport(root)
	_menu = preload("res://scenes/main_menu.tscn").instantiate()
	_canvas.add_child(_menu)
	root.content_scale_size = CAPTURE_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = CAPTURE_SIZE
	root.content_scale_factor = 1.0
	await _settle()
	_require(is_equal_approx(root.content_scale_factor, 1.0) and is_equal_approx(float(Settings.load_settings()["ui_scale"]), 1.0), "100% UI scale")
	await _capture("main_menu")
	await click_button(_menu.get_node("MenuColumn/ChronicleButton"), _canvas)
	await _settle()
	var panel: Control = _menu.get_node("ChroniclePanel")
	_require(panel.records.size() == 7 and panel.selected_index == 0, "Seven mockup records, newest selected")
	_require(panel.get_node("ChronicleFrame").position == Vector2(60, 110), "Panel position follows brief")
	_require((panel.find_child("ChronicleScore", true, false) as Label).text == "567", "Score belongs in selected detail title row")
	await _capture("chronicle")
	panel.open(Store.default_data(), false)
	await _settle()
	_require(panel.records.is_empty(), "Empty history")
	await _capture("empty")
	panel.open(seeded_profile(), false)
	panel.select_record(1, true)
	await _settle()
	_require((panel.find_child("ChronicleOutcome", true, false) as Label).text == "ESCAPED", "Victory selected")
	await _capture("victory")
	var overflow: Dictionary = seeded_profile()
	overflow[Store.CHRONICLE_RECORDS_KEY][0]["deck"] = overflow_deck()
	panel.open(overflow, false)
	await _settle()
	var spells := panel.find_child("ChronicleSpells", true, false) as Label
	_require(spells.text.contains("more") and spells.get_line_count() <= 8, "Thirty-spell overflow is limited to eight lines")
	await _capture("spells_overflow")
	panel.open(seeded_profile(), false)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "xbox")
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	panel._input(down)
	await _settle()
	_require(panel.selected_index == 1 and _canvas.gui_get_focus_owner() == panel.find_child("DescentRow1", true, false), "Controller focus follows selected row")
	_require(panel.get_node("ChronicleControllerPrompts").visible, "Controller Select / Back prompts visible")
	await _capture("controller_focus")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	panel._input(back)
	_require(_menu.get_node("MenuColumn/ChronicleButton").has_focus(), "Back restores Chronicle menu focus")
	router.call("clear_forced_state_for_test")
	_menu.queue_free()
	_canvas.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("CHRONICLE PROBE RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

static func create_capture_viewport(parent: Node) -> SubViewport:
	# Capture a fixed render target, independent of the native Retina window.
	var canvas := SubViewport.new()
	canvas.size = CAPTURE_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(canvas)
	return canvas

func _settle() -> void:
	for frame: int in range(CAPTURE_SETTLE_FRAMES):
		await process_frame
	await RenderingServer.frame_post_draw

static func overflow_deck() -> Array:
	var deck: Array = []
	for id: String in GameData.cards():
		deck.append([id, 1])
		if deck.size() == OVERFLOW_SPELL_COUNT:
			break
	return deck

# Native pointer dispatch is shared by the headless input test and this capture
# probe, so the menu entry is proved through the actual press/release path.
static func click_button(button: Button, viewport: Viewport) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.relative = at - viewport.get_mouse_position()
	viewport.push_input(motion, true)
	for frame: int in range(CLICK_HOVER_SETTLE_FRAMES):
		await button.get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = at
	press.global_position = at
	press.pressed = true
	viewport.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	viewport.push_input(release, true)

func _capture(state: String) -> void:
	var capture: Image = _canvas.get_texture().get_image()
	_require(capture != null and capture.get_size() == CAPTURE_SIZE, "Real renderer at 1920x1080")
	if capture != null:
		_require(capture.save_png(OUTPUT_DIR.path_join(state + ".png")) == OK, "Screenshot saves")

func _require(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error(message)
