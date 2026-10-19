extends SceneTree

## Headless production-route oracle. Sampling includes both legacy overlap and
## blocking-clock boundaries, with their adjacent microseconds.
const Fixtures = preload("res://tests/suites/en06_enemies_suite.gd")
const TYPES := ["hoarfrost_seer", "arc_thrall", "burrow_grub", "ember_tick", "bile_bloomer", "lightning_wisp"]
const PROOF_ORIGIN_USEC: int = 5000000
const PROOF_ENEMY_ROW: int = 3
const PROOF_ENEMY_COLUMN: int = 4
const PROOF_RETALIATE_HP: int = 1
const PROOF_RETALIATE_DAMAGE: int = 1
const PROOF_TIME_MARGIN_USEC: int = 100000
const PROOF_BOUNDARY_OFFSETS_USEC := [-1, 0, 1]
const REVIEW_TICK_FINAL_USEC: int = 900000
var report: Dictionary = {}
var times: Array

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var script: Script = preload("fixed_pacing.gd")
	if args.has("--pacing-source"):
		# Compile the exact Git-base or mutant source without touching production.
		var source: String = FileAccess.get_file_as_string(args[args.find("--pacing-source") + 1])
		source = source.replace("class_name CombatPacing", "")
		for method: String in ["presentation_usec", "present_turn_order", "_process"]:
			source = source.replace("\nfunc " + method + "(", "\nfunc _base_" + method + "(")
		var fixture: String = FileAccess.get_file_as_string("res://tests/rr19/fixed_pacing.gd")
		var loaded := GDScript.new()
		loaded.source_code = source + "\n" + fixture.substr(fixture.find("\n") + 1)
		if loaded.reload() != OK:
			quit(1)
			return
		script = loaded
	times = _sample_times()
	for type: String in TYPES:
		await _deaths(script, type, [type])
		await _deaths(script, "capacitor+" + type, ["storm_capacitor", type])
		await _deaths(script, type + "+capacitor", [type, "storm_capacitor"])
	await _deaths(script, "storm_capacitor", ["storm_capacitor"])
	await _deaths(script, "legacy_multi", ["hoarfrost_seer", "ember_tick"])
	await _deaths(script, "legacy_all", TYPES)
	await _deaths(script, "retaliate_tick", ["ember_tick"], true)
	await _deaths(script, "retaliate_capacitor", ["ember_tick", "storm_capacitor"], true)
	await _deaths(script, "retaliate_legacy", ["ember_tick", "arc_thrall"], true)
	var output: String = args[args.find("--output") + 1]
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("RR19 OVERLAP SAMPLES: PASS (%d cases, %d boundary times; headless logic only)" % [report.size(), times.size()])
	quit()

func _sample_times() -> Array:
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(preload("res://tests/rr17/death_scene.gd"))
	var boundaries: Dictionary = {0: true, REVIEW_TICK_FINAL_USEC: true}
	var longest: int = 0
	var types: Array = TYPES.duplicate()
	types.append("storm_capacitor")
	for type: String in types:
		var unit: Dictionary = {"type": type}
		var count: int = scene._enemy_death_frame_count_for_unit(unit)
		var seconds: float = scene._enemy_death_frame_seconds_for_unit(unit)
		var period: int = roundi(seconds * 1000000.0)
		var duration: int = int(count * seconds * 1000000.0)
		longest = maxi(longest, maxi(duration, count * period))
		for frame: int in range(count):
			for boundary: int in [frame * period, ceili((float(frame) - 0.5) * duration / maxi(1, count - 1))]:
				for offset: int in PROOF_BOUNDARY_OFFSETS_USEC:
					if boundary + offset >= 0: boundaries[boundary + offset] = true
		for end: int in [duration, count * period]:
			for offset: int in PROOF_BOUNDARY_OFFSETS_USEC: boundaries[end + offset] = true
	boundaries[longest + PROOF_TIME_MARGIN_USEC] = true
	scene.free()
	var result: Array = boundaries.keys()
	result.sort()
	return result

func _deaths(script: Script, label: String, types: Array, retaliate: bool = false) -> void:
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(preload("res://tests/rr17/death_scene.gd"))
	scene._combat_pacing.free()
	var pacing: Node = script.new()
	scene._combat_pacing = pacing
	pacing.install(scene)
	root.add_child(scene)
	var units: Array[Dictionary]
	for index: int in range(types.size()):
		units.append(Fixtures.enemy(types[index], index + 1, Vector2i(index + PROOF_ENEMY_COLUMN, PROOF_ENEMY_ROW), "scuttle" if types[index] == "ember_tick" else ""))
	var before: Dictionary = Fixtures.state(units)
	var after: Dictionary = before.duplicate(true)
	if retaliate:
		for unit: Dictionary in before["enemies"]: unit["hp"] = PROOF_RETALIATE_HP
		preload("res://scripts/retaliate_rules.gd").gain(before, {"amount": PROOF_RETALIATE_DAMAGE}, "RR19 fixture")
		var action: Dictionary = preload("res://scripts/game_data.gd").enemy_def("ember_tick")["intents"][0]["actions"][1]
		after = Fixtures.resolve_action(before, action)["state"]
	else:
		for unit: Dictionary in after["enemies"]: unit["hp"] = 0
	var before_snapshot: Dictionary = before.duplicate(true)
	var after_snapshot: Dictionary = after.duplicate(true)
	pacing.enemies_active = true
	pacing.now_usec = PROOF_ORIGIN_USEC
	await scene._animate_turn_order_alongside_defeats(before, after)
	var queued: Array = pacing._deaths
	var rows: Array[Dictionary]
	for time: int in times:
		pacing.now_usec = PROOF_ORIGIN_USEC + time
		var shown: Dictionary = {}
		pacing.decorate(after, shown)
		shown.erase("combat_feel_owner")
		rows.append({"usec": time, "presentation": shown.duplicate(true), "remaining": pacing._deaths.size()})
	var health: Array[Dictionary]
	for unit: Dictionary in after["enemies"]: health.append({"type": unit["type"], "hp": unit["hp"]})
	report[label] = {"rows": rows, "queued": queued.size(), "duration_usec": queued[0]["duration"] if not queued.is_empty() else -1,
		"orders": pacing.orders, "health": health, "burst_events": after.get("death_burst_events", []).size(),
		"states_unchanged": before == before_snapshot and after == after_snapshot}
	scene.free()
