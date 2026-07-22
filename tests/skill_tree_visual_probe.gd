extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")

const OUTPUT_DIR: String = "user://probes/skill_tree_ui_rubric_v2"
const STORAGE_PATH: String = "user://skill_tree_visual_progression.json"
const RUN_STORAGE_PATH: String = "user://skill_tree_visual_run.save"
const PROGRESSION_LEVEL: int = 13
const PROGRESSION_SKILLS = [
	"quick_wits",
	"measured_breath",
	"ghost_stride",
	"discerning_eye",
	"rehearsed_escape",
	"makeshift_tool",
	"carry_the_guard",
	"borrowed_time",
	"prismatic_instinct",
	"encore",
]

var _failures: Array[String]
var _active_screenshot_size: Vector2i

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for skill progression visual proof")
	else:
		for config: Dictionary in _requested_configs():
			await _capture_resolution(packed, config.get("size", Vector2i(1280, 720)), float(config.get("scale", 1.0)))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("SKILL TREE VISUAL PROBE: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("SKILL TREE VISUAL PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)

func _capture_resolution(packed: PackedScene, screenshot_size: Vector2i, ui_scale: float) -> void:
	_active_screenshot_size = screenshot_size
	var viewport_size := Vector2i(
		maxi(1, roundi(float(screenshot_size.x) / ui_scale)),
		maxi(1, roundi(float(screenshot_size.y) / ui_scale))
	)
	var progression: Dictionary = _populated_progression()
	_expect(ProgressionStore.save_data(progression), "%s @ %d%% progression fixture should save" % [screenshot_size, roundi(ui_scale * 100.0)])
	var viewport := SubViewport.new()
	viewport.name = "SkillProgressionProof_%dx%d_ui%d" % [screenshot_size.x, screenshot_size.y, roundi(ui_scale * 100.0)]
	viewport.size = screenshot_size
	if not is_equal_approx(ui_scale, 1.0):
		viewport.size_2d_override = viewport_size
		viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(81173 + screenshot_size.x + roundi(ui_scale * 100.0), progression)
	instance.set("_progression", progression)
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	await _settle()
	_expect(instance.get_viewport().get_visible_rect().size == Vector2(viewport_size), "%s @ %d%% should expose the expected %s logical viewport" % [screenshot_size, roundi(ui_scale * 100.0), viewport_size])
	var output_dir: String = "%s/%dx%d_ui%d" % [OUTPUT_DIR, screenshot_size.x, screenshot_size.y, roundi(ui_scale * 100.0)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await _capture_skills_tree(instance, viewport, viewport_size, output_dir)
	await _capture_reset_flow(instance, viewport, viewport_size, output_dir)
	await _capture_level_up_tree(instance, viewport, viewport_size, output_dir, progression, run_state)
	await _capture_combat_surfaces(instance, viewport, viewport_size, output_dir, progression, run_state)

	instance.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame

func _capture_skills_tree(instance: Node, viewport: SubViewport, viewport_size: Vector2i, output_dir: String) -> void:
	instance.call("_open_character_overlay", "skills")
	await _settle()
	var dialog := instance.get("_upgrade_dialog") as Control
	var tree := instance.get("_skill_tree_view") as SkillTreeView
	_expect(dialog != null and dialog.visible, "%s Skills dialog should be visible" % viewport_size)
	_expect(tree != null and tree.node_count() == 24, "%s Skills dialog should render all 24 nodes" % viewport_size)
	_expect(tree != null and tree.owned_skill_ids().size() == 10, "%s Skills dialog should render ten learned skills" % viewport_size)
	_expect(tree != null and tree.points_remaining() == 2, "%s Skills dialog should show two banked skill points" % viewport_size)
	if tree != null:
		_expect(tree.connection_arrowhead_count() == tree.connection_count(), "%s Every prerequisite route should expose one visible target arrowhead" % viewport_size)
		_expect(tree.collinear_connection_overlap_pairs().is_empty(), "%s No unrelated prerequisite routes should merge onto one rail" % viewport_size)
		_expect(tree.bridged_connection_pairs().size() == 11, "%s Every unavoidable route crossover should render with an explicit line bridge" % viewport_size)
		_expect(tree.unbridged_connection_pairs().is_empty(), "%s No route crossover should resemble an unexplained branch" % viewport_size)
		tree.focus_skill("prismatic_instinct")
		var prismatic_links: Array[String] = tree.highlighted_connection_pairs()
		_expect(prismatic_links.size() == 3, "%s Skills tree should emphasize only Prismatic Instinct's two parents and direct unlock" % viewport_size)
		_expect(prismatic_links.has("quick_wits>prismatic_instinct"), "%s Skills tree should emphasize Prismatic Instinct's Quick Wits parent" % viewport_size)
		_expect(prismatic_links.has("discerning_eye>prismatic_instinct"), "%s Skills tree should emphasize Prismatic Instinct's Discerning Eye parent" % viewport_size)
		_expect(prismatic_links.has("prismatic_instinct>confluence"), "%s Skills tree should emphasize Prismatic Instinct's Confluence unlock" % viewport_size)
	_assert_tree_scroll_contract(tree, viewport_size, "Skills")
	var moltshard_label := dialog.find_child("ProgressionMoltshardsLabel", true, false) as Label
	_expect(moltshard_label != null and moltshard_label.text.contains("2"), "%s Skills dialog should prominently show two Moltshards" % viewport_size)
	_expect(dialog.find_child("SkillResetHint", true, false) == null, "%s Skills dialog should omit permanent reset-explanation copy" % viewport_size)
	_expect(_button_with_text(dialog, "Reset Skills  ·  1 Moltshard") != null, "%s Skills dialog should expose the whole-tree reset command" % viewport_size)
	if tree != null:
		var graph_scroll := tree.find_child("SkillTreeScroll", true, false) as ScrollContainer
		graph_scroll.scroll_horizontal = 61
		graph_scroll.scroll_vertical = 37
		await process_frame
		var scroll_before: Vector2i = tree.graph_scroll_offset()
		var geometry_before: int = tree.link_geometry_rebuild_count()
		var focused_before: String = tree.focused_skill_id()
		for skill_id: String in SkillTreeLibrary.ordered_ids():
			tree.node_for_skill(skill_id).mouse_entered.emit()
		await process_frame
		_expect(tree.focused_skill_id() == focused_before, "%s Hovering should not change skill selection" % viewport_size)
		_expect(tree.graph_scroll_offset() == scroll_before, "%s Hovering the complete tree should not move either scroll axis" % viewport_size)
		_expect(tree.link_geometry_rebuild_count() == geometry_before, "%s Hovering should reuse cached connector geometry" % viewport_size)
		tree.focus_skill("prismatic_instinct")
		await _settle()
	_assert_skill_modal_contained(dialog, tree, viewport_size, "%s Skills dialog" % viewport_size, "Character")
	await _save_screenshot(viewport, "%s/01_skills_tree.png" % output_dir)
	if tree != null:
		tree.focus_skill("living_shadow")
		await _settle()
		var living_links: Array[String] = tree.highlighted_connection_pairs()
		_expect(living_links.size() == 5, "%s Living Shadow focus should expose its complete two-branch ancestry and direct keystone" % viewport_size)
		_expect(living_links.has("measured_breath>pain_remembers"), "%s Living Shadow should trace through Pain Remembers to Measured Breath" % viewport_size)
		_expect(living_links.has("ghost_stride>afterimage"), "%s Living Shadow should trace through Afterimage to Ghost Stride" % viewport_size)
		_expect(living_links.has("living_shadow>open_arsenal"), "%s Living Shadow should retain its direct Open Arsenal route" % viewport_size)
		await _save_screenshot(viewport, "%s/01b_living_shadow_path.png" % output_dir)
		tree.focus_skill("last_door")
		tree.grab_tree_focus()
		await _settle()
		var graph_scroll := tree.find_child("SkillTreeScroll", true, false) as ScrollContainer
		var last_door_node: Button = tree.node_for_skill("last_door")
		_expect(
			graph_scroll != null
			and last_door_node != null
			and graph_scroll.get_global_rect().encloses(last_door_node.get_global_rect()),
			"%s Focusing the far keystone should automatically reveal it inside the graph viewport" % viewport_size
		)
		await _save_screenshot(viewport, "%s/01c_last_door_scroll.png" % output_dir)

func _capture_reset_flow(instance: Node, viewport: SubViewport, viewport_size: Vector2i, output_dir: String) -> void:
	instance.call("_open_skill_reset_confirmation")
	await _settle()
	var tree := instance.get("_skill_tree_view") as SkillTreeView
	var dialog := instance.get("_upgrade_dialog") as Control
	var confirmation := instance.get("_skill_reset_confirmation_scrim") as Control
	var confirmation_message := confirmation.find_child("SkillResetConfirmationMessage", true, false) as Label if confirmation != null else null
	_expect(confirmation != null and confirmation.is_visible_in_tree(), "%s Reset should open an explicit blocking confirmation" % viewport_size)
	_expect(confirmation_message != null and confirmation_message.text.contains("Are you sure you want to clear all 10 learned skills?") and confirmation_message.text.contains("12 earned skill points"), "%s Reset confirmation should name its complete effect" % viewport_size)
	_assert_skill_modal_contained(dialog, tree, viewport_size, "%s Reset confirmation dialog" % viewport_size, "Character")
	await _save_screenshot(viewport, "%s/02_reset_confirmation.png" % output_dir)

	instance.call("_confirm_skill_reset")
	await _settle()
	tree = instance.get("_skill_tree_view") as SkillTreeView
	dialog = instance.get("_upgrade_dialog") as Control
	_expect(instance.get("_skill_reset_confirmation_scrim") == null, "%s Confirming reset should close the prompt" % viewport_size)
	_expect(tree != null and tree.owned_skill_ids().is_empty(), "%s Confirming reset should clear every learned skill" % viewport_size)
	_expect(tree != null and tree.points_remaining() == 12, "%s Confirming reset should refund all twelve earned points" % viewport_size)
	_expect(ProgressionStore.moltshard_count(instance.get("_progression") as Dictionary) == 1, "%s Confirming reset should spend exactly one Moltshard" % viewport_size)
	_assert_skill_modal_contained(dialog, tree, viewport_size, "%s Cleared skill tree" % viewport_size, "Character")
	await _save_screenshot(viewport, "%s/03_reset_complete.png" % output_dir)
	await _settle()
	instance.call("_close_card_upgrade_overlay")
	await _settle()

func _capture_level_up_tree(
	instance: Node,
	viewport: SubViewport,
	viewport_size: Vector2i,
	output_dir: String,
	progression: Dictionary,
	base_run_state: Dictionary
) -> void:
	var level_progression: Dictionary = progression.duplicate(true)
	var cost: int = ProgressionStore.next_level_cost(level_progression)
	_expect(cost > 0, "%s Level-up visual fixture should have a next-level cost" % viewport_size)
	level_progression = ProgressionStore.set_embers(level_progression, cost)
	var level_run: Dictionary = base_run_state.duplicate(true)
	level_run["mode"] = "campfire"
	level_run["progression"] = level_progression.duplicate(true)
	level_run["held_embers"] = cost
	level_run["unbanked_embers"] = cost
	instance.set("_progression", level_progression)
	instance.call("_load_run_state", level_run)
	instance.call("_close_dialogue")
	await _settle()
	instance.call("_open_level_up_overlay")
	await _settle()

	var dialog := instance.get("_upgrade_dialog") as Control
	var tree := instance.get("_skill_tree_view") as SkillTreeView
	_expect(dialog != null and dialog.visible, "%s Level-up dialog should be visible" % viewport_size)
	_expect(tree != null and tree.mode() == SkillTreeView.MODE_VIEW, "%s Campfire leveling should open the same persistent tree state" % viewport_size)
	_expect(tree != null and tree.points_remaining() == 3, "%s Campfire leveling should add one banked point to the existing two" % viewport_size)
	var chosen_skill_id: String = ""
	if tree != null:
		var available: Array[String] = SkillTreeLibrary.available_ids(tree.owned_skill_ids())
		_expect(not available.is_empty(), "%s Level-up fixture should expose an available skill" % viewport_size)
		if not available.is_empty():
			chosen_skill_id = available[0]
			tree.focus_skill(chosen_skill_id)
			await _settle()
			_expect(tree.detail_action_is_enabled(), "%s Focused level-up skill should be actionable" % viewport_size)
		_assert_tree_scroll_contract(tree, viewport_size, "Level-up")
	_assert_skill_modal_contained(dialog, tree, viewport_size, "%s Level-up dialog" % viewport_size, "Character")
	await _save_screenshot(viewport, "%s/07_level_up.png" % output_dir)
	if tree != null and not chosen_skill_id.is_empty():
		tree.activate_focused_skill()
		await process_frame
		await process_frame
		_expect(tree.status_for_skill(chosen_skill_id) == SkillTreeView.STATE_OWNED, "%s Immediate learning should update the existing medallion in place" % viewport_size)
		_expect(instance.find_child("ProgressionOverlayNotice", true, false) == null, "%s Immediate learning should not add redundant learned/remaining copy" % viewport_size)
		await _save_screenshot(viewport, "%s/07b_skill_learned.png" % output_dir)
	_expect(ProgressionStore.save_data(progression), "%s Level-up visual fixture should restore its base profile" % viewport_size)
	instance.call("_close_card_upgrade_overlay")
	await _settle()

func _capture_combat_surfaces(
	instance: Node,
	viewport: SubViewport,
	viewport_size: Vector2i,
	output_dir: String,
	progression: Dictionary,
	base_run_state: Dictionary
) -> void:
	var layout: Dictionary = _combat_layout()
	var combat_engine := CombatEngine.new()
	var deck_cards: Array[String]
	deck_cards.append_array([
		"quick_stab",
		"sidestep_slash",
		"spark_dart",
		"guarded_step",
		"patch_up",
		"bone_dart",
		"frostbolt",
		"ember_jab",
	])
	var combat_state: Dictionary = combat_engine.create_combat(93471 + viewport_size.y, layout, {
		"hp": 360,
		"max_hp": 360,
		"deck_cards": deck_cards,
		"skill_ids": ProgressionStore.selected_skill_ids(progression),
		"level": PROGRESSION_LEVEL,
		"relics": ["ember_lens"],
		"hand_size": 5,
		"heal_bonus": 0,
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	# This hand makes every learned manual skill legal at once: a Burn card for
	# Rehearsed Escape, an item for Makeshift Tool, an intensity card for
	# Prismatic Instinct, any card for Quick Wits, a discard for Encore, and
	# positive block for Carry the Guard below.
	deck["hand"] = ["patch_up", "crimson_draught", "rime_shard", "quick_stab"]
	deck["discard"] = ["bone_dart"]
	deck["draw"] = ["patch_up", "frostbolt", "ember_jab"]
	combat_state["deck"] = deck
	combat_state["banked_play_active"] = 1
	combat_state["banked_play_spent_this_activation"] = 0
	var combat_player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	combat_player["block"] = 20
	combat_state["player"] = combat_player
	var combat_run: Dictionary = base_run_state.duplicate(true)
	combat_run["mode"] = "combat"
	combat_run["current_room"] = layout.get("coord", Vector2i(1, 0))
	combat_run["current_room_layout"] = layout.duplicate(true)
	combat_run["combat_state"] = combat_state.duplicate(true)
	combat_run["progression"] = progression.duplicate(true)
	combat_run["relics"] = ["ember_lens"]
	instance.set("_progression", progression)
	instance.call("_load_run_state", combat_run)
	instance.call("_close_dialogue")
	await _settle()

	var sigil := instance.get("_skill_sigil") as Button
	_expect(sigil != null and sigil.is_visible_in_tree(), "%s Combat HUD should show the skill sigil" % viewport_size)
	_expect(sigil != null and sigil.text.contains("10"), "%s Skill sigil should summarize ten learned skills" % viewport_size)
	_assert_inside(sigil, viewport_size, "%s Combat skill sigil" % viewport_size, 8.0)
	var title_box := instance.get("title_box") as Control
	if sigil != null and title_box != null:
		print("Skill HUD %s title=%s sigil=%s" % [viewport_size, title_box.get_global_rect(), sigil.get_global_rect()])
	var choice_overlay := instance.get("_choice_button_overlay") as Control
	var choice_bar := instance.get("choice_bar") as Control
	var maximum_manual_skill_names: Array[String] = [
		"Quick Wits",
		"Rehearsed Escape",
		"Makeshift Tool",
		"Carry the Guard",
		"Prismatic Instinct",
		"Encore",
	]
	var maximum_manual_skill_ids: Array[String] = [
		"quick_wits",
		"rehearsed_escape",
		"makeshift_tool",
		"carry_the_guard",
		"prismatic_instinct",
		"encore",
	]
	var ready_group: Button = _button_beginning_with(choice_overlay, "Ready Skills (")
	if ready_group == null:
		ready_group = _button_beginning_with(choice_bar, "Ready Skills (")
	_expect(ready_group == null, "%s Activated abilities should not create a contextual control beside Pass" % viewport_size)
	var pass_button: Button = _visible_button_with_text(choice_overlay, "Pass")
	if pass_button == null:
		pass_button = _visible_button_with_text(choice_bar, "Pass")
	_expect(pass_button != null, "%s The normal Pass control should remain uncluttered" % viewport_size)
	for skill_name: String in maximum_manual_skill_names:
		var button: Button = _visible_button_with_text(choice_overlay, skill_name)
		if button == null:
			button = _visible_button_with_text(choice_bar, skill_name)
		_expect(button == null, "%s Grouped combat HUD should not cover the hand with a direct %s control" % [viewport_size, skill_name])
	var banked_badge := instance.get("_play_meter_banked_badge") as Control
	var banked_label := instance.get("_play_meter_banked_label") as Label
	_expect(banked_badge != null and banked_badge.visible, "%s Combat HUD should distinguish the stored play from ordinary plays" % viewport_size)
	_expect(banked_label != null and banked_label.text == "+1 BANKED • NO TIME", "%s Combat HUD should explain Borrowed Time on the stored play" % viewport_size)
	await _save_screenshot(viewport, "%s/04_combat_skill_controls.png" % output_dir)

	instance.call("_toggle_skill_status_popover")
	await _settle()
	var popover := instance.get("_skill_status_popover") as Control
	_expect(popover != null and popover.visible, "%s Skill sigil should open its status popover" % viewport_size)
	for skill_id: String in maximum_manual_skill_ids:
		var ability_button := popover.find_child("SkillStatusRow_%s" % skill_id, true, false) as Button if popover != null else null
		_expect(ability_button != null, "%s Abilities should expose %s through the common entry point" % [viewport_size, SkillTreeLibrary.display_name(skill_id)])
	_expect(_label_with_text(popover, "READY") != null, "%s Skill popover should show at least one ready ability" % viewport_size)
	_expect(_label_with_text(popover, "BANKED") != null and _label_with_text(popover, "PRIMED") != null, "%s Skill popover should expose the stored-play state and its pending no-Time benefit" % viewport_size)
	_expect(_label_with_text(popover, "Quick Wits") != null, "%s Skill popover should list Quick Wits" % viewport_size)
	_expect(_label_with_text(popover, "Discerning Eye") != null, "%s Skill popover should list Discerning Eye" % viewport_size)
	_assert_inside(popover, viewport_size, "%s Skill status popover" % viewport_size, 8.0)
	await _save_screenshot(viewport, "%s/04b_abilities_entry.png" % output_dir)
	await _save_screenshot(viewport, "%s/05_combat_skill_popover.png" % output_dir)

	instance.call("_close_skill_status_popover")
	instance.call("_on_combat_skill_pressed", "quick_wits")
	await _settle()
	var choice_scrim := instance.get("_skill_choice_scrim") as Control
	var selection_prompt := instance.get("_combat_skill_card_selection_prompt") as Control
	var hand_box := instance.get("hand_box") as Control
	_expect(choice_scrim != null and not choice_scrim.visible, "%s Quick Wits should avoid the name-only choice dialog" % viewport_size)
	_expect(selection_prompt != null and selection_prompt.visible and _label_containing(selection_prompt, "CHOOSE A CARD TO DISCARD") != null, "%s Quick Wits should enter live-hand discard mode" % viewport_size)
	_expect(hand_box != null and hand_box.get_child_count() == 4, "%s Quick Wits should preserve the full visible hand for selection" % viewport_size)
	var focused_hand_choice := hand_box.find_child("SkillHandSelectionCard_0", true, false) as Button if hand_box != null else null
	_expect(focused_hand_choice != null and instance.get_viewport().gui_get_focus_owner() == focused_hand_choice, "%s Quick Wits should focus its first full-card controller choice" % viewport_size)
	_assert_inside(selection_prompt, viewport_size, "%s Quick Wits hand-selection prompt" % viewport_size, 8.0)
	var prompt_rect: Rect2 = selection_prompt.get_global_rect() if selection_prompt != null else Rect2()
	var hand_rect: Rect2 = hand_box.get_global_rect() if hand_box != null else Rect2()
	_expect(selection_prompt != null and hand_box != null and prompt_rect.end.y <= hand_rect.position.y - 8.0, "%s Quick Wits prompt should stay above the full-card evidence" % viewport_size)
	await _save_screenshot(viewport, "%s/06_quick_wits_hand_selection.png" % output_dir)
	await _click_control(viewport, focused_hand_choice, "%s Quick Wits full-card choice" % viewport_size)
	_expect(selection_prompt != null and not selection_prompt.visible, "%s Clicking the full hand card should close Quick Wits selection" % viewport_size)
	_expect(combat_engine.skill_was_used(instance.get("_combat_state") as Dictionary, "quick_wits"), "%s Clicking the full hand card should spend Quick Wits" % viewport_size)
	instance.call("_on_combat_skill_pressed", "encore")
	await _settle()
	var pile_scrim := instance.get("_pile_scrim") as Control
	var pile_cards := instance.get("_pile_dialog_cards") as Control
	_expect(pile_scrim != null and pile_scrim.visible, "%s Encore should open the discard pile" % viewport_size)
	var discard_choice := pile_cards.find_child("DiscardSelectionCard_0", true, false) as Button if pile_cards != null else null
	_expect(discard_choice != null, "%s Encore should make the full discarded card selectable" % viewport_size)
	var discard_focus_style := discard_choice.get_theme_stylebox("focus") as StyleBoxFlat if discard_choice != null else null
	_expect(discard_focus_style != null and discard_focus_style.border_width_left >= 4, "%s Encore should show a strong controller focus frame around the full card" % viewport_size)
	await _save_screenshot(viewport, "%s/06b_encore_discard_selection.png" % output_dir)
	await _click_control(viewport, discard_choice, "%s Encore full-card choice" % viewport_size)
	_expect(pile_scrim != null and not pile_scrim.visible, "%s Clicking the full discard card should close Encore selection" % viewport_size)
	_expect(combat_engine.skill_was_used(instance.get("_combat_state") as Dictionary, "encore"), "%s Clicking the full discard card should spend Encore" % viewport_size)

func _populated_progression() -> Dictionary:
	var skill_ids: Array[String] = SkillTreeLibrary.repaired_selection(PROGRESSION_SKILLS, PROGRESSION_SKILLS.size(), PROGRESSION_SKILLS)
	_expect(skill_ids == PROGRESSION_SKILLS, "Visual progression fixture should retain its requested legal skill order")
	_expect(SkillTreeLibrary.selection_is_valid(skill_ids), "Visual progression fixture should be a legal level-%d tree with banked points" % PROGRESSION_LEVEL)
	var progression: Dictionary = ProgressionStore.default_data()
	progression["level"] = PROGRESSION_LEVEL
	progression["skill_ids"] = skill_ids
	progression["moltshards"] = 2
	return ProgressionStore.normalized_data(progression)

func _combat_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 6 else "stone")
		grid.append(row)
	return {
		"coord": Vector2i(1, 0),
		"name": "Hall of Choices",
		"depth": 4,
		"type": "combat",
		"element": "fire",
		"grid": grid,
		"player_start": Vector2i(2, 3),
		"enemies": [{
			"id": "enemy_1",
			"type": "crawler",
			"name": "Tunnel Crawler",
			"pos": Vector2i(6, 3),
			"hp": 60,
			"max_hp": 60,
			"base_initiative": 9,
		}],
		"traps": [],
		"loot": [{"pos": Vector2i(4, 2), "embers": 3}],
		"terrain": [],
	}

func _save_screenshot(viewport: SubViewport, output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should produce a non-empty screenshot" % output_path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == _active_screenshot_size, "%s should be exactly %s, got %s" % [output_path, _active_screenshot_size, image.get_size()])
	var error: Error = image.save_png(output_path)
	_expect(error == OK, "%s should save successfully" % output_path)

func _click_control(viewport: SubViewport, control: Control, label: String) -> void:
	if control == null or not control.is_visible_in_tree():
		_fail("%s should be visible before mouse input" % label)
		return
	var click_position: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = click_position
	motion.global_position = click_position
	viewport.push_input(motion, true)
	await process_frame
	_expect(viewport.gui_get_hovered_control() == control, "%s should own its visible card's mouse hit" % label)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = click_position
		event.global_position = click_position
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame
	await _settle()

func _assert_inside(control: Control, viewport_size: Vector2i, label: String, margin: float = 0.0) -> void:
	if control == null:
		_fail("%s should exist" % label)
		return
	var rect: Rect2 = control.get_global_rect()
	var safe_rect := Rect2(Vector2.ONE * margin, Vector2(viewport_size) - Vector2.ONE * margin * 2.0)
	_expect(rect.position.x >= safe_rect.position.x - 1.0, "%s should not clip left: %s" % [label, rect])
	_expect(rect.position.y >= safe_rect.position.y - 1.0, "%s should not clip top: %s" % [label, rect])
	_expect(rect.end.x <= safe_rect.end.x + 1.0, "%s should not clip right: %s" % [label, rect])
	_expect(rect.end.y <= safe_rect.end.y + 1.0, "%s should not clip bottom: %s" % [label, rect])

func _assert_skill_modal_contained(
	dialog: Control,
	tree: SkillTreeView,
	viewport_size: Vector2i,
	label: String,
	expected_title: String
) -> void:
	_assert_inside(dialog, viewport_size, label, 8.0)
	if dialog == null:
		return
	_expect(dialog.get_combined_minimum_size().y <= float(viewport_size.y) - 16.0, "%s content minimum should fit the proof viewport instead of pushing modal chrome offscreen" % label)
	var title_label: Label = _label_with_text(dialog, expected_title)
	var close_button: Button = _button_with_text(dialog, "X")
	_expect(title_label != null, "%s should retain its title" % label)
	_expect(close_button != null, "%s should retain its close action" % label)
	if title_label != null:
		_assert_inside(title_label, viewport_size, "%s title" % label, 8.0)
	if close_button != null:
		_assert_inside(close_button, viewport_size, "%s close action" % label, 8.0)
	if tree == null:
		return
	_assert_inside(tree, viewport_size, "%s tree" % label, 8.0)
	for control_name: String in [
		"SkillTreeGraphPanel",
		"SkillDetailPanel",
		"SkillDetailScroll",
		"SkillDetailAction",
	]:
		var control := tree.find_child(control_name, true, false) as Control
		_expect(control != null, "%s should retain %s" % [label, control_name])
		if control != null and control.is_visible_in_tree():
			_assert_inside(control, viewport_size, "%s %s" % [label, control_name], 8.0)
	var detail_scroll := tree.find_child("SkillDetailScroll", true, false) as ScrollContainer
	for control_name: String in [
		"SkillDetailStatus",
		"SkillDetailTitle",
		"SkillDetailDescription",
		"SkillDetailActivation",
		"SkillDetailRequirements",
		"SkillDetailUnlocks",
		"SkillDetailReason",
	]:
		_expect(tree.find_child(control_name, true, false) != null, "%s should retain scrollable %s" % [label, control_name])
	if detail_scroll != null:
		var detail_content := tree.find_child("SkillDetailContent", true, false) as Control
		if detail_content != null and detail_content.get_combined_minimum_size().y > detail_scroll.size.y + 1.0:
			_expect(detail_scroll.get_v_scroll_bar().visible and detail_scroll.get_v_scroll_bar().max_value > 0.0, "%s should expose scrolling when exact skill rules exceed the bounded detail pane" % label)

func _assert_tree_scroll_contract(tree: SkillTreeView, viewport_size: Vector2i, label: String) -> void:
	if tree == null:
		return
	var scroll := tree.find_child("SkillTreeScroll", true, false) as ScrollContainer
	_expect(scroll != null, "%s %s tree should retain its bounded scroll host" % [viewport_size, label])
	if scroll == null:
		return
	_expect(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "%s %s tree should allow horizontal inspection when the viewport cannot preserve readable lanes" % [viewport_size, label])
	_expect(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "%s %s tree should allow vertical inspection when the viewport cannot preserve readable tiers" % [viewport_size, label])
	_expect(tree.connection_arrowhead_count() == tree.connection_count(), "%s %s tree should draw one visible target arrowhead per prerequisite" % [viewport_size, label])
	_expect(tree.minimum_target_segment_length() >= 10.0, "%s %s tree should expose every incoming arrow outside its target shadow" % [viewport_size, label])
	if tree.graph_canvas_size().x > scroll.size.x + 2.0:
		_expect(scroll.get_h_scroll_bar().visible, "%s %s tree should reveal horizontal scrolling when the authored graph is wider than its host" % [viewport_size, label])
	if tree.graph_canvas_size().y > scroll.size.y + 2.0:
		_expect(scroll.get_v_scroll_bar().visible, "%s %s tree should reveal vertical scrolling when the authored graph is taller than its host" % [viewport_size, label])
	var graph_bounds := Rect2(Vector2.ZERO, tree.graph_canvas_size())
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var node: Button = tree.node_for_skill(skill_id)
		_expect(node != null and graph_bounds.encloses(Rect2(node.position, node.size)), "%s %s %s should remain inside the authored graph canvas" % [viewport_size, label, skill_id])

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	await process_frame

func _requested_configs() -> Array[Dictionary]:
	var defaults: Array[Dictionary] = [
		{"size": Vector2i(1920, 1080), "scale": 1.0},
		{"size": Vector2i(1280, 720), "scale": 1.0},
		{"size": Vector2i(1280, 800), "scale": 1.0},
		{"size": Vector2i(960, 540), "scale": 1.0},
		{"size": Vector2i(1280, 720), "scale": 1.25},
	]
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var config_index: int = arguments.find("--config")
	if config_index < 0 or config_index + 1 >= arguments.size():
		return defaults
	var specification: String = arguments[config_index + 1].strip_edges().to_lower()
	var scale_parts: PackedStringArray = specification.split("@", false, 1)
	var size_parts: PackedStringArray = scale_parts[0].split("x", false, 1)
	if size_parts.size() != 2:
		_fail("Invalid --config size: %s" % specification)
		return []
	var width: int = int(size_parts[0])
	var height: int = int(size_parts[1])
	var scale_percent: int = int(scale_parts[1]) if scale_parts.size() == 2 else 100
	if width <= 0 or height <= 0 or scale_percent <= 0:
		_fail("Invalid --config value: %s" % specification)
		return []
	return [{"size": Vector2i(width, height), "scale": float(scale_percent) / 100.0}]

func _button_with_text(node: Node, expected: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == expected:
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button_with_text(child, expected)
		if found != null:
			return found
	return null

func _visible_button_with_text(node: Node, expected: String) -> Button:
	var button: Button = _button_with_text(node, expected)
	return button if button != null and button.is_visible_in_tree() else null

func _button_beginning_with(node: Node, prefix: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text.begins_with(prefix):
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button_beginning_with(child, prefix)
		if found != null:
			return found
	return null

func _label_with_text(node: Node, expected: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text == expected:
		return node as Label
	for child: Node in node.get_children():
		var found: Label = _label_with_text(child, expected)
		if found != null:
			return found
	return null

func _label_containing(node: Node, fragment: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text.contains(fragment):
		return node as Label
	for child: Node in node.get_children():
		var found: Label = _label_containing(child, fragment)
		if found != null:
			return found
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
