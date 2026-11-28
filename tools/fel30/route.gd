extends "res://tools/fel30/hunt_policy.gd"
## Route based on fel-20's viewport descent. Take card rewards when offered.

const Graph = preload("res://scripts/section_map_graph.gd")
const SAME_INPUT_LIMIT := 2

var inputs
var _source: Array
var _attempts: Dictionary
var _shop_room: Vector2i
var _shop_bought: bool


func observe(source: Array) -> void:
	if source != _source:
		_source = source
		_attempts.clear()


func dispatched(input: Dictionary) -> void:
	var label: String = input["label"]
	_attempts[label] = int(_attempts.get(label, 0)) + 1
	if label.begins_with("Buy") or str(input.get("text", "")).begins_with("Buy"):
		_shop_bought = true


func _available(input: Dictionary) -> bool:
	return not input.is_empty() and int(_attempts.get(input["label"], 0)) < SAME_INPUT_LIMIT


func next(scene: Node) -> Dictionary:
	if not scene.has_method("has_installed_run"):
		var begin: Control = inputs.named(scene.get("_new_descent_panel"), "DepthBegin")
		return inputs.control(scene.get("start_button") if begin == null else begin)
	var run: Dictionary = scene._run_state
	var mode: String = run.get("mode", "")
	if inputs.available(scene._run_end_recap):
		return inputs.control(inputs.named(scene._run_end_recap, "MainMenuButton"))
	if scene._opening_boon_flow.active() or scene._dialogue_active or scene._guided_tutorial_is_active():
		var introduction: Array = offers(scene)
		for offer: Dictionary in introduction:
			if offer.get("text") in ["Skip Tutorial", "Continue", "Leave"]:
				return inputs.hunt_input(scene, offer)
		if scene._opening_boon_flow.active() or scene._dialogue_active:
			if introduction.is_empty(): return {}
			return inputs.hunt_input(scene, introduction[0])
	if scene._large_map_scrim.visible: return _map(scene)
	if mode == "room" and inputs.available(scene._scavenger_shop_view): return _shop(scene)
	if mode == "room" and Graph.enabled(run) and scene._map_shortcut_can_open(): return inputs.key(KEY_M)
	if mode == "pre_battle": return inputs.control(inputs.named(scene, "PreBattleStartButton"))
	if mode == "event":
		var event: Control = scene._event_view
		if not inputs.available(event): return {}
		if event.page == "result": return inputs.control(event.continue_button)
		for button: Button in event.choices:
			if button.available: return inputs.control(button)
		return {}
	if mode == "reward":
		var dragon: Control = inputs.named(scene, "DragonRewardContinue")
		if dragon != null: return inputs.control(dragon)
	var candidates: Array = offers(scene)
	candidates = candidates.filter(func(offer: Dictionary) -> bool: return _available(inputs.hunt_input(scene, offer)))
	if candidates.is_empty():
		if mode == "combat" and (scene._player_movement_selected or (scene._selected_card_index >= 0 and not scene._pending_umbra_commit_locked)):
			return inputs.key(KEY_ESCAPE)
		return {}
	if mode == "reward":
		for offer: Dictionary in candidates:
			if offer.get("signal") == "activated": return inputs.hunt_input(scene, offer)
	return inputs.hunt_input(scene, choose(scene, candidates))


func _map(scene: Node) -> Dictionary:
	var run: Dictionary = scene._run_state
	var current: Dictionary = scene._run_engine.room_metadata(run, run["current_room"])
	var choices: Array[Dictionary]
	for offer: Dictionary in offers(scene):
		if offer["kind"] != "map_room": continue
		var target: Dictionary = scene._run_engine.room_metadata(run, offer["args"][0])
		var step: int = int(target.get("map_step", 0)) - int(current.get("map_step", 0))
		var score: int = 10 * step - 50 * int(target.get("visited", false))
		var input: Dictionary = inputs.hunt_input(scene, offer)
		if _available(input): choices.append({"input": input, "score": score})
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	return {} if choices.is_empty() else choices[0]["input"]


func _shop(scene: Node) -> Dictionary:
	var shop: Control = scene._scavenger_shop_view
	if _shop_room != scene._run_state["current_room"]:
		_shop_room = scene._run_state["current_room"]
		_shop_bought = false
	if not _shop_bought:
		var buy: Dictionary = inputs.control(shop._detail_action)
		if _available(buy) and str(buy.get("text", "")).begins_with("Buy"): return buy
		for node: Node in shop.find_children("*", "BaseButton", true, false):
			if not node.get_meta("shop_affordable", false): continue
			var select: Dictionary = inputs.control(node)
			if _available(select): return select
	return inputs.control(shop._leave_button)
