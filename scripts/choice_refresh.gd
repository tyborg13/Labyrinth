extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")

const Prepared = preload("res://scripts/prepared_reward_choices.gd")
var _reward_inputs: Dictionary = {}
var _reward_children: Array = []

func refresh(scene: Control, reward_jobs: Variant = null) -> void:
	scene.board_view.set_tooltips_enabled(str(scene._run_state.get("mode", "room")) != "reward")
	scene._sync_treasure_room_reveal()
	if scene._scavenger_shop_view != null:
		scene._scavenger_shop_view.dismiss_immediately()
	var retained_reward: bool = _retain_reward(scene)
	scene._clear_children(scene.choice_bar)
	if scene._choice_button_overlay != null:
		scene._clear_children_now(scene._choice_button_overlay)
		scene._choice_button_overlay.visible = false
	if str(scene._run_state.get("mode", "room")) != "combat" and scene._pass_preview_overlay != null:
		scene._clear_children_now(scene._pass_preview_overlay)
	if scene._pass_preview_overlay != null:
		scene._pass_preview_overlay.visible = false
	scene._clear_context_choice_overlay()
	if not retained_reward: scene._clear_relic_choice_overlay()
	scene._sync_merchant_shop_room()
	var mode: String = str(scene._run_state.get("mode", "room"))
	if scene._graftwright_view != null and mode != "graftwright": scene._graftwright_view.hide()
	var relic_offer_sfx_signature: String = ""
	if mode not in ["victory", "defeat", "embrace"] and scene._run_end_recap != null:
		scene._run_end_recap.reset()
	scene.choice_bar.custom_minimum_size = Vector2.ZERO
	if scene._dialogue_active and scene._dialogue_suppresses_choices:
		scene.choice_bar.visible = false
		return
	if mode == "combat" and not scene._combat_state.is_empty() and scene._combat_engine.is_player_turn(scene._combat_state):
		scene._add_pass_preview_chip()
	match mode:
		"graftwright":
			scene._graftwright_view.configure(scene._run_state, scene._reduced_motion_enabled())
			scene._graftwright_view.present()
		"combat":
			if scene._surface_aim.active():
				scene._add_surface_skill_choices()
		"room":
			var merchant_kind: String = scene._current_room_merchant_kind()
			if not merchant_kind.is_empty():
				if scene._merchant_shop_open:
					scene._scavenger_shop_view.configure(scene._run_state, scene._run_engine, scene._reduced_motion_enabled(), scene._record_runtime_performance_phase if scene._runtime_performance_instrumentation_enabled else Callable())
					scene._scavenger_shop_view.present()
					preload("res://scripts/magic_purge_overlay.gd").install_scavenger(scene, scene._scavenger_shop_view)
				else:
					scene._add_merchant_return_to_shop_button()
			elif scene._run_engine.can_speak_to_emaciated_man(scene._run_state):
				scene._add_context_choice_button("Speak", scene._speak_to_emaciated_man, "Speak to the Emaciated Man.")
				if scene._run_engine.can_use_emaciated_services(scene._run_state):
					scene._add_context_choice_button("Awaken Power", scene._show_emaciated_services, "Trade Moltshards for Embers or purchase levels.")
		"campfire":
			scene._add_campfire_choice(
				"linger",
				scene.CAMPFIRE_CHOICE_LINGER_TEXT,
				scene.CAMPFIRE_CHOICE_LINGER_DESCRIPTION,
				scene.CAMPFIRE_CHOICE_LINGER_ICON_PATH,
				scene.CAMPFIRE_LINGER_ACCENT
			)
			scene._add_campfire_choice(
				"embrace",
				scene.CAMPFIRE_CHOICE_EMBRACE_TEXT,
				scene.CAMPFIRE_CHOICE_EMBRACE_DESCRIPTION,
				scene.CAMPFIRE_CHOICE_EMBRACE_ICON_PATH,
				scene.CAMPFIRE_EMBRACE_ACCENT
			)
			scene._add_campfire_choice(
				"strength",
				scene.CAMPFIRE_CHOICE_STRENGTH_TEXT,
				scene._campfire_strength_description(),
				scene.CAMPFIRE_CHOICE_STRENGTH_ICON_PATH,
				scene.CAMPFIRE_STRENGTH_ACCENT,
				scene._can_level_at_campfire()
			)
			var has_spells: bool = not preload("res://scripts/magic_deck_list.gd").entries(scene._run_state.get("attuned_magic_cards", [])).is_empty()
			scene._add_campfire_choice(
				"purge",
				scene.CAMPFIRE_CHOICE_PURGE_TEXT,
				scene.CAMPFIRE_CHOICE_PURGE_DESCRIPTION if has_spells else scene.CAMPFIRE_CHOICE_PURGE_EMPTY_DESCRIPTION,
				scene.CAMPFIRE_CHOICE_PURGE_ICON_PATH,
				UiPalette.DANGER,
				has_spells
			)
		"reward":
			if not retained_reward and not scene._reward_intro_suppressed and scene._reward_choices_available():
				if scene._run_engine.is_dragon_reward(scene._run_state):
					scene._set_relic_choice_title("DRAGON VANQUISHED")
					scene._add_dragon_reward_stack()
				else:
					scene._set_relic_choice_title(scene.REWARD_CHOICE_TITLE_TEXT)
					scene._add_reward_choice_stack(reward_jobs)
		"treasure":
			var pending_relics: Array = [] if scene._treasure_reveal_active else (scene._run_state.get("pending_relics", []) as Array).duplicate()
			if not pending_relics.is_empty():
				relic_offer_sfx_signature = "%s:%s" % [str(scene._run_state.get("current_room", Vector2i.ZERO)), JSON.stringify(pending_relics)]
				scene._set_relic_choice_title(scene.RELIC_CHOICE_TITLE_TEXT)
			for relic_id_var: Variant in pending_relics:
				var relic_id: String = str(relic_id_var)
				var relic: Dictionary = GameData.relic_def(relic_id)
				scene._add_relic_choice(relic_id, relic)
			scene._configure_relic_choice_focus()
		"victory", "defeat", "embrace":
			scene._show_run_end_recap(mode)
	var has_overlay_choices: bool = scene._choice_button_overlay != null and scene._choice_button_overlay.get_child_count() > 0
	var has_pass_preview: bool = mode == "combat" and not scene._combat_state.is_empty() and scene._combat_engine.is_player_turn(scene._combat_state) and not (scene._dialogue_active and scene._dialogue_suppresses_choices) and scene._pass_preview_overlay != null and scene._pass_preview_overlay.get_child_count() > 0
	scene.choice_bar.visible = scene.choice_bar.get_child_count() > 0
	if scene._choice_button_overlay != null:
		scene._choice_button_overlay.visible = has_overlay_choices
	if scene._pass_preview_overlay != null:
		scene._pass_preview_overlay.visible = has_pass_preview
	if scene._choice_button_overlay != null or scene._pass_preview_overlay != null:
		scene._queue_choice_button_overlay_layout()
	scene._refresh_action_step_tracker()
	if scene._context_choice_overlay != null:
		scene._context_choice_overlay.visible = scene._context_choice_bar != null and scene._context_choice_bar.get_child_count() > 0
	if scene._relic_choice_overlay != null:
		var has_relic_choices: bool = scene._relic_choice_bar != null and scene._relic_choice_bar.get_child_count() > 0
		var has_selection_title: bool = scene._relic_choice_title != null and scene._relic_choice_title.visible
		if scene._relic_choice_backdrop != null:
			scene._relic_choice_backdrop.visible = mode in ["reward", "treasure"] and (has_relic_choices or has_selection_title)
		if scene._relic_choice_host != null:
			scene._relic_choice_host.visible = has_relic_choices
		scene._relic_choice_overlay.visible = has_relic_choices or has_selection_title
		if scene._relic_choice_overlay.visible:
			scene._hud_refresh_layout.request(scene, &"_layout_relic_choice_overlay")
	if mode == "campfire":
		var hearth_key: String = "%s:%s:%s" % [scene._run_state.get("seed", 0), scene._run_state.get("run_index", 0), scene._run_state.get("current_room", Vector2i.ZERO)]
		scene._campfire_presentation.present(scene, scene._relic_choice_bar, hearth_key, scene._reduced_motion_enabled(), scene._play_sfx)
	remember_reward(scene)
	if relic_offer_sfx_signature.is_empty():
		scene._relic_choices_open_sfx_signature = ""
	else:
		scene._play_relic_choices_open_sfx_once(relic_offer_sfx_signature)


func _retain_reward(scene: Control) -> bool:
	if str(scene._run_state.get("mode", "")) != "reward" or scene._reward_intro_suppressed or scene._reward_reveal_pending or scene._run_engine.is_dragon_reward(scene._run_state):
		_reward_inputs.clear()
		_reward_children.clear()
		return false
	return not _reward_inputs.is_empty() and _reward_children == scene._relic_choice_bar.get_children() and _reward_inputs == reward_inputs(scene)

func remember_reward(scene: Control) -> void:
	if str(scene._run_state.get("mode", "")) == "reward" and not scene._reward_intro_suppressed and not scene._run_engine.is_dragon_reward(scene._run_state):
		_reward_inputs = reward_inputs(scene)
		_reward_children = scene._relic_choice_bar.get_children()

static func reward_inputs(scene: Control) -> Dictionary:
	var inputs: Dictionary = Prepared.new()._render_inputs(scene, scene._run_state)
	# Reveal preparation belongs to a new tree, not the completed retained one.
	inputs.erase("reveal")
	return inputs
