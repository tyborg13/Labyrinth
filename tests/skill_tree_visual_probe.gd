extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")

const OUTPUT_DIR: String = "user://probes/skill_tree_progression"
const STORAGE_PATH: String = "user://skill_tree_visual_progression.json"
const RUN_STORAGE_PATH: String = "user://skill_tree_visual_run.save"
const PROGRESSION_LEVEL: int = 11
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
		for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			await _capture_resolution(packed, viewport_size)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("SKILL TREE VISUAL PROBE: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("SKILL TREE VISUAL PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)

func _capture_resolution(packed: PackedScene, viewport_size: Vector2i) -> void:
	var progression: Dictionary = _populated_progression()
	_expect(ProgressionStore.save_data(progression), "%s progression fixture should save" % viewport_size)
	var viewport := SubViewport.new()
	viewport.name = "SkillProgressionProof_%dx%d" % [viewport_size.x, viewport_size.y]
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(81173 + viewport_size.x, progression)
	instance.set("_progression", progression)
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	await _settle()
	_expect(instance.get_viewport().get_visible_rect().size == Vector2(viewport_size), "%s run scene should use the exact proof viewport" % viewport_size)
	var output_dir: String = "%s/%dx%d" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await _capture_skills_tree(instance, viewport, viewport_size, output_dir)
	await _capture_respec_draft(instance, viewport, viewport_size, output_dir)
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
	if tree != null:
		tree.focus_skill("prismatic_instinct")
		var prismatic_links: Array[String] = tree.highlighted_connection_pairs()
		_expect(prismatic_links.size() == 3, "%s Skills tree should emphasize only Prismatic Instinct's two parents and direct unlock" % viewport_size)
		_expect(prismatic_links.has("quick_wits>prismatic_instinct"), "%s Skills tree should emphasize Prismatic Instinct's Quick Wits parent" % viewport_size)
		_expect(prismatic_links.has("discerning_eye>prismatic_instinct"), "%s Skills tree should emphasize Prismatic Instinct's Discerning Eye parent" % viewport_size)
		_expect(prismatic_links.has("prismatic_instinct>confluence"), "%s Skills tree should emphasize Prismatic Instinct's Confluence unlock" % viewport_size)
	_assert_tree_scroll_contract(tree, viewport_size, "Skills")
	_expect(_label_containing(dialog, "MOLTSHARDS 2") != null, "%s Skills dialog should show two Moltshards" % viewport_size)
	_expect(_button_with_text(dialog, "Begin Respec") != null, "%s Skills dialog should expose the respec command" % viewport_size)
	_assert_inside(dialog, viewport_size, "%s Skills dialog" % viewport_size, 8.0)
	await _save_screenshot(viewport, "%s/01_skills_tree.png" % output_dir, viewport_size)

func _capture_respec_draft(instance: Node, viewport: SubViewport, viewport_size: Vector2i, output_dir: String) -> void:
	instance.call("_begin_skill_respec")
	await _settle()
	var tree := instance.get("_skill_tree_view") as SkillTreeView
	_expect(tree != null and tree.mode() == SkillTreeView.MODE_RESPEC, "%s Respec should open the shared tree in draft mode" % viewport_size)
	if tree != null:
		_expect(tree.pending_skill_ids().is_empty(), "%s Respec should begin with an empty replacement build" % viewport_size)
		_expect(tree.points_remaining() == 10, "%s Respec should refund all ten earned points" % viewport_size)
		_expect(tree.focused_skill_id() == "quick_wits", "%s Empty respec should automatically focus its first available root" % viewport_size)
		_expect(tree.detail_title_text() == "Quick Wits" and tree.detail_action_is_enabled(), "%s Empty respec's default focus should be immediately actionable" % viewport_size)
		_expect(tree.status_for_skill("quick_wits") == SkillTreeView.STATE_AVAILABLE, "%s Former skills should return to the available pool" % viewport_size)
		_assert_tree_scroll_contract(tree, viewport_size, "Respec")
	var dialog := instance.get("_upgrade_dialog") as Control
	_assert_inside(dialog, viewport_size, "%s Respec dialog" % viewport_size, 8.0)
	await _save_screenshot(viewport, "%s/02_respec_empty.png" % output_dir, viewport_size)

	var alternate_preference: Array = [
		"measured_breath",
		"ghost_stride",
		"discerning_eye",
		"carry_the_guard",
		"pain_remembers",
		"sure_footed",
		"afterimage",
		"deferred_choice",
		"plunderers_step",
		"living_shadow",
	]
	var alternate: Array[String] = SkillTreeLibrary.repaired_selection([], 10, alternate_preference)
	_expect(alternate != PROGRESSION_SKILLS, "%s Respec visual fixture should rebuild a genuinely different tree" % viewport_size)
	if tree != null:
		for skill_id: String in alternate:
			tree.focus_skill(skill_id)
			_expect(tree.detail_action_is_enabled(), "%s Respec should allocate %s in prerequisite order" % [viewport_size, skill_id])
			tree.activate_focused_skill()
		tree.focus_skill("plunderers_step")
		await _settle()
		_expect(tree.pending_skill_ids() == alternate, "%s Respec should hold the complete rebuilt draft" % viewport_size)
		_expect(tree.points_remaining() == 0, "%s Complete rebuilt draft should spend every refunded point" % viewport_size)
		_expect(tree.confirm_is_enabled(), "%s Different complete rebuilt draft should be confirmable" % viewport_size)
		var plunderer_links: Array[String] = tree.highlighted_connection_pairs()
		_expect(plunderer_links.size() == 2, "%s Rebuilt draft should emphasize only Plunderer's Step's two parent links" % viewport_size)
		_expect(plunderer_links.has("ghost_stride>plunderers_step"), "%s Rebuilt draft should emphasize Plunderer's Step's Ghost Stride parent" % viewport_size)
		_expect(plunderer_links.has("discerning_eye>plunderers_step"), "%s Rebuilt draft should emphasize Plunderer's Step's Discerning Eye parent" % viewport_size)
	await _save_screenshot(viewport, "%s/03_respec_complete.png" % output_dir, viewport_size)
	instance.call("_on_skill_tree_cancel_requested")
	await _settle()
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
	deck["hand"] = ["quick_stab", "sidestep_slash", "spark_dart", "guarded_step"]
	deck["discard"] = ["bone_dart"]
	deck["draw"] = ["patch_up", "frostbolt", "ember_jab"]
	combat_state["deck"] = deck
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
	for skill_name: String in ["Quick Wits", "Prismatic Instinct", "Encore"]:
		var button: Button = _visible_button_with_text(choice_overlay, skill_name)
		if button == null:
			button = _visible_button_with_text(choice_bar, skill_name)
		_expect(button != null, "%s Combat HUD should expose ready %s control" % [viewport_size, skill_name])
	await _save_screenshot(viewport, "%s/04_combat_skill_controls.png" % output_dir, viewport_size)

	instance.call("_toggle_skill_status_popover")
	await _settle()
	var popover := instance.get("_skill_status_popover") as Control
	_expect(popover != null and popover.visible, "%s Skill sigil should open its status popover" % viewport_size)
	_expect(_label_with_text(popover, "READY") != null, "%s Skill popover should show at least one ready ability" % viewport_size)
	_expect(_label_with_text(popover, "Quick Wits") != null, "%s Skill popover should list Quick Wits" % viewport_size)
	_expect(_label_with_text(popover, "Discerning Eye") != null, "%s Skill popover should list Discerning Eye" % viewport_size)
	_assert_inside(popover, viewport_size, "%s Skill status popover" % viewport_size, 8.0)
	await _save_screenshot(viewport, "%s/05_combat_skill_popover.png" % output_dir, viewport_size)

	instance.call("_close_skill_status_popover")
	instance.call("_on_combat_skill_pressed", "quick_wits")
	await _settle()
	var choice_scrim := instance.get("_skill_choice_scrim") as Control
	var choice_dialog := instance.get("_skill_choice_dialog") as Control
	_expect(choice_scrim != null and choice_scrim.visible, "%s Quick Wits should open the manual skill dialog" % viewport_size)
	_expect(_label_with_text(choice_scrim, "Quick Wits") != null, "%s Manual skill dialog should identify Quick Wits" % viewport_size)
	_expect(_button_beginning_with(choice_scrim, "Discard ") != null, "%s Manual skill dialog should offer card choices" % viewport_size)
	_assert_inside(choice_dialog, viewport_size, "%s Manual skill dialog" % viewport_size, 8.0)
	await _save_screenshot(viewport, "%s/06_quick_wits_choice.png" % output_dir, viewport_size)
	instance.call("_close_skill_choice_dialog")

func _populated_progression() -> Dictionary:
	var skill_ids: Array[String] = SkillTreeLibrary.repaired_selection(PROGRESSION_SKILLS, PROGRESSION_SKILLS.size(), PROGRESSION_SKILLS)
	_expect(skill_ids == PROGRESSION_SKILLS, "Visual progression fixture should retain its requested legal skill order")
	_expect(SkillTreeLibrary.selection_is_valid(skill_ids, PROGRESSION_LEVEL - 1), "Visual progression fixture should be a legal level-%d tree" % PROGRESSION_LEVEL)
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

func _save_screenshot(viewport: SubViewport, output_path: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should produce a non-empty screenshot" % output_path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s should be exactly %s, got %s" % [output_path, expected_size, image.get_size()])
	var error: Error = image.save_png(output_path)
	_expect(error == OK, "%s should save successfully" % output_path)

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

func _assert_tree_scroll_contract(tree: SkillTreeView, viewport_size: Vector2i, label: String) -> void:
	if tree == null:
		return
	var scroll := tree.find_child("SkillTreeScroll", true, false) as ScrollContainer
	_expect(scroll != null, "%s %s tree should retain its bounded scroll host" % [viewport_size, label])
	if scroll == null:
		return
	_expect(not scroll.get_h_scroll_bar().visible, "%s %s tree should keep all four branches visible without horizontal scrolling" % [viewport_size, label])
	_expect(tree.graph_canvas_size().x <= scroll.size.x + 2.0, "%s %s graph canvas should remain horizontally bounded" % [viewport_size, label])

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	await process_frame

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
