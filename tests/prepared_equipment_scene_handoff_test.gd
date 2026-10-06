extends SceneTree
const Run = preload("res://scripts/run_engine.gd")
const Original = preload("res://tests/fixtures/pre_battle_factory_reference.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
var errors: Array[String]
var checks: int = 0

func _initialize() -> void:
	Parallel.apply_from_environment()
	Profile.set_storage_path("user://equipment_handoff_profile.json")
	Profile.set_run_storage_path("user://equipment_handoff_run.save")
	Profile.clear_saved_run()
	Profile.save_data(Tutorial.complete_tutorial(Profile.default_data()))
	Settings.set_storage_path("user://equipment_handoff_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["fullscreen"] = false
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	_run.call_deferred()

func _run() -> void:
	var engine := Run.new()
	var source: Dictionary = engine.create_new_run(84217, Tutorial.complete_tutorial(Profile.default_data()))
	source["equipment_inventory"] = ["iron_cleaver", "ward_kite"]
	for room: Dictionary in source["rooms"].values():
		if str(room.get("type", "")) != "combat": continue
		source["current_room"] = room["coord"]
		source["pre_battle_travel_dir"] = Vector2i.RIGHT
		source["mode"] = Run.MODE_PRE_BATTLE
		break
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await _frames(8)
	scene._initial_ui_complete = false
	for kind: String in ["ready", "immediate", "mismatch"]:
		scene._load_run_state(source.duplicate(true))
		await _frames(12)
		scene._open_character_overlay("equipment")
		var prepared: RefCounted = scene._equipment_factory_preparation
		var original_factory: Dictionary = scene._prepared_pre_battle_factory
		var before: Dictionary = scene._run_state.duplicate(true)
		var cached: Dictionary = {}
		if kind != "immediate":
			await _ready(prepared)
			_check(prepared.snapshot()["ready"] == 2, "A live scene must finish both legal equipment futures")
			cached = prepared._ready.get("weapon/iron_cleaver", {}).get("factory", {})
			_check(scene._run_state == before and scene._combat_state.is_empty(), "Menu preparation cannot publish speculative state")
			_check(is_same(scene._prepared_pre_battle_factory, original_factory), "Menu work cannot replace the live factory before an action")
		if kind == "mismatch": scene._run_state["player_hp"] = maxi(1, int(scene._run_state["player_hp"]) - 1)
		var committed: Dictionary = engine.equip_equipment(scene._run_state, "iron_cleaver", "weapon")
		scene._equip_equipment_from_overlay("iron_cleaver", "weapon")
		_check(scene._run_state["equipped_equipment"] == committed["equipped_equipment"], "The actual callback must synchronously commit the canonical equip")
		_check(scene._run_state["equipment_inventory"] == committed["equipment_inventory"], "The actual callback must preserve the canonical inventory exchange")
		_check(scene._run_state["player_hp"] == committed["player_hp"], "Factory adoption must not overwrite committed player HP")
		_check(engine.prepared_pre_battle_matches_input(scene._prepared_pre_battle_factory, scene._run_state), "The ordinary preview must retain the exact final header/receipt input")
		if kind == "ready": _check(is_same(scene._prepared_pre_battle_factory, cached), "A complete actual callback must use the exact owned ready factory")
		elif kind == "mismatch": _check(not is_same(scene._prepared_pre_battle_factory, cached), "A changed live source must use the original synchronous fallback")
		var expected: Dictionary = Original.new().pre_battle_preview_state(scene._run_state)
		_check(scene._pre_battle_preview_run_state["combat_state"] == expected["combat_state"], "The actual preview must preserve the complete original combat state")
		_check(prepared.snapshot()["ready"] == 0 and not prepared.snapshot()["partial"], "The actual callback consumes or discards the old batch")
		var fx_frames: int = 0
		while scene._equipment_swap_animation_active and fx_frames < 300:
			await process_frame
			fx_frames += 1
		_check(not scene._equipment_swap_animation_active, "The original equip motion must finish and restore its interaction state")
		scene._close_card_upgrade_overlay()
		_check(scene._equipment_factory_preparation.snapshot()["ready"] == 0, "Closing the real Character menu must release prepared factories")
		await _frames(4)
	# A real tab change and direct scrim hide each cancel an in-flight generation.
	for reason: String in ["tab", "hide", "reload"]:
		scene._load_run_state(source.duplicate(true))
		await _frames(8)
		scene._open_character_overlay("equipment")
		var prepared: RefCounted = scene._equipment_factory_preparation
		await _frames(4)
		match reason:
			"tab": scene._switch_character_overlay_mode("magic")
			"hide": scene._upgrade_scrim.hide()
			"reload": scene._load_run_state(source.duplicate(true))
		await _frames(4)
		_check(prepared.snapshot()["ready"] == 0 and not prepared.snapshot()["partial"], reason + " must cancel the real old generation")
		scene._close_card_upgrade_overlay()
	scene.free()
	await _frames(4)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Real scene teardown must leave no orphan nodes")
	print("PREPARED EQUIPMENT SCENE HANDOFF RESULT: ", JSON.stringify({"checks":checks,"errors":errors,"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _ready(prepared: RefCounted) -> void:
	var frames: int = 0
	while not prepared.snapshot()["complete"] and frames < 200:
		await process_frame
		frames += 1
	_check(prepared.snapshot()["complete"], "Actual menu preparation must finish without an input wait")

func _frames(count: int) -> void:
	for frame: int in range(count): await process_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label)
