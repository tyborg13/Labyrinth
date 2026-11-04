extends RefCounted

const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const SETTLE_TIMEOUT_MSEC: int = 3000

static func settle(tree: SceneTree, scene: Node, expect: Callable, context: String) -> void:
	var hand: Control = scene.get("hand_box")
	var stack: Control = scene.get("_card_focus_tooltip_stack")
	var index: int = int(scene.get("_controller_hand_index"))
	var deadline: int = Time.get_ticks_msec() + SETTLE_TIMEOUT_MSEC
	var hidden_during_lift: bool = true
	# Process time alone never completes a rendered rest with the dummy renderer.
	# Keep production's actual rest/lift gate; model only the missing draw boundary.
	while bool(scene.get("_hand_hover_rest_pending")) or hand.emphasis_strength() < 1.0 or hand.is_sliding():
		hidden_during_lift = hidden_during_lift and not stack.visible
		if Time.get_ticks_msec() >= deadline:
			break
		await TestClock.rendered_frames(tree, 1)
	expect.call(hidden_during_lift, context + ": keyword stack stays hidden until the controller lift settles")
	expect.call(not bool(scene.get("_hand_hover_rest_pending")) and is_equal_approx(hand.emphasis_strength(), 1.0) and not hand.is_sliding(), context + ": controller lift and rendered rest complete")
	expect.call(int(scene.get("_controller_hand_index")) == index and int(scene.get("_hovered_card_index")) == index, context + ": the settled preview still follows controller focus")
