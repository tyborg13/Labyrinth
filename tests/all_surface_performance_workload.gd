extends "res://tests/ui_flow_performance_workload.gd"

const Library = preload("res://scripts/grimoire_library.gd")
const Search = preload("res://scripts/grimoire_search.gd")
var _engine := RunEngine.new()
var _phases: Dictionary = {}
var _observed_behavior_gaps: Array[String]

func run(probe: SceneTree, instance: Node, sampler: Node) -> Dictionary:
	_probe = probe
	_instance = instance
	_sampler = sampler
	var pre_battle_only: bool = OS.get_environment("LABYRINTH_RUNTIME_PERF_PRE_BATTLE_ONLY") == "1"
	if pre_battle_only:
		await _travel("combat")
	else:
		await _character_tabs()
		await _skills_navigation_and_actions()
		await _reward_skill_choices()
		await _grimoire()
		await _grimoire_unlock_invalidation()
		for kind: String in ["scavenger", "campfire", "treasure", "combat"]:
			await _travel(kind)
	return {"schema_version": 1, "workload_id": "routed_pre_battle_travel_equipment_start_v1" if pre_battle_only else "routed_character_grimoire_travel_campfire_treasure_v1", "viewport": "1920x1080", "ui_scale": 1.0, "cpu_profile": OS.get_environment("LABYRINTH_PERF_CPU_PROFILE"), "renderer": RenderingServer.get_video_adapter_name(), "rendering_method": RenderingServer.get_current_rendering_method(), "sample_boundary": "RenderingServer.frame_post_draw", "phases": _phases, "observed_behavior_gaps": _observed_behavior_gaps, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "focus_observations": probe.get("_focus_observation_count"), "unfocused_observations": probe.get("_unfocused_observation_count")}

func _install(state: Dictionary) -> void:
	var progression: Dictionary = Tutorial.complete_tutorial(state.get("progression", ProgressionStore.default_data()))
	state["progression"] = progression
	state["notice"] = ""
	state["grimoire_notice"] = ""
	state[RunEngine.UNREAD_LOADOUT_EQUIPMENT_KEY] = []
	state[RunEngine.UNREAD_LOADOUT_MAGIC_KEY] = []
	_check(ProgressionStore.save_data(progression), "Private fixture progression must save")
	_instance.set("_progression", progression)
	_instance.call("_load_run_state", state)
	_instance.call("_close_dialogue")
	await _probe.call("_settle_render_frames", 12)

func _measure(name: String, action: Callable, frames: int = 24) -> Dictionary:
	_probe.call("_phase_log", name)
	var result: Dictionary = await _phase(action, frames)
	_phases[name] = result
	return result

func _character_tabs() -> void:
	var state: Dictionary = _engine.create_new_run(84217, Tutorial.complete_tutorial(ProgressionStore.default_data()))
	state["equipment_inventory"] = ["iron_cleaver", "ward_kite"]
	await _install(state)
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	await _measure("character/open", func() -> void: _click(_instance.get("loadout_button")))
	var nodes: Array[int]
	for cycle: int in range(3):
		for mode: String in ["skills", "equipment", "magic", "skills"]:
			var name: String = "character/%d/%s_%d" % [cycle, mode, _phases.size()]
			var phase: Dictionary = await _measure(name, func() -> void: _click(_instance.find_child("Character%sTab" % mode.capitalize(), true, false)))
			_check(str(_instance.get("_progression_overlay_mode")) == mode, name + " must activate the requested tab")
			var tab: Button = _instance.find_child("Character%sTab" % mode.capitalize(), true, false) as Button
			_check(tab != null and tab.button_pressed, name + " must keep its tab visibly selected")
			if mode == "skills":
				var tree: Control = _instance.get("_skill_tree_view") as Control
				_check(tree != null and tree.is_visible_in_tree(), "Skills must show its live graph")
				phase["skill_tree_profile"] = tree.call("performance_metrics")
			nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if cycle == 0: await _probe.call("_save_root_screenshot", "all_surface_skills.png")
		await _measure("character/%d/close" % cycle, func() -> void: _click(_instance.find_child("CloseCharacterOverlay", true, false)), 12)
		await _measure("character/%d/reopen" % cycle, func() -> void: _click(_instance.get("loadout_button")))
	_check(nodes.size() == 12 and nodes[7] == nodes[11], "Repeated Skills tab cycles must retain bounded live nodes")
	_check((_instance.get("_run_state") as Dictionary).get("equipment_inventory") == before.get("equipment_inventory"), "Character inspection must preserve inventory")
	_check(ProgressionStore.unspent_skill_points(_instance.get("_progression") as Dictionary) == ProgressionStore.unspent_skill_points(before.get("progression") as Dictionary), "Character inspection must preserve skill points")
	await _measure("character/final_close", func() -> void: _click(_instance.find_child("CloseCharacterOverlay", true, false)), 12)

func _skills_navigation_and_actions() -> void:
	var profile: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
	profile["level"] = 2
	profile["skill_ids"] = []
	profile["moltshards"] = 1
	await _install(_engine.create_new_run(84217, profile))
	await _measure("skills_actions/open", func() -> void: _click(_instance.get("loadout_button")))
	await _measure("skills_actions/skills", func() -> void: _click(_instance.find_child("CharacterSkillsTab", true, false)))
	var first_tree_id: int = (_instance.get("_skill_tree_view") as Control).get_instance_id()
	await _measure("skills_actions/gear", func() -> void: _click(_instance.find_child("CharacterEquipmentTab", true, false)))
	await _measure("skills_actions/return", func() -> void: _click(_instance.find_child("CharacterSkillsTab", true, false)))
	var tree: Control = _instance.get("_skill_tree_view")
	_phases["skills_actions/return"]["retained_tree"] = first_tree_id == tree.get_instance_id()
	var topology: Dictionary = {}
	for id: String in (tree.get("_node_buttons") as Dictionary):
		for direction: String in ["left", "right", "up", "down"]:
			topology[id + "/" + direction] = tree.call("navigation_neighbor", id, direction)
	_phases["skills_actions/return"]["navigation_topology"] = topology
	var quick: Control = tree.call("node_for_skill", "quick_wits")
	await _measure("skills_actions/select", func() -> void: _click(quick), 12)
	await _measure("skills_actions/up_to_tab", func() -> void: _key(KEY_UP), 6)
	_check(_probe.root.gui_get_focus_owner() == _instance.find_child("CharacterSkillsTab", true, false), "Retained graph Up must reach the current Skills tab")
	await _measure("skills_actions/down_from_tab", func() -> void: _key(KEY_DOWN), 6)
	_check(_probe.root.gui_get_focus_owner() == quick, "Skills tab Down must return to the selected graph node")
	var before: Dictionary = (_instance.get("_progression") as Dictionary).duplicate(true)
	var expected: Dictionary = ProgressionStore.learn_skill(before, "quick_wits")
	var learn: Button = _instance.find_child("SkillDetailAction", true, false) as Button
	_check(learn != null and not learn.disabled, "First skill must expose enabled Learn")
	await _measure("skills_actions/learn", func() -> void: _click(learn), 36)
	_assert_skill_profile(expected, "Learn")
	tree = _instance.get("_skill_tree_view")
	var edge: String = ""
	for id: String in (tree.get("_node_buttons") as Dictionary):
		if str(tree.call("navigation_neighbor", id, "right")).is_empty():
			edge = id
			break
	_check(not edge.is_empty(), "Skills graph must have a right edge")
	var refresh_before: int = int((tree.call("performance_metrics") as Dictionary).get("focus_render_refresh_count", 0))
	await _measure("skills_actions/right_edge_select", func() -> void: _click(tree.call("node_for_skill", edge)), 12)
	_phases["skills_actions/right_edge_select"]["node_refresh_count"] = int((tree.call("performance_metrics") as Dictionary).get("focus_render_refresh_count", 0)) - refresh_before
	await _measure("skills_actions/right_to_reset", func() -> void: _key(KEY_RIGHT), 6)
	_check(_probe.root.gui_get_focus_owner() == _instance.find_child("ResetSkills", true, false), "Retained graph Right must reach current Reset")
	await _measure("skills_actions/reset_dialog", func() -> void: _key(KEY_ENTER), 12)
	var confirm: Button = _instance.find_child("ConfirmSkillReset", true, false) as Button
	_check(confirm != null and confirm.is_visible_in_tree(), "Reset must open its live confirmation")
	before = (_instance.get("_progression") as Dictionary).duplicate(true)
	expected = ProgressionStore.reset_skills(before)
	await _measure("skills_actions/reset_confirm", func() -> void: _click(confirm), 36)
	_assert_skill_profile(expected, "Reset")
	tree = _instance.get("_skill_tree_view")
	var reset_after: Button = _instance.find_child("ResetSkills", true, false) as Button
	_check(reset_after != null and reset_after.disabled, "Spent Moltshard must disable Reset")
	await _measure("skills_actions/reset_disabled_edge", func() -> void: _click(tree.call("node_for_skill", edge)), 12)
	await _measure("skills_actions/reset_disabled_right", func() -> void: _key(KEY_RIGHT), 6)
	var focused_after: Control = _probe.root.gui_get_focus_owner()
	_check(focused_after != null and focused_after.is_visible_in_tree() and focused_after != reset_after, "After reset graph navigation must avoid the disabled command")
	for id: String in tree.get("_node_buttons"):
		var node: Control = tree.call("node_for_skill", id)
		for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			var neighbor: NodePath = node.get_focus_neighbor(side)
			_check(neighbor.is_empty() or node.get_node_or_null(neighbor) != null, "Every graph focus path must resolve after Reset")
	await _measure("skills_actions/close", func() -> void: _click(_instance.find_child("CloseCharacterOverlay", true, false)), 12)

func _assert_skill_profile(expected: Dictionary, label: String) -> void:
	var actual: Dictionary = _instance.get("_progression")
	for field: String in ["level", "skill_ids", "moltshards"]:
		_check(actual.get(field) == expected.get(field), label + " must match profile oracle: " + field)
	_check(ProgressionStore.unspent_skill_points(actual) == ProgressionStore.unspent_skill_points(expected), label + " must preserve unspent points")

func _reward_skill_choices() -> void:
	var reward: Dictionary = _reward_state()
	reward["progression"]["level"] = 3
	reward["progression"]["skill_ids"] = ["discerning_eye", "deferred_choice"]
	reward = _engine.apply_progression_update(reward, reward["progression"])
	await _install(reward)
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var expected: Dictionary = _engine.reroll_card_reward(before)
	var reroll: Button = _instance.find_child("RewardRerollButton", true, false) as Button
	_check(reroll != null and not reroll.disabled, "Discerning Eye must enable reroll")
	var phase: Dictionary = await _measure("reward_skill/reroll", func() -> void: _click(reroll), 45)
	_assert_state_fields(expected, phase, ["pending_reward", "skill_state"])
	before = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var offered: Array = (before.get("pending_reward") as Dictionary).get("cards", [])
	_check(not offered.is_empty(), "Rerolled reward must expose cards")
	if offered.is_empty(): return
	var chosen: String = str(offered[0])
	expected = _engine.skip_reward_for_heal(before, chosen)
	await _measure("reward_skill/defer_dialog", func() -> void: _click(_instance.find_child("RewardRecoverButton", true, false)), 18)
	var option: Button = _choice_button("Heal & save " + str(GameData.card_def(chosen).get("name", chosen)))
	_check(option != null, "Deferred Choice must expose the offered card")
	phase = await _measure("reward_skill/heal_and_save", func() -> void: _click(option), 45)
	_assert_state_fields(expected, phase, ["pending_reward", "player_hp", "skill_state"])

func _choice_button(text: String) -> Button:
	var list: Control = _instance.get("_skill_choice_list")
	for child: Node in list.get_children():
		if child is Button and (child as Button).text == text: return child as Button
	return null

func _grimoire() -> void:
	var state: Dictionary = _engine.create_new_run(84217, Tutorial.complete_tutorial(ProgressionStore.default_data()))
	var entries: Array = Library.entries()
	var sections: Array = Library.sections()
	var ids: Array[String]
	for entry: Dictionary in entries: ids.append(str(entry.get("id", "")))
	state[Library.UNLOCKED_KEY] = ids.duplicate()
	state[Library.UNREAD_KEY] = []
	state["progression"][Library.UNLOCKED_KEY] = ids.duplicate()
	state["progression"][Library.UNREAD_KEY] = []
	await _install(state)
	var opener: Control = _instance.get("grimoire_button") as Control
	await _measure("grimoire/open_all_known", func() -> void: _click(opener))
	_check((_instance.get("_grimoire_scrim") as Control).visible, "Grimoire must open")
	_check(_probe.root.gui_get_focus_owner() == _instance.get("_grimoire_search_input"), "Grimoire must focus search")
	for query: String in ["fire", "damage", "heath c", "reshuffle", "initiative", "purple banana"]:
		var partial: String = ""
		for index: int in range(query.length()):
			var character: String = query.substr(index, 1)
			partial += character
			var expected: Array[String] = _result_ids(Search.search(entries, sections, partial))
			var phase: Dictionary = await _measure("grimoire/%s/%d" % [query.replace(" ", "_"), index + 1], func() -> void: _type_character(character), 6)
			_check(str(_instance.get("_grimoire_search_query")) == partial, "Routed typing must produce query " + partial)
			var actual: Array[String] = _result_ids(_instance.get("_grimoire_search_results") as Array)
			_check(actual == expected, "Search result order must match reference for " + partial)
			phase["result_ids"] = actual
		if query == "heath c": _check(_result_ids(_instance.get("_grimoire_search_results") as Array)[0] == "keyword:health_cost", "Typo query must rank Health Cost first")
		if query == "initiative": _check(str(_instance.get("_grimoire_selected_entry")) == "combat:turn_clock", "Alias query must select Turn Clock")
		if query == "reshuffle":
			await _measure("grimoire/result_focus", func() -> void: _key(KEY_DOWN), 6)
			await _measure("grimoire/result_activate", func() -> void: _key(KEY_ENTER), 12)
			var focused: Control = _probe.root.gui_get_focus_owner()
			_check(focused != null and str(focused.get_meta("grimoire_nav_id", "")) == "combat:fatigue", "Result activation must retain focus on Fatigue")
		if query == "fire": await _probe.call("_save_root_screenshot", "all_surface_grimoire_fire.png")
		await _measure("grimoire/%s/clear" % query.replace(" ", "_"), func() -> void: _click(_instance.find_child("GrimoireSearchClear", true, false)), 12)
		var clear_refreshed: bool = str(_instance.get("_grimoire_search_query")).is_empty()
		_phases["grimoire/%s/clear" % query.replace(" ", "_")]["clear_refreshed_results"] = clear_refreshed
		if not clear_refreshed: _observed_behavior_gaps.append("Clear emptied input but retained results: " + query)
		# Record the pre-existing Clear defect rather than hiding it. The same
		# untimed typed character/backspace reset makes later queries independent.
		_type_character("x")
		await _probe.call("_settle_render_frames", 3)
		_key(KEY_BACKSPACE)
		await _probe.call("_settle_render_frames", 3)
		_check(str(_instance.get("_grimoire_search_query")).is_empty(), "Typed erase must reset query before the next independent search")
	await _measure("grimoire/close", func() -> void: _key(KEY_ESCAPE), 12)
	_check(not (_instance.get("_grimoire_scrim") as Control).visible, "Escape must close Grimoire")
	_check(_probe.root.gui_get_focus_owner() == opener, "Closing Grimoire must restore opener focus")

func _type_character(character: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = character.to_upper().unicode_at(0)
		event.physical_keycode = event.keycode
		event.unicode = character.unicode_at(0)
		event.pressed = pressed
		_probe.root.push_input(event, true)

func _grimoire_unlock_invalidation() -> void:
	var state: Dictionary = _engine.create_new_run(84217, Tutorial.complete_tutorial(ProgressionStore.default_data()))
	await _install(state)
	await _measure("grimoire_unlock/open", func() -> void: _click(_instance.get("grimoire_button")), 12)
	var additions: Array[String]
	for entry: Dictionary in Library.entries():
		var id: String = str(entry.get("id", ""))
		if id.begins_with("enemy:"): additions.append(id)
	_check(additions.size() >= 2, "Unlock fixture needs two enemy entries")
	if additions.size() < 2: return
	for cycle: int in range(3):
		var ids: Array[String]
		ids.append(additions[0])
		if cycle == 1: ids.append(additions[1])
		var changed: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
		changed[Library.UNLOCKED_KEY] = ids.duplicate()
		changed[Library.UNREAD_KEY] = ids.duplicate()
		changed["progression"][Library.UNLOCKED_KEY] = ids.duplicate()
		changed["progression"][Library.UNREAD_KEY] = ids.duplicate()
		_instance.set("_run_state", changed)
		_instance.call("_rebuild_grimoire_overlay")
		await _probe.call("_settle_render_frames", 3)
		# The public library adds default knowledge; derive the allowed catalog
		# from that canonical state, not the smaller requested test subset.
		var known: Array[String] = Library.normalize_entry_ids((_instance.get("_run_state") as Dictionary)[Library.UNLOCKED_KEY])
		var visible: Array = []
		for entry: Dictionary in Library.entries():
			if known.has(str(entry.get("id", ""))): visible.append(entry)
		if cycle == 0:
			for character: String in ["e", "n", "e", "m", "y"]:
				_type_character(character)
				await _probe.call("_settle_render_frames", 2)
		var phase: Dictionary = await _measure("grimoire_unlock/%d/unread_refresh" % cycle, func() -> void: _instance.call("_rebuild_grimoire_overlay"), 12)
		var actual: Array[String] = _result_ids(_instance.get("_grimoire_search_results") as Array)
		var expected: Array[String] = _result_ids(Search.search(visible, Library.sections(), "enemy"))
		_check(actual == expected, "Unchanged query must follow A to AB to A unlock changes")
		phase["result_ids"] = actual
		phase["unlocked_ids"] = known
	await _measure("grimoire_unlock/close", func() -> void: _key(KEY_ESCAPE), 12)

func _result_ids(results: Array) -> Array[String]:
	var ids: Array[String]
	for result: Dictionary in results: ids.append(str((result.get("entry", {}) as Dictionary).get("id", "")))
	return ids

func _travel(kind: String) -> void:
	var fixture: Dictionary = _route_fixture(kind)
	_check(not fixture.is_empty(), "Generated map must offer reachable " + kind)
	if fixture.is_empty(): return
	await _install(fixture.get("state"))
	var destination: Vector2i = fixture.get("destination")
	var before: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var expected: Dictionary = _engine.move_to_pre_battle(before, destination)
	await _measure("travel/%s/map_open" % kind, func() -> void: _key(KEY_M), 12)
	var map: Control = _instance.get("_large_map_view") as Control
	var point: Vector2 = map.call("_coord_position", destination)
	_check(map.call("_coord_at_point", point) == destination, "Map point must identify the reachable destination")
	var phase: Dictionary = await _measure("travel/%s/enter" % kind, func() -> void: _probe.call("_routed_left_click", map, point), 60)
	_assert_state_fields(expected, phase, ["mode", "current_room", "current_room_layout", "turns_spent", "held_embers", "pending_relics"])
	_instance.call("_close_dialogue")
	await _probe.call("_settle_render_frames", 6)
	if kind == "campfire": await _campfire()
	elif kind == "treasure": await _treasure()
	elif kind == "combat":
		_check((_instance.get("_pre_battle_scrim") as Control).visible, "Combat travel must expose the pre-battle preview")
		await _probe.call("_save_root_screenshot", "all_surface_pre_battle.png")
		await _measure("travel/combat/equip_open", func() -> void: _click(_instance.find_child("PreBattleEquipButton", true, false)))
		await _measure("travel/combat/equipment_tab", func() -> void: _click(_instance.find_child("CharacterEquipmentTab", true, false)))
		before = (_instance.get("_run_state") as Dictionary).duplicate(true)
		expected = _engine.equip_equipment(before, "iron_cleaver", "weapon")
		var tile: Control = (_instance.get("_equipment_inventory_tiles") as Dictionary).get("iron_cleaver")
		_check(tile != null and tile.is_visible_in_tree(), "Prebattle must expose the owned replacement weapon")
		phase = await _measure("travel/combat/equip_weapon", func() -> void: _probe.call("_routed_left_click", tile, tile.size * 0.5, true), 90)
		_assert_state_fields(expected, phase, ["equipped_equipment", "equipment_inventory"])
		await _measure("travel/combat/equip_close", func() -> void: _click(_instance.find_child("CloseCharacterOverlay", true, false)), 24)
		_check((_instance.get("_pre_battle_scrim") as Control).visible, "Closing Character must return to the prebattle preview")
		before = (_instance.get("_run_state") as Dictionary).duplicate(true)
		expected = _engine.begin_pre_battle_combat(before)
		phase = await _measure("travel/combat/begin", func() -> void: _click(_instance.find_child("PreBattleStartButton", true, false)), 90)
		_assert_state_fields(expected, phase, ["mode", "current_room", "equipped_equipment", "held_embers"])
		_check(not bool(_instance.get("_animation_lock")), "Beginning combat must restore input")
		_check(not ((_instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []).is_empty(), "Beginning combat must deal a visible hand")

func _campfire() -> void:
	var state: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var bar: Control = _instance.get("_relic_choice_bar") as Control
	_check(bar.get_child_count() == 3, "Campfire must expose its three choices")
	for index: int in range(bar.get_child_count()):
		await _measure("campfire/hover_%d" % index, func() -> void: _motion(bar.get_child(index)), 12)
	await _probe.call("_save_root_screenshot", "all_surface_campfire.png")
	var expected: Dictionary = _engine.leave_campfire(state, RunEngine.CAMPFIRE_LINGER_HEAL)
	var phase: Dictionary = await _measure("campfire/linger", func() -> void: _click(bar.get_child(0)), 60)
	_assert_state_fields(expected, phase, ["mode", "player_hp", "player_max_hp", "held_embers"])
	await _install(state.duplicate(true))
	var before: Dictionary = (_instance.get("_progression") as Dictionary).duplicate(true)
	var expected_progression: Dictionary = ProgressionStore.purchase_level(before)
	bar = _instance.get("_relic_choice_bar") as Control
	phase = await _measure("campfire/strength", func() -> void: _click(bar.get_child(2)), 60)
	var after: Dictionary = _instance.get("_progression") as Dictionary
	for field: String in ["level", "embers"]:
		_check(after.get(field) == expected_progression.get(field), "Campfire Strength must preserve " + field)
	_check(ProgressionStore.unspent_skill_points(after) == ProgressionStore.unspent_skill_points(expected_progression), "Campfire Strength must preserve unspent skill points")
	phase["progression_semantics"] = {"level": after.get("level"), "embers": after.get("embers"), "skill_points": ProgressionStore.unspent_skill_points(after)}
	_check((_instance.get("_upgrade_scrim") as Control).visible and str(_instance.get("_progression_overlay_mode")) == "skills", "Strength must open Skills")
	await _measure("campfire/skills_close", func() -> void: _click(_instance.find_child("CloseCharacterOverlay", true, false)), 12)

func _treasure() -> void:
	var state: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	var offers: Array = state.get("pending_relics", []) as Array
	_check(not offers.is_empty(), "Treasure must expose generated relic offers")
	if offers.is_empty(): return
	var relic_id: String = str(offers[0])
	var choice: Control = _instance.find_child("RelicChoice_" + relic_id, true, false) as Control
	_check(choice != null and str(choice.get_meta("relic_id", "")) == relic_id, "Relic choice must identify the generated offer")
	await _measure("treasure/hover", func() -> void: _motion(choice), 18)
	await _probe.call("_save_root_screenshot", "all_surface_treasure.png")
	var expected: Dictionary = _engine.claim_relic(state, relic_id)
	var phase: Dictionary = await _measure("treasure/claim", func() -> void: _click(choice), 90)
	_assert_state_fields(expected, phase, ["mode", "relics", "player_hp", "player_max_hp", "pending_relics", "defiance_capacity", "defiance_remaining"])

func _assert_state_fields(expected: Dictionary, phase: Dictionary, fields: Array) -> void:
	var actual: Dictionary = _instance.get("_run_state") as Dictionary
	var semantics: Dictionary = {}
	for field: String in fields:
		_check(expected.has(field) and actual.has(field), "State oracle field must exist: " + field)
		_check(actual.get(field) == expected.get(field), "Routed state must match engine oracle: " + field)
		semantics[field] = actual.get(field)
	phase["semantics"] = semantics

func _route_fixture(kind: String) -> Dictionary:
	var progression: Dictionary = Tutorial.complete_tutorial(ProgressionStore.set_embers(ProgressionStore.default_data(), 720))
	var state: Dictionary = _engine.create_new_run(73491, progression)
	for radius: int in range(1, 10):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius: continue
				var destination := Vector2i(x, y)
				var destination_room: Dictionary = _engine.room_metadata(state, destination)
				if str(destination_room.get("type", "")) != kind: continue
				for connection: Dictionary in destination_room.get("connections", []):
					var origin: Vector2i = connection.get("coord", Vector2i(999, 999))
					var source: Dictionary = _engine.room_metadata(state, origin)
					if int(source.get("depth", 99)) > radius or str(source.get("type", "")) != "combat": continue
					var candidate: Dictionary = state.duplicate(true)
					source["revealed"] = true
					source["visited"] = true
					source["cleared"] = true
					source["sealed"] = false
					destination_room["revealed"] = true
					destination_room["visited"] = false
					destination_room["sealed"] = false
					destination_room["cleared"] = false
					candidate["rooms"]["%d,%d" % [origin.x, origin.y]] = source
					candidate["rooms"]["%d,%d" % [destination.x, destination.y]] = destination_room
					candidate["current_room"] = origin
					candidate["current_room_layout"] = _engine.call("_display_layout_for_room", int(candidate.get("seed")), source, Vector2i(1, 0))
					candidate["mode"] = "room"
					candidate["combat_state"] = {}
					candidate["held_embers"] = 720
					candidate["unbanked_embers"] = 720
					candidate["player_hp"] = maxi(1, int(candidate.get("player_max_hp", 24)) / 2)
					candidate["equipment_inventory"] = ["iron_cleaver", "ward_kite"]
					candidate = _engine.repair_loaded_run_state(candidate)
					if str(_engine.room_metadata(candidate, destination).get("type", "")) != kind: continue
					if _engine.available_moves(candidate).has(destination): return {"state": candidate, "destination": destination}
	return {}
