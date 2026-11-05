extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const HandFanContainerScript = preload("res://scripts/hand_fan_container.gd")
const PassPileDockChecks = preload("res://tests/helpers/pass_pile_dock_checks.gd")

const OUTPUT_DIR: String = "user://probes/combat_interaction_context_v5"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)

# Shared live HUD fixtures retained when qa-27 retired the legacy multi-step probe.

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	# Force a logical Full HD canvas before the scene exists. macOS can return a
	# Retina backing image, which _save_root_screenshot deliberately normalizes.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_combat_interaction_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_combat_interaction_probe.save")
	ProgressionStore.clear_saved_run()
	await call("_capture_states")
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()
func _capture_pass_and_meter_states(instance: Node) -> void:
	for state_kind: String in ["safe", "danger", "unknown"]:
		_install_pass_meter_fixture(instance, state_kind)
		await _settle_ui()
		_assert_pass_meter_layout(instance, state_kind)
		await _save_root_screenshot("%s/pass_%s.png" % [OUTPUT_DIR, state_kind])
	var chip: Button = instance.find_child("PassPreviewChip", true, false) as Button
	if chip != null:
		var pass_art: TextureRect = chip.find_child("PassForecastFrameArtHost", true, false) as TextureRect
		var focus_edge: Control = chip.find_child("PassFocusEdgeCue", true, false) as Control
		var pass_content: Control = chip.find_child("PassForecastContent", true, false) as Control
		_assert(pass_art != null and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "normal", "Pass idle proof should use the authored v2 normal frame")
		chip.emit_signal("mouse_entered")
		await _settle_ui()
		_assert(str(chip.get_meta("pass_interaction_state", "")) == "hover", "Pass hover proof should expose its interaction state")
		_assert(pass_art != null and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "hover", "Pass hover proof should use the authored hover frame without a code overlay")
		_assert(focus_edge != null and not focus_edge.visible, "Pass hover should not add a colored focus wash")
		await _save_root_screenshot("%s/pass_hover.png" % OUTPUT_DIR)
		chip.emit_signal("mouse_exited")
		chip.grab_focus()
		await _settle_ui()
		_assert(str(chip.get_meta("pass_interaction_state", "")) == "focus", "Pass focus proof should expose its interaction state")
		_assert(pass_art != null and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "hover", "Pass focus should reuse the authored hover frame")
		var focus_style: StyleBoxFlat = focus_edge.get_theme_stylebox("panel") as StyleBoxFlat if focus_edge != null else null
		_assert(focus_edge != null and focus_edge.visible and focus_style != null and focus_style.bg_color.a <= 0.001 and focus_style.border_width_left <= 2 and focus_style.shadow_size == 0, "Pass focus should add only a narrow shape-aware edge cue")
		await _save_root_screenshot("%s/pass_focus.png" % OUTPUT_DIR)
		chip.emit_signal("button_down")
		await _settle_ui()
		_assert(str(chip.get_meta("pass_interaction_state", "")) == "pressed", "Pass pressed proof should expose its interaction state")
		_assert(pass_art != null and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "pressed", "Pass pressed proof should use the authored pressed frame")
		_assert(pass_content != null and pass_content.position.y >= 0.0 and pass_content.position.y <= 2.0, "Pass pressed travel must remain a subtle one-to-two pixels")
		await _save_root_screenshot("%s/pass_pressed.png" % OUTPUT_DIR)
		chip.emit_signal("button_up")

	_install_pass_meter_fixture(instance, "safe")
	var banked_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	banked_state["skill_ids"] = ["measured_breath", "borrowed_time"]
	banked_state["banked_play_active"] = 1
	banked_state["banked_play_spent_this_activation"] = 0
	instance.set("_combat_state", banked_state)
	instance.call("_refresh_card_play_meter")
	await _settle_ui()
	var banked_badge: Control = instance.get("_play_meter_banked_badge") as Control
	_assert(banked_badge != null and banked_badge.visible, "Banked meter proof should expose the secondary banked row")
	await _save_root_screenshot("%s/meter_banked.png" % OUTPUT_DIR)
func _install_pass_meter_fixture(instance: Node, state_kind: String) -> void:
	# Clear the old selection before installing this fixture.
	instance.call("_reset_card_resolution")
	var combat := CombatEngine.new()
	var full_hand: Array = ["guarded_step", "quick_stab", "sidestep_slash", "thunderline", "patch_up"]
	var state: Dictionary = combat.create_combat(9821, _room_layout(Vector2i(2, 4), [Vector2i(3, 4)]), {
		"hp": 24, "max_hp": 24, "deck_cards": full_hand, "relics": [], "hand_size": full_hand.size(), "heal_bonus": 0
	})
	var enemy_pos: Vector2i = Vector2i(6, 4) if state_kind in ["safe", "unknown"] else Vector2i(3, 4)
	var enemy_intent: Dictionary = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [{"id": 1, "type": "crawler", "pos": enemy_pos, "hp": 14, "max_hp": 14, "block": 0, "intent": enemy_intent}]
	state["deck"] = {"hand": full_hand, "draw": ["bone_dart"], "discard": ["updraft"], "burned": [], "cycles": 0, "fatigue_base": 15}
	state["cards_per_turn"] = full_hand.size()
	state["draw_per_turn"] = full_hand.size()
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 20 if state_kind == "unknown" else 0
	state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	state["initiative_clock"] = 0
	state["current_actor"] = {"kind": "player", "actor_key": "player", "name": "Reaver", "type": "player", "team": "player", "time": 0, "seq": 0}
	state["turn_queue"] = [{"kind": "enemy", "actor_key": "enemy_1", "enemy_id": 1, "type": "crawler", "name": "Tunnel Crawler", "team": "enemy", "time": 1, "seq": 1, "pos": enemy_pos}]
	if state_kind == "unknown":
		var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
		umbra["stage"] = "eclipse"
		umbra["stage_reduction"] = 0
		state["umbra"] = umbra
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state.duplicate(true))
	instance.call("_mark_combat_preview_state_changed")
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
func _assert_pass_meter_layout(instance: Node, state_kind: String) -> void:
	var chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
	var pass_label: Label = instance.find_child("PassActionLabel", true, false) as Label
	var ribbon: Label = instance.find_child("PassPreviewForecastLine", true, false) as Label
	var meter: Control = instance.get("_play_meter") as Control
	var movement_meter: Control = instance.get("_movement_meter") as Control
	var meter_label: Label = instance.get("_play_meter_count") as Label
	_assert(chip != null and pass_label != null and ribbon != null and meter != null and movement_meter != null and meter_label != null, "%s pass/meter proof should build all dock controls" % state_kind)
	if chip == null or pass_label == null or ribbon == null or meter == null or movement_meter == null or meter_label == null:
		return
	_assert(absf(pass_label.get_global_rect().get_center().x - chip.get_global_rect().get_center().x) <= 1.0, "%s PASS label should stay centered" % state_kind)
	_assert(_label_text_fits(ribbon), "%s forecast ribbon should fit its text" % state_kind)
	var ribbon_rect: Rect2 = ribbon.get_global_rect()
	var chip_rect: Rect2 = chip.get_global_rect()
	_assert(ribbon_rect.position.y >= chip_rect.position.y + 71.0 and ribbon_rect.end.y <= chip_rect.position.y + 91.0, "%s TURN END forecast should stay contained in the authored lower ribbon" % state_kind)
	_assert(absf(meter_label.get_global_rect().get_center().y - meter.get_global_rect().get_center().y) <= 1.0, "%s ordinary meter label should stay vertically centered" % state_kind)
	var movement_rect: Rect2 = movement_meter.get_global_rect()
	var resource_rect: Rect2 = meter.get_global_rect().merge(movement_rect)
	# pol-37 / hud-01 (33a62f130, e9c428ec8) reserve a home for the whole deal.
	var hand_bounds: Rect2 = instance.call("_combat_dock_hand_bounds")
	_assert(absf(meter.get_global_rect().get_center().x - movement_rect.get_center().x) <= 1.0 and movement_rect.position.y >= meter.get_global_rect().end.y + 3.0, "%s movement should stack directly beneath card plays" % state_kind)
	_assert(resource_rect.end.x < hand_bounds.position.x and chip_rect.position.x > hand_bounds.end.x, "%s resources and Pass should flank opposite sides of the hand" % state_kind)
	_assert(hand_bounds.position.x - resource_rect.end.x <= 64.0, "%s resources should sit close to the resting fan" % state_kind)
	PassPileDockChecks.assert_layout(instance, _assert, state_kind)
	PassPileDockChecks.assert_hand_clearance(instance, _assert, state_kind, hand_bounds)
	_assert(_rect_is_onscreen(resource_rect) and _rect_is_onscreen(chip_rect), "%s hand controls should remain wholly on screen" % state_kind)
	var tooltips: Control = instance.get("_card_focus_tooltip_stack") as Control
	if tooltips != null and tooltips.visible:
		var tooltip_rect: Rect2 = tooltips.get_global_rect()
		# Keep tooltips anchored beside the card; overlap with Pass is intentional.
		_assert(_rect_is_onscreen(tooltip_rect), "%s card tooltips should stay on screen" % state_kind)
		_assert(not tooltip_rect.intersects(resource_rect), "%s card tooltips should keep the resource stack visible" % state_kind)
	_assert_combat_dock_clearance(instance, resource_rect, chip_rect, state_kind)
func _assert_combat_dock_clearance(instance: Node, meter_rect: Rect2, pass_rect: Rect2, state_kind: String) -> void:
	var dock_rects: Array = [meter_rect, pass_rect]
	var board_rect: Rect2 = instance.call("_contextual_combat_rendered_board_bounds")
	var turn_rail: Control = instance.get("_turn_order_panel") as Control
	var tutorial: Control = instance.get("_contextual_combat_prompt") as Control
	var objective: Control = instance.get("_combat_objective_hud") as Control
	for dock_rect: Rect2 in dock_rects:
		_assert(not dock_rect.intersects(board_rect), "%s action dock should not cover the combat board" % state_kind)
		for pile: Control in [instance.get("draw_pile") as Control, instance.get("discard_pile") as Control]:
			if pile != null and pile.visible:
				_assert(not dock_rect.intersects(pile.get_global_rect()), "%s action dock should stay clear of the %s pile" % [state_kind, pile.name])
		if turn_rail != null and turn_rail.visible:
			_assert(not dock_rect.intersects(turn_rail.get_global_rect()), "%s action dock should stay clear of the turn rail" % state_kind)
		if tutorial != null and tutorial.visible:
			_assert(not dock_rect.intersects(tutorial.get_global_rect()), "%s action dock should stay clear of the contextual tutorial" % state_kind)
		if objective != null and objective.visible:
			_assert(not dock_rect.intersects(objective.get_global_rect()), "%s hand controls should stay clear of the objective" % state_kind)
	var hand: Array = ((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array
	_assert(hand.size() >= 3, "%s fixture should keep a representative playable hand" % state_kind)
	for index: int in range(hand.size()):
		var card: Control = instance.call("_hand_card_control", index) as Control
		if card == null or not card.visible:
			continue
		var card_rect: Rect2 = instance.call("_control_visual_global_rect", card)
		PassPileDockChecks.assert_hand_clearance(instance, _assert, "%s card %d" % [state_kind, index + 1], card_rect)
		for dock_rect: Rect2 in dock_rects:
			_assert(not dock_rect.intersects(card_rect), "%s hand controls should stay clear of card %d" % [state_kind, index + 1])
	if not hand.is_empty():
		var leftmost_card: Control = instance.call("_hand_card_control", 0) as Control
		if leftmost_card != null and leftmost_card.visible:
			var leftmost_rect: Rect2 = instance.call("_control_visual_global_rect", leftmost_card)
			var minimum_gap: float = 4.0 if hand.size() >= 8 else 12.0
			_assert(meter_rect.end.x <= leftmost_rect.position.x - minimum_gap, "%s resources should keep a visible gap before the leftmost card" % state_kind)
		var rightmost_card: Control = instance.call("_hand_card_control", hand.size() - 1) as Control
		if rightmost_card != null and rightmost_card.visible:
			var rightmost_rect: Rect2 = instance.call("_control_visual_global_rect", rightmost_card)
			var minimum_gap: float = 4.0 if hand.size() >= 8 else 12.0
			# pol-46: the lifted seven-card hover may reach Pass. Moving to Pass
			# dismisses that hover; the dealt, at-rest clearance still applies.
			if hand.size() != 7 or int(instance.get("_hovered_card_index")) < 0:
				_assert(pass_rect.position.x >= rightmost_rect.end.x + minimum_gap, "%s Pass should keep a visible gap after the rightmost card" % state_kind)
func _capture_hand_dock_resilience(instance: Node) -> void:
	var hand_sets: Array = [
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"],
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up", "bone_dart"],
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up", "bone_dart", "updraft"],
		["quick_stab", "sidestep_slash", "thunderline"],
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up", "bone_dart", "updraft", "guarded_step"]
	]
	var stable_seven_meter := Rect2()
	var stable_seven_pass := Rect2()
	var pile_dock_home := Rect2()
	for cards_var: Variant in hand_sets:
		var cards: Array = cards_var as Array
		instance.set("_hovered_card_index", -1)
		await _load_combat_fixture(instance, cards, Vector2i(2, 4), [Vector2i(5, 4), Vector2i(5, 2)], 9910 + cards.size())
		var first_card: Control = instance.call("_hand_card_control", 0) as Control
		if first_card != null:
			var rendered_card_width: float = first_card.size.x * first_card.get_global_transform().get_scale().x
			print("HAND GEOMETRY %d-CARD width=%.2f bounds=%s" % [cards.size(), rendered_card_width, instance.call("_combat_hand_resting_visual_bounds")])
			if cards.size() >= 8:
				_assert(rendered_card_width >= 171.5 and rendered_card_width <= 180.5, "Dense eight-card hands should use the readable compact width that preserves focus and dock clearance")
		var meter: Control = instance.get("_play_meter") as Control
		var pass_chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
		_assert(meter != null and pass_chip != null, "%d-card dock proof needs meter and Pass controls" % cards.size())
		if meter == null or pass_chip == null:
			continue
		var resting_meter: Rect2 = meter.get_global_rect()
		var resting_pass: Rect2 = pass_chip.get_global_rect()
		if not pile_dock_home.has_area():
			pile_dock_home = resting_pass
		_assert(_rect_approximately_equal(resting_pass, pile_dock_home), "%d-card hand must preserve Pass's pile-docked home (expected=%s actual=%s)" % [cards.size(), pile_dock_home, resting_pass])
		var resting_hand: Rect2 = instance.call("_combat_hand_visual_bounds")
		print("HAND REST %s %d-CARD hand_right=%.2f pass_left=%.2f gap=%.2f" % [PROBE_VIEWPORT, cards.size(), resting_hand.end.x, resting_pass.position.x, resting_pass.position.x - resting_hand.end.x])
		if cards.size() == 7:
			stable_seven_meter = resting_meter
			stable_seven_pass = resting_pass
			print("HAND DOCK 7-CARD BASELINE meter=%s pass=%s" % [stable_seven_meter, stable_seven_pass])
		_assert_pass_meter_layout(instance, "%d-card idle" % cards.size())
		await _save_root_screenshot("%s/dock_%d_card_idle.png" % [OUTPUT_DIR, cards.size()])
		for index: int in range(cards.size()):
			instance.call("_on_card_hover_started", index)
			await process_frame
			_assert(meter.visible and pass_chip.visible, "%d-card hover %d must keep the dock visible on its first transition frame" % [cards.size(), index + 1])
			_assert(_rect_approximately_equal(meter.get_global_rect(), resting_meter), "%d-card hover %d must not move the meter during its transition" % [cards.size(), index + 1])
			_assert(_rect_approximately_equal(pass_chip.get_global_rect(), resting_pass), "%d-card hover %d must not move Pass during its transition" % [cards.size(), index + 1])
			await create_timer(HandFanContainerScript.EMPHASIS_TRANSITION_SECONDS * 0.5).timeout
			_assert(meter.visible and pass_chip.visible, "%d-card hover %d must keep the dock visible through its transition" % [cards.size(), index + 1])
			_assert(_rect_approximately_equal(meter.get_global_rect(), resting_meter), "%d-card hover %d must not move the meter mid-transition" % [cards.size(), index + 1])
			_assert(_rect_approximately_equal(pass_chip.get_global_rect(), resting_pass), "%d-card hover %d must not move Pass mid-transition" % [cards.size(), index + 1])
			await _settle_ui()
			_assert(_rect_approximately_equal(meter.get_global_rect(), resting_meter), "%d-card hover %d must not move the card-play meter (idle=%s hover=%s)" % [cards.size(), index + 1, resting_meter, meter.get_global_rect()])
			_assert(_rect_approximately_equal(pass_chip.get_global_rect(), resting_pass), "%d-card hover %d must not move Pass (idle=%s hover=%s)" % [cards.size(), index + 1, resting_pass, pass_chip.get_global_rect()])
			_assert_pass_meter_layout(instance, "%d-card hover %d" % [cards.size(), index + 1])
			if index == cards.size() - 1:
				await _save_root_screenshot("%s/dock_%d_card_worst_hover.png" % [OUTPUT_DIR, cards.size()])
			instance.call("_on_card_hover_ended", index)
			await _settle_ui()
	# A real draw can change hand size before a hover animation clears. Resources
	# must reach the seven-card geometry; Pass stays at the same pile dock.
	_assert(stable_seven_meter.size != Vector2.ZERO and stable_seven_pass.size != Vector2.ZERO, "Seven-card idle proof must establish the final dock baseline")
	var five_cards: Array = hand_sets[0] as Array
	await _load_combat_fixture(instance, five_cards, Vector2i(2, 4), [Vector2i(5, 4)], 9921)
	instance.call("_on_card_hover_started", 3)
	await _settle_ui()
	var changing_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var changing_deck: Dictionary = (changing_state.get("deck", {}) as Dictionary).duplicate(true)
	changing_deck["hand"] = hand_sets[2].duplicate()
	changing_state["deck"] = changing_deck
	var changing_run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	changing_run["combat_state"] = changing_state.duplicate(true)
	instance.set("_combat_state", changing_state)
	instance.set("_run_state", changing_run)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	# Refresh emphasis before the new fan settles. Pass retains its pile-docked
	# home even while the hand's layout revision is pending.
	await process_frame
	var pending_revision_before: int = int(instance.get("_hand_layout_revision"))
	instance.call("_on_card_hover_started", 1)
	instance.call("_refresh_ui")
	await process_frame
	var pending_revision_after: int = int(instance.get("_hand_layout_revision"))
	_assert(pending_revision_after >= pending_revision_before, "Hovering during a pending draw must preserve or advance the pending hand revision")
	_assert(int(instance.get("_hand_layout_pending_revision")) == pending_revision_after, "Hover refresh must preserve the pending fan layout at its current revision")
	var pending_meter: Control = instance.get("_play_meter") as Control
	var pending_pass_overlay: Control = instance.get("_pass_preview_overlay") as Control
	_assert(pending_meter != null and pending_pass_overlay != null and pending_meter.visible and pending_pass_overlay.visible, "Hovering during a pending 5-to-7 draw must retain the visible resource and Pass docks")
	var pending_pass: Control = instance.find_child("PassPreviewChip", true, false) as Control
	_assert(pending_pass != null and _rect_approximately_equal(pending_pass.get_global_rect(), pile_dock_home), "Pending hand layout must never displace Pass from the piles")
	PassPileDockChecks.assert_layout(instance, _assert, "Pending 5-to-7 draw")
	PassPileDockChecks.assert_hand_clearance(instance, _assert, "Pending 5-to-7 draw", instance.call("_combat_hand_resting_visual_bounds"))
	await _settle_hand_dock_transition()
	var changed_meter: Control = instance.get("_play_meter") as Control
	var changed_pass: Control = instance.find_child("PassPreviewChip", true, false) as Control
	_assert(changed_meter != null and changed_pass != null, "Hovering hand-size-change proof must retain dock controls")
	if changed_meter != null and changed_pass != null:
		print("HAND DOCK 5-TO-7 FINAL meter=%s pass=%s" % [changed_meter.get_global_rect(), changed_pass.get_global_rect()])
		_assert(_rect_approximately_equal(changed_meter.get_global_rect(), stable_seven_meter), "Hovering 5-to-7-card change must settle the card-play meter at the stable seven-card dock (expected=%s actual=%s)" % [stable_seven_meter, changed_meter.get_global_rect()])
		_assert(_rect_approximately_equal(changed_pass.get_global_rect(), stable_seven_pass), "Hovering 5-to-7-card change must preserve Pass's pile dock (expected=%s actual=%s)" % [stable_seven_pass, changed_pass.get_global_rect()])
		_assert_pass_meter_layout(instance, "hovered 5-to-7-card change")
		await _save_root_screenshot("%s/hovered_hand_size_change.png" % OUTPUT_DIR)
		for hover_index: int in [0, 6]:
			instance.call("_on_card_hover_started", hover_index)
			await _settle_hand_dock_transition()
			_assert(_rect_approximately_equal(changed_meter.get_global_rect(), stable_seven_meter), "Post-draw hover %d must not move the settled seven-card meter" % [hover_index + 1])
			_assert(_rect_approximately_equal(changed_pass.get_global_rect(), stable_seven_pass), "Post-draw hover %d must not move settled seven-card Pass" % [hover_index + 1])
			_assert_pass_meter_layout(instance, "hovered 5-to-7-card post-draw hover %d" % [hover_index + 1])
			instance.call("_on_card_hover_ended", hover_index)
			await _settle_hand_dock_transition()
func _settle_hand_dock_transition() -> void:
	await create_timer(HandFanContainerScript.EMPHASIS_TRANSITION_SECONDS + 0.08).timeout
	await _settle_ui()
func _rect_approximately_equal(first: Rect2, second: Rect2, epsilon: float = 0.25) -> bool:
	return first.position.distance_to(second.position) <= epsilon and first.size.distance_to(second.size) <= epsilon
func _rect_is_onscreen(rect: Rect2) -> bool:
	var viewport := Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
	return rect.position.x >= viewport.position.x and rect.position.y >= viewport.position.y and rect.end.x <= viewport.end.x and rect.end.y <= viewport.end.y
func _load_combat_fixture(instance: Node, hand: Array, player_pos: Vector2i, enemy_positions: Array, seed: int) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _room_layout(player_pos, enemy_positions)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": hand.duplicate(),
		"relics": [],
		"hand_size": hand.size(),
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["traps"] = []
	combat_state["terrain"] = []
	var restrictions: Dictionary = (combat_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	restrictions["immobilized"] = false
	restrictions["frozen"] = false
	restrictions["shocked"] = false
	combat_state["player_turn_restrictions"] = restrictions
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_mark_combat_preview_state_changed")
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle_hand_dock_transition()
func _label_text_fits(label: Label) -> bool:
	if label == null:
		return false
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= label.size.x + 1.0
func _room_layout(player_pos: Vector2i, enemy_positions: Array) -> Dictionary:
	var enemies: Array = []
	for index: int in range(enemy_positions.size()):
		enemies.append({
			"id": index + 1,
			"type": "crawler",
			"pos": enemy_positions[index],
			"hp": 140,
			"max_hp": 140,
			"block": 0
		})
	return {
		"name": "Combat Interaction Probe",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": player_pos,
		"enemies": enemies,
		"traps": [],
		"terrain": [],
		"loot": []
	}
func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid
func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
func _save_root_screenshot(output_path: String, expected_size: Vector2i = PROBE_VIEWPORT) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var texture: Texture2D = root.get_viewport().get_texture()
	var image: Image = texture.get_image()
	_assert(image != null, "Combat HUD proof should capture a renderer image")
	if image == null:
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(expected_size.x)
	var scale_y: float = float(source_size.y) / float(expected_size.y)
	var valid_backing_size: bool = is_equal_approx(scale_x, scale_y) and is_equal_approx(float(source_size.x) / float(source_size.y), float(expected_size.x) / float(expected_size.y))
	_assert(valid_backing_size, "Combat HUD proof must preserve the expected proportional backing, got %s for %s (scale %.4f x %.4f)" % [source_size, expected_size, scale_x, scale_y])
	if not valid_backing_size:
		return
	if source_size != expected_size:
		image.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)
func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))
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
