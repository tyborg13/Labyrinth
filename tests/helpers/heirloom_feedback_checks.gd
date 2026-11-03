extends RefCounted

const Notifications = preload("res://scripts/run_notification_queue.gd")
const Fixture = preload("res://tests/helpers/heirloom_fixture.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const FIRST_NOTICE: String = "Added 14 entries to the Grimoire."
const SECOND_NOTICE: String = "Added Glassbone Cuirass entry to the Grimoire."
const CEREMONY_NOTICE: String = "Heirloom feedback fixture: ceremony notice"

static func run(driver: SceneTree, scene: Node, expect: Callable, open_view: Callable) -> void:
	var view: Control = await open_view.call(driver, scene, 4)
	var counts: Dictionary = {}
	for card: Control in view.cards:
		var rows: Array[Node] = card.find_children("HeirloomSpell_*", "Control", false, false)
		counts[rows.size()] = true
		if rows.is_empty(): continue
		var last: Control = rows.back()
		expect.call(card.size.y == 540.0 and last.get_rect().end.y <= card.size.y - 25.0 - 12.0, "One-, two- and three-spell pieces clear the inner frame by at least 12px")
	expect.call(counts.has(1) and counts.has(2) and counts.has(3), "Frame-fit regression exercises all 1/2/3 spell counts")
	var queue: Node = scene.get_node("DeferredRunNotifications")
	queue.fixed_clock = true
	queue.queued.clear()
	queue.set("_current", {})
	queue.set("_last_persistent", "")
	queue.set("_last_requested", "")
	scene.get("log_label").text = FIRST_NOTICE
	scene.call("_refresh_log_overlay_visibility")
	scene.call("_refresh_log_overlay_visibility")
	scene.call("_show_combat_log_message", SECOND_NOTICE)
	expect.call(not scene.get("log_overlay").visible and queue.queued.size() == 2, "Persistent and explicit transient notifications defer; refreshes do not duplicate persistent notices")
	var cue_requests: Array[Dictionary]
	var bank: Node = scene.get("_sfx_bank")
	var observe := func(id: String, result: String) -> void:
		if id == RunSfx.REWARD_ACCEPTED_ID: cue_requests.append({"id": id, "result": result})
	bank.cue_requested.connect(observe)
	view.call("_choose", 0)
	var ceremony: Control = view.ceremony
	ceremony.fixed_clock = true
	scene.call("_show_combat_log_message", CEREMONY_NOTICE)
	expect.call(not scene.get("log_overlay").visible, "Notifications also remain hidden during the ceremony")
	ceremony.seek(Fixture.BURN_CLOCK_SECONDS)
	expect.call(ceremony.burns.size() == 3, "Only the three non-chosen cards receive a burn effect")
	for burn: Control in ceremony.burns: _burn_contract(burn, expect)
	expect.call(view.cards[0].get_parent() == view.row.get_child(0), "The selected card stays outside all burn CanvasGroups")
	ceremony.seek(0.50)
	for burn: Control in ceremony.burns: expect.call(not burn.group.visible, "Each non-chosen card is fully dissolved at 0.50s")
	ceremony.seek(1.099)
	expect.call(cue_requests.is_empty(), "Reward acceptance cue cannot play before 1.10s")
	ceremony.seek(1.10)
	expect.call(cue_requests.size() == 1 and cue_requests[0]["result"] == "played", "Exactly one real reward acceptance cue plays through the SFX router at 1.10s")
	expect.call(RunSfx.entry(RunSfx.REWARD_ACCEPTED_ID)["path"] == "res://assets/audio/sfx/run/reward_accepted.wav", "The cue uses the existing approved WAV")
	ceremony.seek(1.20)
	ceremony.skip()
	expect.call(cue_requests.size() == 1, "Later seek and skip cannot replay the acceptance cue")
	var shown: Array[String]
	var trace: Array
	for _index: int in range(queue.queued.size() + 2):
		var current: Dictionary = queue.get("_current")
		if current.is_empty(): break
		var text: String = str(scene.get("log_label").text)
		trace.append([current.duplicate(), text])
		var waiting: int = queue.queued.size()
		scene.call("_refresh_log_overlay_visibility")
		expect.call(queue.queued.size() == waiting, "Visibility-only refreshes never requeue a replayed notice")
		if text in [FIRST_NOTICE, SECOND_NOTICE, CEREMONY_NOTICE]: shown.append(text)
		expect.call(scene.get("log_overlay").visible, "Deferred notification is visible after the heirloom view closes")
		queue.advance(float(scene.get_script().get_script_constant_map()["COMBAT_LOG_TRANSIENT_SECONDS"]))
	expect.call(shown == [FIRST_NOTICE, SECOND_NOTICE, CEREMONY_NOTICE], "All held notifications replay exactly once in arrival order: %s; owners=%s; pending=%s" % [shown, queue.get("_owners"), [queue.queued, trace]])
	view = await open_view.call(driver, scene, 1)
	view.call("_choose", 0)
	ceremony = view.ceremony
	ceremony.fixed_clock = true
	var completions: Array[bool]
	ceremony.finished.connect(func() -> void: completions.append(true))
	ceremony.skip()
	ceremony.skip()
	expect.call(completions.size() == 1, "Skipping twice emits ceremony finished exactly once")
	if completions.size() == 1: print("HEIRLOOM CEREMONY COMPLETION CHECK: PASS")
	expect.call(cue_requests.size() == 2 and cue_requests.back()["result"] == "played", "Skipping before 1.10s still delivers exactly one acceptance cue")
	bank.cue_requested.disconnect(observe)
	# An already-visible notice is paused, not discarded, and two explicit
	# requests with identical text are still two notifications.
	queue.queued.clear()
	queue.set("_current", {})
	queue.set("_last_persistent", FIRST_NOTICE)
	queue.set("_last_requested", FIRST_NOTICE)
	scene.get("log_label").text = FIRST_NOTICE
	scene.get("log_overlay").show()
	var owner := Node.new()
	scene.add_child(owner)
	Notifications.hold(scene, owner)
	scene.call("_show_combat_log_message", SECOND_NOTICE)
	scene.call("_show_combat_log_message", SECOND_NOTICE)
	expect.call(not scene.get("log_overlay").visible and queue.queued.size() == 3, "Holding an already-visible notice preserves it and both repeated explicit toasts")
	Notifications.release(scene, owner)
	for text: String in [FIRST_NOTICE, SECOND_NOTICE, SECOND_NOTICE]:
		expect.call(scene.get("log_overlay").visible and scene.get("log_label").text == text, "Already-visible and repeated notifications resume in order")
		queue.advance(float(scene.get_script().get_script_constant_map()["COMBAT_LOG_TRANSIENT_SECONDS"]))
	owner.queue_free()
	print("HEIRLOOM FEEDBACK 1 CHECKS: %s" % ("FAIL" if bool(driver.get("_failed")) else "PASS"))

static func _burn_contract(burn: Control, expect: Callable) -> void:
	expect.call(burn.group.material == burn.burn_material and is_equal_approx(float(burn.burn_material.get_shader_parameter("progress")), 0.36), "At 0.30s the complete card composite uses the ease-in quad burn material at 36 percent")
	expect.call(burn.burn_material.get_shader_parameter("gold_bright") == Palette.GOLD_BRIGHT and burn.burn_material.get_shader_parameter("ember") == Palette.EMBER, "Burn edge uses the approved palette tokens")
	expect.call(float(burn.burn_material.get_shader_parameter("noise_period")) == 24.0 and float(burn.burn_material.get_shader_parameter("noise_amplitude")) == 8.0 and float(burn.burn_material.get_shader_parameter("pixel_grid")) == 2.0 and float(burn.burn_material.get_shader_parameter("band_pixels")) == 5.0, "Real burn shader uniforms use the exact 24px noise, 8px amplitude, 2px grid and 5px band")
	var base: float = floorf(lerpf(burn.size.y, float(burn.get("_top")), 0.36) / 2.0 + 0.5) * 2.0
	for x: int in range(0, 316, 2):
		var edge: float = burn.line_y(float(x), 0.30)
		expect.call(absf(edge - base) <= 8.0 and is_zero_approx(fmod(edge, 2.0)), "Value-noise edge stays within plus/minus 8px on the 2px grid")
	expect.call(burn.sparks.size() == 14, "Every burning card emits exactly fourteen sparks")
	for index: int in range(burn.sparks.size()):
		var spark: Dictionary = burn.sparks[index]
		expect.call(float(spark["birth"]) >= 0.0 and float(spark["birth"]) <= 0.50 and float(spark["rise"]) >= 60.0 and float(spark["rise"]) <= 110.0 and absf(float(spark["drift"])) <= 14.0, "Ember emission and travel use the approved ranges")
		var sample: Dictionary = burn.ember_sample(index, float(spark["birth"]) + 0.30)
		var rect: Rect2 = sample["rect"]
		expect.call(rect.size in [Vector2(2.0, 2.0), Vector2(3.0, 3.0)] and rect.position == rect.position.floor() and is_equal_approx(float(sample["color"].a), 0.50), "Embers are pixel-snapped 2px/3px squares and fade over 0.60s")
		expect.call(burn.ember_sample(index, float(spark["birth"]) + 0.601).is_empty(), "No ember survives its 0.60s lifetime")
