extends SceneTree
const Tables = preload("res://scripts/encounter_tables.gd")
const Generator = preload("res://scripts/room_generator.gd")
const Suite = preload("res://tests/suites/encounter_tables_suite.gd")
var failures: int = 0
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)
func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--write-sidecars"):
		for name: String in DirAccess.get_files_at("res://tools/ptf01"):
			if not name.ends_with(".gd"): continue
			var uid_path: String = "res://tools/ptf01/" + name + ".uid"
			if FileAccess.file_exists(uid_path): continue
			var uid := FileAccess.open(uid_path, FileAccess.WRITE)
			uid.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
			uid.close()
	Suite._test_validation(check)
	Suite._test_invalid_fallback(check)
	Suite._test_tokens_and_trim(check)
	Suite._test_weights(check)
	Suite._test_history(check)
	Suite._test_run_history(check)
	Suite._test_legacy(check)
	Suite._test_section_resume(check)
	var generator := Generator.new()
	for k: int in range(1, 9):
		for depth: int in range(1, 4):
			var expected: int = mini(depth, 1 if k <= 2 else (2 if k <= 4 else 3))
			var room: Dictionary = {"coord": Vector2i(depth, k), "depth": depth, "type": "combat", "element": "lightning", "section_index": 0, "section_map_layout_revision": 7, "encounter_biome": "fire", "fight_number": k}
			for seed_value: int in range(20):
				var layout: Dictionary = generator.generate_room(seed_value, room, Vector2i.ZERO)
				check(layout["encounter_tier"] == expected, "tier depth/fight minimum")
				check(layout["enemies"].size() in range(1, Tables.unit_cap(expected, k) + 1), "post-expansion cap")
				check(layout == generator.generate_room(seed_value, room, Vector2i.ZERO), "deterministic room")
	var engine := Suite.RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(Suite.FIXTURE_SEED, Suite.Progression.default_data())
	var destination: Vector2i = Suite.Graph.room(state, Vector2i.ZERO)["connections"][0]["coord"]
	var started: Dictionary = engine.move_to_room(state, destination)
	var snapshot: Dictionary = preload("res://scripts/analytics_snapshots.gd").combat_started(preload("res://scripts/combat_engine.gd").new(), engine, started, started["combat_state"], "ptf01")
	check(snapshot["fight_number"] == 1 and snapshot["encounter_tier"] == 1, "combat-start additive fields from persisted room")
	var tutorial: Dictionary = Suite.Guided.mark_run_eligible(state)
	var authored: Dictionary = engine.move_to_room(tutorial, destination)
	check(Suite.Guided.is_authored(authored["combat_state"]) and Suite.Graph.room(authored, destination)["fight_number"] == 1, "guided tutorial is fight one")
	Suite.Graph.room(authored, destination)["cleared"] = true
	check(Tables.fight_number(authored, {"coord": Vector2i(99, 0), "section_index": 0}) == 2, "guided tutorial advances next fight")
	check(Tables.fight_number(authored, {"coord": Vector2i(99, 1), "section_index": 1}) == 1, "new section resets fight number")
	var original: Dictionary = Tables.load()
	# Force an impossible first pick (two lightning groups + fire group >3).
	var table: Dictionary = original.duplicate(true)
	table["tiers"]["1"] = [{"id": "too_large", "weight": 1e20, "units": ["$element", "$element", "$biome"]}, {"id": "fallback", "weight": 1, "units": ["$biome", "crawler", "harrier", "warden"]}]
	Tables.install_table_for_tests(table)
	check(not Tables.load().is_empty(), "validator allows rerollable entries")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var picked: Dictionary = Tables.pick(1, "lightning", "fire", [], rng)
	check(picked["id"] == "fallback" and picked["units"].size() <= 3 and not picked["units"].is_empty(), "failed token seeded fitting reroll and concrete trim")
	for bad_cap: Variant in [null, {}, {"1": 0, "2": 4, "3": 6}, {"1": 3.5, "2": 4, "3": 6}, {"1": 3, "2": 4, "3": 8}]:
		var bad: Dictionary = original.duplicate(true)
		bad["rules"]["tier_max_units"] = bad_cap
		check(not Tables.validate(bad).is_empty(), "reject invalid tier caps")
	Tables.clear_table_cache()
	_test_fight_caps(original)
	print("PTF01 FOCUSED: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _test_fight_caps(original: Dictionary) -> void:
	# Explicit authored expectations, independent of the cap resolver.
	var expected: Array = [3, 3, 4, 5, 5, 6, 6, 6]
	for k: int in range(1, expected.size() + 1):
		check(Tables.unit_cap(Tables.fight_number_tier(k), k) == expected[k - 1], "authored cap for fight %d" % k)
	check(Tables.unit_cap(3, 100) == 6, "fight numbers beyond the last key retain the final cap")
	check(Tables.unit_cap(1, 100) == 3 and Tables.unit_cap(2, 100) == 5, "depth tier still bounds later-fight caps")
	for bad_caps: Variant in [null, {}, {"1": 0}, {"1": 3.5}, {"1": 8}, {"2": 3}, {"1": 3, "3": 4}, {"01": 3}, {"bad": 3}]:
		var bad: Dictionary = original.duplicate(true)
		bad["rules"]["fight_max_units"] = bad_caps
		check(not Tables.validate(bad).is_empty(), "reject malformed fight caps")
	# Tier 2 has a cap-5 cohort and a cap-4 cohort. Tier 3 similarly has caps
	# 6 and 5. A fallback at the tier ceiling alone is insufficient.
	for tier: int in [2, 3]:
		var fixture: Dictionary = original.duplicate(true)
		for biome: String in Tables.BIOMES:
			fixture["biome_groups"][biome] = [{"id": "single", "weight": 1, "units": ["crawler"]}]
		var tokens: Array = []
		for index: int in range(tier + 3): tokens.append("$biome")
		fixture["tiers"][str(tier)] = [{"id": "ceiling_only", "weight": 1, "units": tokens}]
		check(not Tables.validate(fixture).is_empty(), "reject missing fallback below tier %d ceiling" % tier)
		var cap_error: bool = false
		for error: String in Tables.validate(fixture):
			if error.contains("tier %d/cap %d/" % [tier, tier + 2]): cap_error = true
		check(cap_error, "validator identifies reachable lower-cap cohort")
		fixture["tiers"][str(tier)].append({"id": "fits_every_cap", "weight": 1, "units": ["crawler"]})
		check(Tables.validate(fixture).is_empty(), "fallback covers every reachable tier/cap cohort")
		Tables.install_table_for_tests(fixture)
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for k: int in range(1, 9):
			if Tables.fight_number_tier(k) < tier: continue
			var pick: Dictionary = Tables.pick(tier, "none", "fire", [], rng, false, k)
			check(not pick.is_empty() and pick["units"].size() <= Tables.unit_cap(tier, k), "validated cohort produces a fitting nonempty fight")
		Tables.clear_table_cache()
