extends RefCounted
## Production step-routing regressions for support, bleed, and clipped Umbra.
const Pacing = preload("res://scripts/combat_pacing.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Motion = preload("res://tests/suites/combat_motion_timing_suite.gd")
const FIXTURE_SUPPORT_AMOUNT: int = 3
const FIXTURE_MISSING_HP: int = 5
const FIXTURE_SUPPORT_RANGE: int = 5
const FIXTURE_ALLY_TILE: Vector2i = Vector2i(4, 3)
const FIXTURE_BLEED_AMOUNT: int = 1
const FIXTURE_NEXT_TILE: Vector2i = Vector2i(6, 3)
const FIXTURE_HIDDEN_TILE: Vector2i = Vector2i(6, 4)
const FIXTURE_HIDDEN_RANGE: int = 6
const CLOCK_TOLERANCE_SECONDS: float = 0.08
const CLEANUP_FRAMES: int = 20
const Clocks = preload("res://tests/suites/combat_enemy_action_clock_suite.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	await Clocks.run(tree, expect)
	await ally_support(tree, expect)
	await _bleed_settle(tree, expect, false)
	await _bleed_settle(tree, expect, true)
	for reduced: bool in [false, true]: await _clipped_umbra_settle(tree, expect, reduced)
	print("COMBAT ACTION PACING SUITE: complete")

static func ally_support(tree: SceneTree, expect: Callable, pacing_script: Script = Pacing) -> void:
	var scene: Node = await _scene(tree)
	scene.get("_combat_pacing").free()
	var pacing: Node = pacing_script.new()
	scene.set("_combat_pacing", pacing)
	pacing.install(scene)
	var engine := Combat.new()
	var base: Dictionary = scene.get("_combat_state").duplicate(true)
	var caster: Dictionary = base["enemies"][0]
	caster["type"] = "acolyte"
	var ally: Dictionary = caster.duplicate(true)
	ally["id"] = 2
	ally["type"] = "crawler"
	ally["pos"] = FIXTURE_ALLY_TILE
	ally["hp"] = int(ally["max_hp"]) - FIXTURE_MISSING_HP
	base["enemies"] = [caster, ally]
	for action_type: String in ["heal_ally", "guard_ally"]:
		var before: Dictionary = base.duplicate(true)
		var action: Dictionary = {"type":action_type, "amount":FIXTURE_SUPPORT_AMOUNT, "range":FIXTURE_SUPPORT_RANGE, "allow_self":false}
		var after: Dictionary = engine._resolve_enemy_action(before.duplicate(true), 0, action)
		var step: Dictionary = engine._enemy_action_step_base(before, after, 0, action)
		expect.call(str(step.get("source_actor_key", "")) == "enemy_1" and str(step.get("actor_key", "")) == "enemy_2", "Ally support fixture is an engine-generated cast onto a different actor")
		var intent: Dictionary = engine._enemy_intent_step_for_player(before, before["enemies"][0], {"name":"Fixture support"})
		var caption: String = "%s: %s" % [intent["actor_name"], intent["intent_name"]]
		_start(scene, before)
		# Exercise the subsequent-actor lead, independently of the banner lead.
		await pacing.before_step({"kind":"intent", "actor_key":"opening_walker"})
		pacing.timeline.clear()
		await scene.call("_animate_enemy_phase_steps", before, [intent, step])
		pacing.end_scope()
		expect.call(pacing.activation_has_action("enemy_1", [step]), "Ally support is classified under its source actor: " + action_type)
		expect.call(not pacing.activation_has_action("enemy_2", [step]), "Ally support recipient does not own the caster's activation")
		var leads: Array[Dictionary] = _rows(pacing, "pre-action delay")
		expect.call(leads.size() == 1, "Ally support receives one caption lead: " + action_type)
		if leads.size() == 1:
			_expect_clock_duration(leads[0], 0.25, expect, "Ally support lead lasts 0.25 s")
			expect.call(str(leads[0]["actor"]) == "enemy_1", "Ally support lead belongs to its caster")
		expect.call(str(pacing.get("_actor")) == "enemy_1" and str(pacing.get("_caption")) == caption, "Ally support keeps caster caption ownership during the recipient's step")
		expect.call(str(scene.get("action_banner").text) == caption, "Ally support renders the caster's printed intent instead of the recipient's utility label")
		_expect_one_settle(pacing, expect, "Ally support " + action_type)
		var stat: String = "hp" if action_type == "heal_ally" else "block"
		expect.call(int(before["enemies"][1][stat]) == int(after["enemies"][1][stat]), "Ally support presentation preserves the engine's target outcome")
		print("COMBAT PACING ALLY SUPPORT %s: leads=%d settles=%d caption=%s" % [action_type, leads.size(), _rows(pacing, "post-action settle").size(), scene.get("action_banner").text])
	await _dispose(tree, scene)

static func _bleed_settle(tree: SceneTree, expect: Callable, with_surface: bool) -> void:
	var scene: Node = await _scene(tree)
	var engine := Combat.new()
	var before: Dictionary = scene.get("_combat_state").duplicate(true)
	before["surfaces"] = {}
	var dying: Dictionary = before["enemies"][0]
	# Death itself emits actor_death in surface_events. Nonlethal bleed takes
	# the ordinary feedback path; lethal bleed takes the early surface branch.
	dying["hp"] = FIXTURE_BLEED_AMOUNT if with_surface else FIXTURE_BLEED_AMOUNT * 2
	dying["bleed"] = FIXTURE_BLEED_AMOUNT
	var walker: Dictionary = dying.duplicate(true)
	walker["id"] = 2
	walker["hp"] = int(walker["max_hp"])
	walker["bleed"] = 0
	walker["pos"] = FIXTURE_HIDDEN_TILE
	before["enemies"] = [dying, walker]
	var bleed: Dictionary = engine._trigger_enemy_bleed_for_action(before.duplicate(true), 0, {"type":"melee"})
	var after: Dictionary = bleed["state"]
	var step: Dictionary = engine._enemy_status_damage_step(bleed["step"], before, after)
	var expected_hp: int = 0 if with_surface else FIXTURE_BLEED_AMOUNT
	expect.call(str(step.get("kind", "")) == "status_damage" and str(step.get("trigger", "")) == "action" and int(after["enemies"][0]["hp"]) == expected_hp, "Bleed fixture is engine-generated action-triggered feedback")
	var has_surface_events: bool = not (step.get("surface_events", []) as Array).is_empty()
	expect.call(has_surface_events == with_surface, "Bleed fixture exercises the requested surface-event branch (surface=%s events=%d)" % [with_surface, (step.get("surface_events", []) as Array).size()])
	var intent: Dictionary = engine._enemy_intent_step_for_player(before, dying, {"name":"Fixture bleed"})
	var next_intent: Dictionary = engine._enemy_intent_step_for_player(after, walker, {"name":"Fixture walk"})
	var move: Dictionary = {"kind":"move", "actor_key":"enemy_2", "actor_name":next_intent["actor_name"], "from":walker["pos"], "to":FIXTURE_NEXT_TILE, "path":[walker["pos"], FIXTURE_NEXT_TILE]}
	_start(scene, before)
	var pacing: Node = scene.get("_combat_pacing")
	await scene.call("_animate_enemy_phase_steps", before, [intent, step, next_intent, move])
	pacing.end_scope()
	_expect_one_settle(pacing, expect, "Action bleed (surface=%s)" % with_surface)
	var settles: Array[Dictionary] = _rows(pacing, "post-action settle")
	for caption: Dictionary in _rows(pacing, "caption"):
		if str(caption["actor"]) == "enemy_2" and settles.size() == 1:
			expect.call(float(caption["clock_start"]) >= float(settles[0]["clock_end"]), "Action bleed settles before the next move-only activation")
	expect.call(int(before["enemies"][0]["hp"]) == expected_hp and before["enemies"][1]["pos"] == FIXTURE_NEXT_TILE, "Bleed/death/move presentation preserves the resolved outcomes")
	print("COMBAT PACING ACTION BLEED surface=%s: settles=%d" % [with_surface, settles.size()])
	await _dispose(tree, scene)

static func _clipped_umbra_settle(tree: SceneTree, expect: Callable, reduced: bool) -> void:
	var scene: Node = await _scene(tree)
	scene.get("_settings")["reduced_motion"] = reduced
	var before: Dictionary = scene.get("_combat_state").duplicate(true)
	before["umbra"] = {"stage":"heart", "stage_reduction":0, "light_sources":[]}
	before["enemies"][0]["pos"] = FIXTURE_HIDDEN_TILE
	var engine := Combat.new()
	var action: Dictionary = {"type":"ranged", "damage":1, "range":FIXTURE_HIDDEN_RANGE, "element":"none"}
	var after: Dictionary = engine._resolve_enemy_action(before.duplicate(true), 0, action)
	var step: Dictionary = engine._enemy_action_step_base(before, after, 0, action)
	step = engine._umbra_marked_enemy_action_step(before, after, step, 1, true)
	var clipped: Dictionary = scene.call("_visible_umbra_action_step", before, step)
	expect.call(bool(step.get("hidden_by_umbra", false)) and bool(clipped.get("umbra_action_clipped", false)), "Umbra fixture presents a hidden attack through its visible clipped span")
	var intent: Dictionary = engine._enemy_intent_step_for_player(before, before["enemies"][0], {"name":"Fixture hidden attack"})
	_start(scene, before)
	var pacing: Node = scene.get("_combat_pacing")
	await scene.call("_animate_enemy_phase_steps", before, [intent, step])
	pacing.end_scope()
	_expect_one_settle(pacing, expect, "Clipped Umbra (reduced=%s)" % reduced)
	expect.call(int(before["player"]["hp"]) == int(after["player"]["hp"]), "Clipped Umbra presentation applies the attack once")
	print("COMBAT PACING CLIPPED UMBRA reduced=%s: settles=%d" % [reduced, _rows(pacing, "post-action settle").size()])
	await _dispose(tree, scene)

static func _scene(tree: SceneTree) -> Node:
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	scene.get("_combat_pacing").free()
	scene.set_script(Clocks.ObservedScene)
	tree.root.add_child(scene)
	await tree.process_frame
	Motion._install_fixture(scene, false)
	scene.set("_turn_order_bar", null)
	return scene

static func _start(scene: Node, state: Dictionary) -> void:
	scene.set("_combat_state", state.duplicate(true))
	scene.get("_run_state")["combat_state"] = scene.get("_combat_state")
	scene.set("_animation_lock", true)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.debug_timeline = true
	pacing.begin_enemies()

static func _dispose(tree: SceneTree, scene: Node) -> void:
	scene.set("_animation_lock", false)
	scene.queue_free()
	for _frame: int in range(CLEANUP_FRAMES): await tree.process_frame

static func _rows(pacing: Node, phase: String) -> Array[Dictionary]:
	var rows: Array[Dictionary]
	for row: Dictionary in pacing.timeline:
		if str(row["phase"]) == phase: rows.append(row)
	return rows

static func _expect_one_settle(pacing: Node, expect: Callable, message: String) -> void:
	var samples: Array = pacing.scene.get("action_scales")
	var action_scale: float = preload("res://scripts/settings_store.gd").combat_speed_scale(pacing.scene.get("_settings"))*0.80
	expect.call(not samples.is_empty() and samples.all(func(scale: float) -> bool: return is_equal_approx(scale,action_scale)),message + " renders at 0.80 times the selected combat speed")
	var settles: Array[Dictionary] = _rows(pacing, "post-action settle")
	expect.call(settles.size() == 1, message + " has exactly one settle")
	if settles.size() == 1: _expect_clock_duration(settles[0], 0.15, expect, message + " settles for 0.15 s")

static func _expect_clock_duration(row: Dictionary, seconds: float, expect: Callable, message: String) -> void:
	var duration: float = float(row["clock_end"]) - float(row["clock_start"])
	expect.call(duration >= seconds and duration <= seconds + CLOCK_TOLERANCE_SECONDS, message + " (%.3f s)" % duration)
