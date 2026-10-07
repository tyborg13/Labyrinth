extends "res://scripts/run_scene.gd"

# Frozen synchronous reward constructor before staged startup card jobs.

func _add_reward_choice_stack(_reward_jobs: Variant = null) -> void:
	if _relic_choice_bar == null:
		return
	var reward_state: Dictionary = _run_state.get("pending_reward", {}) as Dictionary
	var reward_cards: Array = reward_state.get("cards", []) as Array
	var heal_amount: int = maxi(0, int(reward_state.get("heal_amount", 0)))
	var stack := VBoxContainer.new()
	stack.name = "RewardChoiceStack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_theme_constant_override("separation", int(REWARD_CHOICE_STACK_GAP))
	_relic_choice_bar.add_child(stack)
	var focusable_cards: Array[Control]
	var action_buttons: Array[Control]

	if not reward_cards.is_empty():
		var card_row := HBoxContainer.new()
		card_row.name = "RewardCardRow"
		card_row.alignment = BoxContainer.ALIGNMENT_CENTER
		card_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_row.add_theme_constant_override("separation", int(REWARD_CHOICE_CARD_GAP))
		stack.add_child(card_row)
		var reward_card_size: Vector2 = _reward_choice_card_size(reward_cards.size(), heal_amount > 0)
		for card_id_var: Variant in reward_cards:
			var card_id: String = str(card_id_var)
			var widget = CardWidgetScene.instantiate()
			widget.custom_minimum_size = reward_card_size
			widget.configure(card_id, false, false, true, false, true, true, _card_def(card_id))
			widget.set_hover_pose(REWARD_CARD_HOVER_LIFT, REWARD_CARD_HOVER_SCALE)
			widget.activated.connect(_on_reward_card_pressed.bind(card_id, widget))
			var card_slot: Control = _reward_card_choice_slot(widget, card_id, reward_card_size)
			card_row.add_child(card_slot)
			widget.focus_mode = Control.FOCUS_ALL
			widget.focus_entered.connect(widget.set_external_highlighted.bind(true))
			widget.focus_exited.connect(widget.set_external_highlighted.bind(false))
			widget.gui_input.connect(_on_reward_card_keyboard_input.bind(card_id, widget))
			focusable_cards.append(widget)
			if _reward_reveal_pending:
				PostCombatRewardSequence.prepare_card_slot(card_slot, CARD_BACK_TEXTURE_PATH)

	var has_reroll: bool = _run_engine.run_skill_is_ready(_run_state, "discerning_eye")
	if heal_amount <= 0 and not has_reroll:
		_configure_reward_choice_focus(focusable_cards, action_buttons)
		return
	var action_center := CenterContainer.new()
	action_center.name = "RewardSecondaryActionCenter"
	action_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(action_center)
	var action_row := HBoxContainer.new()
	action_row.name = "RewardSecondaryActions"
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 14)
	action_center.add_child(action_row)
	if has_reroll:
		var reroll_button: UiTooltipButton = _reward_secondary_button(
			"RewardRerollButton",
			"REROLL",
			_on_reward_reroll_pressed,
			SkillTreeLibrary.description("discerning_eye"),
			REWARD_REROLL_BUTTON_MIN_WIDTH
		)
		action_row.add_child(reroll_button)
		action_buttons.append(reroll_button)
	if heal_amount > 0:
		var recover_button: UiTooltipButton = _reward_recover_button(heal_amount)
		action_row.add_child(recover_button)
		action_buttons.append(recover_button)
	_configure_reward_choice_focus(focusable_cards, action_buttons)
	if _reward_reveal_pending:
		PostCombatRewardSequence.prepare_secondary_actions(action_row)

