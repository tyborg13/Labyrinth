extends RefCounted

# Refreshes and container signals share a deferred placement pass. A later
# container sort must be allowed another pass in the same idle queue, before
# drawing; a frame cap would expose placement based on the old container sizes.
var _pending: Dictionary = {}
var _scheduled: bool = false
const ORDER: Array = [
	&"_sync_hand_side_widths", &"_layout_header_hud", &"_layout_turn_order_anchor",
	&"_layout_combat_piles", &"_layout_combat_action_dock", &"_layout_choice_button_overlay",
	&"_layout_combat_objective_hud", &"_layout_relic_choice_overlay", &"_layout_action_step_tracker"
]

func request(scene: Control, method: StringName) -> void:
	_pending[method] = true
	if _scheduled: return
	_scheduled = true
	_flush.call_deferred(weakref(scene))

func _flush(owner: WeakRef) -> void:
	# Consume this pass before calling layout. Signals raised during or after it
	# can queue fresh work, including a method already present in this batch.
	var pending: Dictionary = _pending
	_pending = {}
	_scheduled = false
	var scene: Variant = owner.get_ref()
	if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion():
		return
	for method: StringName in ORDER:
		if pending.has(method): scene.call(method)
