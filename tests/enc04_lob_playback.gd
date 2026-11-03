extends RefCounted
## Drives the production dispatcher, pacing and cutout adapter with the real
## animation lock. The observer never sets a caption or substitutes an adapter.
const Combat = preload("res://scripts/combat_engine.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const MAX_PLAYBACK_SECONDS: float = 20.0

static func run(scene: Control, battle: Dictionary, reduced: bool, expect: Callable, observe: Callable = Callable()) -> void:
	var enemy: Dictionary = battle["enemies"][0]
	var key: String = "enemy_%d" % int(enemy["id"])
	var fallback: String = "%s: %s" % [preload("res://scripts/enemy_identity.gd").display_name(enemy), str(enemy["intent"].get("name", ""))]
	var settings: Dictionary = scene.get("_settings").duplicate(true)
	settings["reduced_motion"] = reduced
	scene.set("_settings", settings)
	scene.set("_animation_lock", true)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.call("begin_enemies")
	var engine := Combat.new()
	var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(battle, 0)
	var expected: String = fallback
	var geometry: Dictionary = {}
	var landing: bool = str(enemy["intent"].get("id", "")) == "slag_lands"
	if str(enemy["intent"].get("id", "")) in ["lob_slag", "slag_lands"] and not OS.get_cmdline_user_args().has("--before"):
		# The oracle reads actual committed/held marks, never another forecast or
		# the caption payload under test. It also verifies the exact approved copy.
		var committed: Dictionary = enemy if landing else resolved["state"]["enemies"][0]
		var centers: Array = committed.get("lob_centers", [committed.get("lob_center")])
		geometry = {"tiles": committed.get("lob_tiles", []), "centers": centers, "cross_count": centers.size()}
		var damage: Dictionary = Lob.landing_action(engine, battle, enemy)
		var numbers: Array = [int(damage["center_damage"]), int(damage["arm_damage"])]
		if centers.size() > 1:
			expected = ("Marked tiles take the hit: %d in each centre, %d around them, and they become Fire." if landing else "Marks %d crosses. Next turn: %d in each centre, %d around them, and they become Fire.") % (numbers if landing else [centers.size()] + numbers)
		else:
			expected = ("Marked tiles take the hit: %d in the centre, %d around it, and they become Fire." if landing else "Marks your tile and the 4 around it. Next turn: %d in the centre, %d around it, and they become Fire.") % numbers
	var steps: Array
	var adapter_steps: int = 0
	for step: Dictionary in resolved["steps"]:
		if str(step.get("kind", "")) == "commit": continue
		steps.append(step)
		if step.has("en04_mechanic") and not geometry.is_empty():
			expect.call(step.get("lob_geometry", {}) == geometry, "Playback step carries exactly the committed lob geometry")
		if Action.playback_adapter(step, enemy) == preload("res://assets/units/slag_mortar_cutout/actions.gd"): adapter_steps += 1
	expect.call(adapter_steps > 0, "Playback dispatches the actual Slag Mortar cutout adapter")
	var state: Dictionary = battle.duplicate(true)
	var result: Dictionary = {"complete": false, "samples": 0, "wrong": [], "lock_lost": false, "caption_ready": false}
	var banner: Label = scene.get("action_banner")
	var sample: Callable = func() -> void:
		if not bool(scene.get("_animation_lock")) or not bool(pacing.get("enemies_active")): result["lock_lost"] = true
		# Pre-lob retreat keeps its existing movement caption. Start the lob
		# assertion at the intent lead, and retain it through all adapter frames.
		if str(pacing.get("_actor")) == key and banner.visible and not banner.text.is_empty():
			result["samples"] += 1
			if banner.text != expected and not result["wrong"].has(banner.text): result["wrong"].append(banner.text)
			result["caption_ready"] = true
	scene.get_tree().process_frame.connect(sample)
	_finish(scene, state, steps, result)
	var deadline: int = Time.get_ticks_msec() + int(MAX_PLAYBACK_SECONDS * 1000.0)
	while not result["caption_ready"] and not result["complete"] and Time.get_ticks_msec() < deadline:
		await scene.get_tree().process_frame
	if observe.is_valid() and bool(result["caption_ready"]): await observe.call()
	while not result["complete"] and Time.get_ticks_msec() < deadline:
		await scene.get_tree().process_frame
	sample.call()
	scene.get_tree().process_frame.disconnect(sample)
	expect.call(bool(result["complete"]), "Production lob playback completes within its test deadline")
	expect.call(not result["lock_lost"], "Animation lock and enemy pacing remain active through playback")
	expect.call(int(result["samples"]) > 0 and result["wrong"].is_empty(), "Every playback caption is the approved sentence (Reduced Motion=%s; wrong=%s)" % [reduced, result["wrong"]])
	expect.call(str(pacing.get("_caption")) == expected, "Pacing retains the resolved lob sentence")
	expect.call(state["enemies"][0].get("lob_tiles", []) == resolved["state"]["enemies"][0].get("lob_tiles", []), "Playback applies the production mark/landing state")
	print("ENC04 LOB PLAYBACK: %s Reduced Motion=%s crosses=%d samples=%d adapter_steps=%d lock=%s wrong=%s" % [enemy["intent"]["id"], reduced, int(geometry.get("cross_count", 0)), result["samples"], adapter_steps, not result["lock_lost"], result["wrong"]])
	pacing.call("end_scope")
	scene.set("_animation_lock", false)

static func _finish(scene: Control, state: Dictionary, steps: Array, result: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps", state, steps)
	result["complete"] = true
