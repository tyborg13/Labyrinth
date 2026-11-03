extends SceneTree
const Adapter = preload("res://assets/units/storm_cantor_cutout/action_adapter.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Data = preload("res://scripts/game_data.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
var errors: Array[String]
var checks: int = 0
func _initialize() -> void:
	var actor: Dictionary = {"id":1, "type":"storm_cantor", "intent":{"id":"peal"}}
	var other: Array = [{"kind":"move","actor_key":"enemy_2"}]
	check(Adapter.presentation_steps(actor,other)==other,"Other actor cannot trigger Peal")
	var steps: Array = [{"kind":"intent","actor_key":"enemy_1"},{"kind":"move","actor_key":"enemy_1","intent_id":"peal"},{"kind":"lightning_strikes","actor_key":"enemy_1"}]
	var original: Array = steps.duplicate(true)
	var shown: Array = Adapter.presentation_steps(actor,steps)
	check(steps==original,"Resolver payloads unchanged")
	check(shown.size()==4 and shown[2]["kind"]=="cutout_gesture" and shown[3]==steps[2],"Gesture follows movement and precedes existing lightning step")
	check(Adapter.presentation_steps(actor,shown)==shown,"No duplicate gesture")
	var stationary: Array = Adapter.presentation_steps(actor,[{"kind":"intent","actor_key":"enemy_1"}])
	check(stationary.size()==2 and stationary[1]["kind"]=="cutout_gesture","Stationary Peal gestures")
	for bookkeeping: Dictionary in [{"kind":"intent_refresh"},{"kind":"commit"},{"kind":"no_action","no_action_reason":"frozen"},{"kind":"intent","hidden_by_umbra":true},{"kind":"move","cancelled":true}]:
		bookkeeping["actor_key"]="enemy_1"
		var skipped: Array = [bookkeeping]
		check(Adapter.presentation_steps(actor,skipped)==skipped,"No gesture for hidden/cancelled/skipped activation or bookkeeping: "+str(bookkeeping["kind"]))
	var prior: Dictionary = {"enemies":[{"id":2,"type":"bell_tender","intent":{"id":"peal"}}]}
	check(Action.presentation_steps(prior,other)==other,"Earlier rigs retain their original steps")
	check(not preload("res://scripts/guardian_cutout/renderer.gd").handles("storm_cantor"),"Legacy route retired")
	check(Presentation.handles("storm_cantor") and Presentation.asset_directory("storm_cantor").ends_with("humanoid_v2"),"Board and shared portrait consumers use v2")
	for definition: Dictionary in Data.enemy_def("storm_cantor")["intents"]:
		actor["intent"]=definition
		for action: Dictionary in definition["actions"]:
			var clip: String = Action.clip_for({"action_type":action["type"],"intent_id":definition["id"]},actor)
			if str(action["type"])!="move_toward":check(clip==definition["id"],"Approved action selector: "+definition["id"])
	for message: String in errors:push_error(message)
	print("RR56 ACTION / ROUTING: %s (%d checks)"%["PASS" if errors.is_empty() else "FAIL",checks])
	quit(0 if errors.is_empty() else 1)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message)
