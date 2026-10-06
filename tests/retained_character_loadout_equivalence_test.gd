extends "res://tests/retained_character_inventory_equivalence_test.gd"

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
	await _compare(state, "equipment", "initial equipped column")
	var ids: Dictionary = _ids()
	state["player_hp"] = maxi(1, int(state["player_hp"]) - 1)
	await _compare(state, "equipment", "unrelated HP")
	_check(_ids() == ids, "Unrelated HP must keep every exact equipped control and rig")
	state = engine.equip_equipment(state, "iron_cleaver")
	await _compare(state, "equipment", "actual weapon replacement")
	var next: Dictionary = _ids()
	_check(next["portrait"] == ids["portrait"] and next["rig"] == ids["rig"] and next["panel"] == ids["panel"] and next["items"] == ids["items"], "A weapon change must preserve the final live portrait, rig, panel and item section")
	_check(next["weapon"] != ids["weapon"], "The changed weapon must use a fresh original socket")
	for slot: String in Data.equipment_slots():
		if slot != "weapon": _check(next[slot] == ids[slot], "A weapon change must preserve unchanged " + slot + " socket")
	# The paper-doll resize closure must refer to the new slot owner too.
	var doll: Control = scenes[0]._upgrade_dialog.find_child("CharacterPaperDoll", true, false)
	doll.emit_signal("resized")
	await _settle(8)
	_check(_snapshot(scenes[0]._upgrade_dialog, scenes[0]._upgrade_dialog) == _snapshot(scenes[1]._upgrade_dialog, scenes[1]._upgrade_dialog), "A later native layout must place the replacement socket exactly")
	for card_case: Array in [[], [Data.item_card_ids()[0]], [Data.item_card_ids()[0], Data.item_card_ids()[0]]]:
		ids = _ids()
		state["equipped_items"] = card_case.duplicate()
		await _compare(state, "equipment", "changed equipped item slots")
		if card_case.size() > 0: _check(_ids()["rig"] != ids["rig"], "Changed item rows must take the full original column fallback")
	state["equipped_items"] = []
	await _compare(state, "equipment", "item section restored")
	ids = _ids()
	state["equipped_equipment"]["weapon"] = ""
	await _compare(state, "equipment", "empty weapon focus and icon")
	_check(_ids()["rig"] == ids["rig"] and _ids()["weapon"] != ids["weapon"], "Removing a weapon must keep the ready rig and refresh the empty socket")
	state["equipped_equipment"]["weapon"] = "training_sword"
	await _compare(state, "equipment", "filled weapon focus and callbacks")
	var definitions: Dictionary = Data.equipment()
	var old_icon: Variant = definitions["training_sword"]["icon_path"]
	ids = _ids()
	definitions["training_sword"]["icon_path"] = definitions["ward_kite"]["icon_path"]
	await _compare(state, "equipment", "mutable equipment icon definition")
	_check(_ids()["rig"] != ids["rig"], "A mutable equipment catalog must take the complete original column fallback")
	definitions["training_sword"]["icon_path"] = old_icon
	await _compare(state, "equipment", "restored equipment definition")
	for mode: String in ["combat", "room"]:
		state["mode"] = mode
		await _compare(state, "equipment", mode + " interaction disabled state")
	ids = _ids()
	for scene: Node in scenes:
		scene._equipment_drag_id = "iron_cleaver"
		scene._apply_equipment_drag_highlights()
	state = engine.equip_equipment(state, "iron_cleaver")
	await _compare(state, "equipment", "active drag highlights before swap cleanup")
	_check(_ids()["rig"] != ids["rig"], "An active equipment drag must rebuild the full original column immediately")
	for slot: String in Data.equipment_slots():
		var tile: Control = scenes[0]._equipment_slot_panels[slot]
		_check(tile.modulate == Color.WHITE and not bool(tile.find_child("EquipmentIconChip", true, false).selected), "Equip must reset drag dimming and selected icons before animation cleanup")
	for scene: Node in scenes: scene._clear_equipment_drag_state(true)
	var item_id: String = Data.item_card_ids()[0]
	state["equipped_items"] = [item_id]
	state["item_inventory"] = [item_id]
	await _compare(state, "equipment", "identical consumable drag fixture")
	ids = _ids()
	for scene: Node in scenes:
		scene._item_drag_card_id = item_id
		scene._item_drag_source_kind = "inventory"
		scene._item_drag_index = 0
		scene._apply_item_drag_highlights()
	var prior_items: Array = state["equipped_items"].duplicate()
	state = engine.equip_item_card(state, 0, 0)
	_check(state["equipped_items"] == prior_items, "Consumable regression must replace an equipped card with an identical copy")
	await _compare(state, "equipment", "active identical consumable drag before cleanup")
	_check(_ids()["rig"] != ids["rig"], "An active consumable drag must immediately rebuild the original equipped column")
	for scene: Node in scenes: scene._clear_item_drag_state(true)
	for invalidation: String in ["motion", "caption", "rig"]:
		ids = _ids()
		var panel: Control = scenes[0]._upgrade_dialog.find_child("EquipmentLoadoutPanel", true, false)
		if invalidation == "motion": panel.scale = Vector2(1.02, 1.0)
		elif invalidation == "caption": panel.find_child("WeaponSlotCaption", true, false).free()
		else: panel.find_child("EquipmentCutout", true, false).free()
		state["player_hp"] = maxi(1, int(state["player_hp"]) - 1)
		await _compare(state, "equipment", invalidation + " subtree fallback")
		_check(_ids()["rig"] != ids["rig"], "An invalid " + invalidation + " subtree must be fully rebuilt")
	# Match the original changed-column motion start immediately, before any
	# rendered frame advances idle. The live rig and texture remain ready.
	var rig: Node = scenes[0]._upgrade_dialog.find_child("EquipmentCutout", true, false)
	rig._idle_seconds = 0.6
	rig.present({"clip": "idle"}, false)
	scenes[0]._run_state["player_hp"] = maxi(1, int(scenes[0]._run_state["player_hp"]) - 1)
	scenes[0]._rebuild_progression_overlay()
	_check(rig._idle_seconds == 0.0 and rig.clip == "idle" and rig.facing == "front" and not rig.mirrored, "A retained rig must restart the exact original changed-column idle pose")
	for scene: Node in scenes: scene.free()
	await _settle(4)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Loadout retention must release every owner on teardown")
	print("CHARACTER LOADOUT RETENTION RESULT: " + JSON.stringify({"cases": cases, "errors": errors, "differences": differences, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _ids() -> Dictionary:
	var result: Dictionary = {}
	var panel: Control = scenes[0]._upgrade_dialog.find_child("EquipmentLoadoutPanel", true, false)
	result["panel"] = panel.get_instance_id()
	result["portrait"] = panel.find_child("EquipmentCharacterArt", true, false).get_instance_id()
	result["rig"] = panel.find_child("EquipmentCutout", true, false).get_instance_id()
	result["items"] = panel.find_child("CharacterEquippedItems", true, false).get_instance_id()
	for slot: String in Data.equipment_slots(): result[slot] = scenes[0]._equipment_slot_panels[slot].get_instance_id()
	return result
