extends "res://tools/fel20/hunt_policy.gd"
## Prefer unexplored requested surfaces, then use the inherited resolver policy.

const Graph = preload("res://scripts/section_map_graph.gd")
const TARGET_SAMPLES := 2
const SAME_INPUT_LIMIT := 2
const MENU_STEPS := [
	["character.open", "LoadoutButton", "character"],
	["character.magic", "Magic", "magic"],
	["character.skills", "Skills", "skills"],
	["character.gear", "Gear", "gear"],
	["character.close", "Escape", "combat"],
	["grimoire.open", "GrimoireButton", "grimoire"],
	["grimoire.close", "Escape", "combat"],
	["large_map.open", "M", "map"],
	["large_map.close", "M", "combat"],
	["pause.open", "MenuButton", "pause"],
	["pause.close", "Escape", "combat"],
]

var inputs
var counts: Dictionary = {}
var menu_step: int = -1
var menu_turn: Array = []
var visited: Dictionary = {}
var shop_room: Vector2i
var bought_here: bool = false
var death_route: bool = false
var measure_menus: bool = true
var _source: Array
var _attempts: Dictionary


func observe(source: Array) -> void:
	if source != _source:
		_source = source
		_attempts.clear()


func dispatched(input: Dictionary) -> void:
	var label: String = input["label"]
	_attempts[label] = int(_attempts.get(label, 0)) + 1


func _new_attempt(input: Dictionary) -> bool:
	return not input.is_empty() and int(_attempts.get(input["label"], 0)) < SAME_INPUT_LIMIT


func next(scene: Node) -> Dictionary:
	if not scene.has_method("has_installed_run"):
		if scene.get("_boot_preparing") or scene.get("_loading_run"): return {}
		var resume: Dictionary = inputs.control(scene.get("continue_button"))
		if not resume.is_empty(): return _step(resume, "title.continue", "map")
		var begin: Control = inputs.named(scene.get("_new_descent_panel"), "DepthBegin")
		if begin == null: begin = scene.get("start_button")
		return _step(inputs.control(begin))
	if not scene.has_installed_run() or scene._animation_lock: return {}
	var run: Dictionary = scene._run_state
	var mode: String = run.get("mode", "")
	if inputs.available(scene._run_end_recap):
		return _step(inputs.control(inputs.named(scene._run_end_recap, "MainMenuButton")), "recap.title", "title")
	if menu_step >= 0: return _menu(scene)
	if scene._opening_boon_flow.active() or scene._dialogue_active or scene._guided_tutorial_is_active():
		var introductory: Array = offers(scene)
		for offer: Dictionary in introductory:
			if offer.get("text") in ["Skip Tutorial", "Continue", "Leave"]:
				return _step(inputs.hunt_input(scene, offer))
		if scene._dialogue_active or scene._opening_boon_flow.active():
			if not introductory.is_empty(): return _step(inputs.hunt_input(scene, introductory[0]))
			return {}
	if scene._large_map_scrim.visible:
		if counts.get("title.continue", 0) < TARGET_SAMPLES and run["current_room"] != Vector2i.ZERO:
			var coordinate: Array = [run["current_room"], run.get("run_index", 0)]
			if not visited.has(coordinate):
				visited[coordinate] = true
				return _step(inputs.key(KEY_M))
		return _map(scene)
	if scene._menu_scrim.visible:
		return _step(inputs.control(_button_text(scene._menu_scrim, "Save and Quit")))
	if mode == "room" and inputs.available(scene._scavenger_shop_view):
		return _shop(scene)
	if mode == "room" and counts.get("title.continue", 0) < TARGET_SAMPLES and run["current_room"] != Vector2i.ZERO:
		var coordinate: Array = [run["current_room"], run.get("run_index", 0)]
		if visited.has(coordinate):
			return _step(inputs.control(scene.menu_button))
	if mode == "room" and Graph.enabled(run) and scene._map_shortcut_can_open():
		return _step(inputs.key(KEY_M))
	if mode == "pre_battle":
		return _step(inputs.control(inputs.named(scene, "PreBattleStartButton")), "prebattle.combat", "combat")
	if mode == "event":
		var event: Control = scene._event_view
		if not inputs.available(event) or event._busy or event._closing or event._request_pending: return {}
		if event.page == "result":
			return _step(inputs.control(event.continue_button), "event.map", "map")
		for button: Button in event.choices:
			if button.available: return _step(inputs.control(button), "event.result", "event_result")
		return {}
	if mode == "combat":
		var combat: Dictionary = scene._combat_state
		if not scene._combat_engine.is_player_turn(combat): return {}
		if measure_menus and counts.get("pause.close", 0) < TARGET_SAMPLES and not scene._guided_tutorial_is_active():
			var turn: Array = [run["current_room"], combat.get("turn", 0)]
			if turn != menu_turn and scene._selected_card_index < 0 and not scene._player_movement_selected:
				menu_turn = turn
				menu_step = 0
				return _menu(scene)
		if death_route and scene._selected_card_index < 0 and not scene._player_movement_selected:
			return _step(inputs.key(KEY_P), "", "", true)
	if mode == "reward":
		var dragon: Control = inputs.named(scene, "DragonRewardContinue")
		if dragon != null:
			if run.get("pending_reward", {}).get("final_boss", false): return _step(inputs.control(dragon))
			return _step(inputs.control(dragon), "section.change", "map")
	var candidates: Array = offers(scene)
	candidates = candidates.filter(func(offer: Dictionary) -> bool:
		return _new_attempt(inputs.hunt_input(scene, offer)))
	if candidates.is_empty():
		if mode == "combat" and scene._player_movement_selected: return _step(inputs.key(KEY_ESCAPE))
		if mode == "combat" and scene._selected_card_index >= 0 and not scene._pending_umbra_commit_locked:
			return _step(inputs.key(KEY_ESCAPE))
		return {}
	if mode == "reward" and counts.get("reward.map", 0) < TARGET_SAMPLES:
		for offer: Dictionary in candidates:
			if offer.get("signal") == "activated":
				return _step(inputs.hunt_input(scene, offer), "reward.map", "map")
	var chosen: Dictionary = choose(scene, candidates)
	var input: Dictionary = inputs.hunt_input(scene, chosen)
	if mode == "reward":
		if chosen.get("signal") == "activated":
			return _step(input, "reward.map", "map")
		return _step(input, "", "", true)
	var can_resolve: bool = chosen.get("method") == "_on_board_tile_clicked" or chosen["kind"] in ["pass", "card", "confirm_card"]
	return _step(input, "", "", mode == "combat" and can_resolve)


func _menu(scene: Node) -> Dictionary:
	var option: Array = MENU_STEPS[menu_step]
	var target: Control
	match option[1]:
		"Escape": return _step(inputs.key(KEY_ESCAPE), option[0], option[2])
		"M": return _step(inputs.key(KEY_M), option[0], option[2])
		"Gear", "Magic", "Skills": target = _button_text(scene._upgrade_scrim, option[1])
		_: target = inputs.named(scene, option[1])
	return _step(inputs.control(target), option[0], option[2])


func _map(scene: Node) -> Dictionary:
	var run: Dictionary = scene._run_state
	var map: Control = scene._large_map_view
	if map.activation_coord != Graph.INVALID: return {}
	var choices: Array = []
	for coordinate: Vector2i in map.available_destinations():
		if not scene._run_engine.available_moves(run).has(coordinate): continue
		var target: Dictionary = scene._run_engine.room_metadata(run, coordinate)
		var current: Dictionary = scene._run_engine.room_metadata(run, run["current_room"])
		var kind: String = target.get("type", "")
		var step: int = int(target.get("map_step", 0)) - int(current.get("map_step", 0))
		var score: int = 10 * step - 50 * int(target.get("visited", false))
		var id: String = ""
		var destination: String = ""
		if kind == "event":
			id = "map.event"
			destination = "event_choices"
		elif scene._run_engine.merchant_kind_for_room(target) == "scavenger":
			id = "map.shop"
			destination = "shop"
		elif kind in ["combat", "boss", "guardian", "ambush", "fight"]:
			id = "map.prebattle"
			destination = "prebattle"
		if step > 0 and counts.get(id, TARGET_SAMPLES) < TARGET_SAMPLES:
			if kind == "event": score += 9
			if id == "map.shop": score += 9
		var input: Dictionary = inputs.hunt_input(scene, {"kind": "map_room", "args": [coordinate]})
		if _new_attempt(input):
			choices.append({"step": _step(input, id, destination, true), "score": score, "kind": kind})
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	if choices.is_empty(): return {}
	return choices[0]["step"]


func _shop(scene: Node) -> Dictionary:
	var shop: Control = scene._scavenger_shop_view
	if shop_room != scene._run_state["current_room"]:
		shop_room = scene._run_state["current_room"]
		bought_here = false
	if not bought_here:
		if inputs.available(shop._detail_action) and shop._detail_action.text.begins_with("Buy"):
			return _step(inputs.control(shop._detail_action), "shop.buy", "shop")
		for node: Node in shop.find_children("*", "BaseButton", true, false):
			if node.get_meta("shop_affordable", false) and inputs.available(node):
				return _step(inputs.control(node))
	return _step(inputs.control(shop._leave_button), "shop.leave", "map")


func _button_text(host: Node, label: String) -> Button:
	if not is_instance_valid(host): return null
	for button: Button in host.find_children("*", "Button", true, false):
		if inputs.available(button) and button.text.nocasecmp_to(label) == 0: return button
	return null


func _step(input: Dictionary, id: String = "", destination: String = "", watch: bool = false) -> Dictionary:
	if input.is_empty(): return {}
	return {"input": input, "id": id, "destination": destination, "watch": watch}


func accepted(id: String) -> void:
	counts[id] = counts.get(id, 0) + 1
	if menu_step >= 0 and id == MENU_STEPS[menu_step][0]:
		menu_step += 1
		if menu_step == MENU_STEPS.size(): menu_step = -1
	if id == "shop.buy": bought_here = true
