extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

const OUTPUT_DIR: String = "user://pre_battle_threat_inspection_probe_v1"
const INVALID_COORD: Vector2i = Vector2i(999, 999)

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_pre_battle_preview_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_pre_battle_preview_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_loadout_refresh_and_inspections()
	await _capture_enemy_count_layouts()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_loadout_refresh_and_inspections() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for pre-battle preview probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var probe_run_engine := RunEngine.new()
	var run_state: Dictionary = _run_with_available_combat(probe_run_engine)
	var equipment_inventory: Array = (run_state.get("equipment_inventory", []) as Array).duplicate()
	if not equipment_inventory.has("iron_cleaver"):
		equipment_inventory.append("iron_cleaver")
	run_state["equipment_inventory"] = equipment_inventory
	var magic_inventory: Array = (run_state.get("magic_inventory", []) as Array).duplicate()
	if not magic_inventory.has("bone_dart"):
		magic_inventory.append("bone_dart")
	run_state["magic_inventory"] = magic_inventory
	var combat_coord: Vector2i = _first_available_combat_coord(probe_run_engine, run_state)
	if combat_coord == INVALID_COORD:
		_fail("Probe run should include an available combat room")
		instance.queue_free()
		await process_frame
		return

	instance.call("_load_run_state", run_state)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	await instance.call("_on_map_view_room_selected", combat_coord)
	await process_frame
	await create_timer(0.30).timeout
	await process_frame

	var scrim: Control = instance.get("_pre_battle_scrim") as Control
	var panel: Control = instance.get("_pre_battle_panel") as Control
	if scrim == null or not scrim.visible:
		_fail("Pre-battle preview should be visible")
	elif panel == null:
		_fail("Pre-battle preview panel should exist")
	else:
		if panel.find_child("PreBattleEnemyCard", true, false) == null:
			_fail("Pre-battle preview should render enemy cards")
		if panel.find_child("PreBattleDeckBadge", true, false) == null:
			_fail("Pre-battle preview should render deck badges")
		if panel.find_child("PreBattleEquipmentRow", true, false) == null:
			_fail("Pre-battle preview should render equipment icons")
		if panel.find_child("PreBattleEnemyHealth", true, false) == null:
			_fail("Pre-battle preview should render enemy health")
		if panel.find_child("PreBattleThreatSummary", true, false) == null:
			_fail("Pre-battle preview should render known threat summaries")
		if panel.find_child("PreBattleAttunedRow", true, false) == null:
			_fail("Pre-battle preview should render attuned magic separately")
		if panel.find_child("PreBattleIntentRow", true, false) != null:
			_fail("Pre-battle preview should not render enemy intent icons")
		if panel.find_child("PreBattleCloseButton", true, false) != null:
			_fail("Pre-battle preview should not offer a back-out button")

	var paused_state: Dictionary = instance.get("_run_state")
	if str(paused_state.get("mode", "")) != RunEngine.MODE_PRE_BATTLE:
		_fail("Pre-battle preview should commit to pre-battle mode before Start")
	if paused_state.get("current_room", INVALID_COORD) != combat_coord:
		_fail("Pre-battle preview should already be in the selected room")
	if not (paused_state.get("combat_state", {}) as Dictionary).is_empty():
		_fail("Pre-battle preview should not create the real combat state before Start")
	var natural_enemy_flow: HFlowContainer = panel.find_child("PreBattleEnemyFlow", true, false) as HFlowContainer if panel != null else null
	if natural_enemy_flow == null or natural_enemy_flow.get_child_count() != 3:
		_fail("Deterministic loadout proof should supply the composed three-enemy layout")
	await _save_root_screenshot("%s/enemy_layout_3_loadout_before_swaps_v1.png" % OUTPUT_DIR)

	var enemy_card: Control = panel.find_child("PreBattleEnemyCard", true, false) as Control if panel != null else null
	if enemy_card == null:
		_fail("Enemy inspection proof needs an enemy card")
	else:
		var native_tooltip_popup := PopupPanel.new()
		native_tooltip_popup.name = "SimulatedNativeEnemyTooltip"
		native_tooltip_popup.theme_type_variation = &"TooltipPanel"
		enemy_card.add_child(native_tooltip_popup)
		var hover_inspection: Control = enemy_card.call("_make_custom_tooltip", enemy_card.tooltip_text) as Control
		native_tooltip_popup.add_child(hover_inspection)
		native_tooltip_popup.popup(Rect2i(Vector2i(960, 520), Vector2i(620, 430)))
		await process_frame
		if not native_tooltip_popup.visible:
			_fail("Enemy inspection proof should begin with a visible native-style hover popup")
		_click_control(enemy_card)
		await process_frame
		await process_frame
		await create_timer(0.15).timeout
		var pinned_enemy: Control = instance.find_child("PinnedPreBattleInspection", true, false) as Control
		if pinned_enemy == null or str(pinned_enemy.get_meta("inspection_kind", "")) != "enemy":
			_fail("Enemy card click should pin known move inspection")
		if is_instance_valid(native_tooltip_popup):
			_fail("Focused enemy inspection should dismiss an already-visible hover popup")
		if pinned_enemy != null:
			var hp_label: Label = pinned_enemy.find_child("PreBattleEnemyHpLine", true, false) as Label
			var initiative_label: Label = pinned_enemy.find_child("PreBattleEnemyInitiativeLine", true, false) as Label
			var close_button: Button = pinned_enemy.find_child("PreBattleInspectionCloseButton", true, false) as Button
			if hp_label == null or not hp_label.get_theme_color("font_color").is_equal_approx(Color("f08a7a")):
				_fail("Focused enemy HP line should use the dedicated red treatment")
			if initiative_label == null or not initiative_label.get_theme_color("font_color").is_equal_approx(Color("8ec5ff")):
				_fail("Focused enemy initiative line should use the dedicated blue treatment")
			if _labels_text(pinned_enemy).contains("Known repertoire") or _labels_text(pinned_enemy).contains("next move concealed"):
				_fail("Focused enemy inspection should remove the redundant repertoire/concealment line")
			var move_icons: PackedStringArray = []
			for icon_var: Variant in pinned_enemy.find_children("PreBattleKnownMoveIcon", "TextureRect", true, false):
				move_icons.append(str((icon_var as TextureRect).get_meta("icon_key", "")))
			if move_icons != PackedStringArray(["melee", "block", "melee"]):
				_fail("Compound Warden moves should use melee/block semantics instead of their incidental movement icons: %s" % str(move_icons))
			if close_button == null or not close_button.visible or close_button.text != "X":
				_fail("Focused enemy inspection should expose a visible dedicated X close button")
		await _save_root_screenshot("%s/expanded_enemy_known_moves_v2.png" % OUTPUT_DIR)
		var dismissal_button: Button = pinned_enemy.find_child("PreBattleInspectionCloseButton", true, false) as Button if pinned_enemy != null else null
		if dismissal_button != null:
			dismissal_button.emit_signal("pressed")
		else:
			instance.call("_close_pinned_tooltip")
		await process_frame

	instance.call("_on_pre_battle_equip_pressed")
	await process_frame
	await instance.call("_equip_equipment_from_overlay", "iron_cleaver")
	instance.call("_close_card_upgrade_overlay")
	await process_frame
	await process_frame
	panel = instance.get("_pre_battle_panel") as Control
	if _control_with_meta(panel, "equipment_id", "iron_cleaver") == null:
		_fail("Returning from equipment swap should refresh the equipped weapon chip")
	await _save_root_screenshot("%s/loadout_after_equipment_swap_v1.png" % OUTPUT_DIR)
	await _save_root_screenshot("%s/loadout_before_attunement_swap_v1.png" % OUTPUT_DIR)

	instance.call("_on_pre_battle_equip_pressed")
	await process_frame
	instance.call("_switch_character_overlay_mode", "magic")
	await process_frame
	var reserve_magic: Array = (instance.get("_run_state") as Dictionary).get("magic_inventory", []) as Array
	var bone_dart_index: int = reserve_magic.find("bone_dart")
	if bone_dart_index < 0:
		_fail("Attunement proof needs Bone Dart in reserve magic")
	else:
		await instance.call("_swap_magic_from_overlay", bone_dart_index, 0)
	instance.call("_close_card_upgrade_overlay")
	await process_frame
	await process_frame
	panel = instance.get("_pre_battle_panel") as Control
	var attuned_bone_dart: Control = _control_with_meta(panel, "card_id", "bone_dart", "attuned")
	if attuned_bone_dart == null:
		_fail("Returning from attunement swap should refresh the active spell badge")
	await _save_root_screenshot("%s/loadout_after_attunement_swap_v1.png" % OUTPUT_DIR)

	var equipped_cleaver: Control = _control_with_meta(panel, "equipment_id", "iron_cleaver")
	if equipped_cleaver != null:
		_click_control(equipped_cleaver)
		await process_frame
		await create_timer(0.15).timeout
		await _save_root_screenshot("%s/expanded_equipment_after_swap_v1.png" % OUTPUT_DIR)
		instance.call("_close_pinned_tooltip")
		await process_frame
	if attuned_bone_dart != null:
		_click_control(attuned_bone_dart)
		await process_frame
		await create_timer(0.15).timeout
		await _save_root_screenshot("%s/expanded_attuned_magic_after_swap_v1.png" % OUTPUT_DIR)
		instance.call("_close_pinned_tooltip")
		await process_frame
	var active_deck_card: Control = _first_control_with_source(panel, "deck")
	if active_deck_card != null:
		_click_control(active_deck_card)
		await process_frame
		await create_timer(0.15).timeout
		await _save_root_screenshot("%s/expanded_active_deck_card_v1.png" % OUTPUT_DIR)
		instance.call("_close_pinned_tooltip")
		await process_frame
	var final_state: Dictionary = instance.get("_run_state")
	if str(final_state.get("mode", "")) != RunEngine.MODE_PRE_BATTLE:
		_fail("Loadout inspection and swaps should preserve committed pre-battle mode")
	if not (instance.get("_exit_destinations_by_tile") as Dictionary).is_empty():
		_fail("Loadout inspection should not reveal exits")
	await _capture_all_enemy_portraits(instance)
	instance.queue_free()
	await process_frame

func _capture_enemy_count_layouts() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for enemy-count pre-battle proof")
		return
	var probe_run_engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.default_data()
	var run_state: Dictionary = probe_run_engine.create_new_run(7262026, progression)
	var combat_coord: Vector2i = _first_room_coord_with_min_enemies(probe_run_engine, run_state, 5)
	if combat_coord == INVALID_COORD:
		_fail("Probe should find a generated room with at least five enemies")
		return
	run_state = _pre_battle_state_for_room(probe_run_engine, run_state, combat_coord)
	for enemy_count: int in [1, 3, 5]:
		var instance: Node = packed.instantiate()
		root.add_child(instance)
		await process_frame
		await process_frame
		instance.call("_load_run_state", run_state.duplicate(true))
		await process_frame
		await process_frame
		instance.call("_close_dialogue")
		await create_timer(0.50).timeout
		await process_frame
		var scrim: Control = instance.get("_pre_battle_scrim") as Control
		var panel: Control = instance.get("_pre_battle_panel") as Control
		if scrim == null or not scrim.visible or panel == null:
			_fail("%d-enemy pre-battle preview should be visible" % enemy_count)
			instance.queue_free()
			await process_frame
			continue
		var preview_state: Dictionary = (instance.get("_pre_battle_preview_run_state") as Dictionary).duplicate(true)
		var original_combat_state: Dictionary = (preview_state.get("combat_state", {}) as Dictionary).duplicate(true)
		var original_enemies: Array = (original_combat_state.get("enemies", []) as Array).duplicate(true)
		var layout_enemies: Array = []
		for index: int in range(mini(enemy_count, original_enemies.size())):
			layout_enemies.append((original_enemies[index] as Dictionary).duplicate(true))
		var layout_combat_state: Dictionary = original_combat_state.duplicate(true)
		layout_combat_state["enemies"] = layout_enemies
		var layout_preview_state: Dictionary = preview_state.duplicate(true)
		layout_preview_state["combat_state"] = layout_combat_state
		if enemy_count < 5:
			instance.set("_pre_battle_preview_run_state", layout_preview_state)
			instance.call("_rebuild_pre_battle_overlay")
			await create_timer(0.40).timeout
			await process_frame
		var flow: HFlowContainer = panel.find_child("PreBattleEnemyFlow", true, false) as HFlowContainer
		if flow == null or flow.get_child_count() != enemy_count:
			_fail("%d-enemy pre-battle proof should render exactly %d cards" % [enemy_count, enemy_count])
		elif flow.alignment != FlowContainer.ALIGNMENT_CENTER:
			_fail("%d-enemy pre-battle proof should center incomplete rows" % enemy_count)
		else:
			for index: int in range(flow.get_child_count()):
				var card: Control = flow.get_child(index) as Control
				if card == null or card.find_child("PreBattleThreatSummary", true, false) == null:
					_fail("%d-enemy pre-battle proof should retain threat summaries" % enemy_count)
					break
				if enemy_count == 5 and (card.custom_minimum_size.x > 200.0 or card.custom_minimum_size.y > 154.0):
					_fail("Five-enemy pre-battle preview should use compact enemy cards")
					break
		if enemy_count == 5:
			var umbra_label: Label = panel.find_child("PreBattleUmbraLabel", true, false) as Label
			if umbra_label == null or not umbra_label.get_theme_color("font_color").is_equal_approx(Color("c78bea")):
				_fail("Elemental pre-battle header should keep Umbra purple")
			if _labels_text(panel).contains("Vision"):
				_fail("Elemental pre-battle header should omit Vision X text")
		var screenshot_path: String = "%s/enemy_layout_%d_v1.png" % [OUTPUT_DIR, enemy_count]
		if enemy_count == 3:
			screenshot_path = "%s/_synthetic_three_buffer_warmup.png" % OUTPUT_DIR
		await _save_root_screenshot(screenshot_path)
		if enemy_count == 3:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(screenshot_path))
		instance.queue_free()
		await process_frame
		await process_frame

func _capture_all_enemy_portraits(instance: Node) -> void:
	var ui_root: Control = instance.get("ui_root") as Control
	if ui_root == null:
		_fail("All-enemy portrait proof needs the run UI root")
		return
	var proof_scrim := ColorRect.new()
	proof_scrim.name = "AllEnemyPortraitProof"
	proof_scrim.color = Color(0.012, 0.009, 0.008, 0.98)
	proof_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	proof_scrim.z_index = 1500
	proof_scrim.z_as_relative = false
	proof_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(proof_scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	proof_scrim.add_child(center)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	center.add_child(content)
	var title := Label.new()
	title.text = "ALL ENEMY PORTRAITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("fff0ce"))
	content.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	var enemy_types: Array = GameData.enemies().keys()
	enemy_types.sort()
	for enemy_type_var: Variant in enemy_types:
		var enemy_type: String = str(enemy_type_var)
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		var max_hp: int = int(enemy_def.get("max_hp", 1))
		var card: Control = instance.call("_build_pre_battle_enemy_card", {
			"type": enemy_type,
			"hp": max_hp,
			"max_hp": max_hp
		}, Color(str(enemy_def.get("accent", "#d8b06d"))), Vector2(198.0, 152.0)) as Control
		grid.add_child(card)
	await process_frame
	await process_frame
	await _save_root_screenshot("%s/all_enemy_portraits_centered_v2.png" % OUTPUT_DIR)
	proof_scrim.queue_free()
	await process_frame

func _run_with_available_combat(probe_run_engine: RunEngine) -> Dictionary:
	var progression: Dictionary = ProgressionStore.default_data()
	for seed: int in range(1, 120):
		var state: Dictionary = probe_run_engine.create_new_run(seed, progression)
		if _first_available_combat_coord(probe_run_engine, state) != INVALID_COORD:
			return state
	return {}

func _first_available_combat_coord(probe_run_engine: RunEngine, run_state: Dictionary) -> Vector2i:
	if run_state.is_empty():
		return INVALID_COORD
	for coord_var: Variant in probe_run_engine.available_moves(run_state):
		if typeof(coord_var) != TYPE_VECTOR2I:
			continue
		var coord: Vector2i = coord_var
		var preview_state: Dictionary = probe_run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat" and not (preview_state.get("combat_state", {}) as Dictionary).is_empty():
			return coord
	return INVALID_COORD

func _first_room_coord_with_min_enemies(probe_run_engine: RunEngine, run_state: Dictionary, min_enemies: int) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				var room: Dictionary = probe_run_engine.room_metadata(run_state, coord)
				if str(room.get("type", "")) not in ["combat", "boss"]:
					continue
				var layout: Dictionary = probe_run_engine.call("_combat_layout_for_room", room, _travel_dir_for_coord(coord), run_state)
				var enemies: Array = layout.get("enemies", [])
				if enemies.size() >= min_enemies:
					return coord
	return INVALID_COORD

func _pre_battle_state_for_room(probe_run_engine: RunEngine, run_state: Dictionary, coord: Vector2i) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	var travel_dir: Vector2i = _travel_dir_for_coord(coord)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = RunEngine.MODE_PRE_BATTLE
	state["combat_state"] = {}
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = travel_dir
	return state

func _travel_dir_for_coord(coord: Vector2i) -> Vector2i:
	if coord == Vector2i.ZERO:
		return Vector2i(1, 0)
	if absi(coord.x) >= absi(coord.y) and coord.x != 0:
		return Vector2i(1, 0) if coord.x > 0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if coord.y > 0 else Vector2i(0, -1)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _click_control(control: Control) -> void:
	if control == null:
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	control.call("_gui_input", click)

func _control_with_meta(node: Node, meta_key: String, expected_value: String, source_kind: String = "") -> Control:
	if node == null:
		return null
	if node is Control and str(node.get_meta(meta_key, "")) == expected_value:
		if source_kind.is_empty() or str(node.get_meta("source_kind", "")) == source_kind:
			return node as Control
	for child: Node in node.get_children():
		var match_control: Control = _control_with_meta(child, meta_key, expected_value, source_kind)
		if match_control != null:
			return match_control
	return null

func _first_control_with_source(node: Node, source_kind: String) -> Control:
	if node == null:
		return null
	if node is Control and str(node.get_meta("source_kind", "")) == source_kind:
		return node as Control
	for child: Node in node.get_children():
		var match_control: Control = _first_control_with_source(child, source_kind)
		if match_control != null:
			return match_control
	return null

func _labels_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for child_var: Variant in node.find_children("*", "Label", true, false):
		parts.append((child_var as Label).text)
	return "\n".join(parts)

func _save_root_screenshot(output_path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	_clear_probe_output_absolute(absolute_dir)

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
