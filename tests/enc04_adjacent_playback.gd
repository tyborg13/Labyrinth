extends RefCounted
const Cases = preload("res://tests/enc04_lob_cases.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Playback = preload("res://tests/enc04_lob_playback.gd")
const REVIEW_SIDE: int = -1
const REVIEW_RETREAT := Vector2i(4, 5)

static func run(scene: Control, run_state: Dictionary, expect: Callable) -> void:
	var engine := Combat.new()
	var activations: int = 0
	for blocked: bool in [false, true]:
		var approach: Dictionary = Cases.revealed_adjacent(engine, Vector2i.DOWN, REVIEW_SIDE, "wall" if blocked else "")
		expect.call(approach["declared"]["enemies"][0]["intent"]["id"] == "lob_slag", "Playback case reveals Lob at distance 2")
		var aiming: Dictionary = approach["adjacent"]
		expect.call(aiming["player"]["pos"] == Cases.CAPTAIN + Vector2i.DOWN, "Playback hero legally walks adjacent after the reveal")
		var marked: Dictionary = engine.resolve_enemy_turn_with_steps(aiming, 0)["state"]
		var crosses: int = (marked["enemies"][0].get("lob_centers", []) as Array).size()
		expect.call(crosses == (1 if blocked else 2), "Adjacent playback exercises actual one/two-cross commits")
		if blocked: expect.call(marked["enemies"][0]["pos"] == REVIEW_RETREAT, "Blocked playback reproduces the reviewer's retreat to (4,5)")
		for landing: bool in [false, true]:
			var battle: Dictionary = marked if landing else aiming
			for reduced: bool in [false, true]:
				var display: Dictionary = run_state.duplicate(true)
				display["combat_state"] = battle
				scene.call("_load_run_state", display)
				scene.call("_close_dialogue")
				await Playback.run(scene, battle, reduced, expect)
				activations += 1
	print("ENC04 ADJACENT PLAYBACK: %d activations; revealed Lob -> legal adjacent walk; blocked one/open two crosses; aiming/landing; normal/Reduced Motion" % activations)
