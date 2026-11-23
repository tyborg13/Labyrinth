extends RefCounted

const KeyBindings = preload("res://scripts/key_bindings.gd")

## Pass and 1–9 do exactly what a click does when their controls are clickable.
## Digits follow the layout with a top-row position fallback for symbol rows
## such as AZERTY. Letter keys never count as card picks.

static func handle(scene: Control, event: InputEvent) -> bool:
	if _typing(scene): return false
	if KeyBindings.pressed(KeyBindings.PASS, event):
		if not _pass_clickable(scene): return false
		scene.get_viewport().set_input_as_handled()
		# The chip's pressed handler, as a click runs it.
		scene._on_pass_turn_pressed()
		return true
	var index: int = hand_index(event)
	if index < 0 or not _hand_card_clickable(scene, index): return false
	scene.get_viewport().set_input_as_handled()
	scene._on_card_pressed(index)
	return true

# While a skill asks for a hand card (Quick Wits), a click on a card picks it.
static func handle_skill_card_selection(scene: Control, event: InputEvent) -> bool:
	var index: int = hand_index(event)
	if index < 0 or _typing(scene) or scene._combat_skill_card_selection_zone != "hand" or scene._animation_lock: return false
	if scene._controller_modal_visible() or scene._visible_control(scene._run_end_recap): return false
	scene.get_viewport().set_input_as_handled()
	scene._on_combat_skill_hand_card_selected(index)
	return true

static func hand_index(event: InputEvent) -> int:
	var key := event as InputEventKey
	if not _plain_press(key): return -1
	if key.keycode >= KEY_1 and key.keycode <= KEY_9: return key.keycode - KEY_1
	if key.keycode >= KEY_KP_1 and key.keycode <= KEY_KP_9: return key.keycode - KEY_KP_1
	if key.keycode >= KEY_A and key.keycode <= KEY_Z: return -1
	if key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9: return key.physical_keycode - KEY_1
	return -1

static func _typing(scene: Control) -> bool:
	var focus: Control = scene.get_viewport().gui_get_focus_owner()
	return (focus is LineEdit or focus is TextEdit) and focus.is_visible_in_tree()

static func _plain_press(key: InputEventKey) -> bool:
	return key != null and key.pressed and not key.echo and not (key.alt_pressed or key.ctrl_pressed or key.meta_pressed or key.shift_pressed)

# Clickable means shown and not greyed out: the chip and the availability it
# mirrors (a selected or confirming card, a held drag, animation, the enemy
# turn and skill selection all grey it out), with no modal or menu covering it.
static func _pass_clickable(scene: Control) -> bool:
	var chip: Button = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip") if scene._pass_preview_overlay != null else scene.choice_bar.get_node_or_null("PassPreviewChip")
	return (
		chip != null and chip.is_visible_in_tree() and not chip.disabled
		and scene._pass_preview_action_available()
		and not scene._controller_modal_visible()
		and not scene._visible_control(scene._run_end_recap)
	)

# A click reaches _on_card_pressed only through an interactive hand card: none
# behind a modal or menu, while the board animates, or during a drag.
static func _hand_card_clickable(scene: Control, index: int) -> bool:
	return (
		str(scene._run_state.get("mode", "")) == "combat"
		and not scene._animation_lock
		and scene._drag_card_index < 0
		and not scene._controller_modal_visible()
		and not scene._visible_control(scene._run_end_recap)
		and not scene._card_id_for_hand_index(index).is_empty()
		and scene._hand_card_control(index) != null
	)
