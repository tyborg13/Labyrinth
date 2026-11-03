extends RefCounted

# Prepare the existing bounded FX pool before the first card commit. No new
# cache key or display path: acquisition still configures all current card data.
var pending: bool = false
var prepared: bool = false

func request(scene: Node) -> void:
	if prepared or pending or not _eligible(scene): return
	pending = true
	_prepare.call_deferred(weakref(scene))

func _prepare(reference: WeakRef) -> void:
	pending = false
	var scene: Node = reference.get_ref()
	if not is_instance_valid(scene) or not _eligible(scene): return
	# Keep preparation outside selection, drag and card-resolution frames. A later
	# ordinary hand refresh can request it again if this opportunity was cancelled.
	if scene._animation_lock or scene._selected_card_index >= 0 or scene._drag_card_index >= 0: return
	var hand: Array = scene._combat_state["deck"]["hand"]
	var rect := Rect2(Vector2.ZERO, scene.CARD_WIDGET_BASE_SIZE)
	var proxy: Control = scene._spawn_card_proxy(str(hand[0]), rect)
	scene._mount_card_proxy(proxy, scene._card_fx_layer, rect)
	# No yield between mounting and hiding: preparation never submits a visible
	# card. Staying in the same FX host avoids the next tree/theme reconstruction.
	scene._release_card_proxy(proxy)
	prepared = true

func _eligible(scene: Node) -> bool:
	return scene.is_inside_tree() and not scene.is_queued_for_deletion() and str(scene._run_state.get("mode", "")) == "combat" and is_instance_valid(scene._card_fx_layer) and not ((scene._combat_state.get("deck", {}) as Dictionary).get("hand", []) as Array).is_empty()
