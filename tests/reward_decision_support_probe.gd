extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const PostCombatRewardSequence = preload("res://scripts/post_combat_reward_sequence.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const OUTPUT_DIR: String = "user://reward_composition_v2_proof"
const OFFERED_CARDS: Array[String] = ["spark_dart", "frostbolt", "firebrand_volley"]
const OFFERED_RELICS: Array[String] = ["iron_lung", "ember_lens", "pilgrim_boots"]
const OWNED_CARD_ID: String = "spark_dart"
const NEW_CARD_ID: String = "frostbolt"
const PROOF_VERSION: String = "v3"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_reward_composition_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_reward_composition_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_reward_composition_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	_clear_probe_output(OUTPUT_DIR)
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Reward composition proof must run with a real display renderer")
	else:
		await _capture_configuration(Vector2i(1920, 1080), 1.00)
	var defaults: Dictionary = SettingsStore.default_settings()
	SettingsStore.save_settings(defaults)
	SettingsStore.apply_settings(defaults, root, false)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_configuration(resolution: Vector2i, ui_scale: float) -> void:
	await _configure_window(resolution, ui_scale)
	var output_dir: String = "%s/%dx%d_ui%d" % [
		OUTPUT_DIR,
		resolution.x,
		resolution.y,
		roundi(ui_scale * 100.0)
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for reward composition proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()

	var injured_reward_state: Dictionary = _reward_state(false)
	await _show_state(instance, injured_reward_state)
	var reward_parts: Dictionary = _assert_reward_layout(instance, resolution, ui_scale, false)
	_assert_persistent_combat_board(instance, injured_reward_state, resolution, ui_scale)
	await _capture_reward_sequence_states(instance, output_dir, resolution)
	# The sequence proof intentionally rebuilds the offer to exercise the real
	# prepared/revealed tree, so reacquire live focus targets afterward.
	reward_parts = _assert_reward_layout(instance, resolution, ui_scale, false)
	await _save_root_screenshot(
		"%s/card_reward_settled_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	await _capture_card_focus(
		reward_parts.get("new_card") as Control,
		"%s/card_reward_focused_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	await _capture_button_focus(
		reward_parts.get("recover_button") as Button,
		"%s/card_reward_recover_focused_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	await _capture_reduced_motion_reward(instance, injured_reward_state, output_dir, resolution)

	await _show_state(instance, _reward_state(true))
	_assert_reward_layout(instance, resolution, ui_scale, true)
	await _save_root_screenshot(
		"%s/card_reward_full_health_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)

	await _show_state(instance, _reward_state(false, true))
	_assert_reward_layout(instance, resolution, ui_scale, false, true)
	await _save_root_screenshot(
		"%s/card_reward_reroll_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)

	await _show_state(instance, _treasure_state())
	var relic_parts: Dictionary = _assert_relic_layout(instance, resolution, ui_scale)
	await _save_root_screenshot(
		"%s/relic_reward_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	await _capture_relic_focus(
		relic_parts.get("middle_relic") as Control,
		"%s/relic_reward_focused_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)

	instance.queue_free()
	await _settle()

func _configure_window(resolution: Vector2i, ui_scale: float) -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = resolution
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = resolution
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _settle()
	root.size = resolution
	await _settle()
	print("Reward proof viewport=%s window=%s target=%s ui=%d" % [
		root.get_viewport().get_visible_rect().size,
		root.size,
		resolution,
		roundi(ui_scale * 100.0)
	])

func _reward_state(full_health: bool, with_reroll: bool = false) -> Dictionary:
	var engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.default_data()
	if with_reroll:
		progression["level"] = 3
		progression["skill_ids"] = ["quick_wits", "discerning_eye"]
		progression = ProgressionStore.normalized_data(progression)
	var state: Dictionary = engine.create_new_run(7319, progression)
	var combat_coord: Vector2i = _first_available_room_coord_of_type(engine, state, "combat")
	if combat_coord == Vector2i.ZERO:
		_fail("Reward proof run should expose an available combat room")
		return state
	state = engine.move_to_room(state, combat_coord)
	if str(state.get("mode", "")) == RunEngine.MODE_PRE_BATTLE:
		state = engine.begin_pre_battle_combat(state)
	if str(state.get("mode", "")) != "combat":
		_fail("Reward proof run should enter combat before constructing its reward")
		return state
	state = engine.finish_combat(state, _victory_combat_state(state.get("combat_state", {}) as Dictionary))
	if str(state.get("mode", "")) != "reward":
		_fail("Reward proof combat should resolve into a card reward")
		return state
	state["player_hp"] = 24 if full_health else 12
	state["player_max_hp"] = 24
	state["attuned_magic_cards"] = ["pale_spark", "dull_bolt", "waning_pulse", "chain_bolt"]
	state["magic_inventory"] = [OWNED_CARD_ID]
	state["reward_cards"] = [OWNED_CARD_ID]
	var pending_reward: Dictionary = (state.get("pending_reward", {}) as Dictionary).duplicate(true)
	pending_reward["cards"] = OFFERED_CARDS.duplicate()
	pending_reward["heal_amount"] = RunEngine.REWARD_HEAL
	pending_reward["ember_amount"] = 0
	# Static proof stages are authored explicitly below so loading the state does
	# not race the production intro sequence.
	pending_reward["intro_pending"] = false
	state["pending_reward"] = pending_reward
	return state

func _victory_combat_state(combat_state: Dictionary) -> Dictionary:
	var victory: Dictionary = combat_state.duplicate(true)
	var objective: Dictionary = victory.get("objective", {}) as Dictionary
	var objective_type: String = str(objective.get("type", CombatObjectiveRules.KILL_ALL))
	if objective_type == CombatObjectiveRules.REACH_EXIT:
		var target_tiles: Array[Vector2i] = CombatObjectiveRules.exit_target_tiles(objective)
		if not target_tiles.is_empty():
			var player: Dictionary = (victory.get("player", {}) as Dictionary).duplicate(true)
			player["pos"] = target_tiles[0]
			victory["player"] = player
		return victory
	if objective_type == CombatObjectiveRules.SURVIVE:
		victory["initiative_clock"] = int(objective.get("target_clock", victory.get("initiative_clock", 0)))
		return victory
	var enemies: Array = (victory.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	victory["enemies"] = enemies
	return victory

func _treasure_state() -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(7321, ProgressionStore.default_data())
	var treasure_coord: Vector2i = _first_room_coord_of_type(engine, state, "treasure")
	if treasure_coord == Vector2i.ZERO:
		_fail("Reward proof run should include a treasure room")
		return state
	var room: Dictionary = engine.room_metadata(state, treasure_coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["%d,%d" % [treasure_coord.x, treasure_coord.y]] = room
	state["rooms"] = rooms
	state["current_room"] = treasure_coord
	state["current_room_layout"] = engine.call(
		"_display_layout_for_room",
		int(state.get("seed", 0)),
		room,
		Vector2i(1, 0)
	)
	state["mode"] = "treasure"
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = OFFERED_RELICS.duplicate()
	return state

func _show_state(instance: Node, state: Dictionary) -> void:
	root.gui_release_focus()
	root.warp_mouse(root.get_viewport().get_visible_rect().size - Vector2(2.0, 2.0))
	instance.call("_load_run_state", state)
	await _settle()
	var settled_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	settled_state["notice"] = ""
	settled_state["grimoire_notice"] = ""
	settled_state["grimoire_unread"] = []
	var progression: Dictionary = (settled_state.get("progression", {}) as Dictionary).duplicate(true)
	progression["grimoire_unread"] = []
	settled_state["progression"] = progression
	var pending_reward: Dictionary = (settled_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	if not pending_reward.is_empty():
		pending_reward["intro_pending"] = false
		settled_state["pending_reward"] = pending_reward
	instance.set("_run_state", settled_state)
	instance.set("_reward_intro_suppressed", false)
	instance.set("_reward_reveal_pending", false)
	instance.call("_refresh_ui")
	PostCombatRewardSequence.hide_victory(instance.get("_post_combat_victory_overlay") as Control)
	await _freeze_reward_title(instance)
	root.gui_release_focus()
	await _settle()

func _capture_reward_sequence_states(
	instance: Node,
	output_dir: String,
	resolution: Vector2i
) -> void:
	instance.set("_reward_intro_suppressed", true)
	instance.set("_reward_reveal_pending", false)
	instance.call("_refresh_ui")
	await _settle()
	var victory_overlay: Control = instance.get("_post_combat_victory_overlay") as Control
	PostCombatRewardSequence.show_victory_proof_state(victory_overlay)
	await _save_root_screenshot(
		"%s/card_reward_victory_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	PostCombatRewardSequence.hide_victory(victory_overlay)

	var reveal_parts: Dictionary = await _prepare_reward_reveal_proof(instance)
	var slots: Array[Control] = reveal_parts.get("slots", []) as Array[Control]
	var banner: TextureRect = reveal_parts.get("banner") as TextureRect
	var title: Label = reveal_parts.get("title") as Label
	var secondary_actions: Control = reveal_parts.get("secondary_actions") as Control
	PostCombatRewardSequence.settle_banner(banner, title)
	for slot: Control in slots:
		PostCombatRewardSequence.show_card_back(slot)
	await _settle()
	_assert_reveal_faces(slots, 0, "card-back proof")
	await _save_root_screenshot(
		"%s/card_reward_backs_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	_assert_reveal_transforms(slots, "card-back proof after capture")

	if not slots.is_empty():
		PostCombatRewardSequence.reveal_card_face(slots[0])
	await _settle()
	_assert_reveal_faces(slots, 1, "partial reveal proof")
	await _save_root_screenshot(
		"%s/card_reward_partial_reveal_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	_assert_reveal_transforms(slots, "partial reveal proof after capture")

	# Rebuild the prepared state and let the real timing path run to completion.
	reveal_parts = await _prepare_reward_reveal_proof(instance)
	slots = reveal_parts.get("slots", []) as Array[Control]
	banner = reveal_parts.get("banner") as TextureRect
	title = reveal_parts.get("title") as Label
	secondary_actions = reveal_parts.get("secondary_actions") as Control
	await PostCombatRewardSequence.play_reward_reveal(
		instance.get("stage_root") as Control,
		banner,
		title,
		slots,
		secondary_actions,
		false
	)
	instance.set("_reward_reveal_pending", false)
	_assert_reveal_faces(slots, slots.size(), "animated reveal completion")
	_assert_reveal_transforms(slots, "animated reveal completion")

func _capture_reduced_motion_reward(
	instance: Node,
	state: Dictionary,
	output_dir: String,
	resolution: Vector2i
) -> void:
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _show_state(instance, state)
	var reveal_parts: Dictionary = await _prepare_reward_reveal_proof(instance)
	var slots: Array[Control] = reveal_parts.get("slots", []) as Array[Control]
	await PostCombatRewardSequence.play_reward_reveal(
		instance.get("stage_root") as Control,
		reveal_parts.get("banner") as TextureRect,
		reveal_parts.get("title") as Label,
		slots,
		reveal_parts.get("secondary_actions") as Control,
		true
	)
	instance.set("_reward_reveal_pending", false)
	_assert_reveal_faces(slots, slots.size(), "reduced-motion reveal completion")
	await _save_root_screenshot(
		"%s/card_reward_reduced_motion_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _show_state(instance, state)

func _prepare_reward_reveal_proof(instance: Node) -> Dictionary:
	instance.set("_reward_intro_suppressed", false)
	instance.set("_reward_reveal_pending", true)
	instance.call("_refresh_ui")
	await _settle()
	var card_row: HBoxContainer = instance.find_child("RewardCardRow", true, false) as HBoxContainer
	var slots: Array[Control] = []
	if card_row != null:
		for child: Node in card_row.get_children():
			if child is Control:
				slots.append(child as Control)
	if slots.size() != 3:
		_fail("Prepared reward reveal should contain exactly three card slots")
	return {
		"slots": slots,
		"banner": instance.get("_relic_choice_banner") as TextureRect,
		"title": instance.get("_relic_choice_title") as Label,
		"secondary_actions": instance.find_child("RewardSecondaryActions", true, false) as Control
	}

func _assert_reveal_faces(slots: Array[Control], expected_faces: int, stage_label: String) -> void:
	var visible_faces: int = 0
	for slot: Control in slots:
		var widget: Control = slot.find_child("CardWidget", true, false) as Control
		var back: TextureRect = slot.find_child(PostCombatRewardSequence.CARD_BACK_NAME, true, false) as TextureRect
		if widget != null and widget.visible:
			visible_faces += 1
			_assert_reward_card_title_size(widget, stage_label)
		if widget == null or back == null or widget.visible == back.visible:
			_fail("%s should show exactly one face for every reward card" % stage_label)
	if visible_faces != expected_faces:
		_fail("%s should show %d card faces, got %d" % [stage_label, expected_faces, visible_faces])

func _assert_reveal_transforms(slots: Array[Control], stage_label: String) -> void:
	for slot: Control in slots:
		var scaler: Control = slot.find_child(PostCombatRewardSequence.CARD_FRAME_NAME, true, false) as Control
		if scaler == null:
			_fail("%s should retain every card scale frame" % stage_label)
			continue
		var base_scale: Vector2 = scaler.get_meta("reward_reveal_base_scale", scaler.scale) as Vector2
		var base_position: Vector2 = scaler.get_meta("reward_reveal_base_position", scaler.position) as Vector2
		if not scaler.scale.is_equal_approx(base_scale) or not scaler.position.is_equal_approx(base_position):
			_fail("%s should be settled, got scale %s position %s" % [stage_label, str(scaler.scale), str(scaler.position)])

func _assert_persistent_combat_board(
	instance: Node,
	state: Dictionary,
	resolution: Vector2i,
	ui_scale: float
) -> void:
	var label: String = "%dx%d @ %d%%" % [resolution.x, resolution.y, roundi(ui_scale * 100.0)]
	var reward_state: Dictionary = state.get("pending_reward", {}) as Dictionary
	var expected_board: Dictionary = reward_state.get("board_state", {}) as Dictionary
	var displayed_board: Dictionary = instance.call("_board_display_state") as Dictionary
	if expected_board.is_empty() or displayed_board != expected_board:
		_fail("%s reward should render the exact post-combat board snapshot" % label)
	var board_view: Control = instance.get("board_view") as Control
	var presentation: Dictionary = board_view.get("presentation") as Dictionary if board_view != null else {}
	if str(presentation.get("board_framing_mode", "")) != "combat":
		_fail("%s reward should retain combat framing instead of switching to room framing" % label)
	var status_label: String = str(board_view.get("status_label")) if board_view != null else "missing"
	if not status_label.is_empty():
		_fail("%s reward should not add a duplicate board-level reward label" % label)

func _freeze_reward_title(instance: Node) -> void:
	await create_timer(0.12).timeout
	var title_effect: Node = instance.get("_relic_choice_title_effect") as Node
	if title_effect != null:
		title_effect.set_process(false)
		title_effect.set("phase", 0.0)
		title_effect.call("_animate_labels")

func _assert_reward_layout(
	instance: Node,
	resolution: Vector2i,
	ui_scale: float,
	full_health: bool,
	expects_reroll: bool = false
) -> Dictionary:
	var result: Dictionary = {}
	var label: String = "%dx%d @ %d%%" % [resolution.x, resolution.y, roundi(ui_scale * 100.0)]
	var overlay: Control = instance.get("_relic_choice_overlay") as Control
	var backdrop: ColorRect = instance.get("_relic_choice_backdrop") as ColorRect
	var banner: TextureRect = instance.get("_relic_choice_banner") as TextureRect
	var title: Label = instance.get("_relic_choice_title") as Label
	var stack: VBoxContainer = instance.find_child("RewardChoiceStack", true, false) as VBoxContainer
	var card_row: HBoxContainer = instance.find_child("RewardCardRow", true, false) as HBoxContainer
	var secondary_actions: HBoxContainer = instance.find_child("RewardSecondaryActions", true, false) as HBoxContainer
	var reroll_button: Button = instance.find_child("RewardRerollButton", true, false) as Button
	var recover_button: Button = instance.find_child("RewardRecoverButton", true, false) as Button
	var hand_row: Control = instance.get_node(
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow"
	) as Control
	if overlay == null or not overlay.visible:
		_fail("%s card reward should show the stage selection overlay" % label)
	if backdrop == null or not backdrop.visible or backdrop.color.a < 0.60:
		_fail("%s card reward should visibly dim the room behind the decision" % label)
	if banner == null or not banner.visible or banner.texture == null:
		_fail("%s card reward should put its instruction text on a raster foreground banner" % label)
	if title == null or title.text != "GROW YOUR POWER" or not title.visible:
		_fail("%s card reward should keep the game-native selection title" % label)
	elif (
		title.get_theme_font_size("font_size") > UiTypography.scaled_size(title, 40)
		or title.get_theme_constant("outline_size") > 2
	):
		_fail("%s card reward should use restrained runtime text on the raster banner" % label)
	if hand_row == null or hand_row.visible:
		_fail("%s card reward should not occupy the combat hand strip" % label)
	if stack == null or card_row == null or card_row.get_child_count() != 3:
		_fail("%s should show one centered stack with exactly three card choices" % label)
		return result
	if recover_button == null:
		_fail("%s should place Recover in a button below the three cards" % label)
		return result
	if expects_reroll:
		if reroll_button == null or secondary_actions == null:
			_fail("%s ready Discerning Eye should add a compact Reroll action" % label)
			return result
		if reroll_button.text != "REROLL":
			_fail("%s reward reroll should use the compact secondary-action label" % label)
	elif reroll_button != null:
		_fail("%s reward should not show Reroll without a ready Discerning Eye" % label)
	var title_rect: Rect2 = title.get_global_rect()
	var banner_rect: Rect2 = banner.get_global_rect()
	var row_rect: Rect2 = card_row.get_global_rect()
	var button_rect: Rect2 = recover_button.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	if title_rect.end.y > row_rect.position.y + 2.0:
		_fail("%s selection title should sit above the card row" % label)
	if button_rect.position.y < row_rect.end.y - 2.0:
		_fail("%s Recover should sit beneath the card row" % label)
	if button_rect.size.x >= row_rect.size.x:
		_fail("%s Recover should remain visually subordinate to the offer row" % label)
	if expects_reroll and secondary_actions != null:
		var action_rect: Rect2 = secondary_actions.get_global_rect()
		if action_rect.size.x >= row_rect.size.x:
			_fail("%s Reroll plus Recover should remain narrower than the three-card offer row" % label)
		if not viewport_rect.encloses(action_rect):
			_fail("%s Reroll plus Recover should fit the visible viewport" % label)
	if (
		banner_rect.get_center().distance_to(title_rect.get_center()) > 2.0
		or title_rect.size.x > banner_rect.size.x + 2.0
		or title_rect.size.y > banner_rect.size.y + 2.0
	):
		_fail("%s instruction text should read as part of its banner" % label)
	var composition_rect: Rect2 = banner_rect.merge(row_rect).merge(button_rect)
	if absf(composition_rect.get_center().x - viewport_rect.get_center().x) > viewport_rect.size.x * 0.06:
		_fail("%s reward composition should remain horizontally centered" % label)
	if absf(composition_rect.get_center().y - viewport_rect.get_center().y) > viewport_rect.size.y * 0.18:
		_fail("%s reward composition should sit in the central foreground" % label)
	if not viewport_rect.encloses(banner_rect) or not viewport_rect.encloses(row_rect) or not viewport_rect.encloses(button_rect):
		_fail("%s reward stack should fit the visible viewport" % label)
	if banner_rect.size.x < 880.0:
		_fail("%s reward banner should be materially larger than the previous 760px presentation" % label)
	if not recover_button.text.contains("SKIP & RECOVER"):
		_fail("%s Recover should make the skipped-card consequence explicit" % label)
	var expected_projection: String = "24 → 24" if full_health else "12 → 15"
	if not recover_button.text.contains("+%d HP" % RunEngine.REWARD_HEAL) or not recover_button.text.contains(expected_projection):
		_fail("%s Recover should show exact healing and %s" % [label, expected_projection])
	if recover_button.focus_mode != Control.FOCUS_ALL or recover_button.focus_neighbor_top == NodePath():
		_fail("%s Recover should expose visible focus and return navigation to the cards" % label)
	var visible_cards: int = 0
	for child: Node in card_row.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var card_id: String = str(slot.get_meta("reward_card_id", ""))
		var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
		var badge: Control = slot.find_child("RewardOwnershipBadge", true, false) as Control
		if card_id.is_empty() or card_widget == null or badge == null:
			_fail("%s reward slot should contain card identity and ownership state" % label)
			continue
		visible_cards += 1
		if card_widget.focus_mode != Control.FOCUS_ALL or card_widget.focus_neighbor_bottom == NodePath():
			_fail("%s card %s should support focus navigation to Recover" % [label, card_id])
		if not viewport_rect.encloses(card_widget.get_global_rect()):
			_fail("%s card %s should fit the visible viewport" % [label, card_id])
		if card_widget.get_global_rect().size.x < 280.0:
			_fail("%s card %s should be about one-third larger than the previous 224px offer" % [label, card_id])
		_assert_reward_card_title_size(card_widget, label)
		if card_id == OWNED_CARD_ID:
			result["owned_card"] = card_widget
			_assert_badge_text(badge, "OWNED", label)
		elif card_id == NEW_CARD_ID:
			result["new_card"] = card_widget
			_assert_badge_text(badge, "NEW", label)
	if visible_cards != 3:
		_fail("%s should visibly render all three reward cards" % label)
	result["recover_button"] = recover_button
	return result

func _assert_reward_card_title_size(card_widget: Control, stage_label: String) -> void:
	var card_title: Label = card_widget.find_child("Title", true, false) as Label
	if card_title == null:
		_fail("%s reward card should retain its title label" % stage_label)
		return
	var rendered_size: float = float(card_title.get_theme_font_size("font_size")) * absf(card_title.get_global_transform().get_scale().x)
	if rendered_size < 17.0:
		_fail("%s reward card title should render at least 17px, got %.2fpx for %s" % [stage_label, rendered_size, card_title.text])

func _assert_relic_layout(instance: Node, resolution: Vector2i, ui_scale: float) -> Dictionary:
	var result: Dictionary = {}
	var label: String = "%dx%d @ %d%%" % [resolution.x, resolution.y, roundi(ui_scale * 100.0)]
	var overlay: Control = instance.get("_relic_choice_overlay") as Control
	var backdrop: ColorRect = instance.get("_relic_choice_backdrop") as ColorRect
	var banner: TextureRect = instance.get("_relic_choice_banner") as TextureRect
	var title: Label = instance.get("_relic_choice_title") as Label
	var bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	if overlay == null or not overlay.visible:
		_fail("%s relic reward should show the stage selection overlay" % label)
	if backdrop == null or not backdrop.visible or backdrop.color.a < 0.60:
		_fail("%s relic reward should visibly dim the room behind the decision" % label)
	if banner == null or not banner.visible or banner.texture == null:
		_fail("%s relic reward should put its instruction text on a raster foreground banner" % label)
	if title == null or title.text != "CLAIM YOUR TREASURE" or not title.visible:
		_fail("%s relic reward should keep the game-native selection title" % label)
	if bar == null or bar.get_child_count() != 3:
		_fail("%s relic reward should show exactly three centered relic choices" % label)
		return result
	var first_choice: Control = bar.get_child(0) as Control
	var middle_choice: Control = bar.get_child(1) as Control
	var last_choice: Control = bar.get_child(2) as Control
	var row_rect: Rect2 = first_choice.get_global_rect().merge(last_choice.get_global_rect())
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	if title.get_global_rect().end.y > row_rect.position.y + 2.0:
		_fail("%s treasure title should sit directly above the relic offer row" % label)
	if not viewport_rect.encloses(row_rect):
		_fail("%s relic offer row should fit the visible viewport" % label)
	var relic_choices: Array[Control] = []
	relic_choices.append(first_choice)
	relic_choices.append(middle_choice)
	relic_choices.append(last_choice)
	for choice: Control in relic_choices:
		if choice.focus_mode != Control.FOCUS_ALL:
			_fail("%s relic choices should be keyboard/controller focusable" % label)
		if choice.focus_neighbor_left == NodePath() or choice.focus_neighbor_right == NodePath():
			_fail("%s relic choices should expose complete horizontal focus navigation" % label)
	if (
		bool(middle_choice.get_meta("relic_keyboard_focused", false))
		or bool(middle_choice.get_meta("relic_pointer_hovered", false))
		or middle_choice.z_index != 30
	):
		_fail("%s normal relic proof should begin from a clean unfocused baseline" % label)
	if banner != null:
		var composition_rect: Rect2 = banner.get_global_rect().merge(row_rect)
		if absf(composition_rect.get_center().x - viewport_rect.get_center().x) > viewport_rect.size.x * 0.06:
			_fail("%s relic composition should remain horizontally centered" % label)
		if absf(composition_rect.get_center().y - viewport_rect.get_center().y) > viewport_rect.size.y * 0.18:
			_fail("%s relic composition should sit in the central foreground" % label)
	result["middle_relic"] = middle_choice
	return result

func _capture_card_focus(card_widget: Control, output_path: String, resolution: Vector2i) -> void:
	if card_widget == null:
		_fail("Missing New reward card for focus proof")
		return
	card_widget.grab_focus()
	await create_timer(0.45).timeout
	if not card_widget.has_focus() or card_widget.z_index != 20:
		_fail("Focused reward card should use the same visible lift as pointer hover")
	# The Metal screenshot readback intermittently drops lower-z sibling canvases
	# when this focused child is sorted above them. Preserve its real focused
	# scale/lift and verified focus state, but flatten only the proof-frame sort.
	card_widget.z_index = 0
	await _save_root_screenshot(output_path, resolution)
	card_widget.release_focus()
	await create_timer(0.16).timeout

func _capture_button_focus(button: Button, output_path: String, resolution: Vector2i) -> void:
	if button == null:
		_fail("Missing Recover button for focus proof")
		return
	button.grab_focus()
	await _settle()
	if not button.has_focus():
		_fail("Recover button should accept visible keyboard/controller focus")
	# As with elevated cards, Metal's focused-control sort can drop unrelated
	# sibling canvases from readback. Verify real focus first, then preserve its
	# focus style as the proof-frame normal style after releasing OS focus.
	var focus_style: StyleBox = button.get_theme_stylebox("focus")
	if focus_style != null:
		button.add_theme_stylebox_override("normal", focus_style)
	button.release_focus()
	await _settle()
	await _save_root_screenshot(output_path, resolution)
	button.remove_theme_stylebox_override("normal")
	await _settle()

func _capture_relic_focus(choice: Control, output_path: String, resolution: Vector2i) -> void:
	if choice == null:
		_fail("Missing middle relic for focus proof")
		return
	choice.grab_focus()
	await _settle()
	if (
		not choice.has_focus()
		or not bool(choice.get_meta("relic_keyboard_focused", false))
		or choice.z_index != 40
	):
		_fail("Focused relic should use the same visible emphasis as pointer hover")
	await _save_root_screenshot(output_path, resolution)
	choice.release_focus()
	root.gui_release_focus()
	await _settle()

func _assert_badge_text(badge: Control, expected: String, label: String) -> void:
	if _label_with_text(badge, expected) == null:
		_fail("%s reward badge should read %s" % [label, expected])

func _save_root_screenshot(output_path: String, resolution: Vector2i) -> void:
	# Metal can return a partially composed CanvasItem frame on the first rapid
	# readback. Warm the renderer, then overwrite with a later stable frame.
	await process_frame
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	await create_timer(0.10).timeout
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var warm_image: Image = root.get_viewport().get_texture().get_image()
	if warm_image != null and not warm_image.is_empty():
		if warm_image.get_size() != resolution:
			warm_image.resize(resolution.x, resolution.y, Image.INTERPOLATE_LANCZOS)
		warm_image.save_png(output_path)
	await create_timer(0.35).timeout
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Failed to read renderer frame: %s" % output_path)
		return
	if image.get_size() != resolution:
		# macOS exposes the Retina backing texture even though content_scale_size is
		# the requested proof viewport. Preserve that real Metal render and
		# downsample it to the exact review resolution.
		image.resize(resolution.x, resolution.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png(output_path)
	if error != OK:
		_fail("Failed to save screenshot: %s" % output_path)

func _first_room_coord_of_type(engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i.ZERO

func _first_available_room_coord_of_type(engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for coord: Vector2i in engine.available_moves(state):
		if str(engine.room_metadata(state, coord).get("type", "")) == room_type:
			return coord
	return Vector2i.ZERO

func _labels_under(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node as Label)
	for child: Node in node.get_children():
		labels.append_array(_labels_under(child))
	return labels

func _label_with_text(node: Node, text: String) -> Label:
	for label: Label in _labels_under(node):
		if label.text == text:
			return label
	return null

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	var directory := DirAccess.open(absolute_dir)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		var child_path: String = absolute_dir.path_join(file_name)
		if directory.current_is_dir():
			_clear_probe_output("%s/%s" % [output_dir, file_name])
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		file_name = directory.get_next()
	directory.list_dir_end()
