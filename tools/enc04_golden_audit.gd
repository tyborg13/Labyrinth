extends SceneTree
## Reproduce the frozen oracle with only the pre-enc-03 Slag Mortar data,
## then retain full snapshots so the deliberate golden update is auditable.
const Sweep = preload("res://tools/encounter_sweep.gd")
const Game = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/analytics_store.gd")
const DEFAULT_OUTPUT: String = "/private/tmp/labyrinth_codex/enc-04/golden-audit"

static func approved_pending_counter(state: Dictionary) -> bool:
	return typeof(state.get("pending_summon_card_plays")) == TYPE_INT and state["pending_summon_card_plays"] == 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var output: String = Sweep.option(OS.get_cmdline_user_args(), "--output-dir", DEFAULT_OUTPUT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var current_definition: Dictionary = Game.enemies()["slag_mortar"]
	var report: Dictionary = {}
	for legacy: bool in [true, false]:
		Game.enemies()["slag_mortar"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/enc03_slag_before.json")) if legacy else current_definition
		var snapshots: Array
		var golden: Dictionary = Sweep.golden(func(combats: Array) -> Array:
			var normalized: Array = combats.duplicate(true)
			# Same compatibility normalizer as encounter_measurement_test.gd;
			# no combat-rule differences are removed.
			for state: Dictionary in normalized:
				for enemy: Dictionary in state.get("enemies", []):
					for action: Dictionary in enemy.get("intent", {}).get("actions", []): action.erase("_wind_direction")
			snapshots.append(normalized)
			return normalized)
		var rooms: Dictionary = {}
		for index: int in range(Sweep.GOLDEN_SEEDS.size()):
			var seed_value: int = Sweep.GOLDEN_SEEDS[index]
			var state: Dictionary = Sweep.map_for_seed(seed_value, Sweep.LEGACY_REVISION)
			var generated: Array
			var metadata: Array
			for sample: Dictionary in Sweep.samples(state, PackedStringArray(["standard"])):
				generated.append(Sweep.layout(sample, state))
				metadata.append({"coord": sample["room"]["coord"], "biome": sample["biome"], "tier": sample["tier"]})
			var combats: Array = snapshots[index]
			rooms[str(seed_value)] = {"map": state, "rooms": generated, "metadata": metadata, "combat": combats, "roundtrip": bytes_to_var(var_to_bytes([state, generated, combats]))}
		report["before" if legacy else "after"] = {"golden": golden, "snapshots": rooms}
	Game.enemies()["slag_mortar"] = current_definition
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/encounter_measurement_golden.json"))
	report["legacy_matches_frozen"] = report["before"]["golden"] == frozen
	report["current_matches_frozen"] = report["after"]["golden"] == frozen
	# int-06: prove every changed byte before re-pinning. The merge retained
	# bos-01's seed-421 pair (pre-enc-03 Slag), while enc-04 pinned seed 1's
	# new Slag intents. sum-01 adds a zero pending counter to all 54 rooms
	# (108 initial/next-turn snapshots); none summons during this oracle.
	var prior: Dictionary = {}
	var removed: int = 0
	var valid_pending: bool = true
	for seed_value: int in Sweep.GOLDEN_SEEDS:
		var seed_key: String = str(seed_value)
		var source: Dictionary = report["before" if seed_value == 421 else "after"]["snapshots"][seed_key]
		var combats: Array = source["combat"].duplicate(true)
		for state: Dictionary in combats:
			valid_pending = valid_pending and approved_pending_counter(state)
			if state.erase("pending_summon_card_plays"): removed += 1
		prior[seed_key] = {"map": Sweep.digest(source["map"]), "rooms": Sweep.digest(source["rooms"]), "combat": Sweep.digest(combats), "save_roundtrip": Sweep.digest(bytes_to_var(var_to_bytes([source["map"], source["rooms"], combats])))}
	report["int06_prior_matches_frozen"] = valid_pending and removed == 108 and prior == frozen
	var repin: bool = OS.get_cmdline_user_args().has("--int06-repin")
	if repin and report["int06_prior_matches_frozen"]:
		var golden_file := FileAccess.open("res://tests/fixtures/encounter_measurement_golden.json", FileAccess.WRITE)
		golden_file.store_string(JSON.stringify(report["after"]["golden"], "\t") + "\n")
	print("INT06 GOLDEN AUDIT: prior_matches_frozen=%s; sum-01=54 rooms/108 snapshots; bos-01=1 room already pinned; enc-03/enc-04=2 rooms (seed 421 combined); repinned=%s" % [report["int06_prior_matches_frozen"], repin and report["int06_prior_matches_frozen"]])
	var file := FileAccess.open(output.path_join("snapshots.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(Store._sanitize_variant(report), "\t"))
	print("ENC04 GOLDEN AUDIT: legacy_matches_frozen=%s current_matches_frozen=%s; snapshots=%s" % [report["legacy_matches_frozen"], report["current_matches_frozen"], ProjectSettings.globalize_path(output.path_join("snapshots.json"))])
	quit(0 if report["legacy_matches_frozen"] or report["current_matches_frozen"] or report["int06_prior_matches_frozen"] else 1)
