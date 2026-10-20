extends RefCounted

const Keywords = preload("res://scripts/card_keyword_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Defense = preload("res://scripts/defense_relic_rules.gd")

static func index_for_input(scene: Node, controller: bool = false) -> int:
	if scene._drag_card_index >= 0: return scene._drag_card_index
	if scene._selected_card_index >= 0: return scene._selected_card_index
	if controller: return scene._controller_hand_index if scene._controller_hand_focused else -1
	return scene._hovered_card_index

static func blocked_health(scene: Node, index: int) -> int:
	var card: Dictionary = scene._card_def(scene._card_id_for_hand_index(index), scene._combat_state)
	var health: int = int(Keywords.empower_cost(card).get("health", 0))
	if health <= 0: return 0
	var player: Dictionary = scene._combat_state.get("player", {})
	var skin: int = int(player.get("stoneskin", 0))
	for effect: Dictionary in Defense.effects_of_type(scene._combat_engine._relic_effects(scene._combat_state), "health_cost_stoneskin"):
		var rate: int = maxi(1, int(effect.get("stoneskin_per_health", 2)))
		var paid: int = mini(health, skin / rate)
		health -= paid
		skin -= paid * rate
	return health if health >= int(player.get("hp", 0)) else 0

static func locked(scene: Node, index: int) -> bool:
	if index != scene._selected_card_index: return false
	if scene._pending_umbra_commit_locked or scene._pending_orientation_target_tile.x >= 0: return true
	for tile: Vector2i in scene._pending_selected_targets:
		if tile.x >= 0: return true
	return false

static func available(scene: Node, index: int) -> bool:
	return can_attempt(scene, index) and blocked_health(scene, index) == 0

static func can_attempt(scene: Node, index: int) -> bool:
	# Health-blocked input still reaches toggle for invalid feedback. Keep
	# available() health-gated for the existing controller prompts and visuals.
	return index >= 0 and not scene._animation_lock and str(scene._run_state.get("mode", "")) == "combat" and not scene._controller_modal_visible() and scene._combat_skill_card_selection_zone.is_empty() and not locked(scene, index) and not Keywords.empower_cost(scene._card_def(scene._card_id_for_hand_index(index), scene._combat_state)).is_empty()

static func tooltip(scene: Node, index: int) -> String:
	var blocked: int = blocked_health(scene, index)
	if blocked > 0: return "Not enough health: Empower costs %d HP." % blocked
	var card: Dictionary = scene._card_def(scene._card_id_for_hand_index(index), scene._combat_state)
	var spec: Dictionary = card.get("empower", {}) as Dictionary
	var bonus_tokens: Array = Icons.tokens_for_keyword_bonus(card.get("actions", []) as Array, spec)
	for token: Dictionary in bonus_tokens:
		# Bonus values are increments: "Stagger +4", "Melee +4".
		if str(token.get("value", "")).is_valid_int() and int(token["value"]) > 0:
			token["value"] = "+%d" % int(token["value"])
	var bonus: String = "repeat this card's first action" if bool(spec.get("repeat_first", false)) else Icons.plain_text_for_tokens(bonus_tokens)
	var controller: bool = scene.is_inside_tree() and scene._controller_is_active()
	var charged: bool = scene._hand_card_empowered(index)
	var instruction: String = ("Charged. Press RS to cancel." if controller else "Charged. Click to cancel.") if charged else ("Press RS" if controller else "Click the seal or press E")
	return "Empower: %s · %s\n%s" % [Keywords.empower_cost_label(Keywords.empower_cost(card)), bonus, instruction]

static func sync_widgets(scene: Node) -> void:
	if scene.hand_box == null: return
	scene._empower_charge.observe(scene._combat_state)
	for index: int in range(scene.hand_box.get_child_count()):
		var widget: Control = scene._hand_card_control(index)
		if widget == null or not widget.has_method("set_empower_state"): continue
		var card: Dictionary = scene._card_def(scene._card_id_for_hand_index(index), scene._combat_state)
		var raised: bool = index == scene._selected_card_index or index == scene._hovered_card_index or (scene._controller_hand_focused and index == scene._controller_hand_index)
		var has_empower: bool = Keywords.has_empower(card)
		widget.set_empower_state(has_empower, scene._hand_card_empowered(index), raised, blocked_health(scene, index) > 0 if has_empower else false, locked(scene, index) or scene._animation_lock, scene.get_node("/root/InputRouter").empower_glyph_label(), tooltip(scene, index) if has_empower else "")
		if not widget.empower_toggled.is_connected(scene._on_hand_empower_toggled):
			widget.empower_toggled.connect(scene._on_hand_empower_toggled.bind(widget))

static func toggle(scene: Node, index: int, source: String) -> void:
	if not can_attempt(scene, index): return
	if blocked_health(scene, index) > 0:
		scene._sfx_router.card_invalid()
		return
	scene._empower_charge.observe(scene._combat_state)
	var phase: String = "drag" if scene._drag_card_index >= 0 else ("confirm" if scene._pending_card_requires_confirmation() else ("targeting" if scene._selected_card_index >= 0 else "hand"))
	scene._empower_charge.toggle(index)
	scene._mark_combat_preview_state_changed()
	var preview: Dictionary = scene._sanitize_preview_for_umbra_information(scene._card_preview_for_index(index))
	if (index == scene._selected_card_index or index == scene._drag_card_index) and not bool(preview.get("playable", false)):
		scene._empower_charge.toggle(index)
		scene._mark_combat_preview_state_changed()
		return
	# Successful input toggles own their sound. Play before the awaited preview;
	# automatic charge removal/observation must stay silent.
	if scene._hand_card_empowered(index):
		scene._sfx_bank.play("empower.charge")
	else:
		scene._sfx_bank.play("empower.uncharge")
	if index == scene._drag_card_index:
		scene._drag_card_options = scene._card_play_options_for_index(index).duplicate(false)
	if index == scene._selected_card_index:
		await scene._begin_card_preview(index, preview, scene._selected_card_label_override, false, true)
	else:
		scene._refresh_card_preview_ui()
	if scene._drag_card_proxy != null:
		var proxy_widget: Control = scene._drag_card_proxy.get_child(0)
		var display: Dictionary = scene._card_widget_display_for_index(index)
		proxy_widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []), int(display.get("time_surcharge", 0)))
		proxy_widget.set_empower_state(true, scene._hand_card_empowered(index), true, false, false, scene.get_node("/root/InputRouter").empower_glyph_label(), tooltip(scene, index))
	sync_widgets(scene)
	scene._analytics_store.write_event("empower_toggled", scene._analytics_context_from_states(scene._run_state, scene._combat_state), {"card_id": scene._card_id_for_hand_index(index), "on": scene._hand_card_empowered(index), "source": source, "phase": phase})
	scene._refresh_controller_prompts()

static func observe_targeting_pointer(scene: Node, event: InputEvent) -> void:
	# Modal GUI ownership suspends the arrow, not knowledge of the pointer.
	# Track motion before the scene's modal input guards can return early.
	if scene._selected_card_index >= 0 and event is InputEventMouseMotion:
		scene._card_targeting_pointer_position = (event as InputEventMouseMotion).position

static func pointer_on_board(scene: Node, point: Vector2) -> bool:
	var hovered: Control = scene.get_viewport().gui_get_hovered_control()
	# The viewport hover cache can still name the hand/HUD during a release
	# or modal handoff. Only a control at this endpoint can own it. The board's
	# full-screen ancestors are layout containers, not competing HUD controls.
	if (hovered != null and hovered != scene.board_view
		and not hovered.is_ancestor_of(scene.board_view)
		and not scene.board_view.is_ancestor_of(hovered)
		and scene._control_visual_global_rect(hovered).has_point(point)):
		return false
	return scene._drag_board_tile_at(point).x >= 0
