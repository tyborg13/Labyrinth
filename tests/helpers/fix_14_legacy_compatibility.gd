extends RefCounted

# int-10 baseline after the approved enemy simplifications. Includes additive
# committed_shape/element analytics, Ambush without Veiled, and current Stalker
# snapshots. Trap causality remains part of the exact comparison.
# brs-01 supersedes only retaliate.steps[2].death_burst_events_after and
# retaliate.playback.bursts[0] (Tick 2): every resolved Burst now plays.
# brs-02 moves that Burst's 4 HP out of the attack popup: the attack shows
# -6 at 24 HP; the existing Burst beat owns -4 and the true 20 HP result.
# pol-17 (440ab0d3e) adds each popup's damage-tier hit_scale; pol-26
# (5822959d8) adds its actor-anchored offset. All other playback bytes stay pinned.
const GOLDEN: String = "res://tests/fixtures/fix_14_legacy_presentation.json"

static func resolution(expect: Callable, phase: Dictionary, scene: Control, mode: String) -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var actual: Dictionary = {"steps": phase["steps"], "surface_events": phase["state"].get("surface_events", []), "actions": scene._analytics_enemy_action_events(phase, {}), "statuses": scene._analytics_enemy_status_tick_events(phase, {})}
	actual = actual.duplicate(true)
	expect.call(_remove_lay_metadata(actual, int(phase["state"].get("turn", 1)), expect)>0, "Legacy resolution exercises separately tested bos-04 ground provenance")
	expect.call(JSON.stringify(actual) == str(base[mode]["resolution"]), "Ordinary %s resolution and analytics byte-match int-10 baseline plus brs-01 Burst journal" % mode)

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
	expect.call(JSON.stringify(actual) == str(base[mode]["playback"]), "Ordinary %s production playback byte-matches int-10 baseline plus brs-01 Burst playback" % mode)

# int-10 baseline for current Capacitor and Stalker payloads.
static func nontraced_payloads(expect: Callable, combat: RefCounted, scene: Control) -> void:
	var Fixtures = preload("res://tests/suites/en06_enemies_suite.gd")
	var actual: Dictionary = {}
	for type: String in ["storm_capacitor", "gloam_stalker"]:
		var before: Dictionary = Fixtures.capacitor(0) if type == "storm_capacitor" else Fixtures.state([Fixtures.enemy("gloam_stalker", 1, Vector2i(6, 4), "ambush")])
		before["illusions"] = [{"id": 1, "pos": Vector2i(5, 4), "hp": 20, "max_hp": 20}]
		var phase: Dictionary = combat.resolve_enemy_turn_with_steps(before, 0, false)
		actual[type] = {"steps": phase["steps"], "analytics": scene._analytics_enemy_action_events(phase, {})}
	var expected: String = FileAccess.get_file_as_string("res://tests/fixtures/fix_15_legacy_nontrace.json")
	expect.call(JSON.stringify(actual, "\t", true) + "\n" == expected, "Capacitor and Stalker full presentation payloads and analytics byte-match int-10 baseline")
