extends RefCounted

const F = preload("res://tools/txt24/fixture.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Patterns = preload("res://scripts/pattern_text.gd")
const Board = preload("res://scripts/combat_board_view.gd")

const ADJACENT: Vector2i = F.PLAYER + Vector2i.RIGHT
const DIAGONAL: Vector2i = F.PLAYER + Vector2i(1, 1)
const TWO_EAST: Vector2i = F.PLAYER + Vector2i(2, 0)
const BRAZIER: Vector2i = F.PLAYER + Vector2i.UP
const BANKED_EMPOWER: String = "chain_bolt"
const TRAP_STRIKE: String = "arc_flash"
const LIGHTNING_STRIKE: String = "jolt"
const BURST_FINISHER: String = "arc_flash"
const RAISE_ON_MARK: String = "raise_stone"

static func run(engine: RefCounted, record: Callable) -> void:
	_air_trap(engine, record)
	_ghost_stride(engine, record)
	_borrowed_time(engine, record)
	_arc_lash(engine, record)
	_thornwall(engine, record)
	_conduction(engine, record)
	_wick_shade(engine, record)
	_death_burst_diagrams(engine, record)
	_fade_fallback(engine, record)
	_erupt_fallback(engine, record)

static func _air_trap(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "crawler", ["ghost_stride", "sure_footed"])
	state["traps"] = [{"pos": ADJACENT, "element": "air", "damage": 4}]
	var strike: Dictionary = engine.card_def(TRAP_STRIKE, state)["actions"][0]
	var result: Dictionary = engine.apply_player_action(state, strike, ADJACENT)
	var destination: Vector2i = result["player"]["pos"]
	var charge_used: bool = engine.skill_was_used(result, "sure_footed")
	record.call("sure_footed_air", result["traps"].is_empty() and destination == F.PLAYER + Vector2i.LEFT and not charge_used,
		"Arc Flash triggered the Air trap at %s, player went from %s to %s, skill spent=%s." % [ADJACENT, F.PLAYER, destination, charge_used])
	var walk: Dictionary = engine.apply_player_movement(state, ADJACENT)
	record.call("traps_air_ground", walk["traps"].is_empty() and Surface.tiles(walk).is_empty(),
		"Walking into the Air trap consumed it and left %s ground tiles." % Surface.tiles(walk).size())

static func _ghost_stride(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "crawler", ["ghost_stride"])
	state["enemies"][0]["pos"] = Vector2i(7, 4)
	state["player_movement_remaining"] = 1
	state = engine.arm_ghost_stride(state)
	var action: Dictionary = engine.player_movement_action(state)
	var targets: Array = engine.player_movement_targets(state)
	record.call("ghost_stride_range", action.get("type") == "blink" and action.get("range") == 1 and not targets.has(TWO_EAST),
		"With 1 Movement remaining: the armed move is %s %s and the open visible tile %s is absent from %s." % [action.get("type"), action.get("range"), TWO_EAST, targets])

static func _borrowed_time(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "crawler", ["quick_wits", "measured_breath", "borrowed_time"])
	state["deck"]["hand"] = [BANKED_EMPOWER]
	state["cards_played_this_turn"] = state["cards_per_turn"]
	state["banked_play_active"] = 1
	var before: int = int(state["player_turn_time_spent"])
	var prepared: Dictionary = engine.prepare_player_card(state, 0, "empower")
	var result: Dictionary = engine.finish_player_card(prepared, 0)
	var paid: int = int(result["player_turn_time_spent"]) - before
	record.call("borrowed_time_empower", result.get("last_card_used_banked_play", false) and engine.skill_was_used(result, "borrowed_time") and paid == 2,
		"Empowered Chain Bolt used the banked play and Borrowed Time; Time paid=%d." % paid)

static func _arc_lash(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "storm_capacitor")
	state["enemies"][0]["pos"] = Vector2i(2, 4)
	state["enemies"][0]["charge"] = 3
	state["enemies"][0]["intent"] = F.intent("storm_capacitor", "discharge")
	state["enemies"].append(F.unit("arc_thrall", 1, DIAGONAL))
	var board := Board.new()
	board.combat_state = state
	var tooltip: String = F.text(board.enemy_intent_tooltip("enemy_0"))
	board.free()
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var first_damage: int = int(state["player"]["hp"]) - int(result["player"]["hp"])
	var hop_damage: int = int(state["enemies"][1]["hp"]) - int(result["enemies"][1]["hp"])
	record.call("arc_lash_diagonal", first_damage == 6 and hop_damage == 5 and tooltip.contains("each adjacent to the prior target"),
		"%s Hero at %s lost %d Health; Arc Thrall at %s lost %d." % [tooltip, F.PLAYER, first_damage, DIAGONAL, hop_damage])

static func _thornwall(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "briar_weaver")
	var intent: Dictionary = F.intent("briar_weaver", "thornwall")
	state["enemies"][0]["pos"] = Vector2i(7, 4)
	state["enemies"][0]["intent"] = intent
	var board := Board.new()
	board.combat_state = state
	var tooltip: String = F.text(board.enemy_intent_tooltip("enemy_0"))
	board.free()
	var marked: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var tiles: Array = marked["enemies"][0].get("upheaval_pending", {}).get("marks", [])
	marked["turn"] = int(marked["turn"]) + 1
	var hp: int = marked["player"]["hp"]
	var raised: Dictionary = engine.BrambleRules.begin_turn(engine, marked, 0)
	record.call("marked_thornwall", not tiles.is_empty() and not raised["terrain"].is_empty() and raised["player"]["hp"] == hp and tooltip.contains("Marked tiles are hit"),
		"Thornwall tooltip=%s Marked tiles=%s, Outcrops=%s, player Health=%d." % [tooltip.replace("\n", " "), tiles, raised["terrain"].size(), raised["player"]["hp"]])

static func _conduction(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine)
	state["umbra"]["stage"] = "eclipse"
	state["enemies"][0]["pos"] = ADJACENT
	state["enemies"].append(F.unit("crawler", 1, TWO_EAST))
	Surface.place(state, ADJACENT, "electrified")
	Surface.place(state, TWO_EAST, "electrified")
	var hidden: bool = not engine.is_enemy_visible_to_player(state, state["enemies"][1])
	var strike: Dictionary = engine.card_def(LIGHTNING_STRIKE, state)["actions"][0]
	var result: Dictionary = engine.apply_player_action(state, strike, ADJACENT)
	var first_damage: int = int(state["enemies"][0]["hp"]) - int(result["enemies"][0]["hp"])
	var second_damage: int = int(state["enemies"][1]["hp"]) - int(result["enemies"][1]["hp"])
	record.call("electrified_hidden", hidden and first_damage > 0 and second_damage == 0,
		"Jolt hit the visible Crawler for %d; hidden=%s and HP loss=%d on the connected tile %s." % [first_damage, hidden, second_damage, TWO_EAST])

static func _wick_shade(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "wick_shade")
	state["enemies"][0]["pos"] = F.PLAYER + Vector2i(2, -1)
	state["enemies"][0]["intent"] = F.intent("wick_shade", "snuff")
	state["guardian_braziers"] = [{"id": 1, "pos": BRAZIER, "lit": true}]
	state["brazier_relight_on_step"] = true
	var board := Board.new()
	board.combat_state = state
	var tooltip: String = F.text(board.enemy_intent_tooltip("enemy_0"))
	board.free()
	var snuffed: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var dark: bool = not bool(snuffed["guardian_braziers"][0]["lit"])
	# The single-enemy resolver ends on the enemy actor boundary. Start the
	# following player activation with the same open route to the brazier.
	snuffed["current_actor"] = state["current_actor"]
	var relit: Dictionary = engine.apply_player_movement(snuffed, BRAZIER)
	record.call("wick_shade_snuff_duration", dark and relit["guardian_braziers"][0]["lit"] and tooltip.contains("Last Procession"),
		"%s Brazier lit after Snuff=%s; Shade now at %s; player at %s; brazier now lit=%s." % [tooltip, not dark, snuffed["enemies"][0]["pos"], relit["player"]["pos"], relit["guardian_braziers"][0]["lit"]])

static func _death_burst_diagrams(engine: RefCounted, record: Callable) -> void:
	for enemy_type: String in ["ember_tick", "ember_hoarder"]:
		var state: Dictionary = F.fight(engine, enemy_type)
		state["enemies"][0]["pos"] = DIAGONAL
		state["enemies"][0]["hp"] = 1
		var board := Board.new()
		board.combat_state = state
		var rows: Array = board._intent_rows_for_unit(state["enemies"][0], {})
		var markup: String = str(rows[1][0]["diagram_markup"])
		var template: RegExMatch = Patterns.matches(markup)[0]
		var displayed: Array = Patterns.offsets(template.get_string(1))
		board.free()
		var hp: int = state["player"]["hp"]
		var result: Dictionary = engine.apply_player_action(state, engine.card_def(BURST_FINISHER, state)["actions"][0], DIAGONAL)
		var events: Array = result.get("death_burst_events", [])
		var actual: Array = events[0]["tiles"] if not events.is_empty() else []
		record.call(enemy_type + "_burst_diagram", displayed.has(F.PLAYER - DIAGONAL) and not actual.is_empty() and not actual.has(F.PLAYER) and result["player"]["hp"] == hp,
			"Details diagram=%s (%d highlighted offsets), actual hit tiles=%s, player at %s kept %d Health." % [markup, displayed.size(), actual, F.PLAYER, result["player"]["hp"]])

static func _fade_fallback(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "gloam_stalker")
	var behind: Vector2i = F.PLAYER - engine.hero_facing_direction(state)
	state["grid"][behind.y][behind.x] = "pillar"
	state["enemies"][0]["intent"] = F.intent("gloam_stalker", "fade")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var landing: Vector2i = result["enemies"][0]["pos"]
	record.call("gloam_stalker_fade_fallback", landing != F.ENEMY and landing != behind and Paths.manhattan(landing, F.PLAYER) == 1,
		"Player=%s, blocked behind tile=%s, Fade landed at %s." % [F.PLAYER, behind, landing])

static func _erupt_fallback(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "burrow_grub")
	state["enemies"][0]["intent"] = F.intent("burrow_grub", "burrow")
	var buried: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var mark: Vector2i = buried["enemies"][0]["erupt_tile"]
	buried["current_actor"] = state["current_actor"]
	buried = engine.apply_player_movement(buried, BRAZIER)
	var raise_outcrop: Dictionary = engine.card_def(RAISE_ON_MARK, buried)["actions"][0]
	buried = engine.apply_player_action(buried, raise_outcrop, mark)
	var blocked: bool = engine._terrain_index_at_tile(buried, mark) >= 0
	buried["enemies"][0]["intent"] = F.intent("burrow_grub", "erupt")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(buried, 0, true, false)["state"]
	var grub: Dictionary = result["enemies"][0]
	record.call("burrow_grub_erupt_fallback", blocked and bool(grub.get("erupt_resolved", false)) and grub["pos"] != mark,
		"Burrow marked %s; Raise Stone occupied that tile=%s. Grub emerged at %s." % [mark, blocked, grub["pos"]])
