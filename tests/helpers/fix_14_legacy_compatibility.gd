extends RefCounted

# Pinned int-10 presentation and analytics with the merged Burst and status rules.
# The Warden's strike still deals 6. The Tick's Burst follows the cross, so the
# diagonal hero takes no Burst damage. Snapshot fields follow current combat state.
const GOLDEN: String = "res://tests/fixtures/fix_14_legacy_presentation.json"
const RetiredStatuses = preload("res://scripts/retired_combat_status_migration.gd")

static func current_capture(capture: String) -> Dictionary:
	var value: Dictionary = JSON.parse_string(capture)
	RetiredStatuses.migrate(value)
	# A historical save keeps the event journal. This expected capture models
	# newly resolved events, including the retired fields inside snapshots.
	RetiredStatuses.migrate({"capture": value.get("surface_events", [])})
	for step: Dictionary in value.get("steps", []):
		RetiredStatuses.migrate({"capture": step.get("surface_events", [])})
	return value

static func current_action_records(events: Array) -> void:
	for event: Dictionary in events:
		event["payload"]["status_riders_retired"] = true

static func matches_capture(actual: Dictionary, expected: Dictionary) -> bool:
	# Round-trip the runtime values to compare JSON number and vector representations.
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))

static func resolution(expect: Callable, phase: Dictionary, scene: Control, mode: String) -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var actual: Dictionary = {"steps": phase["steps"], "surface_events": phase["state"].get("surface_events", []), "actions": scene._analytics_enemy_action_events(phase, {}), "statuses": scene._analytics_enemy_status_tick_events(phase, {})}
	actual = actual.duplicate(true)
	expect.call(_remove_lay_metadata(actual, int(phase["state"].get("turn", 1)), expect)>0, "Legacy resolution exercises separately tested bos-04 ground provenance")
	var expected: Dictionary = current_capture(str(base[mode]["resolution"]))
	current_action_records(expected["actions"])
	expect.call(matches_capture(actual, expected), "Ordinary %s resolution and analytics match the current forms of the int-10 records" % mode)

static func _remove_lay_metadata(value: Variant, player_activation: int, expect: Callable) -> int:
	# Ground lay provenance is tested separately and remains excluded here;
	# positions, damage, causality and all other event bytes compare exactly.
	var removed: int = 0
	if value is Array:
		for child: Variant in value: removed += _remove_lay_metadata(child, player_activation, expect)
	elif value is Dictionary:
		if value.has("laid_player_activation"):
			var laid: Variant = value["laid_player_activation"]
			expect.call(typeof(laid)==TYPE_INT and int(laid)>=0 and int(laid)<=player_activation, "Legacy resolution carries a valid saved ground lay index")
			value.erase("laid_player_activation")
			removed += 1
		for child: Variant in value.values(): removed += _remove_lay_metadata(child, player_activation, expect)
	return removed

static func playback(expect: Callable, state: Dictionary, scene: Control, mode: String) -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var actual: Dictionary = {"popups": scene.get("popup_submissions"), "defeats": scene.get("defeat_owners"), "bursts": scene.get("burst_sources"), "hp": preload("res://tests/helpers/fix_12_popup_totals.gd").actors(state).values().map(func(unit: Dictionary) -> int: return int(unit.get("hp", 0)))}
	expect.call(JSON.stringify(actual) == str(base[mode]["playback"]), "Ordinary %s production playback matches the pinned strike and cardinal Burst playback" % mode)

# int-10 baseline for current Capacitor and Stalker payloads.
# qa-28 (b5adc691c) adds Capacitor's private Charge analytics_fields adapter and analytics amount.
static func nontraced_payloads(expect: Callable, combat: RefCounted, scene: Control) -> void:
	var Fixtures = preload("res://tests/suites/en06_enemies_suite.gd")
	var actual: Dictionary = {}
	for type: String in ["storm_capacitor", "gloam_stalker"]:
		var before: Dictionary = Fixtures.capacitor(0) if type == "storm_capacitor" else Fixtures.state([Fixtures.enemy("gloam_stalker", 1, Vector2i(6, 4), "ambush")])
		before["illusions"] = [{"id": 1, "pos": Vector2i(5, 4), "hp": 20, "max_hp": 20}]
		var phase: Dictionary = combat.resolve_enemy_turn_with_steps(before, 0, false)
		actual[type] = {"steps": phase["steps"], "analytics": scene._analytics_enemy_action_events(phase, {})}
	var expected: Dictionary = current_capture(FileAccess.get_file_as_string("res://tests/fixtures/fix_15_legacy_nontrace.json"))
	for type: String in expected: current_action_records(expected[type]["analytics"])
	expect.call(matches_capture(actual, expected), "Capacitor and Stalker presentation and analytics match the current forms of the int-10 records")
