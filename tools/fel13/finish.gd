extends RefCounted
## Check that edited boards can reach a combat outcome through normal actions.

const Policy = preload("res://tools/fel01/policy.gd")
const Fixtures = preload("res://tools/fel13/stage.gd")
const DECISION_LIMIT := 400
const SETTLE_FRAMES := 8
const POLICY_SEED := 13
const HEADLESS_TIME_SCALE := 8.0
const INPUT_IDLE_LIMIT_MSEC := 25000

func run(session: SceneTree) -> void:
	Engine.time_scale = HEADLESS_TIME_SCALE
	var requested: String = OS.get_environment("FEL13_FIXTURE")
	var finished: int = 0
	for id: String in Fixtures.CASES:
		if not requested.is_empty() and id != requested: continue
		if not await session.open_fixture(id):
			session.quit(1)
			return
		var policy := Policy.new()
		policy.rng = RandomNumberGenerator.new()
		policy.rng.seed = POLICY_SEED
		var scene: Node = session.scene
		var decisions: int = 0
		var idle_deadline: int = Time.get_ticks_msec() + INPUT_IDLE_LIMIT_MSEC
		while str(scene.get("_run_state").get("mode")) == "combat" and decisions < DECISION_LIMIT:
			for frame: int in SETTLE_FRAMES: await session.process_frame
			if not session.at_first_input():
				if Time.get_ticks_msec() > idle_deadline:
					session.fail(id + " did not return to combat input")
					return
				continue
			idle_deadline = Time.get_ticks_msec() + INPUT_IDLE_LIMIT_MSEC
			var offers: Array = policy.offers(scene)
			if offers.is_empty():
				session.fail(id + " reached combat without a legal input")
				return
			policy.dispatch(scene, policy.choose(scene, offers))
			decisions += 1
		var outcome: String = str(scene.get("_run_state").get("mode"))
		print("FEL13 COMBAT END ", id, " mode=", outcome, " decisions=", decisions)
		if outcome == "combat":
			session.fail(id + " exceeded the combat decision limit")
			return
		finished += 1
		await session.close_fixture()
	print("FEL13 COMBAT END PASS fixtures=", finished)
	session.quit()
