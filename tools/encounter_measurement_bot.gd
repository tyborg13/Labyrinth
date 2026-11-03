extends "res://tools/encounter_bot.gd"
## Measurement selection only. The policy file remains byte-identical to revision 6.
const MeasurementEngine = preload("res://tools/encounter_measurement_engine.gd")
const CommittedPolicy = preload("res://scripts/battlefield_rules/bot_policy.gd")
const MetricRepair = preload("res://tools/encounter_metric_repair.gd")
const LastLightEngine = preload("res://tools/last_light_measurement_engine.gd")
const HoarderObserver = preload("res://tools/hoarder_measurement_engine.gd")
const METRIC_LOCK_POLL_MSEC: int = 200
var deck_override: Dictionary = {}

static func prepare_addition(presets: Dictionary, addition: Dictionary) -> Dictionary:
	var result: Dictionary = addition.duplicate(true)
	if addition.is_empty() or (addition.get("fields", {}) as Dictionary).is_empty(): return result
	var card_id: String = str(addition["card"])
	for tier: String in ["1", "2", "3"]:
		if not presets[tier].has(card_id): continue
		# Isolate the one added copy when the preset already has this identity.
		# This private in-memory definition never enters reward offers or disk.
		var instance_id: String = "__measurement_added_" + card_id
		assert(not Game.cards().has(instance_id), "Measurement card identity collision")
		var definition: Dictionary = MeasurementEngine.with_fields(Game.cards()[card_id], addition["fields"])
		definition["reward_pool"] = false
		Game.cards()[instance_id] = definition
		result["deck_card"] = instance_id
		break
	return result

static func overridden_presets(presets: Dictionary, addition: Dictionary) -> Dictionary:
	var result: Dictionary = presets.duplicate(true)
	if not addition.is_empty():
		for tier: String in ["1", "2", "3"]: result[tier].append(addition.get("deck_card", addition["card"]))
	return result

func write_report(output: String, revision: int, cohort: String, presets: Dictionary, results: Array[Dictionary]) -> void:
	super.write_report(output, revision, cohort, presets, results)
	if deck_override.is_empty(): return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output))
	report["deck_override"] = deck_override
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()

static func deck_tier(sample: Dictionary) -> int:
	return 3 if sample["cohort"] == "boss" else int(sample["tier"])

static func accepts(sample: Dictionary, tier: int, cohort: String, boss_id: String = "") -> bool:
	return int(sample["tier"]) == tier and sample["cohort"] == cohort and (boss_id.is_empty() or sample["room"].get("boss_id", "") == boss_id)

func measured_result(policy, measurement_engine, room: Dictionary, sample: Dictionary, presets: Dictionary, measure_usage: bool) -> Dictionary:
	var result: Dictionary = policy.run_room(int(sample["seed"]), room, presets[str(deck_tier(sample))])
	if measure_usage:
		result["card_usage"] = measurement_engine.final_metrics.duplicate(true)
		result["card_usage"]["origin_metric"] = MetricRepair.ORIGIN_VERSION
	if measurement_engine.primary_only_shock(): result["primary_only_shock_adapter"] = true
	if room.get("special_type", "") == "ember_hoarder" and policy.engine is HoarderObserver: result.merge(preload("res://scripts/hoarder_room_rules.gd").analytics({"objective": policy.engine.final_objective}))
	result.merge({"revision": sample["revision"], "cohort": sample["cohort"], "special_type": room.get("special_type", ""), "special_variant": room.get("special_variant", ""), "tier": sample["tier"], "biome": sample["biome"], "section_index": sample["section_index"], "coord": Store._sanitize_variant(sample["room"]["coord"]), "travel_dir": Store._sanitize_variant(sample["travel_dir"]), "encounter_id": room.get("encounter_id", "")})
	if sample["cohort"] == "last_light": result.merge(LastLightEngine.dawn_metrics(policy.engine, result))
	if sample["cohort"] in ["guardian", "boss"]:
		result.merge({"deck_tier": deck_tier(sample), "room_tier": posmod(int(sample["room"]["depth"]) - 1, 4) + 1, "room_type": sample["room"]["type"], "boss_id": room.get("boss_id", ""), "guardian_id": room.get("guardian_id", "")})
	return result

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var presets: Dictionary = deck_presets()
	var addition: String = Sweep.option(args, "--add-card", "")
	var overrides: Variant = JSON.parse_string(Sweep.option(args, "--card-overrides", "{}"))
	assert(overrides is Dictionary, "--card-overrides requires a JSON object")
	assert(overrides.is_empty() or not addition.is_empty(), "--card-overrides requires --add-card")
	assert(addition.is_empty() or not Game.card_def(addition).is_empty(), "Unknown added card")
	if not addition.is_empty():
		deck_override = prepare_addition(presets, {"card": addition, "fields": overrides})
		presets = overridden_presets(presets, deck_override)
	var tier: int = int(Sweep.option(args, "--tier", "1"))
	assert(tier in [1, 2, 3])
	var count: int = int(Sweep.option(args, "--runs", "1"))
	var revision: int = int(Sweep.option(args, "--revision", str(Sweep.LATEST_REVISION)))
	assert(revision in Sweep.SUPPORTED_REVISIONS)
	var cohort: String = Sweep.option(args, "--cohort", "standard")
	assert(cohort in Sweep.cohorts(revision) or Sweep.special_cohort(cohort, revision), "Cohort is unavailable in this revision")
	# An empty filter retains the room's own objective; never substitute one.
	var objective: String = Sweep.option(args, "--objective", "")
	var boss_id: String = Sweep.option(args, "--boss-id", "")
	assert(boss_id.is_empty() or (cohort == "boss" and Sweep.Bosses.is_dragon_boss_id(boss_id)))
	assert(cohort != "boss" or tier == 3, "Boss measurements require the tier-3 deck preset")
	var requested_coord: String = Sweep.option(args, "--coord", "")
	assert(requested_coord.is_empty() or count == 1, "Coordinate replay requires exactly one run")
	assert(objective in ["", "kill_all", "kill_leader", "reach_exit"] and count > 0)
	var output: String = Sweep.option(args, "--output", "user://encounter_bot.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var policy := CommittedPolicy.new()
	var measurement_engine := MeasurementEngine.new()
	var measure_usage: bool = args.has("--measure-usage") or not deck_override.is_empty()
	if measure_usage:
		measurement_engine.added_card = addition
		measurement_engine.override_card_id = str(deck_override.get("deck_card", addition))
		measurement_engine.field_overrides = overrides
		policy.engine = measurement_engine
	if cohort == "last_light":
		assert(not measure_usage, "Last Light dawn metrics use their own capturing engine")
		policy.engine = LastLightEngine.new()
	policy.trace = args.has("--trace")
	if cohort == "ember_hoarder" and not measure_usage: policy.engine = HoarderObserver.new()
	var results: Array[Dictionary]
	var resume_path: String = Sweep.option(args, "--resume-report", "")
	if not resume_path.is_empty():
		# A counter refresher atomically replaces a completed checkpoint. Wait
		# before reading it so concurrent prefix validation cannot restore stale data.
		while DirAccess.dir_exists_absolute(resume_path + ".metric-lock"):
			OS.delay_msec(METRIC_LOCK_POLL_MSEC)
		var resumed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resume_path))
		if resumed.get("deck_override", {}) != deck_override:
			push_error("Resume requires identical card overrides")
			quit(1)
			return
		# JSON converts integer variants and typed arrays; compare like formats.
		if resumed["defaults"] != JSON.parse_string(JSON.stringify(defaults())) or resumed["decks"] != JSON.parse_string(JSON.stringify(presets)):
			push_error("Resume requires identical policy defaults and decks")
			quit(1)
			return
		assert(int(resumed["revision"]) == revision and resumed["cohort"] == cohort, "Resume requires the same revision/cohort")
		for result: Dictionary in resumed["results"]:
			if measurement_engine.primary_only_shock() and not result.get("primary_only_shock_adapter", false):
				push_error("Primary-only Shock requires adapter-aware checkpoints")
				quit(1)
				return
			assert(int(result["tier"]) == tier and (objective.is_empty() or result["objective"] == objective))
			assert(boss_id.is_empty() or result.get("boss_id", "") == boss_id)
			results.append(result)
		assert(results.size() <= count)
	var resume_count: int = results.size()
	var refresh_metrics: bool = args.has("--refresh-skybolt-metrics")
	if refresh_metrics and (resume_path.is_empty() or not measure_usage):
		push_error("Metric refresh requires a measured resume report")
		quit(1)
		return
	var metric_replays: int = 0
	var skipped: int = 0
	var seed_value: int = int(Sweep.option(args, "--seed", "1"))
	var first_seed: int = seed_value
	# Validate the whole resumed prefix, even when it already holds the requested count.
	while results.size() < count or skipped < resume_count:
		if seed_value - first_seed >= Sweep.MAX_SEED_SCAN:
			push_error("Seed scan exhausted before the requested cohort was filled")
			quit(1)
			return
		var state: Dictionary = Sweep.map_for_seed(seed_value, revision)
		for sample: Dictionary in Sweep.samples(state, PackedStringArray([cohort])):
			if not accepts(sample, tier, cohort, boss_id): continue
			var coord: Vector2i = sample["room"]["coord"]
			if not requested_coord.is_empty() and requested_coord != "%d,%d" % [coord.x, coord.y]: continue
			var room: Dictionary = Sweep.layout(sample, state)
			if not objective.is_empty() and room["objective"]["type"] != objective: continue
			if room["objective"]["type"] not in ["kill_all", "kill_leader", "reach_exit"] and not (Sweep.special_cohort(cohort, revision) and room["objective"]["type"] == "survive"):
				push_error("TODO_DESIGN_bot_objective_" + str(room["objective"]["type"]))
				quit(1)
				return
			if skipped < resume_count:
				var previous: Dictionary = results[skipped]
				var same_coord: bool = int(previous["coord"]["x"]) == coord.x and int(previous["coord"]["y"]) == coord.y
				var travel: Vector2i = sample["travel_dir"]
				var same_travel: bool = int(previous["travel_dir"]["x"]) == travel.x and int(previous["travel_dir"]["y"]) == travel.y
				if int(previous["seed"]) != seed_value or not same_coord or previous["biome"] != sample["biome"] or not same_travel or previous["objective"] != room["objective"]["type"]:
					push_error("Resume prefix differs from production sample order")
					quit(1)
					return
				if refresh_metrics:
					metric_replays += int(MetricRepair.needs_replay(previous))
					var refreshed: Dictionary = MetricRepair.refresh(previous, func() -> Dictionary: return measured_result(policy, measurement_engine, room, sample, presets, measure_usage))
					if refreshed.is_empty():
						quit(1)
						return
					results[skipped] = refreshed
					write_report(output, revision, cohort, presets, results)
				skipped += 1
				continue
			if results.size() >= count: break
			var result: Dictionary = measured_result(policy, measurement_engine, room, sample, presets, measure_usage)
			results.append(result)
			# Durable offline checkpoint; an interrupted measurement can resume.
			write_report(output, revision, cohort, presets, results)
			print("ENCOUNTER BOT RUN: " + JSON.stringify(result))
			if results.size() >= count: break
		if not requested_coord.is_empty() and results.is_empty():
			push_error("No sampled room matches the requested seed, tier, objective and coordinate")
			quit(1)
			return
		seed_value += 1
	write_report(output, revision, cohort, presets, results)
	if refresh_metrics: print("ENCOUNTER METRIC REFRESH: PASS (%d records; %d fights replayed)" % [results.size(), metric_replays])
	print("ENCOUNTER BOT: PASS (%d runs, revision %d, tier %d, %s / %s)" % [results.size(), revision, tier, cohort, objective])
	quit()
