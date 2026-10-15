extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const HudSuite = preload("res://tests/suites/turn_clock_hud_suite.gd")
const PortraitBuilder = preload("res://tools/build_turn_order_assets.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://probes/turn_order_portraits/turn_order_portraits.png"

# Proof-only fixture choices. Production layout, crop rules and tuning are unchanged.
const FIXTURE_SEED := 73101
const FIXTURE_ENEMIES: Array = ["acolyte", "veilbound_acolyte", "harrier", "grave_surgeon", "warden"]
const FIXTURE_POSITIONS: Array = [Vector2i(4, 1), Vector2i(5, 2), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 5)]
const FIXTURE_FIRST_ENEMY_TIME := 1
var _failures: Array[String]

func _initialize() -> void:
	print("turn order portraits probe: start")
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://turn_order_portraits_profile.json")
	ProgressionStore.set_run_storage_path("user://turn_order_portraits_run.save")
	ProgressionStore.clear_saved_run()
	SettingsStore.set_storage_path("user://turn_order_portraits_settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	await HudSuite._settle(self)
	scene.set("_settings", settings)
	SettingsStore.apply_settings(settings, root, false)
	await HudSuite._install(self, scene, _fixture())
	_assert_portraits(scene)
	_expect(is_equal_approx(float((scene.get("_settings") as Dictionary).get("ui_scale", 0.0)), 1.0), "UI scale is 100 percent")
	var semantics_only: bool = OS.get_cmdline_user_args().has("--semantics-only")
	if not semantics_only:
		_expect(DisplayServer.get_name() != "headless", "Capture requires the real renderer; use --semantics-only for headless checks")
		if DisplayServer.get_name() != "headless" and _failures.is_empty():
			await RenderingServer.frame_post_draw
			var image: Image = viewport.get_texture().get_image()
			_expect(image != null and image.get_size() == VIEWPORT_SIZE, "Capture is exactly 1920x1080")
			if image != null and image.get_size() == VIEWPORT_SIZE:
				var path: String = ProjectSettings.globalize_path(OUTPUT)
				DirAccess.make_dir_recursive_absolute(path.get_base_dir())
				_expect(image.save_png(path) == OK, "Save clock capture")
				print("TURN ORDER PORTRAITS CAPTURE: " + path)
	viewport.queue_free()
	await process_frame
	for failure: String in _failures:
		push_error(failure)
	print("TURN ORDER PORTRAITS %s: %s" % ["SEMANTICS" if semantics_only else "PROBE", "PASS (5 rebuilt portraits)" if _failures.is_empty() else "FAIL"])
	quit(0 if _failures.is_empty() else 1)

func _fixture() -> Dictionary:
	var layout: Dictionary = HudSuite.room_layout()
	var enemies: Array[Dictionary]
	for index: int in range(FIXTURE_ENEMIES.size()):
		var key: String = str(FIXTURE_ENEMIES[index])
		var definition: Dictionary = GameData.enemy_def(key)
		var hp: int = int(definition["max_hp"])
		enemies.append({"id": index + 1, "type": key, "pos": FIXTURE_POSITIONS[index], "hp": hp, "max_hp": hp, "block": 0})
	layout["enemies"] = enemies
	var state: Dictionary = CombatEngine.new().create_combat(FIXTURE_SEED, layout, {"hp": 24, "max_hp": 24, "deck_cards": HudSuite.HAND.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	state["deck"]["hand"] = HudSuite.HAND.duplicate()
	# Put all five distinct portraits before any repeat activation in the rail.
	var queue: Array = state["turn_queue"]
	for index: int in range(queue.size()):
		queue[index]["time"] = int(state["initiative_clock"]) + FIXTURE_FIRST_ENEMY_TIME + index
	return state

func _assert_portraits(scene: Node) -> void:
	var bar: Control = scene.get("_turn_order_bar") as Control
	_expect(bar != null and bar.is_visible_in_tree(), "Production turn-order rail is visible")
	if bar == null:
		return
	var visible_keys: Dictionary = {}
	for config: Dictionary in PortraitBuilder.PORTRAITS:
		var key: String = str(config["key"])
		if not FIXTURE_ENEMIES.has(key):
			continue
		var expected := Image.new()
		_expect(expected.load(str(config["out"])) == OK, "Load shipped portrait: " + key)
		expected.convert(Image.FORMAT_RGBA8)
		for child: Node in bar.get_children():
			var slot: Control = child as Control
			if slot == null or not slot.is_visible_in_tree():
				continue
			var texture: Texture2D = slot.get_meta("turn_order_portrait_texture", null) as Texture2D
			if texture == null:
				continue
			var actual: Image = texture.get_image()
			if actual == null:
				continue
			actual.convert(Image.FORMAT_RGBA8)
			if actual.get_size() != expected.get_size() or actual.get_data() != expected.get_data():
				continue
			_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(slot.get_global_rect()), "Portrait is inside the capture: " + key)
			visible_keys[key] = true
			break
		_expect(visible_keys.has(key), "Rail displays the rebuilt portrait pixels: " + key)
	_expect(visible_keys.size() == FIXTURE_ENEMIES.size(), "Five distinct rebuilt portraits are visible")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
