extends SceneTree

const Fixtures = preload("res://tests/suites/en05_enemies_suite.gd")
const BaseFixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SETTLE_FRAMES: int = 8 # Headless integration scheduling only.
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const OUTPUT_DIR: String = "user://probes/mrg11h_review"
const HERO := Vector2i(1, 4)
const FIRST := Vector2i(2, 4)
const MIRROR := Vector2i(3, 4)
const LAST := Vector2i(4, 4)
const CASTER := Vector2i(5, 4)
const BLOCK: int = 10
var _viewport: SubViewport
var _errors: Array[String]
var _checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://en05_live_profile.json")
	Store.set_run_storage_path("user://en05_live_run.save")
	Settings.set_storage_path("user://en05_live_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = UI_SCALE
	Settings.save_settings(settings)
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	await _settle()
	scene._load_run_state(Run.new().create_new_run(BaseFixtures.TEST_SEED, Store.default_data()))
	await _settle()
	var before: Dictionary = Fixtures.mirror()
	BaseFixtures.install(scene, before)
	await _settle()
	var slot: int = before["deck"]["hand"].find("pale_spark")
	await scene._on_card_pressed(slot)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	var preview: Dictionary = scene.board_view.presentation
	_expect(preview.has("en05_reflect_preview"), "Selected ranged card decorates the real board with reflection marker")
	_expect(scene.board_view._damage_preview_map().has("player"), "Real card preview shows returning damage on hero")
	var engine := Combat.new()
	var action: Dictionary = preload("res://scripts/game_data.gd").card_def("pale_spark")["actions"][0]
	var after: Dictionary = engine.apply_player_action(before, action, before["enemies"][0]["pos"])
	var damage: Dictionary = scene.board_view._damage_preview_map().get("player", {})
	_expect(damage.get("hp") == after["player"]["hp"], "Live reflection preview equals engine resolution")
	_expect(scene.board_view._unit_status_badges({"type": "glacial_mirror"}).any(func(badge: Dictionary) -> bool: return badge["icon"] == "reflect"), "Live mirror badge stays visible")
	before = preload("res://tests/suites/sta01_mechanics_suite.gd").state("gust_shrike", "dive")
	BaseFixtures.install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	preview = scene.board_view.presentation
	_expect(preview.get("enemy_threat_previews", []).any(func(threat: Dictionary) -> bool: return threat.get("enemy_key") == "enemy_1" and not threat.get("projected_attack", []).is_empty()), "Hover discloses Dive through shared preview")
	_expect(scene._combat_portrait_path("gust_shrike") == "res://assets/art/portraits/gust_shrike.png", "Live turn clock resolves explicit shrike portrait")
	scene._show_all_enemy_intents = false
	scene._on_board_tile_hovered(Vector2i(-1, -1))
	await _settle()
	preview = scene.board_view.presentation
	_expect(preview.get("enemy_threat_previews", []).is_empty() and not preview.has("en05_dive_telegraphs"), "Dive has ordinary hover disclosure without a special rest telegraph")
	await _review_visual_states(scene)
	scene.queue_free()
	await process_frame
	await process_frame
	for error: String in _errors: push_error(error)
	var proof: String = "headless logic only" if DisplayServer.get_name() == "headless" else ProjectSettings.globalize_path(OUTPUT_DIR)
	print("EN05 LIVE INTEGRATION: %s (%d checks, %d failures; %s)" % ["PASS" if _errors.is_empty() else "FAIL", _checks, _errors.size(), proof])
	quit(0 if _errors.is_empty() else 1)

func _review_visual_states(scene: Control) -> void:
	var mirror: Dictionary = BaseFixtures.enemy("glacial_mirror", 2, MIRROR, "refraction")
	var flash: Dictionary = BaseFixtures.state([mirror], HERO)
	flash["player"]["block"] = BLOCK
	Surface.place(flash, FIRST, "ice", {})
	await _aim(scene, flash, "flashsteam", FIRST)
	var chips: Array = scene.board_view.presentation.get("friendly_damage_chips", [])
	_expect(chips.any(func(chip: Dictionary) -> bool: return chip.get("label") == "↶ You: −3 Block" and str(chip.get("tooltip", "")).begins_with("Reflect")), "Flashsteam's live preview attributes 3 Block to Reflect")
	_expect(chips.any(func(chip: Dictionary) -> bool: return chip.get("label") == "You: −4 Block" and str(chip.get("tooltip", "")).begins_with("Burst")), "Flashsteam's live preview attributes 4 Block to Burst")
	await _capture("01_flashsteam")

	var chain: Dictionary = BaseFixtures.state([BaseFixtures.enemy("crawler", 1, FIRST), mirror, BaseFixtures.enemy("crawler", 3, LAST)], HERO)
	chain["relics"] = ["storm_crown"]
	await _aim(scene, chain, "chain_bolt", FIRST)
	var arcs: Array = scene.board_view.presentation.get("surface_preview_arcs", [])
	_expect(arcs.any(func(arc: Dictionary) -> bool: return arc.get("from") == FIRST and arc.get("to") == MIRROR), "Chain Bolt's live preview draws the Mirror link")
	_expect(arcs.any(func(arc: Dictionary) -> bool: return arc.get("kind") == "rebound" and arc.get("from") == LAST and arc.get("to") == MIRROR), "Storm Crown's live preview returns through the Mirror")
	await _capture("02_chain_route")

	var ice: Dictionary = BaseFixtures.state([mirror], HERO)
	ice["player"]["block"] = BLOCK
	ice["enemies"][0]["expose"] = 2
	ice["relics"] = ["venom_signet"]
	Surface.place(ice, MIRROR, "ice", {})
	Surface.place(ice, MIRROR, "rubble", {})
	await _aim(scene, ice, "frostbolt", MIRROR)
	_expect(scene.board_view.presentation.get("en05_reflect_preview", {}).get("damage") == 7, "Frostbolt's live Reflect preview includes Mirror Expose and Quarry Signet")
	await _capture("03_frostbolt_reflect")

	var caster: Dictionary = BaseFixtures.enemy("glacial_mirror", 3, CASTER, "refraction")
	var beam: Dictionary = BaseFixtures.state([mirror, caster], HERO)
	beam["enemies"][0]["expose"] = 2
	Surface.place(beam, MIRROR, "ice", {})
	BaseFixtures.install(scene, beam)
	scene._show_all_enemy_intents = false
	scene._on_board_tile_hovered(CASTER)
	await _settle()
	var threats: Array = scene.board_view.presentation.get("enemy_threat_previews", [])
	_expect(threats.any(func(threat: Dictionary) -> bool: return threat.get("enemy_key") == "enemy_3" and threat.get("reflect_return_damage") == 6), "Refraction's live intent shows 6 returned damage")
	await _capture("04_refraction_intent")

	for card: String in ["wind_shear", "caltrops", "refraction"]:
		var panels: Dictionary = BaseFixtures.state([mirror], HERO)
		panels["player"]["block"] = BLOCK
		panels["relics"] = ["anchor_chain"]
		panels["deck"]["hand"] = [card]
		BaseFixtures.install(scene, panels)
		await _settle()
		_expect(scene._hand_card_control(0) != null, card + " uses a real hand CardWidget")
		if scene._hand_card_control(0) == null: continue
		scene._show_card_focus_tooltips(0)
		await _settle()
		var stack: Control = scene._card_focus_tooltip_stack
		_expect(stack.visible and stack.entry_count() > 0, card + " opens its real card focus stack")
		match card:
			"wind_shear":
				var seal: Button = scene._hand_card_control(0).get_node("EmpowerSeal")
				_expect(seal.tooltip_text.contains("Push each target 3 tiles instead."), "The live Wind Shear seal previews Push 3")
			"caltrops":
				_expect(not stack.entry_icon_keys().has("ranged"), "The live Caltrops stack omits the damage panel")
			"refraction":
				_expect(stack.entry_icon_keys().has("illusion"), "The live Refraction stack includes the Illusion hit panel")
		await _capture(card)

func _aim(scene: Control, state: Dictionary, card: String, tile: Vector2i) -> void:
	state["deck"]["hand"] = [card]
	BaseFixtures.install(scene, state)
	await _settle()
	await scene._on_card_pressed(0)
	scene._on_board_tile_hovered(tile)
	await _settle()

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == VIEWPORT_SIZE and image.save_png(directory.path_join(name + ".png")) == OK, "Capture " + name)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _errors.append(message)
