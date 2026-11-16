extends "res://tests/pre_battle_fixture.gd"

# One-off geometry audit of the other production card/item effect paths.
const HeirloomChecks = preload("res://tests/helpers/heirloom_checks.gd")
const HeirloomFixture = preload("res://tests/helpers/heirloom_fixture.gd")
const GraftFixture = preload("res://tests/suites/graftwright_suite.gd")
const Preview = preload("res://scripts/event_reward_preview.gd")
const Consumption = preload("res://scripts/card_consumption_effect.gd")
const EVENT_PROOF_ORIGIN := Vector2(480, 270)
const COMBAT_PROOF_RECT := Rect2(600, 260, 250, 352)
const AUDIT_CLOCK_SECONDS: float = 0.30
const GRAFT_DEADLINE_MSEC: int = 10000
var _native: bool
var _output: String = "/private/tmp/purge-04-audit"
var _measurements: Array[Dictionary]

func _initialize() -> void:
	_setup()
	_native = DisplayServer.get_name().to_lower() != "headless"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(_output)
	var scene: Node = await _instance(HeirloomFixture.terminal())
	var view: Control = await HeirloomChecks.open(self, scene, 4)
	var before: Dictionary = {}
	for card: Control in view.cards: before[str(card.item_id)] = card.get_global_rect()
	view.call("_choose", 0)
	view.ceremony.fixed_clock = true
	view.ceremony.seek(AUDIT_CLOCK_SECONDS)
	for burn: Control in view.ceremony.burns:
		_measure("heirloom_" + str(burn.get("_card").item_id), before[str(burn.get("_card").item_id)], burn.get("_card").get_global_rect())
	await _save("heirloom")
	view.ceremony.skip()
	await _settle()
	# Combat Purge/consume uses its approved shrinking/lifting fade; Exhaust
	# flies to its pile. Measure the handoff at t=0, before intentional motion.
	var proxy: Control = scene.call("_spawn_card_proxy", "pale_spark", COMBAT_PROOF_RECT)
	scene.call("_mount_card_proxy", proxy, scene.get("_card_fx_layer"), COMBAT_PROOF_RECT)
	var expected: Rect2 = COMBAT_PROOF_RECT
	_measure("combat_exhaust_handoff", expected, scene.call("_card_proxy_visual_rect", proxy))
	Consumption.apply_pose(proxy, proxy.position, proxy.scale, proxy.rotation, proxy.modulate, 0.0, false)
	_measure("combat_consumption_t0", expected, scene.call("_card_proxy_visual_rect", proxy))
	await _save("combat")
	scene.call("_release_card_proxy", proxy)
	# The production event caller uses content.size as its source extent. The
	# snapshot is local to a proxy already placed at that extent's origin.
	var effect := preload("res://scripts/event_gain_effect.gd").new()
	effect.kind = "lose_item"
	effect.content = Preview.build({"kind": "lose_item", "ids": ["crimson_draught"]}, HeirloomFixture.terminal(), true)
	effect.origin = Rect2(EVENT_PROOF_ORIGIN, effect.content.size)
	effect.destination = effect.origin.get_center()
	_viewport.add_child(effect)
	effect.set_process(false)
	effect.set("_elapsed", AUDIT_CLOCK_SECONDS)
	effect.call("_update_pose")
	var event_proxy: Control = effect.proxy
	var expected_event: Rect2 = event_proxy.get_global_transform() * Rect2(Vector2.ZERO, effect.origin.size)
	var actual_event: Rect2 = event_proxy.get_global_transform() * (effect.get("_dissolve").get("_source_rect") as Rect2)
	_measure("event_item_loss", expected_event, actual_event)
	await _save("event_loss")
	effect.queue_free()
	scene.queue_free()
	await _settle()
	var graft := preload("res://scripts/graftwright_view.gd").new()
	_viewport.add_child(graft)
	graft.configure(GraftFixture.fixture(), false)
	graft.call("begin_work")
	graft.call("select_recipient", "undertaker_plate")
	graft.call("select_donor", "patched_cloak")
	graft.call("select_source", 0)
	graft.call("select_target", 0)
	await _settle()
	var source: Control = graft.find_child("SourceCard_0", true, false)
	var source_before: Rect2 = source.get_global_rect()
	graft.present_result(graft.state)
	var deadline: int = Time.get_ticks_msec() + GRAFT_DEADLINE_MSEC
	while graft.find_child("SacrificeUnravel", true, false) == null and Time.get_ticks_msec() < deadline: await process_frame
	_expect(graft.find_child("SacrificeUnravel", true, false) != null, "Actual Graftwright reaches its reparenting dissolve")
	_measure("graftwright_sacrifice", source_before, source.get_global_rect())
	await _save("graftwright")
	# Drain the actual ritual continuation before disposing its host.
	while graft.busy and Time.get_ticks_msec() < deadline: await process_frame
	graft.queue_free()
	await _settle()
	var report := FileAccess.open(_output.path_join("audit.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"native": _native, "measurements": _measurements}, "\t"))
	print("PURGE-04 EFFECT AUDIT: %s" % ("FAIL" if _failed else "PASS"))
	print(_output)
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _measure(effect: String, before: Rect2, after: Rect2) -> void:
	var displacement: Vector2 = after.position - before.position
	var resize: Vector2 = after.size - before.size
	_expect(displacement.length() <= 0.5 and resize.length() <= 0.5, effect + " has no reparenting jump")
	_measurements.append({"effect": effect, "before": [before.position.x, before.position.y, before.size.x, before.size.y], "after": [after.position.x, after.position.y, after.size.x, after.size.y]})
	print("PURGE-04 AUDIT %s before=%s after=%s displacement=%s resize=%s" % [effect, before, after, displacement, resize])

func _save(stem: String) -> void:
	if _native: await _capture(_output.path_join(stem + ".png"))
