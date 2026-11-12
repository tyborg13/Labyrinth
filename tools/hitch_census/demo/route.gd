extends RefCounted
const Gate = preload("res://tools/hitch_census/demo/gate.gd")
const Joy = preload("res://tools/hitch_census/demo/joypad.gd")
const Nav = preload("res://scripts/controller_navigation.gd")
const Bot = preload("res://tools/bot_policy.gd")
const Choices = preload("res://tools/run_curve_choices.gd")
const RoutePolicy = preload("res://tools/hitch_census/demo/route_policy.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Guide = preload("res://scripts/contextual_combat_tutorial.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const READ_S: float = 4.0
const CARD_READ_S: float = 1.0
const CARD_STEP_LIMIT: int = 32
const CHARACTER_TAB_LIMIT: int = 8
const SHORT_WAIT_S: float = 0.1
const READY_SETTLE_S: float = 0.05
const APPROACH_SPEED_PX_S: float = 600.0
const FOCUS_LIMIT: int = 128
const APPROACH_LIMIT: int = 240
const APPROACH_TOLERANCE_PX: float = 8.0
const EDGES: Array = [[SIDE_LEFT, JOY_BUTTON_DPAD_LEFT, Vector2.LEFT], [SIDE_RIGHT, JOY_BUTTON_DPAD_RIGHT, Vector2.RIGHT], [SIDE_TOP, JOY_BUTTON_DPAD_UP, Vector2.UP], [SIDE_BOTTOM, JOY_BUTTON_DPAD_DOWN, Vector2.DOWN]]
var s
var pad
var bot = Bot.new()
var inputs: Dictionary
var scene: Node
var map_seen: bool = false
var phase_read: String
var decision_serial: int = 0
var pending_plan: Dictionary
var targets: Array
var target_index: int = 0
var seen_rooms: Dictionary
var planned_dest: Vector2i = Vector2i(-999, -999)
var returning: bool = false
var teaser_done: bool = false
var teaser_pending: bool = false
var purge_pick: String = ""
var merchant_plans: Dictionary
func _init(owner_session) -> void:
	s = owner_session
	pad = Joy.new(s)
	inputs = pad.counts
func run() -> void:
	await wait_ready()
	await pad.pulse(Vector2.DOWN)
	await s.mark("title")
	var settings: Dictionary = preload("res://scripts/settings_store.gd").load_settings()
	var family: String = s.root.get_node("InputRouter").controller_family()
	s.log_event("deck_configuration", {"physical_size": str(s.root.size), "logical_size": str(s.root.get_visible_rect().size), "window_ui_scale": s.root.content_scale_factor, "family": family, "joy_name": Input.get_joy_name(0), "joy_info": Input.get_joy_info(0), "modality": s.root.get_node("InputRouter").modality(), "deck_env": OS.get_environment("SteamDeck"), "settings": settings})
	if s.input_gate.accepted != int(inputs["joypad_button"]) + int(inputs["joypad_motion"]): s.fail("Proof input gate order mismatch at title"); return
	if family != "steam_deck" or str(settings["edge_smoothing"]) != "off" or not is_equal_approx(float(settings["ui_scale"]), 1.15): s.fail("Deck configuration mismatch"); return
	await s.hold(READ_S)
	await control(scene.get("start_button"))
	await pad.button(JOY_BUTTON_A)
	while s.failure.is_empty():
		await wait_ready()
		scene = s.current_scene
		if returning and scene.scene_file_path.ends_with("main_menu.tscn"):
			if not teaser_done: s.fail("Keystone teaser not inspected"); return
			await s.mark("title_return")
			await s.hold(READ_S)
			var required: Array = ["title", "guided_complete", "section_map", "fight", "event", "reward", "dragon", "demo_boundary", "demo_end", "links_focused", "keystone_teaser", "title_return"]
			for id: String in required:
				if not s.milestones.has(id): s.fail("Missing milestone: " + id); return
			var steps: Array = Guide.completed_steps(preload("res://scripts/progression_store.gd").load_data())
			for step: String in Guide.MILESTONE_ORDER:
				if not steps.has(step): s.fail("Missing guided lesson: " + step); return
			s.finish(true)
			return
		if scene.get("_run_state") == null:
			await s.hold(SHORT_WAIT_S)
			continue
		var state: Dictionary = scene.get("_run_state")
		if visible(scene.get("_run_end_recap")):
			await ending()
			continue
		if bool(scene.get("_dialogue_active")):
			await s.hold(READ_S)
			await pad.button(JOY_BUTTON_A)
			continue
		var phase: String = str(scene.get("_guided_tutorial_phase_id"))
		if not phase.is_empty() and bool(scene.call("_guided_tutorial_is_active")):
			if await tutorial(phase): continue
		if visible(scene.get("_pre_battle_scrim")):
			if await equip_drops(state): continue
			var room: Dictionary = scene.get("_run_engine").room_metadata(state, state["current_room"])
			if str(room.get("type")) == "boss": await s.mark("dragon")
			await s.hold(READ_S)
			var buttons: Array[Control] = controls(scene.get("_pre_battle_scrim"))
			var start: Control = match_text(buttons, ["start", "begin", "fight", "enter"])
			if start == null: dump("pre_battle", buttons); s.fail("Pre-battle start button absent"); return
			await control(start)
			await pad.button(JOY_BUTTON_A)
			continue
		var scope: Control = scene.call("_controller_focus_scope")
		if str(state.get("mode")) == "room" and bool(scene.call("_controller_custom_room_available")):
			if teaser_pending and not teaser_done: await inspect_teaser()
			elif not map_seen and not Guide.is_active(scene.get("_progression")): await show_map()
			elif not await equip_drops(state): await travel(state)
			continue
		if scope != scene.get("ui_root"):
			await modal(scope, state)
			continue
		match str(state.get("mode", "")):
			"combat":
				await s.mark("fight")
				await combat()
			"reward": await reward(state)
			"room":
				if teaser_pending and not teaser_done:
					await inspect_teaser()
					continue
				if not map_seen and not Guide.is_active(scene.get("_progression")):
					await show_map()
				else:
					if not await equip_drops(state): await travel(state)
			_:
				s.log_event("route_wait", {"mode": state.get("mode")})
				await s.hold(SHORT_WAIT_S)

func wait_ready() -> void:
	var ready_started_us: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - ready_started_us < int(Gate.READY_TIMEOUT_S * 1000000):
		scene = s.current_scene
		if Gate.ready(scene):
			await s.hold(READY_SETTLE_S)
			if scene == s.current_scene and Gate.ready(scene): return
		await s.process_frame
	s.fail("Scene readiness timeout")

func visible(node: Variant) -> bool:
	return is_instance_valid(node) and node is Control and node.is_visible_in_tree()
func controls(scope: Node) -> Array[Control]:
	var result: Array[Control]
	collect(scope, result)
	return result
func collect(node: Node, result: Array[Control]) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is BaseButton and not node.disabled and node.focus_mode != Control.FOCUS_NONE: result.append(node)
	elif node is Control and node.focus_mode == Control.FOCUS_ALL: result.append(node)
	for child: Node in node.get_children(): collect(child, result)
func match_text(buttons: Array[Control], prefixes: Array) -> Control:
	for prefix: String in prefixes:
		for button: Control in buttons:
			if button is Button and button.text.strip_edges().to_lower().begins_with(prefix): return button
	return null
func dump(label: String, buttons: Array[Control]) -> void:
	var values: Array
	for button: Control in buttons: values.append({"path": str(button.get_path()), "text": button.get("text")})
	s.log_event("controls", {"label": label, "controls": values})
	print("UX09 CONTROLS: ", label, " ", values)

func control(target: Control) -> bool:
	if not is_instance_valid(target): s.fail("Control target absent"); return false
	for step: int in range(FOCUS_LIMIT):
		if not is_instance_valid(target) or not target.is_visible_in_tree(): return false
		var current: Control = s.root.gui_get_focus_owner()
		if scene.get("_run_state") != null and bool(scene.call("_controller_custom_navigation_available")):
			var custom: Dictionary = scene.call("_controller_candidate_for_control", target)
			if not custom.is_empty(): return await candidate_focus(str(custom["key"]))
		if current == target:
			pad.arm_accept()
			s.log_event("focus_destination", {"path": str(target.get_path()), "rect": str(target.get_global_rect())})
			return true
		var path: Array = gui_path(current, target)
		if path.is_empty():
			if scene.get("_run_state") != null and bool(scene.call("_controller_custom_navigation_available")):
				var candidate: Dictionary = scene.call("_controller_candidate_for_control", target)
				if not candidate.is_empty(): return await candidate_focus(str(candidate["key"]))
			await pad.button(JOY_BUTTON_DPAD_DOWN)
		else: await pad.button(int(path[0]))
	s.fail("Controller cannot focus " + str(target.get_path()))
	return false
func gui_path(start: Control, target: Control) -> Array:
	if start == null: return []
	var queue: Array[Control]
	queue.append(start)
	var paths: Dictionary = {start.get_instance_id(): []}
	while not queue.is_empty():
		var current: Control = queue.pop_front()
		for edge: Array in EDGES:
			var next: Control = current.find_valid_focus_neighbor(edge[0])
			if next == null or paths.has(next.get_instance_id()): continue
			var path: Array = paths[current.get_instance_id()].duplicate()
			path.append(edge[1])
			if next == target: return path
			paths[next.get_instance_id()] = path
			queue.append(next)
	return []
func board(tile: Vector2i) -> bool:
	if str(scene.get("_controller_region")) == "hand": await pad.button(JOY_BUTTON_DPAD_UP)
	return await candidate_focus("tile:%d:%d" % [tile.x, tile.y])
func candidate_focus(key: String) -> bool:
	var expected: Dictionary = Gate.witness(scene)
	for step: int in range(APPROACH_LIMIT):
		if not is_instance_valid(scene) or scene != s.current_scene or expected != Gate.witness(scene): return false
		var current: Dictionary = scene.get("_controller_focus_candidate")
		if str(current.get("key")) == key:
			pad.arm_accept()
			s.log_event("candidate_destination", {"key": key, "point": str(current.get("point")), "witness": expected})
			return true
		var candidates: Array[Dictionary] = scene.call("_controller_navigation_candidates")
		var target: Dictionary
		for candidate: Dictionary in candidates:
			if str(candidate.get("key")) == key: target = candidate; break
		if target.is_empty(): s.fail("Rendered controller candidate absent: " + key); return false
		# Read-only model of the real directional navigation. Inputs remain joypad.
		var path: Array = candidate_path(current, target, candidates)
		if not path.is_empty(): await pad.button(int(path[0])); continue
		var origin: Vector2 = scene.get("_controller_virtual_board_position")
		if not is_finite(origin.x): origin = s.root.get_visible_rect().size * 0.5
		var delta: Vector2 = target["point"] - origin
		await pad.pulse(delta.normalized(), minf(0.08, maxf(1.0 / 60.0, delta.length() / APPROACH_SPEED_PX_S)))
	s.fail("Controller cannot reach candidate: " + key)
	return false
func candidate_path(start: Dictionary, target: Dictionary, candidates: Array[Dictionary]) -> Array:
	if start.is_empty(): return []
	var queue: Array[Dictionary]
	queue.append(start)
	var paths: Dictionary = {str(start["key"]): []}
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		for edge: Array in EDGES:
			var next: Dictionary = Nav.best_candidate_in_direction(current["point"], edge[2], candidates, str(current["key"]))
			if next.is_empty() or paths.has(str(next["key"])): continue
			var path: Array = paths[str(current["key"])].duplicate()
			path.append(edge[1])
			if str(next["key"]) == str(target["key"]): return path
			paths[str(next["key"])] = path
			queue.append(next)
	return []

func tutorial(phase: String) -> bool:
	if phase_read != phase:
		phase_read = phase
		s.log_event("lesson_read", {"phase": phase})
		await s.hold(READ_S)
		if phase != str(scene.get("_guided_tutorial_phase_id")): return true
	if phase in ["choose_reward", "choose_path"]: return false
	if phase == "cancel_card_preview":
		await pad.button(JOY_BUTTON_B)
	elif phase == "pass_turn":
		await pad.button(JOY_BUTTON_Y)
	elif phase == "inspect_enemy":
		var tiles: Array[Vector2i] = scene.call("_guided_tutorial_allowed_board_tiles")
		if not tiles.is_empty(): await board(tiles[0])
		await s.hold(SHORT_WAIT_S)
	else:
		if phase in ["select_player", "choose_move", "select_first_target", "select_kill_target", "finish_first_card", "finish_kill_card", "finish_refund_card"]:
			var allowed: Array[Vector2i] = scene.call("_guided_tutorial_allowed_board_tiles")
			if not allowed.is_empty():
				if not await board(allowed[0]): return true
		elif phase.begins_with("select_"):
			if str(scene.get("_controller_region")) != "hand": await pad.button(JOY_BUTTON_X)
		await pad.button(JOY_BUTTON_A)
		if phase == "complete" and not Guide.is_active(scene.get("_progression")):
			await s.mark("guided_complete")
	return true

func combat() -> void:
	var state: Dictionary = scene.get("_combat_state")
	var engine = scene.get("_combat_engine")
	var activation_turn: int = int(state.get("turn", 0))
	if not engine.is_player_turn(state): await s.hold(SHORT_WAIT_S); return
	if int(scene.get("_selected_card_index")) >= 0:
		await resolve_card()
		return
	pending_plan = _measured_bot("choose", state.duplicate(true))
	decision_serial += 1
	var snapshot_started: int = Time.get_ticks_usec()
	var snapshot := FileAccess.open(s.output.path_join("decision-%04d.bin" % decision_serial), FileAccess.WRITE)
	snapshot.store_var({"state": state, "plan": pending_plan}, false)
	snapshot.close()
	s.host.trace.record_driver_cost("bot_snapshot", snapshot_started)
	s.log_event("policy", {"turn": state.get("turn"), "card": pending_plan.get("card"), "pos": str(state["player"]["pos"]), "score": pending_plan.get("score"), "hp": state["player"]["hp"], "plays": engine.cards_remaining_this_turn(state), "snapshot": "decision-%04d.bin" % decision_serial})
	if pending_plan.is_empty():
		var dodge: Dictionary = _measured_bot("best_dodge", state.duplicate(true))
		var tile: Vector2i = dodge["state"]["player"]["pos"]
		if tile != state["player"]["pos"]:
			if not await move_player(tile): return
			await wait_ready()
			if str(scene.get("_run_state").get("mode")) != "combat" or int(scene.get("_combat_state").get("turn", 0)) != activation_turn:
				s.log_event("automatic_pass_observed", {"previous_turn": activation_turn})
				return
		await pad.button(JOY_BUTTON_Y)
		return
	var plan: Dictionary = pending_plan["commit"]
	var destination: Vector2i = plan["before"]["player"]["pos"]
	if destination != state["player"]["pos"]:
		if not await move_player(destination): return
		await wait_ready()
		if str(scene.get("_run_state").get("mode")) != "combat" or int(scene.get("_combat_state").get("turn", 0)) != activation_turn: return
	if str(scene.get("_controller_region")) != "hand": await pad.button(JOY_BUTTON_X)
	var index: int = int(plan["index"])
	var live_hand: Array = scene.get("_combat_state").get("deck", {}).get("hand", [])
	if index >= live_hand.size() or str(live_hand[index]) != str(pending_plan["card"]):
		s.log_event("stale_card_plan_cancelled", {"card": pending_plan["card"], "index": index})
		return
	for step: int in range(FOCUS_LIMIT):
		if int(scene.get("_controller_hand_index")) == index: break
		await pad.button(JOY_BUTTON_LEFT_SHOULDER)
	if int(scene.get("_controller_hand_index")) != index: s.fail("Policy card index not reachable in hand"); return
	await s.hold(CARD_READ_S)
	targets = plan["targets"].duplicate()
	await pad.button(JOY_BUTTON_A)
	if bool(scene.call("_controller_card_mode_active")):
		for step: int in range(CHARACTER_TAB_LIMIT):
			if str(scene.get("_controller_card_mode")) == "play": break
			await pad.button(JOY_BUTTON_RIGHT_SHOULDER)
		await pad.button(JOY_BUTTON_A)
	await resolve_card()

func move_player(tile: Vector2i) -> bool:
	var player: Vector2i = scene.get("_combat_state")["player"]["pos"]
	if not await board(player): return false
	if not await pad.button(JOY_BUTTON_A): return false
	await wait_ready()
	if not bool(scene.get("_player_movement_selected")): return false
	if not await board(tile): return false
	if not await pad.button(JOY_BUTTON_A): return false
	await wait_ready()
	if str(scene.get("_run_state").get("mode")) != "combat": return false
	var actual: Vector2i = scene.get("_combat_state")["player"]["pos"]
	s.log_event("movement_postcondition", {"requested": str(tile), "actual": str(actual), "matched": actual == tile})
	return actual == tile

func resolve_card() -> void:
	for step: int in range(CARD_STEP_LIMIT):
		await wait_ready()
		if int(scene.get("_selected_card_index")) < 0: return
		var tile: Vector2i = Vector2i(-1, -1)
		if bool(scene.call("_pending_card_requires_confirmation")):
			tile = scene.get("_preview_combat_state")["player"]["pos"]
		else:
			var actions: Array = scene.get("_pending_actions")
			var action_index: int = int(scene.get("_pending_action_index"))
			var ordinal: int = 0
			for index: int in range(mini(action_index, actions.size())):
				if scene.get("_combat_engine").player_action_needs_target(actions[index]) and not (str(actions[index].get("type")) == "aoe" and int(actions[index].get("range", 0)) <= 0): ordinal += 1
			if ordinal < targets.size(): tile = targets[ordinal]
			var offered: Array[Vector2i] = scene.call("_controller_board_tiles")
			if action_index < actions.size() and str(actions[action_index].get("type")) in ["move", "blink"] and ordinal + 1 < targets.size():
				var strike: Vector2i = targets[ordinal + 1]
				var preview: Dictionary = scene.call("_active_card_preview")
				var shortcut: Dictionary = scene.call("_shortcut_plan_for_tile", preview, strike, false)
				if not shortcut.is_empty() and offered.has(strike):
					# Hover entry authors the existing approach preference. Clicking
					# the move tile would deliberately omit the required follow-up.
					if offered.has(tile):
						if not await board(tile): return
					if not await board(strike): return
					var live_shortcut: Dictionary = scene.call("_shortcut_plan_for_tile", scene.call("_active_card_preview"), strike)
					s.log_event("move_strike_request", {"target": str(strike), "planned_move": str(tile), "actual_approach": str(live_shortcut.get("move_target"))})
					await pad.button(JOY_BUTTON_A)
					continue
			if not offered.has(tile):
				if not offered.is_empty():
					s.log_event("policy_target_fallback", {"planned": str(tile), "offered": str(offered), "action_index": action_index})
					tile = offered[0]
				else:
					var skip: Control = match_text(controls(scene.get("ui_root")), ["skip", "confirm", "resolve"])
					if skip != null: await control(skip); await pad.button(JOY_BUTTON_A); continue
					s.fail("Selected card has no offered controller step"); return
		if not await board(tile): return
		await pad.button(JOY_BUTTON_A)
	s.fail("Card resolution exceeded guard")

func reward(state: Dictionary) -> void:
	await s.mark("reward")
	await s.hold(READ_S)
	var buttons: Array[Control] = controls(scene.get("ui_root"))
	var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/hitch_census/demo/card-scores.json"))
	var choices = Choices.new(scene.get("_run_engine"), scores, "best", s.proof_seed, true)
	var pick: String = choices.card(state.get("pending_reward", {}).get("cards", []))
	var target: Control
	for button: Control in buttons:
		if not pick.is_empty() and str(button.get("card_id")) == pick: target = button; break
	if scene.get("_run_engine").is_dragon_reward(state): target = scene.find_child("DragonRewardContinue", true, false) as Control
	if target == null: target = match_text(buttons, ["complete ascent", "continue", "take", "claim", "skip"])
	s.log_event("ladder_reward_choice", {"id": pick})
	if target == null:
		if not buttons.is_empty(): target = buttons[0]
	if target == null: dump("reward", buttons); s.fail("Reward has no control"); return
	await control(target)
	await pad.button(JOY_BUTTON_A)

func modal(scope: Control, state: Dictionary) -> void:
	var buttons: Array[Control] = controls(scope)
	if visible(scene.get("_large_map_scrim")):
		await s.mark("section_map")
		await s.hold(READ_S)
		await pad.button(JOY_BUTTON_B)
		map_seen = true
		return
	if visible(scene.get("_scavenger_shop_view")):
		await merchant(scene.get("_scavenger_shop_view"), state)
		return
	if visible(scene.get("_event_view")):
		await s.mark("event")
		await s.hold(READ_S)
		var choices = Choices.new(scene.get("_run_engine"), {}, "none", s.proof_seed, true)
		var choice_id: String = "continue" if str(state.get("event_state", {}).get("page")) == "result" else choices.event_choice(state.duplicate(true))
		s.log_event("ladder_event_choice", {"id": choice_id})
		var desired: Control
		for button: Control in buttons:
			if str(button.get("choice_id")) == choice_id: desired = button
		if desired == null: desired = match_text(buttons, ["continue", "leave"])
		if desired == null and not buttons.is_empty(): desired = buttons[0]
		if desired == null: dump("event", buttons); s.fail("Event has no controller choice"); return
		await control(desired)
		await pad.button(JOY_BUTTON_A)
		return
	if str(state.get("mode")) == "reward": await reward(state); return
	if is_instance_valid(scene.get("_magic_purge_overlay")):
		await purge(scope)
		return
	if str(state.get("mode")) == "campfire":
		await hearth(scope, state)
		return
	await s.hold(READ_S)
	var target: Control = match_text(buttons, ["leave", "continue", "take", "claim", "begin", "return", "close"])
	if target == null and not buttons.is_empty(): target = buttons[0]
	if target == null: dump("modal", buttons); s.fail("Modal has no controller route"); return
	await control(target)
	await pad.button(JOY_BUTTON_A)

func show_map() -> void:
	var target: Control = match_text(controls(scene.get("ui_root")), ["map"])
	if target == null: s.fail("Map toolbar button absent"); return
	await control(target)
	await pad.button(JOY_BUTTON_A)
	await wait_ready()
	if not visible(scene.get("_large_map_scrim")): s.fail("Controller Map action did not open map"); return
	await s.mark("section_map")
	await s.hold(READ_S)
	await pad.button(JOY_BUTTON_B)
	map_seen = true

func route_score(state: Dictionary, coord: Vector2i) -> float:
	var started: int = Time.get_ticks_usec()
	var result: float = RoutePolicy.score(state, coord, not s.milestones.has("event"))
	s.host.trace.record_driver_cost("route_policy", started)
	return result

func travel(state: Dictionary) -> void:
	var engine = scene.get("_run_engine")
	var options: Array[Vector2i] = engine.available_moves(state)
	if options.is_empty(): await s.hold(SHORT_WAIT_S); return
	var best: Vector2i = options[0]
	var score: float = -INF
	for destination: Vector2i in options:
		var value: float = route_score(state, destination)
		if value > score: best = destination; score = value
	s.log_event("route_choice", {"current": str(state["current_room"]), "destination": str(best), "type": engine.room_metadata(state, best).get("type"), "score": score})
	var doors: Dictionary = scene.get("_exit_destinations_by_tile")
	for tile: Vector2i in doors:
		if doors[tile] != best: continue
		var candidate: Dictionary = scene.call("_controller_candidate_for_tile", tile)
		if not await candidate_focus(str(candidate.get("key"))): return
		await s.hold(READ_S)
		var expected: Vector2i = state["current_room"]
		await pad.button(JOY_BUTTON_A)
		var deadline: int = Engine.get_process_frames() + int(Gate.READY_TIMEOUT_S * 60)
		while Engine.get_process_frames() < deadline:
			if scene.get("_run_state").get("current_room") != expected or visible(scene.get("_run_end_recap")):
				s.log_event("route_travel_committed", {"destination": str(best)})
				return
			await s.process_frame
		s.fail("Door action never committed destination " + str(best))
		return
	dump("room", controls(scene.get("ui_root")))
	s.fail("Legal destination has no rendered door")

func ending() -> void:
	var recap = scene.get("_run_end_recap")
	var panel = recap.get("_demo_panel")
	if panel == null or str(panel.get("kind")) != "full": s.fail("Run ended without full demo clear"); return
	while float(recap.get("_elapsed")) < float(recap.call("presentation_duration")):
		await s.process_frame
	await s.mark("demo_boundary")
	await s.mark("demo_end")
	await s.hold(READ_S)
	var links: Array[Button]
	links.assign(panel.get("links"))
	links.push_front(panel.get("wishlist_plate"))
	for link: Button in links:
		if not await control(link): return
		await s.hold(READ_S)
		s.log_event("end_link_focus", {"name": str(link.name), "text": link.text})
		var requests_before: int = s.external_request_count
		await pad.button(JOY_BUTTON_A)
		await s.hold(SHORT_WAIT_S)
		if s.external_request_count != requests_before + 1: s.fail("End link did not emit exactly one intercepted request: " + str(link.name)); return
	s.log_event("end_link_inventory", {"offered": links.size(), "feedback_url_empty": str(preload("res://scripts/demo_rules.gd").config()["feedback_url"]).is_empty()})
	await s.mark("links_focused")
	await control(recap.get("_new_run_button"))
	s.log_event("teaser_route", {"fact": "Keystone teaser is in Skills, not recap; Rise Again uses existing next-run Character/Skills path before returning to title."})
	await pad.button(JOY_BUTTON_A)
	teaser_pending = true

func inspect_teaser() -> void:
	await control(scene.get("loadout_button"))
	await pad.button(JOY_BUTTON_A)
	await s.hold(READ_S)
	for step: int in range(CHARACTER_TAB_LIMIT):
		if str(scene.get("_progression_overlay_mode")) == "skills": break
		await pad.button(JOY_BUTTON_RIGHT_SHOULDER)
	var tree = scene.get("_skill_tree_view")
	if tree == null or not tree.is_visible_in_tree(): s.fail("Skills tree not visible through Character"); return
	for id: String in Skills.visible_ids():
		if not Skills.is_keystone(id): continue
		var button: Button = tree.node_for_skill(id)
		if not await control(button): return
		await s.hold(READ_S)
		s.log_event("keystone_focus", {"id": id, "focused": tree.focused_skill_id(), "demo_locked": Skills.is_demo_locked(id)})
	await s.mark("keystone_teaser")
	teaser_done = true
	await pad.button(JOY_BUTTON_B)
	await control(scene.get("menu_button"))
	await pad.button(JOY_BUTTON_A)
	await s.hold(READ_S)
	var scope: Control = scene.call("_controller_focus_scope")
	var buttons: Array[Control] = controls(scope)
	dump("return-menu", buttons)
	var back: Control = match_text(buttons, ["main menu", "title", "return", "save and quit", "save & quit", "quit to"])
	if back == null: s.fail("Menu return-to-title control absent"); return
	await control(back)
	await pad.button(JOY_BUTTON_A)
	returning = true

func hearth(scope: Control, state: Dictionary) -> void:
	var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/hitch_census/demo/card-scores.json"))
	var choices = Choices.new(scene.get("_run_engine"), scores, "best", s.proof_seed, true)
	var preview: Dictionary = choices.hearth(state.duplicate(true))
	purge_pick = str(preview.get("last_magic_purge", {}).get("card_id", ""))
	var choice_id: String = "purge" if int(preview.get("magic_purges_this_run", 0)) > int(state.get("magic_purges_this_run", 0)) else "linger"
	s.log_event("ladder_hearth_choice", {"choice": choice_id, "card": purge_pick})
	await s.hold(READ_S)
	for target: Control in controls(scope):
		if str(target.get_meta("choice_id", "")) == choice_id:
			await control(target)
			await pad.button(JOY_BUTTON_A)
			return
	s.fail("Ladder Hearth choice has no controller target")

func purge(scope: Control) -> void:
	var overlay = scene.get("_magic_purge_overlay")
	if str(overlay.get("pending_card_id")).is_empty():
		for target: Control in controls(scope):
			if str(target.get("card_id")) == purge_pick:
				await control(target)
				await s.hold(READ_S)
				await pad.button(JOY_BUTTON_A)
				return
		s.fail("Ladder purge card not offered")
		return
	await control(overlay.get("_confirm"))
	await s.hold(READ_S)
	await pad.button(JOY_BUTTON_A)

func equip_drops(state: Dictionary) -> bool:
	if Guide.is_active(scene.get("_progression")) or not scene.get("_run_engine").can_change_equipment(state): return false
	var choices = Choices.new(scene.get("_run_engine"), {}, "none", s.proof_seed, true)
	var predicted: Dictionary = choices.equip_drops(state.duplicate(true))
	var wanted: Dictionary = predicted.get("equipped_equipment", {})
	var current: Dictionary = state.get("equipped_equipment", {})
	var pick: String = ""
	for slot: String in wanted:
		if str(wanted[slot]) != str(current.get(slot, "")): pick = str(wanted[slot]); break
	if pick.is_empty(): return false
	var opening: Control = scene.get("loadout_button")
	if visible(scene.get("_pre_battle_scrim")): opening = match_text(controls(scene.get("_pre_battle_scrim")), ["equip"])
	if not await control(opening): return true
	await pad.button(JOY_BUTTON_A)
	await wait_ready()
	for step: int in range(CHARACTER_TAB_LIMIT):
		if str(scene.get("_progression_overlay_mode")) == "equipment": break
		await pad.button(JOY_BUTTON_RIGHT_SHOULDER)
	var tile: Control = scene.get("_equipment_inventory_tiles").get(pick)
	if not await control(tile): return true
	await s.hold(CARD_READ_S)
	var equip: Control = match_text(controls(tile), ["equip"])
	if equip == null: s.fail("Inventory equipment action absent"); return true
	await control(equip)
	await pad.button(JOY_BUTTON_A)
	await wait_ready()
	s.log_event("ladder_equip", {"id": pick, "actual": scene.get("_run_state").get("equipped_equipment")})
	await pad.button(JOY_BUTTON_B)
	return true

func merchant(shop: Control, state: Dictionary) -> void:
	var room_key: String = str(state["current_room"])
	var engine = scene.get("_run_engine")
	var kind: String = engine.merchant_kind_for_current_room(state)
	if not merchant_plans.has(room_key):
		var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/hitch_census/demo/card-scores.json"))
		var choices = Choices.new(engine, scores, "best", s.proof_seed, true)
		var predicted: Dictionary = choices.merchant(state.duplicate(true))
		var picks: Array[String]
		for field: String in ["attuned_magic_cards", "equipment_inventory"]:
			var previous: Array = state.get(field, []).duplicate()
			for id: String in predicted.get(field, []):
				if previous.has(id): previous.erase(id)
				else: picks.append(id)
		merchant_plans[room_key] = picks
	var planned: Array = merchant_plans[room_key]
	if planned.is_empty():
		await control(shop.get("_leave_button"))
		await pad.button(JOY_BUTTON_A)
		return
	var pick: String = str(planned[0])
	var source: Control = shop.get("_offer_sources").get("buy:" + pick)
	if source == null: s.fail("Ladder merchant offer absent: " + pick); return
	await control(source)
	await s.hold(CARD_READ_S)
	await pad.button(JOY_BUTTON_A)
	await control(shop.get("_detail_action"))
	await s.hold(READ_S)
	await pad.button(JOY_BUTTON_A)
	await wait_ready()
	s.log_event("ladder_purchase", {"id": pick, "kind": kind})
	planned.pop_front()

func _measured_bot(method: String, state: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = bot.call(method, state)
	s.host.trace.record_driver_cost("bot_" + method, started)
	return result
