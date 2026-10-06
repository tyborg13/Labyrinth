extends "res://tests/retained_character_inventory_equivalence_test.gd"
var boundary: int = 0
var cancel_boundary: int = -1
var source_mutation_boundary: int = -1
var live_id: int
var live_mode: String
var owned_state: Dictionary
var live_bindings: Dictionary
var checks: int = 0
var boundaries: Dictionary = {}
var termination: String = ""
var termination_boundary: int = -1

func _run() -> void:
	for mode: String in ["equipment", "magic"]:
		await _setup(mode, true)
		await _prepare()
		boundaries[mode] = boundary
		var target: String = "magic" if mode == "equipment" else "equipment"
		var view: Dictionary = scenes[0]._character_inventory_rows._views.get(target, {})
		_check(not view.is_empty(), "The other tab must publish its complete dialog")
		if not view.is_empty():
			var prepared: Control = view["node"]
			_check(not prepared.visible and prepared.get_parent() == scenes[0]._upgrade_center, "Only a hidden dialog under its final owner may be published")
			for scene: Node in scenes: scene._switch_character_overlay_mode(target)
			_check(scenes[0]._upgrade_dialog == prepared, "Switch must adopt the actual prepared dialog")
			await _compare_live("complete " + target)
		await _teardown()
	# Switch at every unfinished boundary. Partial controls cannot be published
	# or freed after the normal synchronous open has adopted their exact rows.
	await _setup("equipment", false)
	await _prepare()
	var total: int = boundary
	await _teardown()
	for point: int in range(1, total + 1):
		cancel_boundary = point
		await _setup("equipment", false)
		await _prepare()
		_check(scenes[0]._character_inventory_rows._views.get("magic", {}).is_empty(), "An interrupted future view must never remain eligible")
		await _compare_live("switch boundary " + str(point))
		await _teardown()
	cancel_boundary = -1
	for point: int in [1, 2]:
		source_mutation_boundary = point
		await _setup("equipment", false)
		await _prepare()
		_check(not scenes[0]._character_inventory_rows._views.get("magic", {}).is_empty() if point == 1 else scenes[0]._character_inventory_rows._views.get("magic", {}).is_empty(), "Capture the newest input before work starts; discard it if it changes after capture")
		for scene: Node in scenes: scene._switch_character_overlay_mode("magic")
		await _compare_live("changed input " + str(point))
		await _teardown()
	source_mutation_boundary = -1
	for change: String in ["revision", "close", "detach", "queue_free", "free"]:
		termination = change
		termination_boundary = total - 1
		await _setup("equipment", false)
		var actual: Variant = scenes[0]
		await _prepare()
		if is_instance_valid(actual): _check(actual._character_inventory_rows._views.get("magic", {}).is_empty(), "An invalid owner must not publish a future dialog: " + change)
		await _teardown()
		cases += 1
	termination = ""
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Other-view teardown must leave no orphan nodes")
	print("PREPARED OTHER CHARACTER VIEW RESULT: " + JSON.stringify({"cases": cases, "checks": checks, "boundaries": boundaries, "cancellation_boundaries": total, "differences": differences, "errors": errors, "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _setup(mode: String, large: bool) -> void:
	boundary = 0
	scenes.clear()
	for original: bool in [false, true]:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		if original: scene.set_script(Reference)
		root.add_child(scene)
		scenes.append(scene)
	await _settle(8)
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(84217, Tutorial.complete_tutorial(Profile.default_data()))
	state["equipment_inventory"] = ["iron_cleaver", "duelist_rapier", "iron_cleaver"]
	state["item_inventory"] = Data.item_card_ids()
	var magic: Array = []
	var pools: Dictionary = Data.reward_card_pool_by_rarity("", true)
	for rarity: String in Data.CARD_RARITY_TIERS:
		for id: String in pools.get(rarity, []):
			if not magic.has(id): magic.append(id)
	magic.sort()
	magic.resize(mini(magic.size(), 64 if large else 12))
	state["magic_inventory"] = magic
	state["reward_cards"] = magic.duplicate()
	for scene: Node in scenes:
		scene._initial_ui_complete = false
		scene._load_run_state(state.duplicate(true))
		scene._close_dialogue()
		scene._pre_battle_scrim.hide()
		scene._large_map_scrim.hide()
		scene._open_character_overlay(mode)
	await _settle(6)
	owned_state = scenes[0]._run_state.duplicate(true)
	live_id = scenes[0]._upgrade_dialog.get_instance_id()
	live_mode = mode
	live_bindings = scenes[0]._character_view_bindings()
	await _compare_live("initial " + mode)

func _prepare() -> void:
	var actual: Variant = scenes[0]
	await Rows.prepare_other_for(actual, actual._character_other_view_preparation_revision, _present_other)
	await _settle(4)
	if is_instance_valid(actual): _check(actual._run_state == owned_state or source_mutation_boundary > 0, "Preparation must preserve authoritative state")

func _present_other() -> void:
	boundary += 1
	_check(scenes[0]._upgrade_dialog.get_instance_id() == live_id and scenes[0]._progression_overlay_mode == live_mode, "Each preparation boundary must retain the live dialog and mode")
	_check(scenes[0]._character_view_bindings() == live_bindings, "Every synchronous job must restore all live controls and drop bindings before yielding")
	if boundary == termination_boundary and not termination.is_empty():
		match termination:
			"revision": scenes[0]._character_other_view_preparation_revision += 1
			"close": scenes[0]._close_card_upgrade_overlay()
			"detach": scenes[0].get_parent().remove_child(scenes[0])
			"queue_free": scenes[0].queue_free()
			"free": scenes[0].free()
		await process_frame
		return
	if boundary == cancel_boundary:
		for scene: Node in scenes: scene._switch_character_overlay_mode("magic")
		return
	if boundary == source_mutation_boundary:
		for scene: Node in scenes: scene._run_state["magic_inventory"].reverse()
	await process_frame

func _compare_live(label: String) -> void:
	await _settle(6)
	var actual: Dictionary = _snapshot(scenes[0]._upgrade_dialog, scenes[0]._upgrade_dialog)
	var expected: Dictionary = _snapshot(scenes[1]._upgrade_dialog, scenes[1]._upgrade_dialog)
	if actual != expected: _print_differences(actual, expected, label)
	_check(actual == expected, "Complete controls, geometry, fonts, art and callbacks must match the original: " + label)
	# Scene loads intentionally generate different analytics run identities.
	# Preparation ownership uses the complete actual state assertion above;
	# compare the original's gameplay fields separately from that identity.
	for field: String in ["seed", "mode", "current_room", "equipped_equipment", "equipment_inventory", "magic_inventory", "attuned_magic_cards", "equipped_items", "item_inventory", "player_hp", "held_embers", "progression", Run.UNREAD_LOADOUT_EQUIPMENT_KEY, Run.UNREAD_LOADOUT_MAGIC_KEY]:
		_check(scenes[0]._run_state.get(field) == scenes[1]._run_state.get(field), "Gameplay field must match its independent original: " + field)
	cases += 1

func _teardown() -> void:
	for scene: Variant in scenes:
		if is_instance_valid(scene): scene.free()
	scenes.clear()
	await _settle(5)

func _check(ok: bool, message: String) -> void:
	checks += 1
	super._check(ok, message)
