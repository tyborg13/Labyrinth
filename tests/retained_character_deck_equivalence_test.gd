extends "res://tests/retained_character_inventory_equivalence_test.gd"

# Exact original-builder comparison plus actual identity retention. A changed
# input must rebuild its own group while leaving unrelated final parents live.
func _run() -> void:
	for original: bool in [false, true]:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		if original: scene.set_script(Reference)
		root.add_child(scene)
		scene._initial_ui_complete = false
		scenes.append(scene)
	await _settle(8)
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(84217, Tutorial.complete_tutorial(Profile.default_data()))
	state["equipment_inventory"] = ["iron_cleaver", "duelist_rapier", "ward_kite"]
	state["attuned_magic_cards"] = ["bone_dart", "pale_spark", "spark_dart"]
	state["equipped_items"] = [Data.item_card_ids()[0], Data.item_card_ids()[0]]
	for mode: String in ["equipment", "magic"]:
		await _compare(state, mode, mode + " initial aliases and duplicate counts")
		state["attuned_magic_cards"] = ["pale_spark", "spark_dart"]
		state["equipped_items"] = []
		state = engine._repair_equipment_state(state)
		await _compare(state, mode, mode + " canonical legal loadout before equip")
		var panel_id: int = scenes[0]._upgrade_dialog.find_child("CurrentDeckPanel", true, false).get_instance_id()
		var old_groups: Dictionary = _group_ids(mode)
		state["player_hp"] = maxi(1, int(state["player_hp"]) - 1)
		await _compare(state, mode, mode + " unrelated HP change")
		_check(_group_ids(mode) == old_groups, "Unrelated HP must retain every complete deck group in " + mode)
		_check(scenes[0]._upgrade_dialog.find_child("CurrentDeckPanel", true, false).get_instance_id() == panel_id, "Deck panel must retain its actual native parent in " + mode)
		var next_weapon: String = "duelist_rapier" if str(state["equipped_equipment"]["weapon"]) == "iron_cleaver" else "iron_cleaver"
		state = engine.equip_equipment(state, next_weapon)
		await _compare(state, mode, mode + " actual weapon replacement")
		var new_groups: Dictionary = _group_ids(mode)
		_check(new_groups["magic"] == old_groups["magic"] and new_groups["items"] == old_groups["items"], "Weapon replacement must retain magic and item groups in " + mode)
		_check(new_groups["weapon"] != old_groups["weapon"], "Weapon replacement must rebuild its exact changed group in " + mode)
		for slot: String in Data.equipment_slots():
			if slot != "weapon" and old_groups.has(slot): _check(new_groups.get(slot, 0) == old_groups[slot], "Weapon replacement must retain unchanged " + slot + " in " + mode)
		old_groups = new_groups
		state["attuned_magic_cards"] = ["spark_dart", "pale_spark", "spark_dart"]
		await _compare(state, mode, mode + " magic counts and ordering")
		new_groups = _group_ids(mode)
		_check(new_groups["magic"] != old_groups["magic"] and new_groups["items"] == old_groups["items"] and new_groups["weapon"] == old_groups["weapon"], "Magic changes must rebuild only their printed group in " + mode)
		old_groups = new_groups
		state["equipped_items"] = [Data.item_card_ids()[1]]
		await _compare(state, mode, mode + " item replacement")
		new_groups = _group_ids(mode)
		_check(new_groups["items"] != old_groups["items"] and new_groups["weapon"] == old_groups["weapon"], "Item changes must retain unaffected equipment groups in " + mode)
		state["equipment_grafts"] = {str(state["equipped_equipment"]["weapon"]): {"index": 0, "card_id": "spark_dart"}}
		await _compare(state, mode, mode + " graft changes granted cards")
		var card: Dictionary = Data.cards()["spark_dart"]
		var original_name: Variant = card["name"]
		card["name"] = "Revised exact deck name"
		await _compare(state, mode, mode + " mutable printed definition")
		card["name"] = original_name
		await _compare(state, mode, mode + " definition restored")
		var group: Control = _deck_group(mode, "magic")
		var group_id: int = group.get_instance_id()
		var strip: Control = group.find_child("CharacterCardStrip", true, false)
		strip.set("selected", true)
		state["player_hp"] = maxi(1, int(state["player_hp"]) - 1)
		await _compare(state, mode, mode + " selected strip invalidation")
		_check(_deck_group(mode, "magic").get_instance_id() != group_id, "An active deck strip must return to the original fresh interaction state")
		state["attuned_magic_cards"] = []
		state["equipped_items"] = []
		state["equipped_equipment"]["weapon"] = ""
		await _compare(state, mode, mode + " empty groups and removed weapon")
		_check(not _group_ids(mode).has("weapon"), "Removed weapon groups must leave the bounded current cache")
		state["attuned_magic_cards"] = ["bone_dart", "pale_spark", "spark_dart"]
		state["equipment_inventory"] = ["iron_cleaver", "duelist_rapier", "ward_kite"]
		state["equipped_equipment"]["weapon"] = "training_sword"
		state["equipment_grafts"] = {}
	for scene: Node in scenes: scene.free()
	await _settle(4)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Deck retention teardown must leave no orphan nodes")
	print("CHARACTER DECK RETENTION RESULT: ", JSON.stringify({"cases": cases, "errors": errors, "differences": differences, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _deck_group(mode: String, key: String) -> Control:
	return scenes[0]._character_inventory_rows._entries.get("deck/" + mode + "/" + key, {}).get("node")

func _group_ids(mode: String) -> Dictionary:
	var ids: Dictionary = {}
	for key: String in ["magic", "items"]:
		var group: Control = _deck_group(mode, key)
		if is_instance_valid(group): ids[key] = group.get_instance_id()
	for slot: String in Data.equipment_slots():
		var group: Control = _deck_group(mode, "equipment/" + slot)
		if is_instance_valid(group): ids[slot] = group.get_instance_id()
	return ids
