extends SceneTree

## A bounded geometry/Time diagnostic, never an automated fun or win test.
## Engine-created fields and held warnings stay fixed while ordinary movement
## and two production primitive cards are interleaved. See the owning review.
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const ROSTER = {"vyraketh":4, "tharokh":8, "iskaldra":12, "vaeloryx":16, "zekarion":20, "noctyrax":24}
const PAIRS = {
	"MOVE_ONLY":[],
	"MM":["quick_stab", "quick_stab"], "MR":["quick_stab", "dull_bolt"],
	"RM":["dull_bolt", "quick_stab"], "RR":["dull_bolt", "dull_bolt"]
}
const SOURCES = ["data/enemies.json", "data/cards.json", "data/relics.json", "scripts/combat_engine.gd",
	"scripts/guardian_combat_rules.gd", "scripts/dragon_combat_rules.gd", "scripts/dragon_pressure_fields.gd",
	"scripts/committed_pattern_shapes.gd", "scripts/board_surface_rules.gd", "scripts/room_generator.gd",
	"tests/dragon_pressure_escape_probe.gd"]
const BAD_STATUSES = ["freeze", "shock", "immobilize", "chilled", "bleed", "burn", "poison", "expose", "sunder"]
var combat := Combat.new()
var failures: Array[String]
var records: Array[Dictionary]
var seed_value: int = 20260928
var output_path: String = "user://dragon_pressure_escape_report.json"
var boss_filter: String = ""
var intent_filter: String = ""
var start_mode: String = "adjacent"
var depth_override: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_parse_arguments()
	_run.call_deferred()

func _parse_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		var option: String = args[index]
		if index + 1 >= args.size():
			failures.append("Missing value for " + option)
			break
		var value: String = args[index + 1]
		match option:
			"--output": output_path = value
			"--boss": boss_filter = value
			"--intent": intent_filter = value
			"--start": start_mode = value
			"--depth": depth_override = int(value)
			"--seed": seed_value = int(value)
			_: failures.append("Unknown argument " + option)
		index += 2
	if not boss_filter.is_empty() and not ROSTER.has(boss_filter): failures.append("Unknown boss " + boss_filter)
	if start_mode not in ["entry", "adjacent"]: failures.append("--start must be entry or adjacent")
	if depth_override != 0 and depth_override not in [4, 8, 12, 16, 20, 24]: failures.append("Invalid --depth")

func _run() -> void:
	var started: int = Time.get_ticks_msec()
	var source_hashes: Dictionary = _source_hashes()
	if failures.is_empty():
		for boss_id: String in ROSTER:
			if not boss_filter.is_empty() and boss_id != boss_filter: continue
			await _inspect_cycle(boss_id)
	if source_hashes != _source_hashes(): failures.append("Source files changed during this diagnostic")
	if records.is_empty() and failures.is_empty(): failures.append("No warnings matched the requested filters")
	var report := {
		"schema":1, "kind":"bounded_geometry_opportunity_cost_screen", "fun_verdict":"not_evaluated",
		"seed":seed_value, "start_mode":start_mode, "source_sha256":source_hashes,
		"elapsed_seconds":float(Time.get_ticks_msec()-started)/1000.0,
		"limits":[
			"Staged production arenas; no deck, acquired-build, full-fight, fairness or fun claim.",
			"Setup follows the real queue with empty Passes and replenished setup-only HP/Block; each warning removes that protection and player statuses.",
			"Every warning starts with 24 HP, no defense/skills/trophies, and only Pilgrim Boots for the three-move budget.",
			"Two actual primitive cards are supplied deliberately; this tests access and armor interaction, not hand likelihood.",
			"Only cardinal ordinary movement and direct boss-targeted attacks are searched; no paid movement, control, terrain clearing or helper kills.",
			"Engine preview uses the complete roster; hidden-helper loss is not credited as public encounter pressure.",
			"A zero-damage outcome can still inflict status or displacement. Direct warning and before-return results are separate.",
			"Equivalent states are deduplicated; example routes are witnesses, not counts of every syntactic input order."
		], "card_pairs":PAIRS, "primitive_cards":{"quick_stab":combat.card_def("quick_stab"),"dull_bolt":combat.card_def("dull_bolt")},
		"warnings":records, "failures":failures
	}
	var directory: String = ProjectSettings.globalize_path(output_path).get_base_dir()
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK: failures.append("Cannot create output directory: %s" % error_string(mkdir_error))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write report: %s" % error_string(FileAccess.get_open_error()))
	else:
		file.store_string(JSON.stringify(_json_value(report), "  "))
		file.close()
	print("DRAGON ESCAPE DIAGNOSTIC: ", "COMPLETE" if failures.is_empty() else "ERROR", " warnings=", records.size(), " output=", ProjectSettings.globalize_path(output_path))
	for message: String in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)

func _inspect_cycle(boss_id: String) -> void:
	var depth: int = int(ROSTER[boss_id]) if depth_override == 0 else depth_override
	if (boss_id == "noctyrax") != (depth == 24):
		failures.append("Noctyrax requires depth 24; elemental dragons require depth 4–20: " + boss_id)
		return
	var room: Dictionary = Rooms.new().generate_room(seed_value, {
		"coord":Vector2i(depth,0), "depth":depth, "type":"boss", "boss_id":boss_id,
		"element":Bosses.element_for_boss(boss_id), "connections":[]
	}, Vector2i.RIGHT)
	var state: Dictionary = combat.create_combat(seed_value, room, {
		"hp":24, "max_hp":24, "deck_cards":["quick_stab", "dull_bolt"],
		"relics":[], "hand_size":2, "cards_per_turn":2, "draw_per_turn":0
	})
	if start_mode == "adjacent":
		var legal: Array[Vector2i] = combat.valid_targets_for_player_action(state, {"type":"move", "range":20})
		var origin: Vector2i = state["player"]["pos"]
		legal.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = Paths.manhattan(origin,a)
			var db: int = Paths.manhattan(origin,b)
			return da < db if da != db else (a.x < b.x if a.x != b.x else a.y < b.y))
		var selected := Vector2i(-1,-1)
		for tile: Vector2i in legal:
			if combat._enemy_distance_to_tile(_boss(state,boss_id),tile) != 1: continue
			if combat._trap_index_at_tile(state,tile) >= 0 or Surface.surface_at(state,tile) != {}: continue
			selected = tile
			break
		if selected.x < 0:
			failures.append("No legal staged adjacent position for " + boss_id)
			return
		state["player"]["pos"] = selected
		# Initial fixture placement precedes declaration. No branch redeclares it.
		var rng := RandomNumberGenerator.new()
		rng.state = int(state["rng_state"])
		for enemy_index: int in range(state["enemies"].size()):
			if str(state["enemies"][enemy_index]["type"]) != boss_id: continue
			state["enemies"][enemy_index]["dragon_cycle"] = -1
			combat._assign_enemy_intent(state,enemy_index,rng)
		state["rng_state"] = rng.state
	var seen: Dictionary = {}
	var setup_trace: Array[Dictionary]
	for activation: int in range(20):
		var boss: Dictionary = _boss(state,boss_id)
		if boss.is_empty() or int(boss.get("hp",0)) <= 0:
			failures.append("Setup killed the boss before all warnings: " + boss_id)
			return
		var intent_id: String = str(boss["intent"]["id"])
		if not seen.has(intent_id):
			seen[intent_id] = true
			if intent_filter.is_empty() or intent_filter == intent_id:
				for allowance: int in [2,3]:
					var warning: Dictionary = _warning_state(state,allowance)
					var record: Dictionary = _inspect_warning(warning,boss_id,depth,allowance)
					record["setup_trace"] = setup_trace.duplicate(true)
					records.append(record)
					print("ESCAPE WARNING ",boss_id,"/",intent_id," F=",allowance," ",record["summary"])
					await process_frame
		if seen.size() >= (Data.enemy_def(boss_id)["intents"] as Array).size(): return
		# Carry actual surfaces, terrain, actor positions and declarations through
		# a Pass-only setup trajectory. Protection is never copied into a warning.
		state = _warning_state(state,2)
		state = combat.finish_player_activation(state)
		for slice: int in range(40):
			state["player"]["hp"] = 24
			state["player"]["block"] = 1000
			var result: Dictionary = combat.advance_one_activation_with_steps(state,false)
			state = result["state"]
			for step: Dictionary in result["steps"]:
				if str(step.get("kind","")) == "intent":
					setup_trace.append({"clock":state["initiative_clock"], "actor":step.get("actor_key",""), "intent":step.get("intent_name","")})
			if combat.combat_outcome(state) != "":
				failures.append("Setup ended before complete cycle: " + boss_id)
				return
			if bool(result.get("complete",false)): break
			if slice == 39: failures.append("Setup queue bound exceeded for " + boss_id); return
	failures.append("Did not reach all four warnings for " + boss_id)

func _warning_state(source: Dictionary, allowance: int) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	state["player"] = combat._normalized_player({"pos":source["player"]["pos"], "hp":24, "max_hp":24, "block":0, "stoneskin":0})
	state["relics"] = ["pilgrim_boots"] if allowance == 3 else []
	state["skill_ids"] = []
	state["skill_flags"] = {}
	state["relic_flags"] = {}
	state["current_actor"] = combat._player_actor_entry(int(state["initiative_clock"]),int(state.get("activation_seq",0)))
	state["player_turn_ending"] = false
	state["player_turn_time_spent"] = 0
	state["cards_played_this_turn"] = 0
	state["cards_per_turn"] = 2
	state["draw_per_turn"] = 0
	state["player_movement_capacity"] = combat.player_movement_capacity(state)
	state["player_movement_remaining"] = combat.player_movement_capacity(state)
	state["banked_plays"] = 0
	state["banked_play_active"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["pending_relic_card_plays"] = 0
	state["player_turn_restrictions"] = {"frozen":false,"shocked":false,"immobilized":false}
	state["turn_flags"] = {"first_attack_bonus_used":false,"first_move_bonus_used":false}
	state.erase("pending_card_payment")
	return state

func _inspect_warning(state: Dictionary, boss_id: String, depth: int, allowance: int) -> Dictionary:
	var boss: Dictionary = _boss(state,boss_id)
	var index: int = combat._enemy_index_for_id(state,int(boss["id"]))
	var result := {"boss":boss_id,"depth":depth,"intent":boss["intent"]["id"],"budget":allowance,
		"clock":state["initiative_clock"],"player":state["player"],"boss_position":boss["pos"],
		"boss_hp":boss["hp"],"frost_armor":boss.get("frost_armor",0),"declared_intent":boss["intent"].duplicate(true),
		"queue":state["turn_queue"].duplicate(true),"terrain":state["terrain"].duplicate(true),
		"surfaces":state["surfaces"].duplicate(true),"braziers":state.get("guardian_braziers",[]).duplicate(true),
		"threat_preview":combat.enemy_threat_tiles(state,index),"pairs":{},"summary":{}}
	for pair_name: String in PAIRS:
		var pair_result: Dictionary = _search(state,boss_id,PAIRS[pair_name])
		result["pairs"][pair_name] = pair_result
		result["summary"][pair_name] = {"terminal_states":pair_result["outcomes"].size(),
			"direct_zero_damage":pair_result["direct_zero_damage"],"zero_damage_with_retained_melee":pair_result["retained_melee"],
			"zero_damage_with_retained_ranged":pair_result["retained_ranged"],"warning_not_due_before_return":pair_result["warning_not_due"],
			"boss_defeated_before_warning":pair_result["lethal_lines"]}
	return result

func _search(warning: Dictionary, boss_id: String, cards: Array) -> Dictionary:
	var initial: Dictionary = warning.duplicate(true)
	initial["deck"] = {"hand":cards.duplicate(),"draw":[],"discard":[],"burned":[],"consumed":[],"cycles":0,"draw_revision":0}
	var queue: Array[Dictionary]
	queue.append({"state":initial,"operations":[],"moves":0,"plays":0})
	var seen: Dictionary = {}
	var outcomes: Array[Dictionary]
	var direct_zero: int = 0
	var retained_melee: int = 0
	var retained_ranged: int = 0
	var not_due: int = 0
	var lethal_lines: int = 0
	var cursor: int = 0
	while cursor < queue.size():
		var node: Dictionary = queue[cursor]
		cursor += 1
		var state: Dictionary = node["state"]
		var key: String = _mechanical_key(state,int(node["moves"]),int(node["plays"]))
		if seen.has(key): continue
		seen[key] = true
		var state_outcome: String = combat.combat_outcome(state)
		if state_outcome != "" and state_outcome != "victory": continue
		if int(node["plays"]) == cards.size() or state_outcome == "victory":
			var outcome: Dictionary = _outcome(warning,node,boss_id)
			outcomes.append(outcome)
			if bool(outcome["boss_defeated_before_warning"]): lethal_lines += 1
			if bool(outcome["direct_zero_damage"]):
				direct_zero += 1
				if bool(outcome["melee_access_after_warning"]): retained_melee += 1
				if bool(outcome["ranged_access_after_warning"]): retained_ranged += 1
			if not bool(outcome["warning_resolved_before_return"]) and not bool(outcome["boss_defeated_before_warning"]): not_due += 1
		if state_outcome != "": continue
		if int(node["moves"]) < 3 and combat.player_movement_remaining(state) > 0:
			var legal: Array[Vector2i] = combat.player_movement_targets(state)
			for direction: Vector2i in Paths.DIRS_4:
				var target: Vector2i = state["player"]["pos"] + direction
				if not legal.has(target): continue
				var moved: Dictionary = combat.apply_player_movement(state,target)
				if moved["player"]["pos"] == state["player"]["pos"]: continue
				var operations: Array = node["operations"].duplicate(true)
				operations.append({"kind":"free_move","from":state["player"]["pos"],"to":moved["player"]["pos"],
					"cost":moved["last_player_movement"]["spent"],"hp_loss":int(state["player"]["hp"])-int(moved["player"]["hp"])})
				queue.append({"state":moved,"operations":operations,"moves":int(node["moves"])+1,"plays":node["plays"]})
		if int(node["plays"]) < cards.size() and combat.cards_remaining_this_turn(state) > 0:
			var card_id: String = cards[int(node["plays"])]
			var action: Dictionary = combat.card_play_actions(card_id,state)[0]
			var target: Vector2i = _boss_target(state,boss_id,action)
			if target.x >= 0:
				var attacked: Dictionary = combat.apply_player_action(state,action,target)
				attacked = combat.finish_player_card(attacked,0)
				var operations: Array = node["operations"].duplicate(true)
				operations.append({"kind":"card","card":card_id,"from":state["player"]["pos"],"target":target,
					"boss_hp_loss":int(_boss(state,boss_id).get("hp",0))-int(_boss(attacked,boss_id).get("hp",0)),
					"time":int(attacked["player_turn_time_spent"])-int(state["player_turn_time_spent"])})
				queue.append({"state":attacked,"operations":operations,"moves":node["moves"],"plays":int(node["plays"])+1})
	return {"states_visited":seen.size(),"outcomes":outcomes,"direct_zero_damage":direct_zero,
		"retained_melee":retained_melee,"retained_ranged":retained_ranged,"warning_not_due":not_due,"lethal_lines":lethal_lines}

func _outcome(warning: Dictionary, node: Dictionary, boss_id: String) -> Dictionary:
	var state: Dictionary = node["state"]
	var boss: Dictionary = _boss(state,boss_id)
	if boss["intent"] != _boss(warning,boss_id)["intent"]: failures.append("Search changed the held warning for " + boss_id)
	var ending: Dictionary = combat.finish_player_activation(state)
	var projection: Dictionary = combat.preview_revealed_enemy_actions_before_player_turn_with_steps(ending)
	var forecast: Dictionary = projection["state"]
	var known_start: Dictionary = projection.get("player_turn_before_state",{})
	if not known_start.is_empty() and not bool(projection.get("unrevealed_before_player",false)) and combat.combat_outcome(known_start) == "":
		forecast = combat.prepare_next_player_turn(known_start)
	var direct_input: Dictionary = ending.duplicate(true)
	for entry: Dictionary in ending["turn_queue"]:
		if str(entry.get("kind","")) == "enemy" and int(entry.get("enemy_id",-1)) == int(boss["id"]):
			direct_input["initiative_clock"] = int(entry["time"])
			break
	var direct: Dictionary = combat.resolve_enemy_turn_with_steps(direct_input,combat._enemy_index_for_id(direct_input,int(boss["id"])),false)["state"]
	var boss_defeated: bool = int(boss.get("hp",0)) <= 0
	var zero_damage: bool = not boss_defeated and int(direct["player"]["hp"]) == int(warning["player"]["hp"])
	var direct_status: Dictionary = _bad_statuses(direct["player"])
	var forecast_boss: Dictionary = _boss(forecast,boss_id)
	var card_damage: int = 0
	var movement_hp_loss: int = 0
	for operation: Dictionary in node["operations"]:
		if str(operation["kind"]) == "card": card_damage += int(operation.get("boss_hp_loss",0))
		else: movement_hp_loss += int(operation.get("hp_loss",0))
	return {"operations":node["operations"],"finish_tile":state["player"]["pos"],"plays_committed":node["plays"],
		"boss_defeated_before_warning":boss_defeated,
		"free_movement_spent":combat.player_movement_capacity(state)-combat.player_movement_remaining(state),
		"card_time":state["player_turn_time_spent"],"movement_hp_loss":movement_hp_loss,
		"input_hp_loss":int(warning["player"]["hp"])-int(state["player"]["hp"]),
		"boss_hp_loss_by_cards":card_damage,"boss_hp_loss_during_inputs":int(_boss(warning,boss_id)["hp"])-int(boss["hp"]),
		"armor_after_cards":boss.get("frost_armor",0),
		"melee_access_at_finish":_has_access(state,boss_id,"quick_stab"),"ranged_access_at_finish":_has_access(state,boss_id,"dull_bolt"),
		"direct_hp_loss":int(warning["player"]["hp"])-int(direct["player"]["hp"]),"direct_zero_damage":zero_damage,
		"direct_zero_damage_no_bad_status":zero_damage and direct_status.is_empty(),"direct_bad_status":direct_status,
		"after_warning_tile":direct["player"]["pos"],"boss_after_warning":_boss(direct,boss_id).get("pos",Vector2i(-1,-1)),
		"melee_access_after_warning":_has_access(direct,boss_id,"quick_stab"),"ranged_access_after_warning":_has_access(direct,boss_id,"dull_bolt"),
		"forecast_hp_loss":int(warning["player"]["hp"])-int(forecast["player"]["hp"]),"forecast_bad_status":_bad_statuses(forecast["player"]),
		"forecast_clock":forecast["initiative_clock"],"unrevealed_followup_before_return":projection.get("unrevealed_before_player",false),
		"warning_resolved_before_return":int(forecast_boss.get("dragon_cycle",-1)) > int(boss.get("dragon_cycle",-1)),
		"forecast_includes_player_start":not known_start.is_empty() and not bool(projection.get("unrevealed_before_player",false)),
		"held_intent_unchanged":boss["intent"] == _boss(warning,boss_id)["intent"]}

func _has_access(state: Dictionary, boss_id: String, card_id: String) -> bool:
	return _boss_target(state,boss_id,combat.card_play_actions(card_id,state)[0]).x >= 0

func _boss_target(state: Dictionary, boss_id: String, action: Dictionary) -> Vector2i:
	var boss: Dictionary = _boss(state,boss_id)
	if boss.is_empty() or int(boss.get("hp",0)) <= 0: return Vector2i(-1,-1)
	var body: Array[Vector2i] = combat._enemy_footprint_tiles(boss)
	var candidates: Array[Vector2i] = combat.valid_targets_for_player_action(state,action)
	for tile: Vector2i in candidates:
		if body.has(tile): return tile
	return Vector2i(-1,-1)

func _boss(state: Dictionary, boss_id: String) -> Dictionary:
	for enemy: Dictionary in state.get("enemies",[]):
		if str(enemy.get("type","")) == boss_id: return enemy
	return {}

func _bad_statuses(player: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in BAD_STATUSES:
		if int(player.get(key,0)) > 0: result[key] = player[key]
	return result

func _mechanical_key(state: Dictionary, moves: int, plays: int) -> String:
	var parts: Array = [moves,plays]
	for key: String in ["player","enemies","terrain","surfaces","traps","moss","umbra","guardian_braziers",
		"turn_flags","relic_flags","skill_flags","player_movement_remaining","player_turn_time_spent","rng_state"]:
		parts.append(state.get(key,null))
	return var_to_str(parts).sha256_text()

func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCES: result[path] = FileAccess.get_sha256("res://"+path)
	return result

func _json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I, TYPE_VECTOR2: return [value.x,value.y]
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key: Variant in value: result[str(key)] = _json_value(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item: Variant in value: result.append(_json_value(item))
			return result
	return value
