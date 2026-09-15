extends RefCounted
const Fixtures=preload("res://tests/suites/guardian_suite.gd")
const Combat=preload("res://scripts/combat_engine.gd")
const Data=preload("res://scripts/game_data.gd")
const Rules=preload("res://scripts/guardian_combat_rules.gd")
const Outcomes=preload("res://scripts/combat_outcome_feedback.gd")
const Fx=preload("res://scripts/attack_fx_library.gd")
const Sfx=preload("res://scripts/attack_sfx_library.gd")
const Icons=preload("res://scripts/action_icon_library.gd")

static func run(expect: Callable) -> void:
	var engine:=Combat.new()
	var fixtures:=Fixtures.new()
	var state: Dictionary=fixtures.guardian_fixture("ashen_reaver")
	state["enemies"][1]["hp"]=0
	fixtures.set_cycle(engine,state,0)
	var threat: Dictionary=engine.enemy_threat_tiles(state,0)
	var summons: Array=threat.get("summon",[])
	expect.call(summons.size()==1,"Missing Guardian helper has a summon tile")
	for tile: Vector2i in summons:
		expect.call(not (threat["projected_attack"] as Array).has(tile),"Summon tile is not mislabeled as an attack")
	var result: Dictionary=engine.resolve_enemy_turn_with_steps(state,0)
	var spawned: Array=result["state"]["enemies"].slice(state["enemies"].size())
	expect.call(spawned.size()==1 and summons.has(spawned[0]["pos"]),"Actual replacement agrees with its summon marker")
	state=fixtures.fixture("",[Vector2i(4,4)])
	state["enemies"][0]["type"]="zekarion"
	state["enemies"][0]["intent"]={"id":"backup","name":"Call backup","time":5,"actions":[{"type":"summon_minions","minion_type":"lightning_wisp","count":2}]}
	threat=engine.enemy_threat_tiles(state,0)
	result=engine.resolve_enemy_turn_with_steps(state,0)
	for enemy: Dictionary in result["state"]["enemies"].slice(1):
		expect.call((threat.get("summon",[]) as Array).has(enemy["pos"]),"Ordinary boss summon also previews its actual arrival")
	var row: Array=Icons.tokens_for_action({"type":"summon_minions","minion_type":"ash_hound","count":1,"guardian_cap":2})
	var text: String=Icons.plain_text_for_tokens(row)
	expect.call(text.contains("Ash Hound") and not text.contains("max"),"Summon row names the helper without a cap sentence")
	for depth: int in [2,22]:
		for id: String in ["gallows_roc","roc_fledgling","storm_cantor","bell_tender","lightning_wisp"]:
			var actor: Dictionary={"type":id}
			var context: Dictionary={"room_type":"guardian","room_depth":depth}
			for intent: Dictionary in Data.enemy_def(id)["intents"]:
				var delay: int=engine._enemy_base_initiative(context,actor)+engine._enemy_intent_time_cost(intent)
				expect.call(delay>=19,id+" cannot repeatedly double a normal 19-clock turn at depth "+str(depth))
	expect.call(engine._enemy_base_initiative({"room_type":"combat","room_depth":2},{"type":"lightning_wisp"})==7,"Ordinary Wisps retain their cadence")
	var area: Dictionary={"kind":"aoe","action_type":"ranged","range":3,"element":"lightning","to":Vector2i(2,2),"tiles":[Vector2i(2,2),Vector2i(3,2)]}
	expect.call(Fx.uses_authored_elemental_attack(area),"A ranged attack expanded into an area retains elemental rendering")
	expect.call(Sfx.entry_for_enemy_step(area).get("id","")=="attack.elemental.lightning","Elemental areas use elemental sound")
	var events: Array=[{"kind":"surface_conducted","tile":Vector2i(2,2)},{"kind":"surface_conducted","tile":Vector2i(3,2)},{"kind":"surface_created","surface":"electrified","tile":Vector2i(3,2)}]
	var feedback: Array=Outcomes.prepare(events,area)
	expect.call(feedback[0]["feedback_element"]=="" and feedback[1]["feedback_element"]=="lightning" and feedback[2]["feedback_element"]=="","Primary and indirect effects cover each tile once")
	expect.call(Outcomes.sounds(events).size()==1 and Outcomes.sounds(events,"lightning").is_empty(),"A network plays one elemental sound, not one per tile")
	var creation: Array=[{"kind":"terrain_created","tile":Vector2i(2,2),"terrain_id":"outcrop_1"}]
	expect.call(Outcomes.sounds(creation)[0]["id"]=="attack.elemental.earth","Shared outcrop creation uses Earth sound")
	expect.call(Outcomes.outcrop_progress(creation,"outcrop_1",0.1,false)<Outcomes.outcrop_progress(creation,"outcrop_1",0.8,false),"Outcrop emerges vertically")
	expect.call(Outcomes.outcrop_progress(creation,"outcrop_1",0.0,true)==1.0,"Reduced motion shows complete terrain immediately")

	var chain_before: Dictionary={"surface_event_sequence":5,"surfaces":{}}
	var chain_after: Dictionary={"surface_events":[{"sequence":6,"kind":"terrain_created","tile":Vector2i(2,2),"terrain_id":"outcrop_2"}],"surfaces":{}}
	var chain_events: Array=preload("res://scripts/chain_attack_feedback.gd")._ground_visual_changes(chain_before,chain_after)
	expect.call(chain_events.size()==1 and Outcomes.prepare(chain_events)[0]["feedback_element"]=="earth","Chained spells retain outcrop emergence and Earth feedback at cleanup")
