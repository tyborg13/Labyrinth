extends SceneTree
const Preparation = preload("res://scripts/encounter_asset_preparation.gd")
const Reference = preload("res://tests/fixtures/pre_battle_view_reference.gd")
const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
var errors: Array[String]
var scene: Node
var active: bool = true
var cancel_on_present: bool = false
var free_on_present: bool = false
var presented: int = 0
var cases: int = 0

func _initialize() -> void:
	Parallel.apply_from_environment()
	Profile.set_storage_path("user://prepared_pre_battle_profile.json")
	Profile.set_run_storage_path("user://prepared_pre_battle_run.save")
	Profile.clear_saved_run()
	Settings.set_storage_path("user://prepared_pre_battle_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["fullscreen"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()

func _run() -> void:
	scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await _settle(4)
	scene._close_dialogue()
	scene._pre_battle_scrim.hide()
	var engine := Run.new()
	var profile: Dictionary = Tutorial.complete_tutorial(Profile.default_data())
	var preference: Array[String]
	_append_skill_path("true_bearing", preference)
	var count: int = maxi(preference.size(), Skills.minimum_owned("true_bearing") + 1)
	profile["level"] = count + 1
	profile["skill_ids"] = Skills.repaired_selection([], count, preference)
	var state: Dictionary = engine.create_new_run(84217, profile)
	_check(engine.has_run_skill(state, "true_bearing"), "View fixture must grant a legal True Bearing build")
	var destination: Vector2i = Vector2i(-999, -999)
	for coord: Vector2i in engine.available_moves(state):
		if str(engine.room_metadata(state, coord).get("type")) in ["combat", "guardian"]:
			destination = coord
			break
	_check(destination.x != -999, "Fixture must expose a real combat destination")
	state = engine.move_to_pre_battle(state, destination)
	_check(str(state.get("mode")) == "pre_battle", "Fixture must prepare actual pre-battle state")
	for variant: int in range(3):
		state["player_hp"] = 13 + variant
		state["player_max_hp"] = 32 + variant
		if variant == 1:
			state["equipment_inventory"].append("iron_cleaver")
			state = engine.equip_equipment(state, "iron_cleaver")
			_check(state["equipped_equipment"]["weapon"] == "iron_cleaver", "Equipment variant must change the actual kit")
		var factory: Dictionary = engine.prepare_pre_battle_combat(state)
		var preview: Dictionary = engine.pre_battle_preview_state(state, factory)
		var original: Dictionary = state.duplicate(true)
		var actual_before: Dictionary = scene._run_state.duplicate(true)
		var live_before: Dictionary = scene._combat_state.duplicate(true)
		scene._encounter_preparation_generation += 1
		scene._prepared_pre_battle_view_revision += 1
		scene._pre_battle_scrim.hide()
		await Preparation.prepare_hidden_pre_battle_for(scene, state, preview, scene._encounter_preparation_generation, _present, _alive)
		_check(scene._prepared_pre_battle_view_ready, "Hidden build must complete its exact key")
		_check(scene._run_state == actual_before and scene._combat_state == live_before and state == original, "Future panel preparation must preserve all authoritative state")
		var panel: PanelContainer = scene._pre_battle_panel
		var prepared_content: Node = panel.find_child("PreBattleContent", true, false)
		scene._run_state = state.duplicate(true)
		scene._pre_battle_preview_run_state = preview.duplicate(true)
		scene._rebuild_pre_battle_overlay()
		_check(panel.find_child("PreBattleContent", true, false) == prepared_content, "Matching arrival must reuse the actual prepared subtree")
		_check(not scene._prepared_pre_battle_view_ready, "Prepared view reuse must be consumed once")
		scene._pre_battle_scrim.show()
		var reference := PanelContainer.new()
		reference.custom_minimum_size = panel.custom_minimum_size
		reference.size = panel.size
		reference.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel").duplicate())
		panel.get_parent().add_child(reference)
		scene._ui_skin.apply_menu_finish(reference, "outer")
		var room: Dictionary = engine.room_metadata(preview, state.get("current_room", Vector2i.ZERO))
		var combat: Dictionary = preview.get("combat_state", {})
		var element: String = str(combat.get("room_element", room.get("element", "none")))
		var elements = preload("res://scripts/element_data.gd")
		var accent: Color = elements.accent(element) if elements.is_elemental(element) else Color("d8b06d")
		Reference.build(scene, reference, room, combat, accent)
		await _settle(8)
		var actual_snapshot: Dictionary = _snapshot(panel, panel)
		var reference_snapshot: Dictionary = _snapshot(reference, reference)
		if actual_snapshot != reference_snapshot: _print_differences(actual_snapshot, reference_snapshot, "case%d" % variant)
		_check(actual_snapshot == reference_snapshot, "Prepared view must match original content, geometry, fonts, art and focus paths for case %d" % variant)
		reference.free()
		scene._pre_battle_scrim.hide()
		cases += 1
	# Updating a visible encounter keeps unchanged sections while every changed
	# presentation is checked against the independent original builder.
	scene._pre_battle_scrim.show()
	await _compare_current_view(engine, state, "retained initial")
	var header: Node = scene._pre_battle_panel.find_child("PreBattleHeader", true, false)
	var foes: Node = scene._pre_battle_panel.find_child("PreBattleEnemySection", true, false)
	var kit: Node = scene._pre_battle_panel.find_child("PreBattleDeckSection", true, false)
	var attuned_before: Node = scene._pre_battle_panel.find_child("PreBattleAttunedRow", true, false)
	var deck_before: Dictionary = _deck_ids()
	state["player_hp"] = int(state["player_hp"]) - 1
	await _compare_current_view(engine, state, "health change")
	_check(scene._pre_battle_panel.find_child("PreBattleHeader", true, false) == header and scene._pre_battle_panel.find_child("PreBattleEnemySection", true, false) == foes, "Health change must retain unchanged header and foes")
	_check(scene._pre_battle_panel.find_child("PreBattleDeckSection", true, false) == kit and _deck_ids() == deck_before, "Health changes must retain the current kit and every unchanged deck card")
	if not state["equipment_inventory"].has("duelist_rapier"): state["equipment_inventory"].append("duelist_rapier")
	state = engine.equip_equipment(state, "duelist_rapier")
	await _compare_current_view(engine, state, "weapon change")
	_check(scene._pre_battle_panel.find_child("PreBattleAttunedRow", true, false) == attuned_before, "A weapon replacement must retain the original attuned row parent")
	var next_deck: Dictionary = _deck_ids()
	for id: String in deck_before:
		if next_deck.has(id): _check(next_deck[id] == deck_before[id], "A weapon replacement must retain unchanged card " + id)
	_check(scene._pre_battle_panel.find_child("PreBattleHeader", true, false) == header and scene._pre_battle_panel.find_child("PreBattleEnemySection", true, false) == foes, "Weapon change must retain unchanged encounter sections")
	var tiles: Array[Vector2i] = engine.pre_battle_start_tiles(state)
	_check(tiles.size() > 1, "Retention fixture must expose an alternate legal start")
	if tiles.size() > 1:
		state = engine.set_pre_battle_start(state, tiles[1])
		await _compare_current_view(engine, state, "entry position change")
		_check(scene._pre_battle_panel.find_child("PreBattleEnemySection", true, false) != foes, "Position change must replace the foe actions and their tooltip")
	var card_def: Dictionary = Data.cards()[str(state["deck_cards"][0])]
	var card_name: Variant = card_def.get("name")
	card_def["name"] = "Revised active deck name"
	await _compare_current_view(engine, state, "card definition change")
	card_def["name"] = card_name
	await _compare_current_view(engine, state, "card definition restored")
	var preview_for_enemy: Dictionary = engine.pre_battle_preview_state(state)
	var enemy_type: String = str(preview_for_enemy["combat_state"]["enemies"][0]["type"])
	var enemy_def: Dictionary = Data.enemies()[enemy_type]
	var enemy_name: Variant = enemy_def.get("name")
	enemy_def["name"] = "Revised foe name"
	await _compare_current_view(engine, state, "enemy definition change")
	enemy_def["name"] = enemy_name
	await _compare_current_view(engine, state, "enemy definition restored")
	var original_deck: Array = state["deck_cards"].duplicate()
	state["deck_cards"].reverse()
	await _compare_current_view(engine, state, "deck ordering")
	state["deck_cards"].append(str(state["deck_cards"][0]))
	await _compare_current_view(engine, state, "deck duplicate count")
	state["attuned_magic_cards"] = ["bone_dart", "pale_spark", "spark_dart"]
	await _compare_current_view(engine, state, "attuned legacy aliases")
	state["deck_cards"] = []
	state["attuned_magic_cards"] = []
	await _compare_current_view(engine, state, "empty card grids")
	state["deck_cards"] = original_deck
	state["attuned_magic_cards"] = Data.starting_magic_cards()
	await _compare_current_view(engine, state, "restored current card grids")
	var old_kit: Node = scene._pre_battle_panel.find_child("PreBattleDeckSection", true, false)
	var selected: Node = scene._pre_battle_panel.find_child("PreBattleDeckFlow", true, false).get_child(0)
	selected.set("selected", true)
	state["player_hp"] = int(state["player_hp"]) - 1
	await _compare_current_view(engine, state, "active strip fresh fallback")
	_check(scene._pre_battle_panel.find_child("PreBattleDeckSection", true, false) != old_kit, "A selected strip must restore the original fresh kit interaction state")
	old_kit = scene._pre_battle_panel.find_child("PreBattleDeckSection", true, false)
	var focused: Control = scene._pre_battle_panel.find_child("PreBattleDeckFlow", true, false).get_child(0) as Control
	focused.grab_focus()
	state["player_hp"] = int(state["player_hp"]) - 1
	await _compare_current_view(engine, state, "focused strip fresh fallback")
	_check(scene._pre_battle_panel.find_child("PreBattleDeckSection", true, false) != old_kit, "A focused strip must receive the original fresh kit replacement")
	scene._pre_battle_scrim.hide()
	# A visible panel cannot be changed by a future preparation request.
	scene._pre_battle_scrim.show()
	var visible: Dictionary = _snapshot(scene._pre_battle_panel, scene._pre_battle_panel)
	var preview: Dictionary = engine.pre_battle_preview_state(state)
	await Preparation.prepare_hidden_pre_battle_for(scene, state, preview, scene._encounter_preparation_generation, _present, _alive)
	_check(visible == _snapshot(scene._pre_battle_panel, scene._pre_battle_panel), "Preparation must leave a visible panel intact")
	scene._pre_battle_scrim.hide()
	# A completed future view must invalidate on a presentation input change.
	await Preparation.prepare_hidden_pre_battle_for(scene, state, preview, scene._encounter_preparation_generation, _present, _alive)
	var previous: Node = scene._pre_battle_panel.find_child("PreBattleContent", true, false)
	scene._run_state["player_hp"] = int(state["player_hp"]) - 1
	scene._pre_battle_preview_run_state = preview.duplicate(true)
	scene._rebuild_pre_battle_overlay()
	_check(scene._pre_battle_panel.find_child("PreBattleContent", true, false) != previous, "Changed HP must use the synchronous fallback")
	# The Position tooltip consumes the current authored skill description.
	await Preparation.prepare_hidden_pre_battle_for(scene, state, preview, scene._encounter_preparation_generation, _present, _alive)
	previous = scene._pre_battle_panel.find_child("PreBattleContent", true, false)
	var definitions: Dictionary = Skills.definitions()
	var description: String = definitions["true_bearing"]["description"]
	definitions["true_bearing"]["description"] = description + " Revised description."
	scene._run_state = state.duplicate(true)
	scene._pre_battle_preview_run_state = engine.pre_battle_preview_state(state)
	scene._rebuild_pre_battle_overlay()
	_check(scene._pre_battle_panel.find_child("PreBattleContent", true, false) != previous, "A changed skill description must invalidate the prepared view")
	definitions["true_bearing"]["description"] = description
	# Interruption during real component/glyph work cannot advertise a partial view.
	cancel_on_present = true
	await Preparation.prepare_hidden_pre_battle_for(scene, state, preview, scene._encounter_preparation_generation, _present, _alive)
	_check(not scene._prepared_pre_battle_view_ready, "Cancelled hidden work must leave readiness false")
	active = true
	cancel_on_present = false
	scene._run_state = state.duplicate(true)
	scene._pre_battle_preview_run_state = preview.duplicate(true)
	scene._rebuild_pre_battle_overlay()
	_check(scene._pre_battle_panel.find_child("PreBattleStartButton", true, false) != null, "Cancelled partial view must recover through the original synchronous path")
	free_on_present = true
	# A new 58px title forces cold outlined glyph preparation to cross a frame.
	preview["combat_state"]["room_name"] = "XYZQRSTUVWXYZ"
	await Preparation.prepare_hidden_pre_battle_for(scene, state, preview, scene._encounter_preparation_generation, _present, _alive)
	if is_instance_valid(scene): scene.free()
	await _settle(4)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Prepared view cancellation and teardown must leave no orphan nodes")
	print("PREPARED PRE-BATTLE VIEW EQUIVALENCE RESULT: " + JSON.stringify({"errors": errors, "cases": cases, "presented": presented}))
	quit(0 if errors.is_empty() else 1)

func _deck_ids() -> Dictionary:
	var result: Dictionary = {}
	for child: Node in scene._pre_battle_panel.find_child("PreBattleDeckFlow", true, false).get_children():
		result[str(child.get_meta("card_id", ""))] = child.get_instance_id()
	return result

func _compare_current_view(engine: RefCounted, state: Dictionary, label: String) -> void:
	var preview: Dictionary = engine.pre_battle_preview_state(state)
	scene._run_state = state.duplicate(true)
	scene._pre_battle_preview_run_state = preview.duplicate(true)
	scene._rebuild_pre_battle_overlay()
	var panel: PanelContainer = scene._pre_battle_panel
	var reference := PanelContainer.new()
	reference.custom_minimum_size = panel.custom_minimum_size
	reference.size = panel.size
	reference.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel").duplicate())
	panel.get_parent().add_child(reference)
	scene._ui_skin.apply_menu_finish(reference, "outer")
	var room: Dictionary = engine.room_metadata(preview, state.get("current_room", Vector2i.ZERO))
	var combat: Dictionary = preview.get("combat_state", {})
	var element: String = str(combat.get("room_element", room.get("element", "none")))
	var elements = preload("res://scripts/element_data.gd")
	var accent: Color = elements.accent(element) if elements.is_elemental(element) else Color("d8b06d")
	Reference.build(scene, reference, room, combat, accent)
	await _settle(8)
	var actual: Dictionary = _snapshot(panel, panel)
	var expected: Dictionary = _snapshot(reference, reference)
	if actual != expected: _print_differences(actual, expected, label)
	_check(actual == expected, "Retained components must match the original rendered layout, content and focus: " + label)
	reference.free()
	cases += 1

func _snapshot(node: Node, origin: Control) -> Dictionary:
	var result: Dictionary = {"class": node.get_class()}
	var node_name: String = str(node.name)
	if not node_name.begins_with("@") and node != origin: result["name"] = node_name
	if node is Control:
		var control: Control = node as Control
		# Invisible overflow markers retain incidental geometry from earlier sorts.
		# Compare geometry of every rendered control to subpixel precision.
		if control.is_visible_in_tree():
			result["position"] = (control.global_position - origin.global_position).snapped(Vector2(0.001, 0.001))
			result["size"] = control.size.snapped(Vector2(0.001, 0.001))
		result["minimum"] = control.custom_minimum_size
		result["visible"] = control.visible
		result["tooltip"] = control.tooltip_text
		result["focus_mode"] = control.focus_mode
		var focus: Array[String]
		for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			var neighbor: NodePath = control.get_focus_neighbor(side)
			if neighbor.is_empty():
				focus.append("")
			else:
				var target: Node = control.get_node_or_null(neighbor)
				_check(target != null, "Explicit focus neighbor must resolve")
				focus.append(_indexed_path(target, origin))
		result["focus"] = focus
	if node is Label:
		var label: Label = node as Label
		result["text"] = label.text
		result["font_size"] = label.get_theme_font_size("font_size")
		result["outline"] = label.get_theme_constant("outline_size")
		result["font"] = label.get_theme_font("font").get_instance_id()
	if node is Button:
		var button: Button = node as Button
		result["text"] = button.text
		result["disabled"] = button.disabled
		result["icon"] = button.icon.get_instance_id() if button.icon != null else 0
	if node is TextureRect:
		var texture: Texture2D = (node as TextureRect).texture
		result["texture"] = texture.get_instance_id() if texture != null else 0
	if node is Range:
		var range_control: Range = node as Range
		result["value"] = range_control.value
		result["max_value"] = range_control.max_value
	var children: Array[Dictionary]
	for child: Node in node.get_children(): children.append(_snapshot(child, origin))
	result["children"] = children
	return result
func _indexed_path(target: Node, origin: Node) -> String:
	if target == null: return "invalid"
	var indices: Array[String]
	var cursor: Node = target
	while cursor != origin and cursor != null:
		indices.push_front(str(cursor.get_index()))
		cursor = cursor.get_parent()
	_check(cursor == origin, "Foe focus neighbors must remain inside the panel")
	return target.get_class() + ":" + "/".join(indices)

func _alive() -> bool: return active

func _append_skill_path(skill_id: String, preference: Array[String]) -> void:
	for prerequisite: String in Skills.prerequisites(skill_id): _append_skill_path(prerequisite, preference)
	if not preference.has(skill_id): preference.append(skill_id)
func _present() -> void:
	presented += 1
	if cancel_on_present:
		cancel_on_present = false
		active = false
	if free_on_present and is_instance_valid(scene):
		free_on_present = false
		scene.free()
	await process_frame
func _settle(frames: int) -> void:
	for frame: int in range(frames): await process_frame
func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _print_differences(actual: Variant, expected: Variant, path: String) -> void:
	if actual == expected: return
	if actual is Dictionary and expected is Dictionary:
		for key: Variant in expected:
			if not actual.has(key): print("VIEW DIFFERENCE ", path + "/" + str(key), " actual=<missing> reference=", expected[key])
		for key: Variant in actual:
			_print_differences(actual[key], expected.get(key), path + "/" + str(key))
	elif actual is Array and expected is Array and actual.size() == expected.size():
		for index: int in range(actual.size()): _print_differences(actual[index], expected[index], path + "/" + str(index))
	else: print("VIEW DIFFERENCE ", path, " actual=", actual, " reference=", expected)
