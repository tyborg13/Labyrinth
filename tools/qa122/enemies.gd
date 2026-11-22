extends RefCounted
## Resolve declared intents with the ordinary activation loop, including set-up turns.

const Fx = preload("res://tools/qa122/fixture.gd")
const Cards = preload("res://tools/qa122/cards.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Inspect = preload("res://scripts/pre_battle_inspection_view.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Marked = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const GuardianCombat = preload("res://scripts/guardian_combat_rules.gd")
const BossAreas = preload("res://scripts/boss_area_rules.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Tags = preload("res://scripts/pre_battle_threat_tags.gd")
const ProbePositions: Array = [Fx.Foe, Vector2i(6, 5), Vector2i(8, 5), Vector2i(6, 7)]
const Ally := Vector2i(7, 6)
const CaptionFields: Array = ["kind", "action_type", "label", "text", "amount", "damage", "hits",
	"intent_id", "status", "tile", "impact_tiles", "no_action_reason", "actor_key", "target_key"]

static func catalog(engine: RefCounted, filter: String) -> Array:
	var rows: Array = []
	for type: String in Fx.Data.enemies():
		if not filter.is_empty() and type != filter: continue
		var definition: Dictionary = Fx.Data.enemy_def(type)
		var intents: Array = definition.get("intents", [])
		for intent: Dictionary in intents:
			for pos: Vector2i in ProbePositions:
				rows.append(probe(engine, type, definition, intent, pos))
	return rows

static func _stage(engine: RefCounted, state: Dictionary, type: String, intent: Dictionary) -> Dictionary:
	var action_types: Array = intent.get("actions", []).map(func(action: Dictionary) -> String: return str(action["type"]))
	for action_type: String in ["icefall_land", "lob_land", "erupt", "detonate_cinders"]:
		if not action_types.has(action_type): continue
		for candidate: Dictionary in Fx.Data.enemy_def(type)["intents"]:
			for action: Dictionary in candidate["actions"]:
				if str(action["type"]) in ["icefall_mark", "lob_mark", "burrow", "cinder_marks"]:
					state["enemies"][0]["intent"] = candidate
					return engine.resolve_enemy_turn_with_steps(state, 0, false, false)["state"]
	if action_types.has("chain_discharge"):
		for candidate: Dictionary in Fx.Data.enemy_def(type)["intents"]:
			if candidate["id"] != "charge": continue
			for charge: int in range(3):
				state["enemies"][0]["intent"] = candidate
				state = engine.resolve_enemy_turn_with_steps(state, 0, false, false)["state"]
	return state

static func probe(engine: RefCounted, type: String, definition: Dictionary, intent: Dictionary, pos: Vector2i) -> Dictionary:
	var state: Dictionary = Fx.state(engine, pos, type)
	var source: Dictionary = state["enemies"][0]
	var footprint: Variant = definition.get("footprint", Vector2i.ONE)
	if footprint is Array: source["footprint"] = Vector2i(int(footprint[0]), int(footprint[1]))
	var ally: Dictionary = Fx.enemy(Ally, 2)
	ally["hp"] = Fx.Health >> 1
	state["enemies"].append(ally)
	state = _stage(engine, state, type, intent)
	source = state["enemies"][0]
	var authored: Dictionary = intent.duplicate(true)
	var prepared: Dictionary = engine._surface_prepare_enemy_intent(state, source, authored)
	if GuardianCombat.has_authored_actions(prepared) and not prepared.has("committed_plan"):
		prepared = GuardianCombat.commit(engine, state, 0, prepared)
	prepared = BossAreas.freeze(engine, state, source, prepared)
	source["intent"] = prepared
	var presented: Dictionary = Marked.presentation_intent(engine, state, source, prepared)
	var panel_rows: Array = Inspect.move_rows(presented, source, state)
	var panel: String = Icons.plain_text_for_rows(panel_rows, true)
	for act: Dictionary in presented.get("actions", []):
		if str(act["type"]) in ["lob_mark", "lob_land"]: panel = Icons.lob_diagram_text(act)
	var badges: Array = Badges.build(engine, state, state, "", {}, {"enemy_1": ["1"]}, {})["badges"]
	var badge: Dictionary = {}
	for candidate: Dictionary in badges:
		if candidate.get("key", "") == "enemy_1":
			for field: String in ["icon", "number", "secondary_icon", "secondary_number", "condition_icon", "cancelled"]:
				if candidate.has(field): badge[field] = candidate[field]
	var before: Dictionary = Fx.receipt(state)
	var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)
	var captions: Array = []
	var ledger: Array = []
	var previous: Dictionary = before
	for step: Dictionary in resolved["steps"]:
		if step.get("kind", "") == "commit":
			var snapshot: Dictionary = Fx.receipt(step["state"])
			ledger.append({"boundary": step["boundary"], "delta": Fx.delta(previous, snapshot)})
			previous = snapshot
			continue
		if str(step.get("kind", "")) in ["intent_refresh", "trace_state"]: continue
		var caption: Dictionary = {}
		for field: String in CaptionFields:
			if step.has(field): caption[field] = step[field]
		if step.has("target_losses"): caption["target_losses"] = step["target_losses"]
		captions.append(caption)
	return {"enemy": type, "id": intent["id"], "name": intent.get("name", ""), "pos": Fx.tile(pos),
		"panel": panel, "panel_tokens": Cards.token_rows(panel_rows),
		"tags": Tags.summary(Tags.from_intents([presented])), "notes": Guardians.intent_notes(presented),
		"panel_tooltip": Inspect.move_tooltip(panel_rows), "shown_time": int(intent.get("time", 0)), "badge": badge,
		"time": resolved["time_cost"], "captions": captions, "boundaries": ledger, "delta": Fx.delta(before, Fx.receipt(resolved["state"]))}
