extends RefCounted
## Frozen pre-bos-03 selection, offline measurement only.
const Library = preload("res://scripts/guardian_library.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Current = preload("res://scripts/guardian_combat_rules.gd")
const SUMMON_ORIGIN_FIELD = "summon_origin"
const SUMMON_ORIGIN_AUTHORED = "authored"
const SUMMON_ORIGIN_REPLACEMENT = "guardian_replacement"
static func objects(state: Dictionary, kind: String, owner: int) -> Array[Dictionary]:
	return Current.objects(state, kind, owner)

static func living_helpers(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for helper: Dictionary in state.get("enemies",[]):
		if int(helper.get("hp",0))>0 and bool(helper.get("guardian_helper",false)):
			var id: String = str(helper["type"])
			result[id] = int(result.get(id,0))+1
	return result

static func missing_helpers(state: Dictionary, enemy: Dictionary) -> Array[String]:
	var definition: Dictionary = Library.for_guardian(str(enemy.get("type","")))
	var missing: Array[String]
	var living: Dictionary = living_helpers(state)
	for id: String in definition.get("helpers",[]):
		if int(living.get(id,0))>0: living[id]=int(living[id])-1
		else: missing.append(id)
	return missing

static func choose_intent(state: Dictionary, enemy: Dictionary, intents: Array, cycle: int) -> Dictionary:
	var choice: Dictionary = intents[posmod(cycle,intents.size())]
	if str(choice.get("id",""))=="call_the_spark" and missing_helpers(state,enemy).is_empty(): return intents[0]
	if str(choice.get("id",""))=="peal" and Surfaces.tiles(state,"electrified").is_empty(): return intents[0]
	if str(choice.get("id",""))=="upheaval" and objects(state,"crag_outcrop",int(enemy["id"])).size()>=2: return intents[1]
	return choice

static func with_reinforcements(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	var missing: Array[String] = missing_helpers(state,enemy)
	var result: Dictionary = intent.duplicate(true)
	# The compatibility flag below also marks authored Call the Spark. Record
	# origin before adding a replacement so economy can distinguish the two.
	for action: Dictionary in result.get("actions", []):
		if str(action.get("type", "")) == "summon_minions" and not action.has(SUMMON_ORIGIN_FIELD):
			action[SUMMON_ORIGIN_FIELD] = SUMMON_ORIGIN_AUTHORED
	if missing.is_empty(): return result
	var id: String = missing[0]
	var cap: int = (Library.for_guardian(str(enemy["type"])).get("helpers",[]) as Array).count(id)
	for action: Dictionary in result.get("actions",[]):
		if str(action.get("type",""))=="summon_minions":
			if not bool(action.get("snuff_brazier",false)):
				action["minion_type"]=id
				action["guardian_cap"]=cap
				action["guardian_reinforcement"]=true
			return result
	# One replacement per revealed Guardian activation. A helper defeated after
	# this declaration buys a whole activation before a new summon is announced.
	result["actions"].append({"type":"summon_minions","minion_type":id,"count":1,"range":3,"guardian_cap":cap,"guardian_reinforcement":true,SUMMON_ORIGIN_FIELD:SUMMON_ORIGIN_REPLACEMENT})
	return result

