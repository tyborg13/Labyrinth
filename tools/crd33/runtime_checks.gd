extends SceneTree
## Adapted from crd-28. Every witness is an authored card through the real
## targeting, resolution and card acceptance functions.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Data = preload("res://scripts/game_data.gd")
const Fight = preload("res://tools/crd33/fight.gd")
const PatternChecks = preload("res://tools/crd33/pattern_checks.gd")
const Cases = preload("res://tools/crd33/witness_cases.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const MUTATION_DAMAGE_DELTA := 1
const GROUND_FALLBACKS := ["ice", "fire", "electrified", "rubble"]
const FIXTURE_ILLUSION_TILE := Vector2i(2, 5)
const FIXTURE_ILLUSION_ID := 10
const FIXTURE_ILLUSION_HEALTH := 20

var _fight := Fight.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Runtime.apply_from_environment()
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 and args.size() != 3:
		push_error("Usage: runtime_checks.gd -- <results.json> [<card-id> <scratch-cards.json>]")
		quit(2)
		return
	var ids: Array = Data.cards().keys()
	var specific: String = args[1] if args.size() == 3 else ""
	if not specific.is_empty():
		if not ids.has(specific):
			push_error("Unknown requested ID: " + specific)
			quit(2)
			return
		if not args[2].is_empty() and not _load_scratch(args[2], specific):
			push_error("Scratch card table must differ only in the selected card's first damage field (+1)")
			quit(2)
			return
		ids = [specific]
	ids.sort()
	var cards: Dictionary = {}
	var committed: int = 0
	for id: String in ids:
		var entries: Dictionary = {"base": _sample(id)}
		var card: Dictionary = Data.card_def_for_progression(id, {})
		if specific.is_empty() and not (card.get("empower", {}) as Dictionary).is_empty():
			entries["empower"] = _sample(id, "empower")
		if specific.is_empty() and Data.card_def(id, true) != Data.card_def(id):
			entries["legacy"] = _sample(id, "play", true)
		for entry: Dictionary in entries.values():
			if not entry.has("blocked"): committed += 1
		cards[id] = entries
	var witnesses: Dictionary = Cases.run(_fight) if specific.is_empty() else {}
	var patterns: Dictionary = {}
	if specific.is_empty():
		for id: String in ids:
			for mode: String in ["base", "legacy"]:
				if not cards[id].has(mode): continue
				var measurement: Dictionary = PatternChecks.measure(_fight, id, mode == "legacy")
				if not measurement.is_empty(): patterns[id + "/" + mode] = measurement
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot save runtime receipts: %s" % FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(JSON.stringify({"cards": cards, "witnesses": witnesses, "patterns": patterns}, "  ") + "\n")
	file.close()
	print("CRD32 RUNTIME: %d card IDs; %d successful plays; %d named scenarios; %d sampled areas" % [cards.size(), committed, witnesses.size(), patterns.size()])
	quit(0)

func _sample(id: String, mode: String = "play", legacy: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var state: Dictionary = _sample_state(legacy)
	result = _fight.play(state, id, [], false, mode)
	if not result.has("blocked"): return _receipt(result, "clear board")
	var blocked: Array = [result["blocked"]]
	for ground: String in GROUND_FALLBACKS:
		state = _sample_state(legacy)
		for tile: Vector2i in [Fight.HERO, Fight.NEAR, Fight.SECOND]:
			Ground.place(state, tile, ground)
		result = _fight.play(state, id, [], false, mode)
		if not result.has("blocked"): return _receipt(result, ground)
		if not blocked.has(result["blocked"]): blocked.append(result["blocked"])
	state = _sample_state(legacy)
	var light: Dictionary = _fight.play(state, "beacon", [Fight.NEAR], true)
	if not light.has("blocked"):
		result = _fight.play(light["after"], id, [], false, mode)
		if not result.has("blocked"): return _receipt(result, "Light from Beacon")
	state = _sample_state(legacy)
	var outcrop_tile := Fight.HERO + Vector2i.UP
	var setup: Dictionary = _fight.play(state, "geode", [outcrop_tile], true)
	if not setup.has("blocked"):
		result = _fight.play(setup["after"], id, [outcrop_tile], false, mode)
		if not result.has("blocked"): return _receipt(result, "Outcrop from Geode")
	return {"blocked": "; ".join(blocked)}

func _sample_state(legacy: bool) -> Dictionary:
	var state: Dictionary = _fight.fresh()
	state[Data.LEGACY_STARTER_CARDS_KEY] = legacy
	state["illusions"] = [{"id": FIXTURE_ILLUSION_ID, "pos": FIXTURE_ILLUSION_TILE, "hp": FIXTURE_ILLUSION_HEALTH, "max_hp": FIXTURE_ILLUSION_HEALTH}]
	return state

func _receipt(result: Dictionary, layout: String) -> Dictionary:
	return {
		"layout": layout, "targets": result["targets"], "steps": result["steps"],
		"before": _fight.snapshot(result["before"]), "after": _fight.snapshot(result["after"]),
	}

func _load_scratch(path: String, id: String) -> bool:
	if path == "res://data/cards.json" or path.simplify_path() == ProjectSettings.globalize_path("res://data/cards.json"):
		return false
	var scratch: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not scratch is Dictionary:
		return false
	var live: Dictionary = Data.cards()
	var expected: Dictionary = live.duplicate(true)
	var actions: Array = expected[id].get("actions", [])
	if actions.is_empty() or not (actions[0] as Dictionary).has("damage"):
		return false
	var first: Dictionary = actions[0]
	first["damage"] = int(first["damage"]) + MUTATION_DAMAGE_DELTA
	# JSON parser preserves the same numeric type as the source table.
	first["damage"] = float(first["damage"])
	if expected != scratch: return false
	live[id] = scratch[id]
	return true
