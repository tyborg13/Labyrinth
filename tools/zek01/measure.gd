extends SceneTree
## Same bounded policy/loop as run_curve_combat, with measurement-only receipts.
const Data = preload("res://scripts/game_data.gd")
const Bot = preload("res://tools/encounter_bot.gd")
const Instrumented = preload("res://tools/zek01/measurement_combat.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Store = preload("res://scripts/analytics_store.gd")
const Sweep = preload("res://tools/encounter_sweep.gd")
var audit_mode: bool = false
const STRIDE: int = 1000003
const ROSTER: Array = ["vyraketh", "tharokh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	audit_mode = args.has("--audit")
	var directory: String = Sweep.option(args, "--inputs", "")
	var output: String = Sweep.option(args, "--output", "")
	var first: int = int(Sweep.option(args, "--first", "0"))
	var last: int = int(Sweep.option(args, "--last", "64"))
	var completed: Dictionary = {}
	var completed_path: String = Sweep.option(args, "--completed", "")
	if not completed_path.is_empty():
		for key: String in JSON.parse_string(FileAccess.get_file_as_string(completed_path)): completed[key] = true
	var stream := FileAccess.open(output, FileAccess.WRITE)
	assert(stream != null)
	var new_definition: Dictionary = Data.enemies()["zekarion"].duplicate(true)
	for sample: int in range(first, last):
		var loadout: int = sample % 8 + 1
		var repeat: int = sample / 8
		var reader := FileAccess.open(directory.path_join("input-%d.bin" % loadout), FileAccess.READ)
		var payload: Dictionary = reader.get_var()
		reader.close()
		var rng_input: int = int(payload["run_seed"]) + repeat * STRIDE
		var variants: Array = ["hp62"] if audit_mode else ["baseline", "pattern50", "hp56", "hp62", "hp68", "hp74"]
		for variant: String in variants:
			var definition: Dictionary = new_definition.duplicate(true)
			if variant == "baseline":
				definition["max_hp"] = 50
				definition.erase("cycle_order")
				definition["intents"][0]["actions"][0]["placement"] = "band"
				definition["intents"][0]["actions"][0]["count"] = 7
			else: definition["max_hp"] = 50 if variant == "pattern50" else int(variant.trim_prefix("hp"))
			Data.enemies()["zekarion"] = definition
			var roster: Array = ROSTER if variant == "baseline" else ["zekarion"]
			for id: String in roster:
				if completed.has("%d|%s|%s" % [sample, variant, id]): continue
				var metadata: Dictionary = {"coord":payload["layout"]["coord"], "depth":payload["layout"]["depth"], "type":"boss", "element":Bosses.element_for_boss(id), "boss_id":id, "connections":[]}
				var layout: Dictionary = Rooms.new().generate_room(int(payload["run_seed"]), metadata, Vector2i.RIGHT)
				var initial: Dictionary = Instrumented.new().create_combat(rng_input, layout, payload["snapshot"])
				var row: Dictionary = _fight(initial)
				row.merge({"sample":sample, "loadout":loadout, "repeat":repeat, "combat_seed_input":rng_input, "section":int(metadata["depth"]) / 4 - 1, "dragon":id, "variant":variant, "boss_hp":layout["enemies"][0]["max_hp"]})
				stream.store_line(JSON.stringify(Store._sanitize_variant(row)))
				stream.flush()
				print("ZEK01 FIGHT sample=%d variant=%s dragon=%s won=%s turns=%d" % [sample, variant, id, row["won"], row["turns"]])
	Data.enemies()["zekarion"] = new_definition
	stream.close()
	print("ZEK01 MEASUREMENT PASS first=%d last=%d" % [first, last])
	quit(0)

func _fight(initial: Dictionary) -> Dictionary:
	var policy := Bot.Policy.new()
	policy.engine = preload("res://tools/zek01/audit_combat.gd").new() if audit_mode else Instrumented.new()
	var state: Dictionary = initial
	var turns: int = 1
	var decisions: int = 0
	var capped: bool = false
	while policy.engine.combat_outcome(state).is_empty():
		turns = int(state["turn"])
		if turns > Bot.MAX_TURNS: break
		var decision: int = 0
		while decision < Bot.MAX_DECISIONS_PER_TURN and policy.engine.combat_outcome(state).is_empty():
			state["_zek01_phase"] = "card"
			var selected: Dictionary = policy.choose(state)
			if selected.is_empty(): break
			state = selected["state"]
			decision += 1
			decisions += 1
		if decision == Bot.MAX_DECISIONS_PER_TURN: capped = true
		if not policy.engine.combat_outcome(state).is_empty(): break
		state["_zek01_phase"] = "dodge"
		state = policy.best_dodge(state)["state"]
		if not policy.engine.combat_outcome(state).is_empty(): break
		state["_zek01_phase"] = "enemy_phase"
		state = policy.engine.advance_to_next_player_turn_with_steps(policy.engine.finish_player_activation(state))["state"]
	return {"trace_version":2, "won":policy.engine.combat_outcome(state) == "victory", "turns":mini(turns, Bot.MAX_TURNS), "hp_lost":int(state.get("run_stats", {}).get("damage_received", 0)) - int(initial.get("run_stats", {}).get("damage_received", 0)), "decisions":decisions, "search_capped":capped, "turn_cap_reached":policy.engine.combat_outcome(state).is_empty(), "receipts":state.get("_zek01_receipts", []), "log":state.get("log", []), "surface_events":state.get("surface_events", [])}
