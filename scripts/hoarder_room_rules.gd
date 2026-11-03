extends RefCounted
## Ember Hoarder (spx-09). No new mechanic: the room combines the Warband
## captain's back-line placement, keep-away step and break, the Snare
## Sealbinder's player-turn clock and silent dissolve, the Ember Tick's Kindle
## and death burst, and an ordinary move_away intent. Every value is read from
## `types.ember_hoarder` in data/special_encounters.json.
const Library = preload("res://scripts/special_encounter_library.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")
const WarbandRooms = preload("res://scripts/warband_room_rules.gd")
const TYPE: String = "ember_hoarder"
const KILL_LEADER: String = "kill_leader"
const KILL_ALL: String = "kill_all"
const RESULT_CAUGHT: String = "caught"
const RESULT_ESCAPED: String = "escaped"
const PANEL_RULE_ID: String = "ember_hoarder"
# int-09: the director-approved Ember Tick rig alias keeps its scale and landmarks.

static func rules() -> Dictionary:
	return Library.definition(TYPE)

static func is_room(room: Dictionary) -> bool:
	return str(room.get("type", "")) == "special" and str(room.get("special_type", "")) == TYPE

static func active(state: Dictionary) -> bool:
	return str(state.get("objective", {}).get("special_type", "")) == TYPE

# ---------------------------------------------------------------- generation

static func roster(tier: int) -> Array:
	var data: Dictionary = rules()
	var result: Array = [str(data["hoarder"]["unit"])]
	for index: int in range(int(data["brood"]["count"])): result.append(str(data["brood"]["unit"]))
	return result

static func escape_turn(tier: int) -> int:
	return int(rules()["hoarder"]["slips_away_after_player_turns_by_tier"][clampi(tier, 1, 3) - 1])

# The generic Defeat the Leader objective, without its generic leader HP or
# Stoneskin: the Hoarder's Health is set by configure() after depth scaling.
static func objective(room: Dictionary, tier: int) -> Dictionary:
	var data: Dictionary = rules()
	return {"special_type": TYPE, "special_variant": room["special_variant"], "goal_met": false,
		"leader_display_name": data["hoarder"]["title"], "leader_health_multiplier": 1.0, "leader_stoneskin": 0,
		"keep_distance": data["hoarder"]["keep_distance"].duplicate(true), "break_line": data["break_line"],
		"escape_after_player_turns": escape_turn(tier), "player_turns_completed": 0, "enemy_round_pending": false,
		"hoarder_escaped": false, "hoarder_caught": false, "hoarder_caught_turn": 0}

# Runs before omen additions, exactly where the Warband validates its formation.
static func mark_layout(layout: Dictionary, entry_safe_radius: int) -> void:
	layout["special_type"] = TYPE
	layout["special_variant"] = layout["objective"]["special_variant"]
	assert(WarbandRooms.validate(layout, entry_safe_radius), "Illegal Ember Hoarder placement")

# After ordinary depth and Umbra scaling: Health is the multiplier times the
# brood Ember Tick's final scaled Health in this same room.
static func configure(layout: Dictionary) -> void:
	var data: Dictionary = rules()
	var enemies: Array = layout["enemies"]
	var hoarder: Dictionary = enemies[0]
	var tick_hp: int = -1
	for index: int in range(1, enemies.size()):
		if str(enemies[index]["type"]) == str(data["brood"]["unit"]):
			tick_hp = int(enemies[index]["max_hp"])
			break
	assert(tick_hp > 0, "Ember Hoarder brood must contain an Ember Tick")
	hoarder["max_hp"] = ceili(float(tick_hp) * float(data["hoarder"]["hp_multiplier"]))
	hoarder["hp"] = hoarder["max_hp"]
	hoarder["display_name"] = data["hoarder"]["title"]
	layout["objective"]["hoarder_id"] = int(hoarder["id"])

# ---------------------------------------------------------------- combat

static func hoarder_unit(state: Dictionary) -> Dictionary:
	if not active(state): return {}
	var id: int = int(state["objective"].get("hoarder_id", state["objective"].get("leader_id", -1)))
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -2)) == id: return enemy
	return {}

static func at_large(state: Dictionary) -> bool:
	if not active(state): return false
	var objective_value: Dictionary = state["objective"]
	if bool(objective_value.get("hoarder_escaped", false)) or bool(objective_value.get("hoarder_caught", false)): return false
	return int(hoarder_unit(state).get("hp", 0)) > 0

static func turns_left(state: Dictionary) -> int:
	if not active(state): return 0
	var objective_value: Dictionary = state["objective"]
	return maxi(0, int(objective_value.get("escape_after_player_turns", 0)) - int(objective_value.get("player_turns_completed", 0)))

# The Warband captain's keep-away step: within trigger range it takes one legal
# step, farthest screened destinations first, then farthest unscreened.
static func retreat_path(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var empty: Array[Vector2i]
	if not at_large(state) or not bool(enemy.get("is_leader", false)) or int(enemy.get("hp", 0)) <= 0: return empty
	# Run the captain's own step unchanged, with this room's keep-distance dials;
	# only the objective differs, and the step reads no other objective field.
	var as_captain: Dictionary = state.duplicate(false)
	as_captain["objective"] = {"special_type": "warband", "keep_distance": state["objective"]["keep_distance"]}
	return Warband.retreat_path(engine, as_captain, enemy)

# The Sealbinder's clock: one completed player turn per enemy round, guarded by
# the saved pending bit so preview, resume and the batch API advance it once.
# At the deadline the Hoarder dissolves at once, at the end of that player turn.
static func begin_round(engine: RefCounted, state: Dictionary) -> void:
	if not at_large(state) or engine.combat_outcome(state) != "": return
	var objective_value: Dictionary = state["objective"]
	if bool(objective_value.get("enemy_round_pending", false)): return
	objective_value["enemy_round_pending"] = true
	objective_value["player_turns_completed"] = int(objective_value.get("player_turns_completed", 0)) + 1
	if int(objective_value["player_turns_completed"]) >= int(objective_value["escape_after_player_turns"]): slip_away(state)

static func end_round(state: Dictionary) -> void:
	if active(state): state["objective"]["enemy_round_pending"] = false

# The Sealbinder dissolve: no death effects, rewards, kill credit or sound. The
# fight continues as the ordinary Defeat All against everyone still standing.
static func slip_away(state: Dictionary) -> void:
	var objective_value: Dictionary = state["objective"]
	var escaping: Dictionary = hoarder_unit(state)
	objective_value["hoarder_id"] = int(escaping.get("id", objective_value.get("leader_id", -1)))
	if not escaping.is_empty():
		escaping["hp"] = 0
		escaping["snare_dissolved"] = true
		escaping["objective_cleared"] = true
	objective_value["hoarder_escaped"] = true
	objective_value["goal_met"] = false
	objective_value["type"] = KILL_ALL
	var objectives: GDScript = load("res://scripts/combat_objective_rules.gd")
	objective_value["name"] = objectives.display_name(KILL_ALL)
	objective_value["description"] = objectives.description(KILL_ALL)
	objective_value["icon_path"] = objectives.icon_path(KILL_ALL)
	objective_value.erase("leader_id")

# Catching it wins at once; the brood scatters by the Warband break.
static func catch(engine: RefCounted, state: Dictionary, leader_id: int) -> Dictionary:
	var objective_value: Dictionary = state["objective"]
	if not bool(objective_value.get("hoarder_caught", false)):
		objective_value["hoarder_id"] = leader_id
		objective_value["hoarder_caught"] = true
		objective_value["hoarder_caught_turn"] = int(state.get("turn", 1))
		objective_value["goal_met"] = true
	return Warband.break_followers(engine, state, leader_id)

# The Warband's batched-death rule: once the Hoarder is actually dead (never
# after slipping away), queued brood deaths cannot outlive the break.
static func broken(state: Dictionary) -> bool:
	if not active(state) or bool(state["objective"].get("hoarder_escaped", false)): return false
	if bool(state["objective"].get("completed_by_leader", false)): return true
	for enemy: Dictionary in state.get("enemies", []):
		if bool(enemy.get("is_leader", false)) and int(enemy.get("hp", 0)) <= 0 and not bool(enemy.get("snare_dissolved", false)): return true
	return false

static func suppress_death_effects(state: Dictionary, enemy: Dictionary) -> bool:
	return not bool(enemy.get("is_leader", false)) and broken(state)

# The legacy batch API shares the initiative activation path and clock.
static func resolve_phase(engine: RefCounted, state: Dictionary) -> Dictionary:
	var needs_preparation: bool = engine.is_player_turn(state) and not bool(state["objective"].get("enemy_round_pending", false))
	var next_state: Dictionary = engine.finish_player_activation(state) if needs_preparation else state.duplicate(true)
	begin_round(engine, next_state)
	var steps: Array[Dictionary]
	for index: int in range((next_state.get("enemies", []) as Array).size()):
		if engine.combat_outcome(next_state) != "": break
		if int(next_state["enemies"][index]["hp"]) <= 0: continue
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(next_state, index, false)
		next_state = result["state"]
		steps.append_array(result["steps"])
	end_round(next_state)
	return {"state": next_state, "steps": steps}

# ---------------------------------------------------------------- presentation

static func ordinal(value: int) -> String:
	var suffix: String = "th"
	if posmod(value, 100) < 11 or posmod(value, 100) > 13:
		match posmod(value, 10):
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [value, suffix]

static func rule_sentence(objective_value: Dictionary) -> String:
	return str(rules()["rule_line"]) % ordinal(int(objective_value.get("escape_after_player_turns", 0)))

# The one rule sentence, docked above the objective while the Hoarder is at
# large, with the turns left on the rule panel's kicker.
static func panel(state: Dictionary) -> Dictionary:
	if not at_large(state): return {}
	var data: Dictionary = rules()["rule_panel"]
	var left: int = turns_left(state)
	return {"rule": PANEL_RULE_ID, "name": str(data["name"]), "icon_path": str(data["icon"]), "sentence": rule_sentence(state["objective"]),
		"kicker": str(data["kicker"]) + (str(data["turns_left_one"]) if left == 1 else str(data["turns_left"]) % left)}

# ---------------------------------------------------------------- rewards

static func bonus_kind(room: Dictionary) -> String:
	return str(rules().get("bonus", {}).get("kind", "")) if is_room(room) else ""

# A standard fight's Ember reward at this depth, through the same calculation
# the special reward uses for its standard-fight base (the captured starting
# roster's reward_embers, ordinary half-up rounding, the combat's omens).
static func hoard_embers(room: Dictionary, combat: Dictionary) -> int:
	var base: int = int(room.get("special_starting_reward_embers", 0))
	var standard: int = int(floor(base * float(rules()["bonus"]["standard_fight_embers"]) + 0.5))
	return Omens.ember_drop(combat, standard)

static func reward_line(amount: int) -> String:
	return str(rules()["bonus"]["reward_line"]) % amount

# ---------------------------------------------------------------- analytics

static func analytics(state: Dictionary) -> Dictionary:
	var objective_value: Dictionary = state.get("objective", {})
	var result: String = ""
	if active(state):
		if bool(objective_value.get("hoarder_caught", false)): result = RESULT_CAUGHT
		elif bool(objective_value.get("hoarder_escaped", false)): result = RESULT_ESCAPED
	return {"hoarder_result": result, "hoarder_caught_turn": int(objective_value.get("hoarder_caught_turn", 0)) if result == RESULT_CAUGHT else 0}
