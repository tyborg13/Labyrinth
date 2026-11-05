extends RefCounted
## Layout C (hud-02): Pass is right-aligned above the piles, independent of
## hand width. Share that contract between the hand-flow test and visual probes.

const APPROVED_PASS_PILE_GAP: float = 10.0
const RECT_TOLERANCE: float = 1.0

static func assert_layout(scene: Node, expect: Callable, context: String) -> void:
	var pass_chip: Control = scene.find_child("PassPreviewChip", true, false) as Control
	var draw: Control = scene.get("draw_pile") as Control
	var discard: Control = scene.get("discard_pile") as Control
	expect.call(pass_chip != null and draw != null and discard != null, "%s needs Pass and both piles" % context)
	if pass_chip == null or draw == null or discard == null:
		return
	var pass_rect: Rect2 = pass_chip.get_global_rect()
	var piles: Rect2 = draw.get_global_rect().merge(discard.get_global_rect())
	expect.call(pass_rect.has_area() and piles.has_area(), "%s Pass/pile dock must have settled geometry" % context)
	expect.call(absf(pass_rect.end.x - piles.end.x) <= RECT_TOLERANCE, "%s Pass must stay right-aligned with the piles" % context)
	expect.call(absf(piles.position.y - pass_rect.end.y - APPROVED_PASS_PILE_GAP) <= RECT_TOLERANCE, "%s Pass must keep layout C's ten-pixel gap above the piles" % context)

static func assert_hand_clearance(scene: Node, expect: Callable, context: String, hand_bounds: Rect2) -> void:
	if not hand_bounds.has_area():
		return
	var pass_chip: Control = scene.find_child("PassPreviewChip", true, false) as Control
	var controls: Array[Control]
	controls.assign([pass_chip, scene.get("draw_pile"), scene.get("discard_pile")])
	for control: Control in controls:
		if control != null and control.is_visible_in_tree():
			expect.call(not hand_bounds.intersects(control.get_global_rect()), "%s hand %s must stay clear of %s %s" % [context, hand_bounds, control.name, control.get_global_rect()])

static func assert_presented_hand_clearance(scene: Node, expect: Callable, context: String, draw_entries: Array = []) -> void:
	var hand: Control = scene.get("hand_box") as Control
	if hand != null and hand.is_visible_in_tree():
		for index: int in range(hand.get_child_count()):
			var card: Control = scene.call("_hand_card_control", index) as Control
			if card != null and card.is_visible_in_tree():
				assert_hand_clearance(scene, expect, "%s card %d" % [context, index], scene.call("_control_visual_global_rect", card))
	# The incoming flight starts at the draw pile. Check its fan destination and
	# every arrived proxy, rather than treating the hidden old hand as painted.
	var proxies: Array = scene.get("_draw_hand_transition_proxies") as Array
	if proxies.is_empty():
		return
	var size: Vector2 = scene.call("_hand_card_size", proxies.size(), false)
	var incoming: Array[int]
	for entry: Dictionary in draw_entries:
		incoming.append(int(entry.get("index", -1)))
	for index: int in range(proxies.size()):
		assert_hand_clearance(scene, expect, "%s deal destination %d" % [context, index], scene.call("_hand_receive_rect", index, proxies.size(), size))
		var proxy: Control = proxies[index] as Control
		if not is_instance_valid(proxy) or not proxy.is_visible_in_tree():
			continue
		var tween: Tween = proxy.get_meta("active_card_proxy_tween") as Tween if proxy.has_meta("active_card_proxy_tween") else null
		if not incoming.has(index) or tween == null or not tween.is_valid() or not tween.is_running():
			assert_hand_clearance(scene, expect, "%s retained/arrived card %d" % [context, index], scene.call("_card_proxy_visual_rect", proxy))
