extends RefCounted
## Enemy action clock coverage, independent of gameplay tuning and assets.
const Pacing = preload("res://scripts/combat_pacing.gd")
const Motion = preload("res://tests/suites/combat_motion_timing_suite.gd")
const En03 = preload("res://tests/suites/en03_enemies_suite.gd")
const En02 = preload("res://tests/suites/en02_enemies_suite.gd")
const En05 = preload("res://tests/suites/en05_enemies_suite.gd")
const En06 = preload("res://tests/suites/en06_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const NESTED_MOVE_OFFSET: Vector2i = Vector2i(0, 1)
const AUTHORED_DURATION_TOLERANCE_SECONDS: float = 0.001
const CLOCK_SAMPLE_SECONDS: float = 0.08
const CLOCK_SAMPLE_TOLERANCE_SECONDS: float = 0.025
const DIRECTOR_FIXTURE_SCALE: float = 0.5
const BLINK_FIXTURE_FROM: Vector2i = Vector2i(6, 4)
const BLINK_FIXTURE_TO: Vector2i = Vector2i(3, 4)

class ClockOwner:
	extends Node
	var _settings: Dictionary = preload("res://scripts/settings_store.gd").default_settings()
	var _run_state: Dictionary = {"mode":"combat"}
	var _animation_lock: bool = true
	var _drag_card_index: int = -1
	var modal: bool = false
	func _controller_modal_visible() -> bool: return modal

const ObservedScene = preload("res://tests/helpers/combat_action_clock_scene.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	await action_clocks(tree, expect)
	await _nested_movement(tree, expect)
	await veil_blinks(tree, expect)
	await unaligned_dive(tree, expect)
	await _mechanic_views(tree, expect)

static func action_clocks(tree: SceneTree, expect: Callable, pacing_script: Script = Pacing) -> void:
	var settings_script = preload("res://scripts/settings_store.gd")
	for speed: String in ["normal", "fast", "fastest"]:
		for reduced: bool in [false, true]:
			var owner := ClockOwner.new()
			owner._settings["combat_speed"] = speed
			owner._settings["reduced_motion"] = reduced
			tree.root.add_child(owner)
			var pacing: Node = pacing_script.new()
			pacing.install(owner)
			var scale: float = settings_script.combat_speed_scale(owner._settings)
			pacing.begin_enemies()
			for kind: String in Pacing.ENEMY_ACTION_KINDS:
				await pacing.before_step({"kind":kind,"actor_key":"fixture"})
				expect.call(is_equal_approx(Engine.time_scale,scale*0.80),"Every enemy action uses 0.80 times combat speed: %s / %s / reduced=%s" % [kind,speed,reduced])
			await pacing.before_step({"kind":"move","actor_key":"fixture"})
			expect.call(is_equal_approx(Engine.time_scale,scale),"Movement uses combat speed without the action multiplier")
			var counts: Array[int]
			counts.assign([1])
			expect.call(is_equal_approx(pacing.walk_frame_seconds("fixture",counts,1.0)+preload("res://scripts/floating_combat_text.gd").TARGET_FRAME_SECONDS,0.20),"Movement keeps the 0.20 s tile bound")
			await pacing.before_step({"kind":"melee"})
			var began: int = Time.get_ticks_usec()
			var clock_began: int = pacing.presentation_usec()
			await pacing._wait_until(clock_began+int(CLOCK_SAMPLE_SECONDS*1000000.0))
			var elapsed: float = float(Time.get_ticks_usec()-began)/1000000.0
			expect.call(elapsed >= CLOCK_SAMPLE_SECONDS/(scale*0.80) and elapsed <= CLOCK_SAMPLE_SECONDS/(scale*0.80)+CLOCK_SAMPLE_TOLERANCE_SECONDS,"Enemy clock keeps the full authored duration at %s" % speed)
			pacing.hit_stop.request(12,false,false,reduced)
			expect.call(Engine.time_scale == 0.0,"Enemy action hit-stop freezes the presentation clock")
			pacing.hit_stop.cancel()
			expect.call(is_equal_approx(Engine.time_scale,scale*0.80),"Hit-stop restores the enemy action scale")
			owner.modal = true
			await tree.process_frame
			await tree.process_frame
			expect.call(is_equal_approx(Engine.time_scale,1.0),"Blocking overlay restores the base clock")
			owner.modal = false
			await tree.process_frame
			await tree.process_frame
			expect.call(is_equal_approx(Engine.time_scale,scale*0.80),"Closing an overlay resumes the action clock")
			pacing.end_scope()
			Engine.time_scale = DIRECTOR_FIXTURE_SCALE
			pacing.begin_enemies()
			await pacing.before_step({"kind":"melee"})
			expect.call(is_equal_approx(Engine.time_scale,DIRECTOR_FIXTURE_SCALE*scale*0.80),"Enemy action multiplies the external director scale")
			pacing.end_scope()
			expect.call(is_equal_approx(Engine.time_scale,DIRECTOR_FIXTURE_SCALE),"Enemy cleanup restores the external director scale")
			Engine.time_scale = 1.0
			pacing.begin_card()
			await pacing.before_step({"kind":"melee"})
			expect.call(is_equal_approx(Engine.time_scale,scale),"Hero cards keep combat speed without the enemy action multiplier")
			pacing.end_scope()
			owner.free()
	print("COMBAT ACTION CLOCKS: all action kinds / three speeds / reduced motion / movement / hero / hit-stop / modal / director checked")

static func _nested_movement(tree: SceneTree, expect: Callable) -> void:
	var scene: Node = await _scene(tree)
	for speed: String in ["normal", "fast", "fastest"]:
		for reduced: bool in [false, true]:
			var before: Dictionary = scene.get("_combat_state").duplicate(true)
			var unit: Dictionary = before["enemies"][0]
			var step: Dictionary = {"kind":"move","actor_key":"enemy_1","from":unit["pos"],"to":unit["pos"]+NESTED_MOVE_OFFSET}
			_start(scene, before, speed, reduced)
			var pacing: Node = scene.get("_combat_pacing")
			await pacing.before_step({"kind":"ranged"})
			await scene.call("_animate_move_step", before, step)
			var scale: float = Settings.combat_speed_scale(scene.get("_settings"))
			var samples: Array = scene.get("movement_scales")
			expect.call(not samples.is_empty() and samples.all(func(value: float) -> bool: return is_equal_approx(value,scale)),"Nested mechanic movement uses combat speed without the action multiplier at %s reduced=%s" % [speed,reduced])
			expect.call(is_equal_approx(Engine.time_scale,scale*0.80),"Nested mechanic movement resumes the enemy action clock")
			_verify_presentations(scene, expect, "Nested movement")
			pacing.end_scope()
	scene.queue_free()
	await tree.process_frame
	print("COMBAT NESTED MOVEMENT CLOCKS: three speeds / reduced motion / action resume checked")

static func veil_blinks(tree: SceneTree, expect: Callable) -> void:
	var scene: Node = await _scene(tree)
	for speed: String in ["normal", "fast", "fastest"]:
		for reduced: bool in [false, true]:
			for intent: String in ["fade", "ambush"]:
				var before: Dictionary = En03.state([En03.enemy("gloam_stalker",1,BLINK_FIXTURE_FROM,intent)])
				before["enemies"][0]["veiled"] = intent == "ambush"
				var resolved: Dictionary = En06.resolve_action(before)
				var step: Dictionary = resolved["step"]
				expect.call(step["from"] == BLINK_FIXTURE_FROM and step["to"] == BLINK_FIXTURE_TO,"Fade and Ambush fixtures share the same nonzero blink")
				_start(scene,before,speed,reduced)
				await scene.call("_animate_enemy_phase_steps",before,[step])
				scene.get("_combat_pacing").end_scope()
				var scale: float = Settings.combat_speed_scale(scene.get("_settings"))
				var effects: Dictionary = scene.get("effect_scales")
				var blinks: Array = effects.get("blink",[])
				var strikes: Array = effects.get("melee",[])
				expect.call(not blinks.is_empty() and blinks.all(func(value: float) -> bool: return is_equal_approx(value,scale)),"Veil blink uses combat speed: %s / %s / reduced=%s" % [intent,speed,reduced])
				if intent == "ambush":
					expect.call(not strikes.is_empty() and strikes.all(func(value: float) -> bool: return is_equal_approx(value,scale*0.80)),"Ambush strike resumes the enemy action scale at %s reduced=%s" % [speed,reduced])
				else: expect.call(strikes.is_empty(),"Fade remains movement only")
				expect.call(before["enemies"] == resolved["state"]["enemies"] and before["player"] == resolved["state"]["player"],"Veil presentation preserves the resolved blink/strike outcome")
				_verify_presentations(scene,expect,"Veil "+intent)
	scene.queue_free()
	await tree.process_frame
	print("COMBAT VEIL BLINK CLOCKS: Fade / Ambush / three speeds / reduced motion / independent blink and strike scales checked")

static func unaligned_dive(tree: SceneTree, expect: Callable, scene_script: Script = ObservedScene) -> void:
	var scene: Node = await _scene(tree,scene_script)
	for speed: String in ["normal", "fast", "fastest"]:
		for reduced: bool in [false, true]:
			var before: Dictionary = En05.shrike()
			before["enemies"][0]["pos"] = En05.TEST_UNALIGNED_START
			var resolved: Dictionary = En06.resolve_action(before)
			var step: Dictionary = resolved["step"]
			expect.call((step.get("approach_path",[]) as Array).size() > 1 and not bool(step.get("cancelled",false)),"Unaligned Dive fixture must walk before its attack")
			_start(scene,before,speed,reduced)
			await scene.call("_animate_enemy_phase_steps",before,[step])
			scene.get("_combat_pacing").end_scope()
			var scale: float = Settings.combat_speed_scale(scene.get("_settings"))
			var approaches: Array = scene.get("movement_scales")
			var attacks: Array = scene.get("effect_scales").get("dive_line",[])
			expect.call(not approaches.is_empty() and approaches.all(func(value: float) -> bool: return is_equal_approx(value,scale)),"Unaligned Dive approach uses combat speed at %s reduced=%s" % [speed,reduced])
			expect.call(not attacks.is_empty() and attacks.all(func(value: float) -> bool: return is_equal_approx(value,scale*0.80)),"Unaligned Dive attack resumes the enemy action scale at %s reduced=%s" % [speed,reduced])
			expect.call(before["enemies"] == resolved["state"]["enemies"] and before["player"] == resolved["state"]["player"],"Unaligned Dive presentation preserves the resolved approach/attack outcome")
			_verify_presentations(scene,expect,"Unaligned Dive")
	scene.queue_free()
	await tree.process_frame
	print("COMBAT UNALIGNED DIVE CLOCKS: nonzero approach / three speeds / reduced motion / independent approach and attack scales checked")

static func _mechanic_views(tree: SceneTree, expect: Callable) -> void:
	var scene: Node = await _scene(tree)
	var engine := Combat.new()
	# Existing fixtures and authored intents only; no gameplay values are tuned.
	var cases: Array = [
		["hoarfrost_seer","icefall"], ["hoarfrost_seer","icefall_land"],
		["gale_herald","call_the_wind"], ["briar_weaver","thornwall"],
		["slag_mortar","slag_lands"], ["arc_thrall","tether"],
		["ember_tick","kindle"], ["burrow_grub","burrow"],
		["glacial_mirror","refraction"], ["gust_shrike","dive"],
		["storm_capacitor","discharge"], ["hollow_mimic","mirror"]]
	for speed: String in ["normal", "fast", "fastest"]:
		for reduced: bool in [false, true]:
			for fixture: Array in cases:
				var type: String = fixture[0]
				var before: Dictionary = En02.fixture(engine,type)
				if type == "gust_shrike": before = En05.shrike()
				elif type == "glacial_mirror": before = En05.mirror()
				elif type == "storm_capacitor": before = En06.capacitor()
				elif type == "hollow_mimic": before = En06.mirror()
				if type != "hollow_mimic": before["enemies"][0]["intent"] = En02.intent(type,fixture[1])
				if str(fixture[1]) == "icefall_land": before["enemies"][0]["icefall_tiles"] = [before["player"]["pos"]]
				if str(fixture[1]) == "slag_lands": before["enemies"][0]["lob_center"] = before["player"]["pos"]
				var resolved: Dictionary = En06.resolve_action(before)
				var expected: Dictionary = resolved["state"]
				_start(scene, before, speed, reduced)
				await scene.call("_animate_enemy_phase_steps",before,[resolved["step"]])
				var pacing: Node = scene.get("_combat_pacing")
				pacing.end_scope()
				var scale: float = Settings.combat_speed_scale(scene.get("_settings"))*0.80
				var samples: Array = scene.get("action_scales")
				expect.call(not samples.is_empty() and samples.all(func(value: float) -> bool: return is_equal_approx(value,scale)),"Mechanic action renders at the effective enemy clock: %s / %s / reduced=%s" % [type,speed,reduced])
				expect.call(before["enemies"] == expected["enemies"] and before["player"] == expected["player"],"Mechanic presentation applies its resolved actor outcome once: "+type)
				_verify_presentations(scene,expect,type)
				var settles: int = 0
				for row: Dictionary in pacing.timeline:
					if row["phase"] == "post-action settle": settles += 1
				expect.call(settles == 1,"Mechanic action completes and settles exactly once: "+type)
	scene.queue_free()
	await tree.process_frame
	print("COMBAT MECHANIC ACTION CLOCKS: 12 routes / three speeds / reduced motion / complete authored presentations checked")

static func _scene(tree: SceneTree, scene_script: Script = ObservedScene) -> Node:
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	scene.get("_combat_pacing").free()
	scene.set_script(scene_script)
	tree.root.add_child(scene)
	await tree.process_frame
	Motion._install_fixture(scene,false)
	scene.set("_turn_order_bar",null)
	return scene

static func _start(scene: Node, state: Dictionary, speed: String, reduced: bool) -> void:
	scene.get("_settings")["combat_speed"] = speed
	scene.get("_settings")["reduced_motion"] = reduced
	scene.set("_combat_state",state.duplicate(true))
	scene.get("_run_state")["combat_state"] = scene.get("_combat_state")
	scene.set("_animation_lock",true)
	scene.get("action_scales").clear()
	scene.get("movement_scales").clear()
	scene.get("effect_scales").clear()
	scene.get("timed_presentations").clear()
	scene.set("record_clocks",true)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.debug_timeline = true
	pacing.begin_enemies()

static func _verify_presentations(scene: Node, expect: Callable, label: String) -> void:
	for shown: Dictionary in scene.get("timed_presentations"):
		var frames: Array = shown["frames"]
		expect.call(not frames.is_empty() and frames.back() == shown["count"],label+" reaches its authored final frame")
		for index: int in range(1,frames.size()):
			expect.call(int(frames[index]) > int(frames[index-1]),label+" advances without replaying a frame")
		expect.call(float(shown["elapsed"])+AUTHORED_DURATION_TOLERANCE_SECONDS >= int(shown["count"])*float(shown["seconds"]),label+" retains its full authored presentation duration")

