extends SceneTree
## Measurement only: production state transitions; no profile/analytics writes.
const Run = preload("res://scripts/run_engine.gd")
const LadderRun = preload("res://tools/run_curve_ladder.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Events = preload("res://scripts/event_rules.gd")
const Sweep = preload("res://tools/encounter_sweep.gd")
const Choices = preload("res://tools/run_curve_choices.gd")
const Battle = preload("res://tools/run_curve_combat.gd")
const Store = preload("res://scripts/analytics_store.gd")
# Measurement fault guard only; reaching it fails the worker, never counts death.
const MAX_TRANSITIONS: int = 1000

func count_uncovered(record: Dictionary, kind: String) -> void:
	record["uncovered_rooms"][kind] = int(record["uncovered_rooms"].get(kind, 0)) + 1

func entry(state: Dictionary, picks: int = -1) -> Dictionary:
	var equipment_count: int = 0
	for id: String in state["equipped_equipment"].values():
		if not id.is_empty(): equipment_count += 1
	var result: Dictionary = {"section": Graph.active_section(state), "hp": state["player_hp"], "max_hp": state["player_max_hp"], "deck_size": state["deck_cards"].size(), "relics": state["relics"].size(), "equipment": equipment_count}
	if picks >= 0: result["card_reward_picks"] = picks
	return result

func room_kind(room: Dictionary) -> String:
	if room["type"] == "special": return str(room["special_type"])
	if room["type"] == "boss": return "dragon"
	if room["type"] == "combat": return "standard"
	return str(room["type"])

func new_run_engine(ladder: bool) -> RefCounted:
	return LadderRun.new() if ladder else Run.new()

func fight_started(_initial: Dictionary) -> void:
	pass

func fight_finished(_initial: Dictionary, _fought: Dictionary) -> void:
	pass

func whole_run(seed_value: int, draft: String, scores: Dictionary, ladder: bool = false) -> Dictionary:
	var engine: RefCounted = new_run_engine(ladder)
	var state: Dictionary = engine.create_new_run(seed_value, Progression.default_data(), true)
	assert(int(state["player_hp"]) == 24 and int(state["player_max_hp"]) == 24)
	var choices := Choices.new(engine, scores, draft, seed_value, ladder)
	var record: Dictionary = {"schema_version": 1, "seed": seed_value, "policy": draft, "policy_sha256": FileAccess.get_sha256("res://tools/encounter_bot.gd"), "map_revision": state["section_map_layout_revision"], "entries": [entry(state, 0 if ladder else -1)], "fights": [], "route": [], "choices": [], "uncovered_rooms": {}, "turn_cap_deaths": 0}
	var reward_picks: int = 0
	if ladder:
		record["schema_version"] = 2
		record["ladder"] = true
		record["noncombat_health_clamps"] = 0
		record["victory_hp_repairs"] = 0
		record["forced_victories"] = 0
		record["turn_cap_fights"] = 0
	# Start-room NPC services are outside the supplied policy.
	count_uncovered(record, "start")
	var transitions: int = 0
	while not bool(state.get("game_over", false)) and not bool(state.get("victory", false)):
		transitions += 1
		assert(transitions <= MAX_TRANSITIONS, "Whole-run transition fault guard")
		state = choices.equip_drops(state)
		var room: Dictionary = engine.room_metadata(state, state["current_room"])
		match str(state["mode"]):
			"room":
				state = engine.move_to_room(state, choices.destination(state))
				room = engine.room_metadata(state, state["current_room"])
				record["route"].append({"section": Graph.active_section(state), "kind": room_kind(room), "coord": str(state["current_room"]), "hp": state["player_hp"]})
				if str(state["mode"]) == "room":
					if not engine.merchant_kind_for_current_room(state).is_empty():
						state = choices.merchant(state)
					else: count_uncovered(record, room_kind(room))
			"pre_battle": state = engine.begin_pre_battle_combat(state)
			"combat":
				print("RUN_CURVE_FIGHT_START seed=%d policy=%s section=%d kind=%s" % [seed_value, draft, Graph.active_section(state), room_kind(room)])
				var before: Dictionary = state["combat_state"]
				if ladder: assert(int(before["player"]["hp"]) == int(before["player"]["max_hp"]), "Ladder fight must start full")
				fight_started(before)
				var fought: Dictionary = Battle.fight(before)
				fight_finished(before, fought)
				var after: Dictionary = fought["state"]
				print("RUN_CURVE_FIGHT_DONE seed=%d policy=%s section=%d won=%s turns=%d" % [seed_value, draft, Graph.active_section(state), fought["won"], fought["turns"]])
				record["fights"].append({"section": Graph.active_section(state), "kind": room_kind(room), "depth": room["depth"], "won": fought["won"], "turn_cap_reached": fought["turn_cap_reached"], "turns": fought["turns"], "decisions": fought["decisions"], "search_capped": fought["search_capped"], "hp_before": before["player"]["hp"], "max_hp_before": before["player"]["max_hp"], "hp_after": after["player"]["hp"], "hp_lost": int(after.get("run_stats", {}).get("damage_received", 0)) - int(before.get("run_stats", {}).get("damage_received", 0)), "net_hp_lost": int(before["player"]["hp"]) - int(after["player"]["hp"]), "deck_size": state["deck_cards"].size()})
				if not ladder: record["fights"].back().erase("max_hp_before")
				if ladder:
					if bool(fought["turn_cap_reached"]): record["turn_cap_fights"] += 1
					if not bool(fought["won"]):
						record["forced_victories"] += 1
						if int(after["player"]["hp"]) < 1: record["victory_hp_repairs"] += 1
						var transition: Dictionary = LadderRun.victory_transition(after)
						record["fights"].back()["transition_ember_topup"] = int(transition.get("room_embers", 0)) - int(after.get("room_embers", 0))
						after = transition
				elif bool(fought["turn_cap_reached"]):
					# A measurement classification, not a fabricated engine defeat.
					record["turn_cap_deaths"] += 1
					state = engine.set_combat_state(state, after)
					break
				state = engine.finish_combat(state, after)
			"reward":
				if engine.is_dragon_reward(state): state = engine.continue_dragon_reward(state)
				else:
					var offered: Array = state["pending_reward"].get("cards", [])
					var pick: String = choices.card(offered)
					record["choices"].append({"section": Graph.active_section(state), "kind": "card_reward", "offered": offered.duplicate(), "picked": pick})
					if not pick.is_empty(): reward_picks += 1
					state = engine.skip_reward_for_heal(state) if pick.is_empty() else engine.claim_card_reward(state, pick)
			"treasure":
				var relics: Array = state.get("pending_relics", [])
				state = engine.claim_relic(state, str(relics[0]) if not relics.is_empty() else "")
			"campfire":
				var previous_deck: Array = state["deck_cards"].duplicate()
				state = choices.hearth(state)
				if ladder:
					record["choices"].append({"section": Graph.active_section(state), "kind": "hearth", "deck_before": previous_deck, "deck_after": state["deck_cards"].duplicate(), "purged": state.get("last_magic_purge", {}).get("card_id", "") if state["deck_cards"].size() < previous_deck.size() else ""})
			"event":
				if str(state["event_state"].get("page", "choices")) == "result": state = Events.continue_event(state)
				else:
					var pick: String = choices.event_choice(state)
					assert(not pick.is_empty(), "Event has no available choice")
					record["choices"].append({"section": Graph.active_section(state), "kind": "event", "event": Events.current_id(state), "picked": pick})
					if ladder: record["noncombat_health_clamps"] += LadderRun.event_native_clamps(state, pick, engine)
					state = Events.choose_event(state, pick, engine)
			"graftwright":
				count_uncovered(record, "graftwright")
				state = engine.leave_graftwright(state)
			"escape": state = engine.continue_pending_escape(state)
			_: assert(false, "Unhandled production mode: " + str(state["mode"]))
		if ladder: LadderRun.clamp_health(state, record)
		var section: int = Graph.active_section(state)
		if section != int(record["entries"].back()["section"]): record["entries"].append(entry(state, reward_picks if ladder else -1))
	if ladder:
		record["health_resets"] = engine.health_resets
		record["card_reward_picks"] = reward_picks
		record["completed_ladder"] = bool(state.get("victory", false))
	record["escaped"] = bool(state.get("victory", false))
	record["end_section"] = Graph.active_section(state)
	record["end_hp"] = state["player_hp"]
	record["end_max_hp"] = state["player_max_hp"]
	record["end_embers"] = engine.held_embers(state)
	record["deck_at_end"] = state["deck_cards"].duplicate()
	record["relics_at_end"] = state["relics"].duplicate()
	record["equipment_at_end"] = state["equipped_equipment"].duplicate()
	return record

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sweep.option(args, "--scores", "")))
	var draft: String = Sweep.option(args, "--policy", "best")
	assert(draft in ["best", "random", "none"])
	var ladder: bool = args.has("--ladder")
	var first_seed: int = int(Sweep.option(args, "--seed", "1"))
	var runs: int = int(Sweep.option(args, "--runs", "1"))
	var deadline: float = float(Sweep.option(args, "--deadline-unix", "0"))
	var output := FileAccess.open(Sweep.option(args, "--output", ""), FileAccess.WRITE)
	assert(output != null)
	var completed: int = 0
	for seed_value: int in range(first_seed, first_seed + runs):
		if deadline > 0.0 and Time.get_unix_time_from_system() >= deadline: break
		print("RUN_CURVE_START policy=%s seed=%d ladder=%s started_unix=%.6f" % [draft, seed_value, ladder, Time.get_unix_time_from_system()])
		var record: Dictionary = whole_run(seed_value, draft, scores, ladder)
		output.store_line(JSON.stringify(Store._sanitize_variant(record)))
		output.flush()
		completed += 1
		print("RUN_CURVE_DONE policy=%s seed=%d section=%d escaped=%s" % [draft, seed_value, record["end_section"], record["escaped"]])
	output.close()
	print("RUN_CURVE_WORKER_PASS policy=%s completed=%d" % [draft, completed])
	quit(0)
