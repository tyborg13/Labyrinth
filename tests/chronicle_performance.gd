extends SceneTree

# Fresh-process menu load includes transitive compilation. Keep all project
# scripts dynamically loaded after this timer starts, including the rules.
const RECORDS: int = 50
const DISTINCT_CARDS: int = 45
const NORMALIZE_SAMPLES: int = 20
const NORMALIZE_LIMIT_MS: float = 5.0
const RELIC_HEAVY_RELICS: Array[String] = ["crown_of_surplus", "leaden_pommel"]
var failures: Array[String]

func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	var menu: PackedScene = load("res://scenes/main_menu.tscn")
	var menu_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	if menu == null:
		quit(1)
		return
	var rules: Script = load("res://scripts/chronicle_rules.gd")
	var data: Script = load("res://scripts/game_data.gd")
	var deck: Array = data.cards().keys().slice(0, DISTINCT_CARDS)
	var state := {"chronicle_path": [["combat"]], "deck_cards": deck, "relics": [], "seed": 8821, "run_index": 0}
	var no_relic: Dictionary = _measure_history(rules, state, "no_relic")
	state["relics"] = RELIC_HEAVY_RELICS.duplicate()
	var relic_heavy: Dictionary = _measure_history(rules, state, "relic_heavy")
	_check(no_relic["stored_definitions"] == 0, "Unmodified history stores no card definitions")
	_check(relic_heavy["stored_definitions"] >= 40, "Relic-heavy history exercises at least 40 modified cards per record")
	_check(no_relic["normalize_median_ms"] <= NORMALIZE_LIMIT_MS, "No-relic normalization median must be <= 5 ms")
	_check(relic_heavy["normalize_median_ms"] <= NORMALIZE_LIMIT_MS, "Relic-heavy normalization median must be <= 5 ms")
	print("CHRONICLE PERFORMANCE: " + JSON.stringify({
		"menu_load_ms": menu_ms, "records": RECORDS, "distinct_cards": DISTINCT_CARDS,
		"no_relic": no_relic, "relic_heavy": relic_heavy,
		"relic_heavy_relics": RELIC_HEAVY_RELICS,
		"normalize_samples": NORMALIZE_SAMPLES, "normalize_limit_ms": NORMALIZE_LIMIT_MS,
		"run_scene_cached": ResourceLoader.has_cached("res://scripts/run_scene.gd")
	}))
	print("CHRONICLE PERFORMANCE RESULT: PASS" if failures.is_empty() else "CHRONICLE PERFORMANCE RESULT: FAIL (%d failure(s))" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _measure_history(rules: Script, state: Dictionary, history_name: String) -> Dictionary:
	# build_record obtains its stored deltas through deck_card_definitions on this
	# real run state, so the heavy case measures actual relic-modified card data.
	var record: Dictionary = rules.build_record(state, "victory", {}, {"day": 15, "month": 10})
	var records: Array = []
	for index: int in range(RECORDS):
		var next: Dictionary = record.duplicate(true)
		next["run_id"] = "%s-%d" % [history_name, index]
		records.append(next)
	rules.normalized_records(records)
	var samples: Array[float]
	for index: int in range(NORMALIZE_SAMPLES):
		var started: int = Time.get_ticks_usec()
		rules.normalized_records(records)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	return {
		"record_bytes": JSON.stringify(record).to_utf8_buffer().size(),
		"history_bytes": JSON.stringify(records).to_utf8_buffer().size(),
		"stored_definitions": record.get("deck_card_definitions", {}).size(),
		"normalize_median_ms": (samples[NORMALIZE_SAMPLES / 2 - 1] + samples[NORMALIZE_SAMPLES / 2]) / 2.0
	}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
