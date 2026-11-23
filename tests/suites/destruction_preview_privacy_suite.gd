extends RefCounted

const Run = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Forecast = preload("res://scripts/pass_forecast_action_source.gd")
const RedTiles = preload("res://scripts/pass_forecast_red_tiles.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")

# Review reproductions use production cards/relics with proof-only fixture data.
const ENEMY_START := Vector2i(3, 3)
const HIDDEN_TRAP_TILE := Vector2i(5, 3)
const GALE_DESTINATION := Vector2i(6, 3)
const WALL_DESTINATION := Vector2i(8, 3)
const ILLUSION_COLLISION_DESTINATION := Vector2i(7, 3)
const ILLUSION_START := Vector2i(4, 3)
const CONCEALED_ILLUSION_TILE := Vector2i(8, 6)
const ENEMY_HP: int = 100
const HIDDEN_TRAP_DAMAGE: int = 1000
const ILLUSION_HP: int = 2
const WAIT_ACTION: Dictionary = {"type": "move", "range": 1}
const SKIPPED_ACTION: Dictionary = {"type": "ranged", "damage": 1, "range": 1, "optional": true}
const INVALID_TARGET := Vector2i(-1000, -1000)
const CONCEALED_CONTACT := Vector2i(5, 3)
const HERO_AT_CONTACT := Vector2i(3, 3)
const ENEMY_ATTACKER := Vector2i(2, 3)
const WALK_PUSH_HEALTH: int = 8
const WALK_PUSH_DAMAGE: int = 6
const PREVIEW_PUSH: Dictionary = {"type": "push", "amount": 3, "damage": 3, "range": 3}
const PREVIEW_PULL: Dictionary = {"type": "pull", "amount": 3, "damage": 3, "range": 3, "force_direction": Vector2i.RIGHT, "_allow_sideways_force": true}
const AREA_PULL: Dictionary = {"type": "force_area", "center": "self", "radius": 3, "pull": 3, "expose": 1}
const WALK_FIRE_TRAP := Vector2i(4, 3)
const WALK_DISTANT_TRAP := Vector2i(8, 7)
const WALK_TRADE_TARGET := Vector2i(3, 3)
const WALK_TRAP_DAMAGE: int = 12
const WALK_LIGHT_RADIUS: int = 0
const CHAIN_WALK_ORIGIN := Vector2i(4, 1)
const CHAIN_WALK_LANDING := Vector2i(3, 3)
const CHAIN_PUSH_TRAP := Vector2i(5, 3)
const CHAIN_ENEMY_FOOTPRINT := Vector2i(2, 1)
const CHAIN_INTERMEDIATE_TRAPS: Array[Vector2i] = Array([Vector2i(7, 3), Vector2i(7, 5), Vector2i(5, 5)], TYPE_VECTOR2I, "", null)
const CHAIN_ENEMY_STARTS: Array[Vector2i] = Array([CHAIN_PUSH_TRAP, Vector2i(7, 4), Vector2i(6, 5), Vector2i(5, 4)], TYPE_VECTOR2I, "", null)

static func run(expect: Callable) -> void:
	_test_hidden_cause_retention(expect)
	_test_hover_contacts(expect)
	_test_concealed_mover(expect)
	_test_announced_enemy_force(expect)
	_test_illusion_destination_sight(expect)
	_test_concealed_illusion_losses(expect)
	_test_walk_forecast_privacy(expect)
	_test_walk_concealed_push(expect)

static func _test_walk_forecast_privacy(expect: Callable) -> void:
	var engine := Combat.new()
	var before: Dictionary = _fixture()
	before["umbra"]["stage"] = "eclipse"
	before["enemies"][0]["pos"] = WALK_DISTANT_TRAP + Vector2i.UP
	before["traps"] = [{"id": "walk_fire", "pos": WALK_FIRE_TRAP, "element": "fire", "damage": WALK_TRAP_DAMAGE}]
	var available: Array[Vector2i] = engine.player_movement_targets(before)
	expect.call(available.has(WALK_FIRE_TRAP) and not engine.is_tile_visible_to_player(before, WALK_FIRE_TRAP), "Review walk target is legal and its Fire trap is concealed")
	var without_air: Dictionary = _walk_forecast(before, WALK_FIRE_TRAP, true)
	before["traps"].append({"id": "distant_air", "pos": WALK_DISTANT_TRAP, "element": "air", "damage": WALK_TRAP_DAMAGE})
	var with_air: Dictionary = _walk_forecast(before, WALK_FIRE_TRAP, true)
	expect.call(without_air.get("hp_loss") == 0 and with_air.get("hp_loss") == 0 and with_air == without_air,
		"Distant Air trap leaves the Eclipse walk forecast identical and at 0 Health loss (without %s, with %s)" % [without_air.get("hp_loss"), with_air.get("hp_loss")])
	before["traps"] = [{"id": "air_without_push", "pos": WALK_FIRE_TRAP, "element": "air", "damage": WALK_TRAP_DAMAGE}]
	var isolated_air: Dictionary = _walk_forecast(before, WALK_FIRE_TRAP, true)
	expect.call(isolated_air == without_air, "A concealed Air trap with no actor in its wake leaves the walk forecast undisclosed")

	# Glassway lets the illusion trip the Air trap at the old hero tile. Its
	# wake pushes the hero onto the second trap before the walk finishes.
	before["relics"] = ["glassway_compass"]
	before["illusions"] = [{"id": 1, "pos": WALK_TRADE_TARGET, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}]
	for lighting: String in ["eclipse", "lit eclipse", "clear"]:
		before["umbra"]["stage"] = "clear" if lighting == "clear" else "eclipse"
		before["umbra"]["light_sources"] = []
		if lighting == "lit eclipse":
			before["umbra"]["light_sources"].append({"pos": WALK_FIRE_TRAP, "radius": WALK_LIGHT_RADIUS})
		var visible: bool = engine.is_tile_visible_to_player(before, WALK_FIRE_TRAP)
		expect.call(visible == (lighting != "eclipse"), lighting + " fixture sets the landing trap's decision-time visibility")
		for element: String in ["fire", "air"]:
			before["traps"] = [
				{"id": "trade_air", "pos": before["player"]["pos"], "element": "air", "damage": 0},
				{"id": "landing_trap", "pos": WALK_FIRE_TRAP, "element": element, "damage": WALK_TRAP_DAMAGE},
			]
			var actual: Dictionary = engine.apply_player_movement(before, WALK_TRADE_TARGET)
			var damage: int = WALK_TRAP_DAMAGE + (Ground.FIRE_ENTRY_DAMAGE if element == "fire" else 0)
			var disclosed_loss: int = damage if visible else 0
			var forecast: Dictionary = _walk_forecast(before, WALK_TRADE_TARGET)
			var label: String = "%s %s landing trap" % [lighting, element]
			expect.call(actual["player"]["pos"] == WALK_FIRE_TRAP and int(before["player"]["hp"]) - int(actual["player"]["hp"]) == damage, label + " fixture pushes the hero and takes damage")
			expect.call(forecast.get("pos") == WALK_FIRE_TRAP and forecast.get("hp_loss") == disclosed_loss,
				label + " forecasts the push and %d visible Health loss (got %s)" % [disclosed_loss, forecast])
			expect.call(forecast.get("board_hp_loss") == disclosed_loss, label + " board preview discloses the same Health loss")

static func _test_walk_concealed_push(expect: Callable) -> void:
	var engine := Combat.new()
	var before: Dictionary = _fixture()
	before["player"]["pos"] = CHAIN_WALK_ORIGIN
	before["umbra"]["stage"] = "eclipse"
	before["enemies"] = []
	for tile: Vector2i in CHAIN_ENEMY_STARTS:
		before["enemies"].append(Base.enemy(before["enemies"].size() + 1, tile))
	before["enemies"][0]["footprint"] = CHAIN_ENEMY_FOOTPRINT
	# The first wake pushes a wide enemy three tiles from the trap centre.
	# The subsequent wakes wrap around, so the last trap pushes the hero.
	var centers: Array[Vector2i]
	centers.append(WALK_FIRE_TRAP)
	centers.append_array(CHAIN_INTERMEDIATE_TRAPS)
	centers.append(CHAIN_PUSH_TRAP)
	for tile: Vector2i in centers:
		before["traps"].append({"id": str(tile), "pos": tile, "element": "air", "damage": WALK_TRAP_DAMAGE})
	Ground.place(before, CHAIN_WALK_LANDING, "fire")
	var original: Dictionary = before.duplicate(true)
	var actual: Dictionary = engine.apply_player_movement(before, WALK_FIRE_TRAP)
	var forecast: Dictionary = _walk_forecast(before, WALK_FIRE_TRAP)
	expect.call(not engine.is_tile_visible_to_player(before, CHAIN_PUSH_TRAP) and not engine.is_tile_visible_to_player(before, CHAIN_WALK_LANDING), "Last Air trap and Fire ground are concealed before the walk")
	expect.call(actual["player"]["pos"] == CHAIN_WALK_LANDING and int(actual["player"]["hp"]) < int(before["player"]["hp"]), "A concealed Air trap at the end of the chain really pushes the hero onto Fire")
	expect.call(forecast.get("pos") == CHAIN_WALK_LANDING and forecast.get("hp_loss") == 0 and forecast.get("board_hp_loss") == 0,
		"A concealed Air trap still forecasts its resolved push, with 0 hidden trap or ground damage (got %s)" % forecast)
	expect.call(before == original, "Walk preview leaves the committed snapshot intact")

static func _walk_forecast(before: Dictionary, target: Vector2i, include_enemy_phase: bool = false) -> Dictionary:
	var scene := Run.new()
	_arm_walk(scene, before, target)
	var source: Dictionary = scene.call("_build_pass_preview_source_state_for_tile", target, false)
	var summary: Dictionary = scene.call("_pass_preview_summary") if include_enemy_phase else scene.call("_pass_preview_summary_for_phase_result", source, {"state": source})
	var board: Dictionary = {}
	scene.call("_append_surface_action_preview", board, scene.call("_active_card_preview"))
	var result: Dictionary = {"pos": source.get("player", {}).get("pos"), "hp_loss": summary.get("hp_loss"),
		"board_hp_loss": board.get("damage_preview", {}).get("player", {}).get("hp_loss", 0)}
	if include_enemy_phase: result["summary"] = summary
	scene.free()
	return result

static func _arm_walk(scene: Node, before: Dictionary, target: Vector2i) -> void:
	var engine: RefCounted = scene.get("_combat_engine")
	scene.set("_combat_state", before)
	scene.set("_hovered_board_tile", target)
	scene.set("_player_movement_selected", true)
	scene.set("_player_movement_action", engine.player_movement_action(before))
	scene.set("_player_movement_target_tiles", engine.player_movement_targets(before))

static func _test_hidden_cause_retention(expect: Callable) -> void:
	for mode: String in ["confirmation", "automatic_prefix", "selected_prefix", "skipped_prefix"]:
		for hidden_trap: bool in [false, true]:
			var scene := Run.new()
			var engine := Combat.new()
			var before: Dictionary = _fixture()
			if hidden_trap:
				before["traps"] = [{"id": "concealed_lethal", "pos": HIDDEN_TRAP_TILE, "element": "fire", "damage": HIDDEN_TRAP_DAMAGE}]
			expect.call(not engine.is_tile_visible_to_player(before, HIDDEN_TRAP_TILE), mode + " fixture conceals the lethal trap")
			var targeted: bool = mode in ["selected_prefix", "skipped_prefix"]
			var card_id: String = "skybreak_current" if targeted else "unsealed_gale"
			var hand: Array[String]
			hand.append(card_id)
			before["deck"]["hand"] = hand
			var actions: Array = engine.card_play_actions(card_id, before)
			var selected: Array[Vector2i]
			var actual: Dictionary = engine.prepare_player_card(before, 0)
			if mode == "skipped_prefix":
				actions.push_front(SKIPPED_ACTION)
				selected.append(INVALID_TARGET)
			if targeted:
				actual = engine.apply_player_action(actual, actions[-1], ENEMY_START)
				selected.append(ENEMY_START)
			else:
				actual = engine.apply_player_action(actual, actions[0])
			var resolved_count: int = actions.size()
			if mode != "confirmation": actions.append(WAIT_ACTION)
			_install(scene, before, actual, actions, resolved_count, selected)
			var committed_snapshot: Dictionary = before.duplicate(true)
			var actual_snapshot: Dictionary = actual.duplicate(true)
			var known: Dictionary = scene.call("_pending_card_known_forecast_state")
			var shown: Dictionary = scene.call("_board_display_state")
			var expected: Vector2i = WALL_DESTINATION if targeted else GALE_DESTINATION
			var landing: Vector2i = HIDDEN_TRAP_TILE if hidden_trap else expected
			expect.call(known["enemies"][0]["pos"] == landing and known["enemies"][0]["hp"] == actual["enemies"][0]["hp"], mode + " forecasts the resolved force and its concealed landing hazard")
			expect.call(shown["enemies"][0]["pos"] == (ENEMY_START if hidden_trap else landing), mode + " retains lethal bodies on the committed tile")
			var presentation: Dictionary = {}
			scene.call("_append_confirmation_force_preview", presentation)
			expect.call(presentation.get("trap_trigger_previews", []).is_empty(), mode + " omits the concealed trap marker")
			expect.call(before == committed_snapshot and actual == actual_snapshot, mode + " forecast/display leave committed and actual states unchanged")
			expect.call(is_same(shown, scene.call("_board_display_state")) and is_same(known, scene.call("_pending_card_known_forecast_state")), mode + " reuses unchanged display and known-forecast caches")
			if mode != "confirmation":
				expect.call((known["deck"]["hand"] as Array).has(card_id), mode + " does not pay for or finish an unresolved card")
			scene.free()

static func _test_hover_contacts(expect: Callable) -> void:
	var engine := Combat.new()
	for kind: String in ["wall", "wooden_crate", "outcrop", "enemy", "illusion", "fire", "air_trap"]:
		for action: Dictionary in [PREVIEW_PUSH, PREVIEW_PULL]:
			var scene := Run.new()
			var before: Dictionary = _fixture()
			match kind:
				"wall": before["grid"][CONCEALED_CONTACT.y][CONCEALED_CONTACT.x] = "wall"
				"wooden_crate", "outcrop":
					before["terrain"] = [{"id": kind, "kind": kind, "pos": CONCEALED_CONTACT, "hp": ENEMY_HP, "max_hp": ENEMY_HP}]
				"enemy": before["enemies"].append(Base.enemy(2, CONCEALED_CONTACT))
				"illusion": before["illusions"] = [{"id": 2, "pos": CONCEALED_CONTACT, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}]
				"fire": Ground.place(before, CONCEALED_CONTACT, "fire")
				"air_trap": before["traps"] = [{"id": kind, "pos": CONCEALED_CONTACT, "element": "air", "damage": HIDDEN_TRAP_DAMAGE}]
			var label: String = str(action["type"]) + " into " + kind
			expect.call(not engine.is_tile_visible_to_player(before, CONCEALED_CONTACT), label + ": contact is concealed")
			var actual: Dictionary = engine.apply_player_action(before, action, ENEMY_START)
			scene.set("_combat_state", before)
			scene.set("_hovered_board_tile", ENEMY_START)
			var result: Dictionary = {}
			scene.call("_append_surface_action_preview", result, {"state": before, "action": action, "target_tiles": [ENEMY_START], "actions": [action], "action_index": 0})
			var forecast: Dictionary = scene.get("_surface_preview_cache").get("state", {})
			expect.call(forecast["enemies"][0]["hp"] == actual["enemies"][0]["hp"] and forecast["enemies"][0]["pos"] == actual["enemies"][0]["pos"], label + ": hover matches resolved Health and anchor")
			var losses: Dictionary = result.get("damage_preview", {})
			var observed_hp: int = ENEMY_HP - int(losses.get("enemy_1", {}).get("hp_loss", 0))
			expect.call(observed_hp == int(actual["enemies"][0]["hp"]), label + ": board shows resolved damage")
			expect.call(not losses.has("enemy_2") and not losses.has("illusion_2") and not losses.has("terrain_" + kind) and not losses.has("trap_" + kind), label + ": board omits concealed actors and objects")
			var collisions: Array = engine._surface_events_since(before, actual).filter(func(event: Dictionary) -> bool: return event.get("kind") == "force_collision")
			var markers: Array = result.get("collision_markers", [])
			expect.call(collisions.size() == markers.size(), label + ": board retains the resolved collision")
			if action == PREVIEW_PUSH:
				var prepared: Dictionary = engine.prepare_player_card(before, 0)
				_install(scene, before, prepared, [action], 0)
				scene.set("_pending_target_tiles", scene.call("_vector2i_array", [ENEMY_START]))
				var pass_source: Dictionary = scene.call("_pass_preview_source_state")
				var projected: Dictionary = engine._surface_actor(pass_source, "enemy", 1)
				expect.call(projected.get("hp") == actual["enemies"][0]["hp"] and projected.get("pos") == actual["enemies"][0]["pos"], label + ": targeted Pass source retains the same Health and anchor")
			scene.free()

static func _test_concealed_mover(expect: Callable) -> void:
	var scene := Run.new()
	var engine: RefCounted = scene.get("_combat_engine")
	var before: Dictionary = _fixture()
	before["enemies"].append(Base.enemy(2, CONCEALED_CONTACT))
	var hero: Vector2i = before["player"]["pos"]
	var actual: Dictionary = engine.apply_player_action(before, AREA_PULL)
	expect.call(actual["enemies"][1]["pos"] != CONCEALED_CONTACT and actual["enemies"][0]["hp"] < ENEMY_HP, "A concealed area Pull mover moves and collides with the visible enemy")
	scene.set("_combat_state", before)
	scene.set("_hovered_board_tile", hero)
	var shown: Dictionary = {}
	scene.call("_append_surface_action_preview", shown, {"state": before, "action": AREA_PULL, "target_tiles": [hero], "actions": [AREA_PULL], "action_index": 0})
	var losses: Dictionary = shown.get("damage_preview", {})
	expect.call(int(losses.get("enemy_1", {}).get("hp_loss", 0)) == ENEMY_HP - int(actual["enemies"][0]["hp"]), "The visible enemy shows the concealed mover's collision damage")
	expect.call(not losses.has("enemy_2") and shown.get("preview_units", []).is_empty() and shown.get("displacement_paths", []).is_empty(), "The concealed mover contributes no damage entry, ghost or path")
	scene.free()

static func _test_announced_enemy_force(expect: Callable) -> void:
	var scene := Run.new()
	var engine: RefCounted = scene.get("_combat_engine")
	var walk_start: Dictionary = _fixture()
	walk_start["player"]["pos"] = HERO_AT_CONTACT + Vector2i.UP
	walk_start["player"]["hp"] = WALK_PUSH_HEALTH
	walk_start["enemies"][0]["pos"] = ENEMY_ATTACKER
	var push: Dictionary = PREVIEW_PUSH.merged({"damage": WALK_PUSH_DAMAGE}, true)
	walk_start["enemies"][0]["intent"] = {"id": "proof_push", "time_cost": 20, "actions": [push]}
	walk_start["enemies"].append(Base.enemy(2, CONCEALED_CONTACT + Vector2i.RIGHT))
	walk_start["turn_queue"] = [{"kind": "enemy", "enemy_id": 1, "time": 1, "seq": 1}]
	_arm_walk(scene, walk_start, HERO_AT_CONTACT)
	var hover_source: Dictionary = scene.call("_pass_preview_source_state")
	var hover_phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(RedTiles.schedule(engine, hover_source), true)
	var hover_summary: Dictionary = scene.call("_pass_preview_summary")
	var before: Dictionary = engine.apply_player_movement(walk_start, HERO_AT_CONTACT)
	scene.set("_combat_state", before)
	expect.call(before["player"]["pos"] == HERO_AT_CONTACT and engine.is_enemy_visible_to_player(walk_start, walk_start["enemies"][0])
		and not engine.is_enemy_visible_to_player(before, before["enemies"][1]), "Heart walk is legal, with an announced Push and a concealed blocker")
	var source: Dictionary = Forecast.rest_source(scene, before)
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(RedTiles.schedule(engine, source), true)
	var actual: Dictionary = Committed.advance_to_player(engine, Committed.finish_player_activation(engine, before))["state"]
	var hover_hero: Dictionary = hover_phase["state"]["player"]
	expect.call(actual["player"]["pos"] == CONCEALED_CONTACT and actual["player"]["hp"] == 0
		and hover_hero["pos"] == CONCEALED_CONTACT and hover_hero["hp"] == 0 and bool(hover_summary.get("defeat", false)),
		"Walk hover matches the committed lethal Push collision at %s (hover at %s with %s Health)" % [CONCEALED_CONTACT, hover_hero["pos"], hover_hero["hp"]])
	expect.call(phase["state"]["player"]["pos"] == actual["player"]["pos"] and phase["state"]["player"]["hp"] == actual["player"]["hp"], "Pass matches the announced enemy Push into a concealed unit")
	var summary: Dictionary = scene.call("_pass_preview_summary_for_phase_result", source, phase)
	expect.call(int(summary["hp_loss"]) == int(before["player"]["hp"]) - int(actual["player"]["hp"]) and not summary.get("enemy_hits", {}).has("enemy_2"), "Pass shows the known loss without a hidden enemy receipt")
	var threat: Dictionary = scene.call("_enemy_threat_at_tile", before, ENEMY_ATTACKER)
	var presentation: Dictionary = {}
	scene.call("_append_enemy_force_intent_preview", presentation, threat, before)
	expect.call(threat.get("projected_player_force", {}).get("destination") == actual["player"]["pos"] and (presentation.get("collision_markers", []) as Array).size() == 1, "Focused enemy Push shows the resolved destination and collision")
	scene.free()

static func _test_illusion_destination_sight(expect: Callable) -> void:
	for limited: bool in [false, true]:
		var scene := Run.new()
		var engine := Combat.new()
		var before: Dictionary = _fixture()
		before["umbra"]["stage"] = "heart" if limited else "clear"
		before["enemies"][0]["pos"] = ILLUSION_COLLISION_DESTINATION + Vector2i.RIGHT
		before["illusions"] = [{"id": 1, "pos": ILLUSION_START, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}]
		before["relics"] = ["hollow_puppet"]
		before["deck"]["hand"] = ["skybreak_current"]
		var actions: Array = engine.card_play_actions("skybreak_current", before)
		scene.set("_combat_state", before)
		var preview: Dictionary = scene.call("_card_preview_from_state", "skybreak_current", before, actions, 0)
		_install(scene, before, preview["state"], actions, int(preview["action_index"]))
		scene.set("_pending_target_tiles", scene.call("_vector2i_array", preview["target_tiles"]))
		scene.set("_hovered_board_tile", ILLUSION_START)
		var actual: Dictionary = engine.apply_player_action(before, actions[0], ILLUSION_START)
		expect.call(actual["illusions"][0]["pos"] == ILLUSION_COLLISION_DESTINATION and int(actual["illusions"][0]["hp"]) == 0, "Hollow Puppet regression reaches a lethal enemy collision")
		expect.call(engine.is_tile_visible_to_player(before, ILLUSION_COLLISION_DESTINATION) != limited, "Illusion landing visibility matches committed sight")
		var result: Dictionary = {}
		scene.call("_append_surface_action_preview", result, preview)
		result.merge(scene.call("_stage_visibility_presentation", before), true)
		var board := Board.new()
		board.set("combat_state", before)
		board.set("presentation", result)
		var marked_positions: Array = []
		for unit: Dictionary in board.call("_build_visible_units"):
			if bool(board.call("_unit_is_preview_lethal", unit)): marked_positions.append(unit["pos"])
		expect.call(marked_positions.has(ILLUSION_START), "Lethal illusion keeps its visible original death mark")
		expect.call(marked_positions.has(ILLUSION_COLLISION_DESTINATION) != limited, "Lethal illusion destination ghost respects committed sight")
		board.free()
		scene.free()

static func _test_concealed_illusion_losses(expect: Callable) -> void:
	var scene := Run.new()
	var engine := Combat.new()
	var before: Dictionary = _fixture()
	before["illusions"] = [{"id": 1, "pos": ILLUSION_START, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}, {"id": 2, "pos": CONCEALED_ILLUSION_TILE, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}]
	scene.set("_combat_state", before)
	expect.call(engine.is_tile_visible_to_player(before, ILLUSION_START) and not engine.is_tile_visible_to_player(before, CONCEALED_ILLUSION_TILE), "Illusion-loss regression has visible and concealed illusions")
	var after: Dictionary = before.duplicate(true)
	for illusion: Dictionary in after["illusions"]: illusion["hp"] = 0
	var raw: Dictionary = scene.call("_damage_preview_between_states", before, after)
	expect.call(raw.has("illusion_2"), "Concealed illusion loss exists before privacy filtering")
	var safe: Dictionary = scene.call("_sanitize_damage_preview_for_umbra_information", before, raw)
	expect.call(safe.has("illusion_1") and not safe.has("illusion_2"), "Limited Umbra retains visible illusion losses and omits concealed illusion damage keys")
	scene.free()

static func _fixture() -> Dictionary:
	var state: Dictionary = Base.fixture(Combat.new())
	state["terrain"] = []
	state["traps"] = []
	state["illusions"] = []
	state["umbra"]["stage"] = "heart"
	state["enemies"][0]["pos"] = ENEMY_START
	state["enemies"][0]["hp"] = ENEMY_HP
	state["enemies"][0]["max_hp"] = ENEMY_HP
	return state

static func _install(scene: Node, before: Dictionary, actual: Dictionary, actions: Array, action_index: int, selected: Array = []) -> void:
	scene.set("_combat_state", before)
	scene.set("_run_state", {"mode": "combat"})
	scene.set("_selected_card_index", 0)
	scene.set("_preview_combat_state", actual)
	scene.set("_pending_actions", actions)
	scene.set("_pending_action_index", action_index)
	scene.set("_pending_selected_targets", scene.call("_vector2i_array", selected))
