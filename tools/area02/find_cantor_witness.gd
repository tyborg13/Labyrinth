extends SceneTree
## Replays the area-02 ladder controller and saves an unmodified Pass state.

const Cases = preload("res://tools/atk13/rule_cases.gd")
const Controller = preload("res://tools/bot_policy.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const Witness = preload("res://tools/area02/cantor_witness.gd")
const Progression = preload("res://scripts/progression_store.gd")
const DEFAULT_SAMPLES: int = 8
const ADJACENT_TILE_DISTANCE: int = 1

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var count: int = int(Cases.Sweep.option(args, "--samples", str(DEFAULT_SAMPLES)))
	var skip: int = int(Cases.Sweep.option(args, "--skip", "0"))
	if skip < 0 or count <= 0:
		push_error("CAP-06 SCAN: --skip must be nonnegative and --samples must be positive")
		quit(1)
		return
	var folder: String = Cases.Sweep.option(args, "--out", "/private/tmp/labyrinth_codex/cap-06/fixtures/storm_cantor")
	var controller := Controller.new()
	var deck: Array = Witness.Bot.deck_presets()[str(Cases.DIFFICULTY_TIER)]
	var best: Dictionary = {}
	for sample: Dictionary in Cases.samples_for("storm_cantor", skip + count).slice(skip):
		var found: Dictionary = _fight(controller, sample, deck)
		print("CAP-06 LADDER SAMPLE seed=%d room=%s witness=%s" % [sample["seed"], sample["room"]["coord"], not found.is_empty()])
		if not found.is_empty() and (best.is_empty() or found["distance"] < best["distance"]):
			best = found
			if best["distance"] <= ADJACENT_TILE_DISTANCE: break
	if best.is_empty():
		push_error("CAP-06 SCAN: no qualifying 24-Health Cantor witness in %d ladder rooms" % count)
		quit(1)
		return
	quit(0 if _save(best, folder, deck) else 1)

func _fight(controller: RefCounted, sample: Dictionary, deck: Array) -> Dictionary:
	var engine: RefCounted = controller.engine
	var max_hp: int = Witness.Bot.MAX_HP
	var state: Dictionary = engine.create_combat(int(sample["seed"]), sample["layout"], {
		"hp": max_hp, "max_hp": max_hp, "deck_cards": deck,
		"equipped_equipment": Witness.Bot.Game.starting_equipped_equipment(), "relics": [],
	})
	var best: Dictionary = {}
	while engine.combat_outcome(state).is_empty() and int(state["turn"]) <= Witness.Bot.MAX_TURNS:
		state = _play_to_pass(controller, state)
		if not engine.combat_outcome(state).is_empty(): break
		var phase: Dictionary = Witness.resolve_pass(engine, state)
		if Witness.real_health(phase["state"]["player"]) and not Witness.visible_electrified(engine, state).is_empty():
			var peal: Dictionary = Witness.peal(engine, state, phase["steps"])
			if not peal.is_empty():
				var distance: int = _nearest_new_tile(state["player"]["pos"], peal["laid"])
				if best.is_empty() or distance < best["distance"]:
					best = {"sample": sample, "state": state, "peal": peal, "distance": distance}
					if distance <= ADJACENT_TILE_DISTANCE: break
		state = phase["state"]
	return best

func _play_to_pass(controller: RefCounted, state: Dictionary) -> Dictionary:
	var engine: RefCounted = controller.engine
	for decision: int in range(Witness.Bot.MAX_DECISIONS_PER_TURN):
		if not engine.combat_outcome(state).is_empty(): return state
		var selected: Dictionary = controller.choose(state)
		if selected.is_empty(): break
		var plan: Dictionary = selected["commit"]
		var accepted: Dictionary = Commit.accept(engine, plan["before"])
		state = Commit.player_card(engine, accepted, plan["resolved"], int(plan["index"]), plan["actions"],
			engine._vector2i_values(plan["targets"]), {"play_mode": "play"})
	if not engine.combat_outcome(state).is_empty(): return state
	return Commit.accept(engine, controller.best_dodge(state)["state"])

func _nearest_new_tile(hero: Vector2i, tiles: Array[Vector2i]) -> int:
	var distance: int = Cases.Sweep.Paths.manhattan(hero, tiles[0])
	for tile: Vector2i in tiles:
		distance = mini(distance, Cases.Sweep.Paths.manhattan(hero, tile))
	return distance

func _save(witness: Dictionary, folder: String, deck: Array) -> bool:
	var sample: Dictionary = witness["sample"]
	var state: Dictionary = witness["state"]
	var run: Dictionary = Witness.Bot.Run.new().create_new_run(int(sample["seed"]), Progression.default_data())
	run["mode"] = "combat"
	run["current_room"] = sample["room"]["coord"]
	run["current_room_layout"] = sample["layout"]
	run["deck_cards"] = deck
	run["player_hp"] = state["player"]["hp"]
	run["player_max_hp"] = state["player"]["max_hp"]
	run["combat_state"] = state
	var path: String = folder.path_join("run_state.txt")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CAP-06 SCAN: cannot write " + path)
		return false
	file.store_string(var_to_str(run))
	file.close()
	print("CAP-06 SCAN: PASS (seed=%d room=%s turn=%d clock=%d HP=%d/%d new=%d strike=%d distance=%d) %s" % [
		sample["seed"], sample["room"]["coord"], state["turn"], state["initiative_clock"], state["player"]["hp"],
		state["player"]["max_hp"], witness["peal"]["laid"].size(), witness["peal"]["strike"].size(), witness["distance"], path,
	])
	return true
