extends RefCounted

# Live Quick Wits must distinguish a surviving identical card from a fresh draw.
const CARD: String = "kwtest_empower_time"
const FILLER: String = "kwtest_filler"
const FIXTURE_SEED: int = 60307
const CASES: Array = [
	{"name": "uncharged departure before charged survivor", "hand": [CARD, CARD], "charged": [1], "discard": 0, "draw": [FILLER], "flags": [true, false]},
	{"name": "charged departure before uncharged survivor", "hand": [CARD, CARD], "charged": [0], "discard": 0, "draw": [FILLER], "flags": [false, false]},
	{"name": "charged last copy departs", "hand": [CARD, CARD], "charged": [1], "discard": 1, "draw": [FILLER], "flags": [false, false]},
	{"name": "charged survivor and fresh identical draw", "hand": [CARD, CARD], "charged": [0, 1], "discard": 0, "draw": [CARD], "flags": [true, false]},
	{"name": "immediate identical redraw", "hand": [CARD], "charged": [0], "discard": 0, "draw": [CARD], "flags": [false]},
	{"name": "immediate reshuffle and redraw", "hand": [CARD], "charged": [0], "discard": 0, "draw": [], "flags": [false], "cycles": 1},
]

static func run_live(tree: SceneTree, expect: Callable, fixtures: Script) -> void:
	for fixture: Dictionary in CASES:
		var scene: Node = await fixtures._live_instance(tree, expect, fixture["hand"], FIXTURE_SEED)
		var state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
		state["skill_ids"] = ["quick_wits"]
		var deck: Dictionary = state["deck"]
		deck["draw"] = (fixture["draw"] as Array).duplicate()
		deck["discard"] = []
		deck["cycles"] = 0
		scene.set("_combat_state", state)
		(scene.get("_run_state") as Dictionary)["combat_state"] = state
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_refresh_ui")
		for index: int in fixture["charged"]:
			scene.call("_on_card_hover_started", index)
			await scene.call("_toggle_pending_empower")
			expect.call(bool(scene.call("_hand_card_empowered", index)), "%s: fixture copy starts charged" % fixture["name"])
		scene.call("_on_combat_skill_pressed", "quick_wits")
		expect.call(str(scene.get("_combat_skill_card_selection_zone")) == "hand", "%s: Quick Wits opens live hand selection" % fixture["name"])
		await scene.call("_on_card_pressed", int(fixture["discard"]))
		# The hand-click handler starts the asynchronous skill animation. Wait for
		# that live boundary before inspecting the committed hand and its widgets.
		await wait_for_idle(tree, scene, expect)
		var committed: Dictionary = scene.get("_combat_state")
		var actual_hand: Array = (committed.get("deck", {}) as Dictionary).get("hand", [])
		var expected_hand: Array = (fixture["hand"] as Array).duplicate()
		expected_hand.remove_at(int(fixture["discard"]))
		expected_hand.append(CARD if (fixture["draw"] as Array).is_empty() else fixture["draw"][0])
		expect.call(actual_hand == expected_hand, "%s: the live skill commits its discard and replacement draw" % fixture["name"])
		expect.call(bool((committed.get("skill_flags", {}) as Dictionary).get("used:quick_wits", false)), "%s: Quick Wits really ran" % fixture["name"])
		expect.call(int((committed.get("deck", {}) as Dictionary).get("cycles", 0)) == int(fixture.get("cycles", 0)), "%s: the expected reshuffle occurred" % fixture["name"])
		for index: int in range((fixture["flags"] as Array).size()):
			var expected: bool = bool(fixture["flags"][index])
			expect.call(bool(scene.call("_hand_card_empowered", index)) == expected, "%s: hand copy %d has the correct charge" % [fixture["name"], index])
			if actual_hand[index] == CARD:
				var seal: Node = (scene.call("_hand_card_control", index) as Node).get_node("EmpowerSeal")
				expect.call(bool(seal.get("charged")) == expected, "%s: copy %d's real seal matches its charge" % [fixture["name"], index])
		scene.queue_free()
		await tree.process_frame

const ACTION_TIMEOUT_MSEC: int = 10000

static func wait_for_idle(tree: SceneTree, scene: Node, expect: Callable) -> void:
	var deadline: int = Time.get_ticks_msec() + ACTION_TIMEOUT_MSEC
	while bool(scene.get("_animation_lock")) or int(scene.get("_drag_card_index")) >= 0:
		if Time.get_ticks_msec() >= deadline:
			expect.call(false, "The live card/skill gesture settles within its test timeout")
			return
		await tree.process_frame
	await tree.process_frame
	await tree.process_frame
