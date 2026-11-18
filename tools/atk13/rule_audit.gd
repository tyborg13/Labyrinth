extends SceneTree
## Natural fights, deterministic movement/PASS only. No encounter or dial edits.
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Cases = preload("res://tools/atk13/rule_cases.gd")
const RuleTruth = preload("res://tools/atk13/rule_truth.gd")
const Observer = preload("res://tools/atk13/rule_observer.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const View = preload("res://scripts/battlefield_rule_view.gd")
const Bot = preload("res://tools/encounter_bot.gd")
const Store = preload("res://scripts/analytics_store.gd")
const PROOF_SAMPLES: int = 3
const PROOF_ACTIVATIONS: int = 24
const PROOF_HEALTH: int = 9999
const PROOF_SPENT_TIME: int = 24
const PROOF_CANTOR_SPENT_TIME: int = 96
const PROOF_MOVE_PROBABILITY: float = 0.75
var failures: Array[String]
var coverage: Dictionary
const ForecastPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const Rows = preload("res://tools/ptf08/row_tests.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const Paths = preload("res://scripts/path_utils.gd")
const PROOF_FROZEN_SPAN_LIMIT: int = 100
var cantor_new_tiles_included: int = 0
var passes: Array[Dictionary]
var scene: Node
var records: Array[Dictionary]
var proof_witnesses: Dictionary
var proof_output: String

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var output: String = Cases.Sweep.option(OS.get_cmdline_user_args(), "--output", "/private/tmp/labyrinth_codex/area-02/truth.json")
	proof_output = output
	scene = preload("res://scripts/run_scene.gd").new()
	var selected: String = Cases.Sweep.option(OS.get_cmdline_user_args(), "--instance", "")
	for id: String in Rules.data()["instances"]:
		if not selected.is_empty() and selected != id: continue
		coverage[id] = {"fights": 0, "passes": 0, "beats": 0, "nonempty_beats": 0, "mismatches": 0, "drawn_but_not_red": 0, "impassable": 0, "occupied_raise": 0, "trap": 0, "brazier": 0, "forecast_known": 0, "forecast_hidden": 0, "forecast_mismatches": 0, "forecast_safe": 0, "seeds": []}
		for sample: Dictionary in Cases.samples_for(id, PROOF_SAMPLES): _fight(id, sample, output)
		print("AREA02 TRUTH INSTANCE %s: %s" % [id, JSON.stringify(coverage[id])])
		_write(output)
	if selected.is_empty() and cantor_new_tiles_included <= 0: failures.append("No natural Bell Tender post-Pass placement before Peal was witnessed")
	_write(output)
	for failure: String in failures: print("FAIL: " + failure)
	print("AREA02 TRUTH: %s (%d instances; %d mismatches; %d Cantor/Bell Tender inclusion witnesses)" % ["PASS" if failures.is_empty() else "FAIL", coverage.size(), failures.size(), cantor_new_tiles_included])
	scene.free()
	quit(0 if failures.is_empty() else 1)

func _fight(id: String, sample: Dictionary, output: String) -> void:
	var engine := Observer.new()
	var state: Dictionary = engine.create_combat(int(sample["seed"]), sample["layout"], {"hp": PROOF_HEALTH, "max_hp": PROOF_HEALTH, "deck_cards": Bot.deck_presets()["3"], "equipped_equipment": Bot.Game.starting_equipped_equipment(), "relics": []})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sample["seed"])
	coverage[id]["fights"] += 1
	coverage[id]["seeds"].append(sample["seed"])
	for activation: int in range(PROOF_ACTIVATIONS):
		if not engine.combat_outcome(state).is_empty(): break
		var legal: Array[Vector2i] = engine.player_movement_targets(state)
		if not legal.is_empty() and rng.randf() < PROOF_MOVE_PROBABILITY: state = engine.apply_player_movement(state, legal[rng.randi_range(0, legal.size() - 1)])
		state["player_turn_time_spent"] = PROOF_CANTOR_SPENT_TIME if id == "storm_cantor" else PROOF_SPENT_TIME
		var pass_state: Dictionary = state.duplicate(true)
		var summary: Dictionary = _forecast(pass_state)
		var steps: Array[Dictionary]
		proof_witnesses.clear()
		engine.impacts.clear()
		engine.fatigue_hp_loss = 0
		var skipped: int = 0
		while true:
			state = engine.finish_player_activation_with_rule_steps(state, Commit.callback(engine), steps)
			var advanced: Dictionary = Commit.advance_to_player(engine, state)
			steps.append_array(advanced["steps"])
			state = advanced["state"]
			if engine.combat_outcome(state) != "" or not bool(state.get("player_turn_restrictions", {}).get("frozen", false)): break
			skipped += 1
			if skipped >= PROOF_FROZEN_SPAN_LIMIT:
				failures.append("%s seed=%d: committed Freeze span exceeded %d" % [id, sample["seed"], PROOF_FROZEN_SPAN_LIMIT])
				break
		coverage[id]["passes"] += 1
		_check_forecast(engine, id, sample, pass_state, state, summary, steps)
		for step: Dictionary in steps:
			if not bool(step.get("battlefield_rule_step", false)): continue
			_check_beat(engine, id, sample, pass_state, step)
		# Persist only the first qualifying native witness, without staging actors.
		if bool(proof_witnesses.get(id, false)):
			var folder: String = output.get_base_dir().path_join("fixtures/" + id)
			if not FileAccess.file_exists(folder.path_join("run_state.txt")):
				DirAccess.make_dir_recursive_absolute(folder)
				var owner := preload("res://scripts/run_engine.gd").new()
				var run: Dictionary = owner.create_new_run(int(sample["seed"]), preload("res://scripts/progression_store.gd").default_data())
				run["mode"] = "combat"
				run["current_room"] = sample["room"]["coord"]
				run["current_room_layout"] = sample["layout"]
				run["combat_state"] = pass_state
				var file := FileAccess.open(folder.path_join("run_state.txt"), FileAccess.WRITE)
				file.store_string(var_to_str(run)); file.close()
				file = FileAccess.open(folder.path_join("combat_state.txt"), FileAccess.WRITE)
				file.store_string(var_to_str(pass_state)); file.close()

func _forecast(state: Dictionary) -> Dictionary:
	scene.set("_combat_state", state)
	var engine: RefCounted = scene.get("_combat_engine")
	var source: Dictionary = scene.call("_build_pass_preview_source_state_for_tile", state["player"]["pos"], false)
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(Red.schedule(engine, source), true)
	return scene.call("_pass_preview_summary_for_phase_result", source, phase)

func _check_forecast(engine: RefCounted, id: String, sample: Dictionary, before: Dictionary, after: Dictionary, summary: Dictionary, steps: Array[Dictionary]) -> void:
	var hidden: Array[String]
	for field: String in ["umbra_unknown_before_player", "unseen_ground_crossed", "new_arrival_before_player", "forecast_limit_reached", "unrevealed_before_player"]:
		if bool(summary.get(field, false)): hidden.append(field)
	if not summary.get("repeated_enemy_names", []).is_empty(): hidden.append("unknown_repeat")
	var rows: String = Rows.text(scene, summary)
	var safe: bool = rows.split("\n").has(":Safe")
	var shown: int = int(ForecastPanel.row_losses(summary)["health"])
	var loss: int = maxi(0, int(before["player"]["hp"]) - int(after["player"]["hp"]) - engine.fatigue_hp_loss)
	var actual_hp: int = int(after["player"]["hp"])
	var hurt: bool = int(after.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0)) > int(before.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0))
	for step: Dictionary in steps:
		for target: Dictionary in step.get("target_losses", []):
			if str(target.get("kind", "")) == "player" and (int(target.get("block_loss", 0)) > 0 or int(target.get("stoneskin_loss", 0)) > 0): hurt = true
	var mismatch: bool = safe and (not hidden.is_empty() or hurt)
	if hidden.is_empty():
		coverage[id]["forecast_known"] += 1
		mismatch = mismatch or shown != loss or int(summary.get("projected_hp", -1)) != actual_hp
	else:
		coverage[id]["forecast_hidden"] += 1
	if safe: coverage[id]["forecast_safe"] += 1
	if mismatch:
		coverage[id]["forecast_mismatches"] += 1
		failures.append("%s seed=%d clock=%d forecast health=%d hp=%d actual loss=%d hp=%d safe=%s hurt=%s hidden=%s" % [id, sample["seed"], before.get("initiative_clock", 0), shown, summary.get("projected_hp", -1), loss, actual_hp, safe, hurt, hidden])
		if coverage[id]["forecast_mismatches"] == 1: _exception_repro(id + "-pass", sample, before, before, after, TypedArrays.dictionaries([{"summary": summary, "rows": rows}]))
	passes.append({"instance": id, "seed": sample["seed"], "clock": before.get("initiative_clock", 0), "shown_loss": shown, "realized_loss": loss, "shown_hp": summary.get("projected_hp", -1), "realized_hp": actual_hp, "safe": safe, "actual_hurt": hurt, "hidden": hidden, "mismatch": mismatch})

func _check_beat(engine: RefCounted, id: String, sample: Dictionary, passed: Dictionary, step: Dictionary) -> void:
	var before: Dictionary = step["before"]
	var instance: Dictionary = before["battlefield_rule"]
	var rule: String = str(instance["rule"])
	var expected: Array[Vector2i]
	var actual: Array[Vector2i]
	var mismatch: bool = false
	var exceptions: Array[Dictionary]
	if rule == "gust":
		var dials: Dictionary = instance["dials"]
		var mode: String = str(dials["direction"])
		var axis: Vector2i = instance.get("locked_direction", Vector2i.ZERO)
		if mode == "toward_entry": axis = Rules.Gust.entry_direction(before)
		elif mode.begins_with("fixed:"): axis = Rules.Gust.FIXED_DIRECTIONS[mode.trim_prefix("fixed:")]
		mismatch = axis != step.get("action_direction", Vector2i.ZERO)
	else:
		expected.assign(_sentence_tiles(engine, before, instance))
		if rule == "upheaval":
			var outcomes: Array[Dictionary] = RuleTruth.rise(engine, before, instance)
			mismatch = step.get("upheaval_outcomes", []) != outcomes
			for receipt: Dictionary in outcomes:
				var category: String = receipt["category"]
				if category == "raised": continue
				expected.erase(receipt["tile"])
				coverage[id][category] += 1
				exceptions.append(receipt)
			for event: Dictionary in engine._surface_events_since(before, step["after"]):
				if event["kind"] == "terrain_created": actual.append(event["tile"])
		elif rule == "shadowstep":
			for move: Dictionary in Rules.Outcomes.project(engine, before, step["after"], false)["moves"]:
				if str(move["actor_key"]).begins_with("enemy_"): actual.append(move["to"])
		elif rule == "wildfire":
			for event: Dictionary in engine._surface_events_since(before, step["after"]):
				if str(event["kind"]) in ["surface_created", "surface_replaced"] and event.get("surface") == "fire" and event.get("source", {}).get("rule") == "wildfire": actual.append(event["tile"])
		else:
			for impact: Dictionary in engine.impacts:
				if impact["rule"] == rule and int(impact["clock"]) == int(before.get("initiative_clock", 0)) and int(impact["sequence"]) == int(before.get("surface_event_sequence", 0)) and int(impact["beat"]) == int(instance.get("beats_fired", 0)):
					actual.assign(impact["tiles"])
		mismatch = mismatch or not _same(expected, actual)
	# The stage supplies the renderer's mask. For Gust the affected tiles are
	# the visible units' original locations, including units that only collide.
	var board_presentation: Dictionary = scene.call("_stage_visibility_presentation", before)
	var shown: Array[Vector2i] = _rule_red(before, board_presentation)
	var drawn_but_not_red: Array[Vector2i]
	if rule != "shadowstep":
		var drawn: Array[Vector2i]
		var visible_tiles: Array = board_presentation["umbra_visible_tiles"]
		if rule == "gust":
			expected = _gust_origins(engine, before, step["after"], board_presentation["visible_enemy_ids"])
		drawn.assign(expected.filter(func(tile: Vector2i) -> bool: return visible_tiles.has(tile)))
		drawn_but_not_red.assign(drawn.filter(func(tile: Vector2i) -> bool: return not shown.has(tile)))
		coverage[id]["drawn_but_not_red"] += drawn_but_not_red.size()
		mismatch = mismatch or not _same(drawn, shown)
	if id == "storm_cantor":
		for tile: Vector2i in expected:
			if Surface.element_at(passed, tile) == "electrified": continue
			var source: Dictionary = Surface.surface_at(before, tile).get("elemental_source", {})
			var actor: Dictionary = engine._surface_actor(before, "enemy", int(source.get("actor_id", -1)))
			if str(actor.get("type", "")) == "bell_tender" and actual.has(tile) and shown.has(tile):
				cantor_new_tiles_included += 1
				proof_witnesses[id] = true
	if id == "ashen_reaver" and not actual.is_empty(): proof_witnesses[id] = true
	if rule == "upheaval" and not actual.is_empty(): proof_witnesses[id] = true
	if rule == "gust" and not mismatch: proof_witnesses[id] = true
	coverage[id]["beats"] += 1
	if not actual.is_empty() or rule == "gust": coverage[id]["nonempty_beats"] += 1
	if mismatch:
		coverage[id]["mismatches"] += 1
		failures.append("%s seed=%d clock=%d expected=%s actual=%s shown=%s" % [id, int(sample["seed"]), int(before.get("initiative_clock", 0)), str(expected), str(actual), str(shown)])
	if not exceptions.is_empty() or mismatch: _exception_repro(id, sample, passed, before, step["after"], exceptions)
	records.append({"instance": id, "seed": sample["seed"], "clock": before.get("initiative_clock", 0), "expected": expected, "actual": actual, "mismatch": mismatch, "upheaval_outcomes": step.get("upheaval_outcomes", []), "direction": step.get("action_direction", Vector2i.ZERO), "red_at_beat": shown, "drawn_but_not_red": drawn_but_not_red})

func _gust_origins(engine: RefCounted, before: Dictionary, after: Dictionary, visible_enemy_ids: Array) -> Array[Vector2i]:
	var contacts: Dictionary = {}
	for event: Dictionary in engine._surface_events_since(before, after):
		if event.get("kind") == "force_collision": contacts[event["actor_key"]] = true
	var result: Array[Vector2i]
	for actor: Dictionary in engine._surface_actor_records(before):
		if actor["kind"] == "enemy" and not visible_enemy_ids.has(actor["id"]): continue
		var tile: Vector2i = actor["unit"]["pos"]
		var unit: Dictionary = engine._surface_actor(after, actor["kind"], actor["id"])
		if (unit.get("pos", tile) != tile or contacts.has(actor["key"])) and not result.has(tile):
			result.append(tile)
	return result

func _rule_red(state: Dictionary, board_presentation: Dictionary) -> Array[Vector2i]:
	var key: String = View.THREAT_KEY
	var presentation: Dictionary
	if str(state.get("objective", {}).get("special_type", "")) == "umbral_snare":
		key = "snare_pressure"
		presentation = preload("res://scripts/snare_pressure_view.gd").presentation_for(state, board_presentation)
	else:
		presentation = View.presentation_for(state, board_presentation)
	var tiles: Array[Vector2i]
	for threat: Dictionary in presentation.get("threats_at_rest", {}).get("threats", []):
		if threat["key"] == key: tiles.assign(threat["tiles"])
	return tiles

func _sentence_tiles(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	var rule: String = str(instance["rule"])
	match rule:
		"lightning_storm", "frostbite":
			var element: String = "electrified" if rule == "lightning_storm" else "ice"
			tiles.assign(Surface.tiles(state, element).filter(func(tile: Vector2i) -> bool: return Surface.can_place(state, tile)))
		"wildfire":
			var axes: Array[Vector2i]
			match str(instance["dials"]["spread"]):
				"all": axes.assign(Paths.DIRS_4)
				"toward_player": axes.append(engine._cardinal_direction(Vector2i(state["player"]["pos"]) - Vector2i(engine._surface_actor(state, "enemy", int(instance["source"]["id"]))["pos"])))
				"away_from_entry": axes.append(-Rules.Gust.entry_direction(state))
			for origin: Vector2i in Surface.tiles(state, "fire"):
				for axis: Vector2i in axes:
					var tile: Vector2i = origin + axis
					if Surface.can_place(state, tile) and Surface.element_at(state, tile) != "fire" and not tiles.has(tile): tiles.append(tile)
		"upheaval": tiles.assign(instance.get("marks", []))
		"shadowstep": tiles.assign(RuleTruth.shadowstep(engine, state, instance))
	return tiles

func _exception_repro(id: String, sample: Dictionary, passed: Dictionary, before: Dictionary, after: Dictionary, exceptions: Array[Dictionary]) -> void:
	var folder: String = proof_output.get_base_dir().path_join("repro/%s-%d-%d" % [id, int(sample["seed"]), int(before.get("initiative_clock", 0))])
	DirAccess.make_dir_recursive_absolute(folder)
	for name: String in ["pass", "before", "after"]:
		var file := FileAccess.open(folder.path_join(name + ".txt"), FileAccess.WRITE)
		file.store_string(var_to_str({"pass": passed, "before": before, "after": after}[name])); file.close()
	var file := FileAccess.open(folder.path_join("exceptions.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(Store._sanitize_variant(exceptions), "	")); file.close()

static func _same(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size(): return false
	for tile: Vector2i in a:
		if not b.has(tile): return false
	return true

func _write(output: String) -> void:
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"coverage": coverage, "cantor_new_tiles_included": cantor_new_tiles_included, "failures": failures, "beats": Store._sanitize_variant(records), "passes": Store._sanitize_variant(passes)}, "\t")); file.close()
