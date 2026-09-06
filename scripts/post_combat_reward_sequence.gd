extends RefCounted
class_name PostCombatRewardSequence

const AssetLoader = preload("res://scripts/asset_loader.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const VICTORY_LABEL_NAME: String = "PostCombatVictoryLabel"
const CARD_BACK_NAME: String = "RewardRevealCardBack"
const CARD_FRAME_NAME: String = "CardScaleFrame"

const VICTORY_FONT_SIZE: int = 132
const VICTORY_REDUCED_HOLD_SECONDS: float = 0.22
const VICTORY_UNFURL_SECONDS: float = 0.30
const VICTORY_SETTLE_SECONDS: float = 0.08
const VICTORY_HOLD_SECONDS: float = 0.26
const VICTORY_FADE_SECONDS: float = 0.22
const BANNER_UNFURL_SECONDS: float = 0.30
const CARD_BACK_ENTRY_SECONDS: float = 0.22
const CARD_BACK_ENTRY_STAGGER_SECONDS: float = 0.075
const CARD_BACK_HOLD_SECONDS: float = 0.14
const CARD_FLIP_CLOSE_SECONDS: float = 0.10
const CARD_FLIP_OPEN_SECONDS: float = 0.13
const CARD_SETTLE_SECONDS: float = 0.09
const SECONDARY_ACTION_FADE_SECONDS: float = 0.18


static func build_victory_overlay(stage_host: Control) -> Control:
	var overlay := Control.new()
	overlay.name = "PostCombatVictoryOverlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.z_index = 84
	stage_host.add_child(overlay)

	var label := Label.new()
	label.name = VICTORY_LABEL_NAME
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.5
	label.anchor_top = 0.46
	label.anchor_right = 0.5
	label.anchor_bottom = 0.46
	label.offset_left = -640.0
	label.offset_top = -108.0
	label.offset_right = 640.0
	label.offset_bottom = 108.0
	label.text = "VICTORY"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.apply_label_role(label, UiTypography.ROLE_BANNER)
	UiTypography.set_label_size(label, VICTORY_FONT_SIZE)
	UiTypography.apply_stone_text(label, 0.17, 5.0)
	label.add_theme_color_override("font_color", Color("f7dfaa"))
	label.add_theme_color_override("font_outline_color", Color("241108"))
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 12)
	overlay.add_child(label)
	return overlay


static func victory_label(overlay: Control) -> Label:
	if overlay == null:
		return null
	return overlay.get_node_or_null(VICTORY_LABEL_NAME) as Label


static func show_victory_proof_state(overlay: Control) -> void:
	var label: Label = victory_label(overlay)
	if overlay == null or label == null:
		return
	overlay.visible = true
	label.visible = true
	label.modulate = Color.WHITE
	label.scale = Vector2.ONE
	label.rotation = 0.0
	label.pivot_offset = label.size * 0.5


static func hide_victory(overlay: Control) -> void:
	if overlay == null:
		return
	overlay.visible = false
	var label: Label = victory_label(overlay)
	if label != null:
		label.modulate = Color.WHITE
		label.scale = Vector2.ONE
		label.rotation = 0.0


# The musical resolution continues under the reward choices. Its reverb tail
# must never become an input lock: celebrate the result, then let players choose.
static func victory_hold_seconds(reduced_motion: bool) -> float:
	return VICTORY_REDUCED_HOLD_SECONDS if reduced_motion else VICTORY_HOLD_SECONDS


static func victory_sequence_seconds(reduced_motion: bool) -> float:
	var hold_seconds: float = victory_hold_seconds(reduced_motion)
	if reduced_motion:
		return hold_seconds
	return VICTORY_UNFURL_SECONDS + VICTORY_SETTLE_SECONDS + hold_seconds + VICTORY_FADE_SECONDS


static func play_victory(overlay: Control, reduced_motion: bool) -> void:
	var label: Label = victory_label(overlay)
	if overlay == null or label == null or not overlay.is_inside_tree():
		return
	show_victory_proof_state(overlay)
	await overlay.get_tree().process_frame
	label.pivot_offset = label.size * 0.5
	if reduced_motion:
		await overlay.get_tree().create_timer(victory_hold_seconds(true)).timeout
		hide_victory(overlay)
		return

	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.scale = Vector2(0.04, 0.86)
	label.rotation = deg_to_rad(-1.2)
	var unfurl: Tween = label.create_tween().set_parallel(true)
	unfurl.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unfurl.tween_property(label, "scale", Vector2(1.04, 1.0), VICTORY_UNFURL_SECONDS)
	unfurl.tween_property(label, "rotation", 0.0, VICTORY_UNFURL_SECONDS)
	unfurl.tween_property(label, "modulate:a", 1.0, VICTORY_UNFURL_SECONDS * 0.58)
	await unfurl.finished
	var settle: Tween = label.create_tween()
	settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(label, "scale", Vector2.ONE, VICTORY_SETTLE_SECONDS)
	await settle.finished
	await overlay.get_tree().create_timer(victory_hold_seconds(false)).timeout
	var fade: Tween = label.create_tween().set_parallel(true)
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(label, "modulate:a", 0.0, VICTORY_FADE_SECONDS)
	fade.tween_property(label, "scale", Vector2(1.08, 0.94), VICTORY_FADE_SECONDS)
	await fade.finished
	hide_victory(overlay)


static func prepare_banner(banner: TextureRect, title: Label) -> void:
	if banner != null:
		banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
		banner.scale = Vector2(0.055, 0.84)
	if title != null:
		title.modulate = Color(1.0, 1.0, 1.0, 0.0)
		title.scale = Vector2(0.86, 0.96)


static func prepare_card_slot(slot: Control, card_back_texture_path: String) -> void:
	if slot == null:
		return
	var scaler: Control = slot.find_child(CARD_FRAME_NAME, true, false) as Control
	var widget: Control = slot.find_child("CardWidget", true, false) as Control
	if scaler == null or widget == null:
		return
	var back: TextureRect = scaler.get_node_or_null(CARD_BACK_NAME) as TextureRect
	if back == null:
		back = TextureRect.new()
		back.name = CARD_BACK_NAME
		back.texture = AssetLoader.load_texture(card_back_texture_path)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# The face is hidden while the back is visible, so the back does not need
		# to sort above neighboring card slots. A high cross-slot z-index causes
		# Godot to flatten the still-hidden backs during a neighboring card flip.
		back.z_index = 0
		scaler.add_child(back)
		scaler.move_child(back, scaler.get_child_count() - 1)
	slot.set_meta("reward_reveal_prepared", true)
	scaler.set_meta("reward_reveal_base_position", scaler.position)
	scaler.set_meta("reward_reveal_base_scale", scaler.scale)
	widget.set_meta("reward_reveal_focus_mode", widget.focus_mode)
	widget.set_meta("reward_reveal_mouse_filter", widget.mouse_filter)
	widget.focus_mode = Control.FOCUS_NONE
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.visible = false
	back.visible = true
	slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	scaler.position = (scaler.get_meta("reward_reveal_base_position") as Vector2) + Vector2(0.0, 58.0)


static func prepare_secondary_actions(actions: Control) -> void:
	if actions == null:
		return
	actions.set_meta("reward_reveal_prepared", true)
	actions.modulate = Color(1.0, 1.0, 1.0, 0.0)
	for child: Node in actions.get_children():
		if child is Control:
			var control: Control = child as Control
			control.set_meta("reward_reveal_focus_mode", control.focus_mode)
			control.set_meta("reward_reveal_mouse_filter", control.mouse_filter)
			control.focus_mode = Control.FOCUS_NONE
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func settle_banner(banner: TextureRect, title: Label) -> void:
	if banner != null:
		banner.pivot_offset = banner.size * 0.5
		banner.modulate = Color.WHITE
		banner.scale = Vector2.ONE
	if title != null:
		title.pivot_offset = title.size * 0.5
		title.modulate = Color.WHITE
		title.scale = Vector2.ONE


static func show_card_back(slot: Control) -> void:
	var scaler: Control = _card_scaler(slot)
	if slot == null or scaler == null:
		return
	var back: TextureRect = scaler.get_node_or_null(CARD_BACK_NAME) as TextureRect
	var widget: Control = slot.find_child("CardWidget", true, false) as Control
	_restore_card_transform(slot, scaler)
	slot.modulate = Color.WHITE
	if widget != null:
		widget.visible = false
	if back != null:
		back.visible = true


static func reveal_card_face(slot: Control, restore_interaction: bool = false) -> void:
	var scaler: Control = _card_scaler(slot)
	if slot == null or scaler == null:
		return
	var back: TextureRect = scaler.get_node_or_null(CARD_BACK_NAME) as TextureRect
	var widget: Control = slot.find_child("CardWidget", true, false) as Control
	_restore_card_transform(slot, scaler)
	slot.modulate = Color.WHITE
	if back != null:
		back.visible = false
	if widget != null:
		widget.visible = true
		if restore_interaction:
			_restore_interaction(widget)


static func settle_secondary_actions(actions: Control, restore_interaction: bool = true) -> void:
	if actions == null:
		return
	actions.modulate = Color.WHITE
	if restore_interaction:
		for child: Node in actions.get_children():
			if child is Control:
				_restore_interaction(child as Control)


static func settle_reward(
	banner: TextureRect,
	title: Label,
	card_slots: Array[Control],
	secondary_actions: Control
) -> void:
	settle_banner(banner, title)
	for slot: Control in card_slots:
		reveal_card_face(slot, true)
	settle_secondary_actions(secondary_actions, true)


static func play_reward_reveal(
	sequence_host: Control,
	banner: TextureRect,
	title: Label,
	card_slots: Array[Control],
	secondary_actions: Control,
	reduced_motion: bool,
	card_flip_cue: Callable = Callable()
) -> void:
	if sequence_host == null or not sequence_host.is_inside_tree():
		return
	await sequence_host.get_tree().process_frame
	if reduced_motion:
		settle_reward(banner, title, card_slots, secondary_actions)
		return

	if banner != null:
		banner.pivot_offset = banner.size * 0.5
	if title != null:
		title.pivot_offset = title.size * 0.5
	# One timeline owns every reveal track. The banner and deal overlap, then
	# faces turn in a short ripple instead of waiting for each card to settle.
	# Interaction is restored once, after all faces and actions are readable.
	var reveal: Tween = sequence_host.create_tween().set_parallel(true)
	if banner != null:
		reveal.tween_property(banner, "scale", Vector2.ONE, BANNER_UNFURL_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(banner, "modulate:a", 1.0, BANNER_UNFURL_SECONDS * 0.62)
	if title != null:
		reveal.tween_property(title, "scale", Vector2.ONE, BANNER_UNFURL_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(title, "modulate:a", 1.0, BANNER_UNFURL_SECONDS * 0.72).set_delay(0.04)

	var last_flip_end: float = BANNER_UNFURL_SECONDS
	for index: int in range(card_slots.size()):
		var slot: Control = card_slots[index]
		var scaler: Control = _card_scaler(slot)
		if scaler == null:
			continue
		var base_position: Vector2 = scaler.get_meta("reward_reveal_base_position", scaler.position) as Vector2
		var entry_delay: float = 0.06 + float(index) * CARD_BACK_ENTRY_STAGGER_SECONDS
		reveal.tween_property(slot, "modulate:a", 1.0, CARD_BACK_ENTRY_SECONDS).set_delay(entry_delay)
		reveal.tween_property(scaler, "position", base_position, CARD_BACK_ENTRY_SECONDS).set_delay(entry_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var flip_delay: float = entry_delay + CARD_BACK_ENTRY_SECONDS + CARD_BACK_HOLD_SECONDS
		_schedule_card_flip(reveal, slot, flip_delay, card_flip_cue)
		last_flip_end = flip_delay + CARD_FLIP_CLOSE_SECONDS + CARD_FLIP_OPEN_SECONDS + CARD_SETTLE_SECONDS

	if secondary_actions != null:
		reveal.tween_property(secondary_actions, "modulate:a", 1.0, SECONDARY_ACTION_FADE_SECONDS).set_delay(maxf(0.0, last_flip_end - SECONDARY_ACTION_FADE_SECONDS)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Also supports an empty offer without constructing an empty Tween.
	reveal.tween_interval(last_flip_end)
	await reveal.finished
	settle_reward(banner, title, card_slots, secondary_actions)


static func _schedule_card_flip(timeline: Tween, slot: Control, delay: float, card_flip_cue: Callable) -> void:
	var scaler: Control = _card_scaler(slot)
	if scaler == null:
		return
	var base_scale: Vector2 = scaler.get_meta("reward_reveal_base_scale", scaler.scale) as Vector2
	var closed_scale := Vector2(maxf(0.01, base_scale.x * 0.045), base_scale.y * 1.025)
	var open_scale := base_scale * 1.045
	if card_flip_cue.is_valid():
		timeline.tween_callback(card_flip_cue).set_delay(delay)
	timeline.tween_property(scaler, "scale", closed_scale, CARD_FLIP_CLOSE_SECONDS).set_delay(delay).from(base_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var face_time: float = delay + CARD_FLIP_CLOSE_SECONDS
	timeline.tween_callback(_show_flipped_face.bind(slot)).set_delay(face_time)
	timeline.tween_property(scaler, "scale", open_scale, CARD_FLIP_OPEN_SECONDS).set_delay(face_time).from(closed_scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	timeline.tween_property(scaler, "scale", base_scale, CARD_SETTLE_SECONDS).set_delay(face_time + CARD_FLIP_OPEN_SECONDS).from(open_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _show_flipped_face(slot: Control) -> void:
	if not is_instance_valid(slot):
		return
	var scaler: Control = _card_scaler(slot)
	if scaler == null:
		return
	var back: TextureRect = scaler.get_node_or_null(CARD_BACK_NAME) as TextureRect
	var widget: Control = slot.find_child("CardWidget", true, false) as Control
	if back != null:
		back.visible = false
	if widget != null:
		widget.visible = true


static func _flip_card(slot: Control, card_flip_cue: Callable = Callable()) -> void:
	if _card_scaler(slot) == null:
		return
	var flip: Tween = slot.create_tween().set_parallel(true)
	_schedule_card_flip(flip, slot, 0.0, card_flip_cue)
	await flip.finished


static func _card_scaler(slot: Control) -> Control:
	if slot == null:
		return null
	return slot.find_child(CARD_FRAME_NAME, true, false) as Control


static func _restore_card_transform(slot: Control, scaler: Control) -> void:
	var base_position: Vector2 = scaler.get_meta("reward_reveal_base_position", scaler.position) as Vector2
	var base_scale: Vector2 = scaler.get_meta("reward_reveal_base_scale", scaler.scale) as Vector2
	scaler.position = base_position
	scaler.scale = base_scale


static func _restore_interaction(control: Control) -> void:
	if control == null:
		return
	if control.has_meta("reward_reveal_focus_mode"):
		control.focus_mode = int(control.get_meta("reward_reveal_focus_mode"))
	if control.has_meta("reward_reveal_mouse_filter"):
		control.mouse_filter = int(control.get_meta("reward_reveal_mouse_filter"))
