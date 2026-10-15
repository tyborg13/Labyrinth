extends SceneTree

# Fresh-process menu load includes transitive compilation. Keep all project
# scripts dynamically loaded after this timer starts, including the rules.
const RECORDS: int = 50
const DISTINCT_CARDS: int = 45
const NORMALIZE_SAMPLES: int = 20

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
	var record: Dictionary = rules.build_record(state, "victory", {}, {"day": 15, "month": 10})
	var records: Array = []
	for index: int in range(RECORDS):
		var next: Dictionary = record.duplicate(true)
		next["run_id"] = "measure-%d" % index
		records.append(next)
	rules.normalized_records(records)
	var samples: Array[float]
	for index: int in range(NORMALIZE_SAMPLES):
		started = Time.get_ticks_usec()
		rules.normalized_records(records)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	print("CHRONICLE PERFORMANCE: " + JSON.stringify({
		"menu_load_ms": menu_ms, "records": RECORDS, "distinct_cards": DISTINCT_CARDS,
		"record_bytes": JSON.stringify(record).to_utf8_buffer().size(),
		"history_bytes": JSON.stringify(records).to_utf8_buffer().size(),
		"stored_definitions": record.get("deck_card_definitions", {}).size(),
		"normalize_median_ms": (samples[NORMALIZE_SAMPLES / 2 - 1] + samples[NORMALIZE_SAMPLES / 2]) / 2.0,
		"normalize_samples": NORMALIZE_SAMPLES,
		"run_scene_cached": ResourceLoader.has_cached("res://scripts/run_scene.gd")
	}))
	quit()
