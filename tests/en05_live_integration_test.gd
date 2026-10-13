extends SceneTree

const Fixtures = preload("res://tests/suites/en05_enemies_suite.gd")
const BaseFixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SETTLE_FRAMES: int = 8 # Headless integration scheduling only.
var _errors: Array[String]
var _checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://en05_live_profile.json")
	Store.set_run_storage_path("user://en05_live_run.save")
	Settings.set_storage_path("user://en05_live_settings.json")
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
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
	before = Fixtures.shrike()
	BaseFixtures.install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	preview = scene.board_view.presentation
	_expect(preview.get("displacement_paths", []).size() >= 2, "Live Dive shows side-push paths on both intervening allies")
	_expect(preview.get("threats_at_rest", {}).get("badges", []).any(func(badge: Dictionary) -> bool: return badge.get("key") == "enemy_1" and badge.get("icon") == "dive" and badge.get("number") == "4" and badge.get("secondary_number") == "1" and bool(badge.get("danger"))), "Live Dive chip shows integer damage, side Push and real hero danger")
	_expect(scene._combat_portrait_path("gust_shrike") == "res://assets/art/portraits/gust_shrike.png", "Live turn clock resolves explicit shrike portrait")
	_expect(preview.get("displacement_paths", []).has(engine._vector2i_values([Vector2i(3, 4), Vector2i(3, 5)])), "Live aligned Dive previews approved right-hand tile")
	before = Fixtures.blocked_landing()
	BaseFixtures.install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	preview = scene.board_view.presentation
	_expect(not preview.get("damage_preview", {}).has("player"), "Live blocked landing omits hero damage")
	_expect(preview.get("enemy_threat_previews", []).any(func(threat: Dictionary) -> bool: return threat.get("enemy_key") == "enemy_1" and threat.get("projected_attack_target") == Vector2i(4, 4) and threat.get("projected_attack", []).size() == 2), "Live blocked telegraph ends at actual stop tile")
	_expect(preview.get("displacement_paths", []).has(engine._vector2i_values([Vector2i(5, 4), Vector2i(5, 5)])), "Live blocked push marks attempted right-hand tile")
	scene._show_all_enemy_intents = false
	scene._on_board_tile_hovered(Vector2i(-1, -1))
	await _settle()
	preview = scene.board_view.presentation
	_expect(preview.get("enemy_threat_previews", []).is_empty(), "V2 rest presentation does not inject detailed Dive popups")
	_expect(preview.get("en05_dive_telegraphs", []).any(func(threat: Dictionary) -> bool: return threat.get("projected_attack_target") == Vector2i(4, 4)), "V2 rest Dive retains the dashed line to its blocked stop")
	_expect(preview.get("threats_at_rest", {}).get("badges", []).any(func(badge: Dictionary) -> bool: return badge.get("key") == "enemy_1" and badge.get("icon") == "dive" and not bool(badge.get("danger"))), "V2 blocked Dive chip has no hero danger")
	scene.queue_free()
	await process_frame
	await process_frame
	for error: String in _errors: push_error(error)
	print("EN05 LIVE INTEGRATION: %s (%d checks, %d failures; headless logic only)" % ["PASS" if _errors.is_empty() else "FAIL", _checks, _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _errors.append(message)
