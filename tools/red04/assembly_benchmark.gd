extends SceneTree
## Paired red-04/red-05 per-submission CPU cost on production threat rows.

const Suite = preload("res://tests/suites/threats_at_rest_suite.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const Tiles = preload("res://scripts/threat_tiles.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Cases = preload("res://tools/red04/followup_repros.gd")
const WARMUP_SUBMISSIONS: int = 1000
const SUBMISSIONS_PER_SAMPLE: int = 2000
const SAMPLE_COUNT: int = 31
const LOB_SUBMISSIONS_PER_SAMPLE: int = 200

func _initialize() -> void:
	_run()

func _run() -> void:
	var engine := Combat.new()
	var state: Dictionary = Suite.crowded_state(engine)
	var base: Dictionary = Badges.build(engine, state, state)
	var key: String = base["badges"][0]["key"]
	var hero: Vector2i = base["hero_tile"]
	var decoration: Dictionary = {"key": Red.RULE_KEY, "tiles": [hero, hero + Vector2i.DOWN], "rule_outline": true}
	_bench("warm_no_change", base, Discs.record({"enemy_activations": {key: 1}}, 1), {})
	_bench("restored_warning", base, Discs.record({"died_first_keys": {key: true}}, 1), {})
	_bench("contacts_and_rule_outline", base, Discs.record({"hero_red_contacts": {hero: {Red.RULE_KEY: true, Red.FOE_SURFACE_KEY: true}}}, 1), decoration)
	_bench_lob("crowded_without_lob", state)
	_bench_lob("slag_mortar", Cases.mortar_state())
	_bench_lob("slagmaster_retreat", Cases.mortar_state(true, Cases.NEAR_CAPTAIN))
	quit()

func _bench(label: String, base: Dictionary, marks: Dictionary, decoration: Dictionary) -> void:
	_measure(base, marks, decoration, false, WARMUP_SUBMISSIONS)
	_measure(base, marks, decoration, true, WARMUP_SUBMISSIONS)
	var legacy: Array[float]
	var current: Array[float]
	var deltas: Array[float]
	for sample: int in range(SAMPLE_COUNT):
		var old_cost: float
		var new_cost: float
		if sample % 2 == 0:
			old_cost = _measure(base, marks, decoration, false, SUBMISSIONS_PER_SAMPLE)
			new_cost = _measure(base, marks, decoration, true, SUBMISSIONS_PER_SAMPLE)
		else:
			new_cost = _measure(base, marks, decoration, true, SUBMISSIONS_PER_SAMPLE)
			old_cost = _measure(base, marks, decoration, false, SUBMISSIONS_PER_SAMPLE)
		legacy.append(old_cost)
		current.append(new_cost)
		deltas.append(new_cost - old_cost)
	legacy.sort()
	current.sort()
	deltas.sort()
	var mid: int = SAMPLE_COUNT / 2
	var p95: int = ceili(SAMPLE_COUNT * 0.95) - 1
	print("RED05 ASSEMBLY %s: red-04 median=%.2f us red-05 median=%.2f us paired delta median=%+.2f us p95=%+.2f us" %
		[label, legacy[mid], current[mid], deltas[mid], deltas[p95]])

func _measure(base: Dictionary, marks: Dictionary, decoration: Dictionary, own_rows: bool, submissions: int) -> float:
	var previous: Dictionary = {}
	var marker_coverage: Dictionary = {}
	var floor_coverage: Dictionary = {}
	var started: int = Time.get_ticks_usec()
	for frame: int in range(submissions):
		var release: Dictionary = Discs.apply(base, marks, 1, true)
		var override: Variant = Red.floor_override(base, release, marks)
		var rows: Array = release["threats"]
		if not decoration.is_empty():
			rows = rows.duplicate()
			rows.append(decoration)
			release["threats"] = rows
		var shown: Dictionary = {Tiles.REST_KEY: release}
		if override != null:
			if not decoration.is_empty():
				override = override.duplicate()
				override.append(decoration)
			shown[Red.FLOOR_KEY] = override
		if own_rows:
			Tiles.own_paint_inputs(shown, previous, true, Red.FLOOR_KEY)
		var marker_rows: Array = shown[Tiles.REST_KEY]["threats"]
		if marker_coverage.is_empty() or marker_rows != previous.get(Tiles.REST_KEY, {}).get("threats", []):
			marker_coverage = Tiles.coverage(marker_rows)
		if not shown.has(Red.FLOOR_KEY):
			floor_coverage = marker_coverage
		elif floor_coverage.is_empty() or shown[Red.FLOOR_KEY] != previous.get(Red.FLOOR_KEY):
			floor_coverage = Tiles.coverage(shown[Red.FLOOR_KEY])
		previous = shown
	return float(Time.get_ticks_usec() - started) / submissions

func _bench_lob(label: String, state: Dictionary) -> void:
	var board := Cases.Board.new()
	board.combat_state = state
	_measure_lob(board, false)
	_measure_lob(board, true)
	var legacy: Array[float]
	var current: Array[float]
	var deltas: Array[float]
	for sample: int in range(SAMPLE_COUNT):
		var old_cost: float
		var new_cost: float
		if sample % 2 == 0:
			old_cost = _measure_lob(board, false)
			new_cost = _measure_lob(board, true)
		else:
			new_cost = _measure_lob(board, true)
			old_cost = _measure_lob(board, false)
		legacy.append(old_cost)
		current.append(new_cost)
		deltas.append(new_cost - old_cost)
	legacy.sort()
	current.sort()
	deltas.sort()
	var mid: int = SAMPLE_COUNT / 2
	var p95: int = ceili(SAMPLE_COUNT * 0.95) - 1
	print("RED06 LOB ASSEMBLY %s: release median=%.2f us red-06 median=%.2f us paired delta median=%+.2f us p95=%+.2f us" %
		[label, legacy[mid], current[mid], deltas[mid], deltas[p95]])
	board.free()

func _measure_lob(board: Control, retained: bool) -> float:
	var started: int = Time.get_ticks_usec()
	for submission: int in range(LOB_SUBMISSIONS_PER_SAMPLE):
		if retained:
			Lob.floor_marks(board)
			Lob.floor_marks(board)
		else:
			Lob._marks(board.combat_state)
			Lob._marks(board.combat_state)
	return float(Time.get_ticks_usec() - started) / LOB_SUBMISSIONS_PER_SAMPLE
