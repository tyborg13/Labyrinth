extends RefCounted

const F = preload("res://tools/txt27/fixture.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Patterns = preload("res://scripts/pattern_text.gd")
const RunScene = preload("res://scripts/run_scene.gd")
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
	var forecast: Dictionary = engine.surface_preview_for_player_action(state, strike, ADJACENT)
	var scene := RunScene.new()
	scene._combat_state = state
	scene._hovered_board_tile = ADJACENT
	scene._append_surface_action_preview({}, {"state": state, "action": strike, "target_tiles": [ADJACENT]})
	var aim_position: Vector2i = scene._surface_preview_cache["state"]["player"]["pos"]
	scene.free()
	var destination: Vector2i = result["player"]["pos"]
	var charge_used: bool = engine.skill_was_used(result, "sure_footed")
	record.call("sure_footed_air", result["traps"].is_empty() and destination == F.PLAYER and charge_used and forecast["state"]["player"]["pos"] == destination and aim_position == destination,
		"Arc Flash triggered the Air trap at %s, player went from %s to %s, skill spent=%s; held-card forecast=%s; aim forecast=%s." % [ADJACENT, F.PLAYER, destination, charge_used, forecast["state"]["player"]["pos"], aim_position])
	result["traps"] = state["traps"].duplicate(true)
	var unprotected: Dictionary = engine.apply_player_action(result, strike, ADJACENT)
	record.call("sure_footed_second_push", unprotected["player"]["pos"] == F.PLAYER + Vector2i.LEFT,
		"Second Air trap Push moved the hero to %s." % unprotected["player"]["pos"])
	var walk: Dictionary = engine.apply_player_movement(state, ADJACENT)
	record.call("traps_air_ground", walk["traps"].is_empty() and Surface.tiles(walk).is_empty() and preload("res://scripts/glossary.gd").definition("traps") == "Traps hit when entered or attacked." and engine.skill_was_used(walk, "sure_footed"),
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
	var scene := RunScene.new()
	scene._combat_state = state
	scene._hovered_card_index = 0
	scene._empower_charge.observe(state)
	scene._empower_charge.toggle(0)
	var forecast: Dictionary = scene._turn_order_card_time_preview()
	var rail: Dictionary = scene._turn_order_display_state({})
	var chips: Array = engine.current_turn_order(rail).filter(func(entry: Dictionary) -> bool: return entry.has("projected_card_name"))
	var chip: Dictionary = chips.front() if not chips.is_empty() else {}
	scene.free()
	record.call("borrowed_time_empower", result.get("last_card_used_banked_play", false) and engine.skill_was_used(result, "borrowed_time") and paid == 0 and forecast.get("time", -1) == paid and int(chip.get("projected_time_delta", -1)) == paid,
		"Empowered Chain Bolt used the banked play and Borrowed Time; Time paid=%d; preview=%s; turn-order delta=%d." % [paid, forecast, int(chip.get("projected_time_delta", -1))])

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
	var marks: Array = preload("res://scripts/enemy_mechanics/capacitor_view.gd").presentation_for(state, {})["projected_attack_tiles"]
	var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)
	var result: Dictionary = resolved["state"]
	var struck: Array[Vector2i]
	for step: Dictionary in resolved["steps"]:
		for hit: Dictionary in step.get("chain_hits", []): struck.append(hit["to"])
	var first_damage: int = int(state["player"]["hp"]) - int(result["player"]["hp"])
	var hop_damage: int = int(state["enemies"][1]["hp"]) - int(result["enemies"][1]["hp"])
	record.call("arc_lash_diagonal", first_damage == 6 and hop_damage == 0 and marks == [F.PLAYER] and marks == struck and tooltip.contains("each adjacent to the prior target"),
		"%s Hero at %s lost %d Health; Arc Thrall at %s lost %d. Marked=%s; struck=%s." % [tooltip, F.PLAYER, first_damage, DIAGONAL, hop_damage, marks, struck])

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
	record.call("marked_thornwall", not tiles.is_empty() and not raised["terrain"].is_empty() and raised["player"]["hp"] == hp and tooltip.contains("Marked tiles show where this enemy acts on its next turn."),
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
	record.call("wick_shade_snuff_duration", dark and relit["guardian_braziers"][0]["lit"] and tooltip.contains("Enter the brazier's tile to relight the brazier and restore Light on these tiles.") and not tooltip.contains("Last Procession"),
		"%s Brazier lit after Snuff=%s; Shade now at %s; player at %s; brazier now lit=%s." % [tooltip, not dark, snuffed["enemies"][0]["pos"], relit["player"]["pos"], relit["guardian_braziers"][0]["lit"]])
	var icons = preload("res://scripts/action_icon_library.gd")
	var keeper_snuff: Dictionary = F.intent("last_lamplighter", "snuff")
	var night_coil: Dictionary = F.intent("noctyrax", "night_coil")
	var keeper_copy: String = icons.brazier_rule_tooltip(keeper_snuff["actions"][0])
	var coil_copy: String = icons.brazier_rule_tooltip(night_coil["actions"][0])
	record.call("snuff_dispatch", keeper_copy == "Lasts until Last Procession, including a skipped turn." and coil_copy.begins_with("Night Coil") and not preload("res://scripts/guardian_library.gd").intent_notes(night_coil).contains("Last Procession"),
		"Lamplighter: %s Night Coil: %s" % [keeper_copy, coil_copy])

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
		var displayed: Array = Patterns.offsets(template.get_string(1)).map(func(offset: Vector2i) -> Vector2i: return DIAGONAL + offset)
		var trait_diagram: String = str(rows[0][0]["display_tooltip"])
		board.free()
		var hp: int = state["player"]["hp"]
		var result: Dictionary = engine.apply_player_action(state, engine.card_def(BURST_FINISHER, state)["actions"][0], DIAGONAL)
		var events: Array = result.get("death_burst_events", [])
		var actual: Array = events[0]["tiles"] if not events.is_empty() else []
		record.call(enemy_type + "_burst_diagram", displayed.size() == actual.size() and actual.all(func(tile: Vector2i) -> bool: return displayed.has(tile)) and trait_diagram.begins_with(markup) and not actual.has(F.PLAYER) and result["player"]["hp"] == hp,
			"Details diagram=%s (%d highlighted offsets), actual hit tiles=%s, player at %s kept %d Health." % [markup, displayed.size(), actual, F.PLAYER, result["player"]["hp"]])

static func _fade_fallback(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "gloam_stalker")
	var behind: Vector2i = F.PLAYER - engine.hero_facing_direction(state)
	state["grid"][behind.y][behind.x] = "pillar"
	state["enemies"][0]["intent"] = F.intent("gloam_stalker", "fade")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var landing: Vector2i = result["enemies"][0]["pos"]
	var board := Board.new()
	board.combat_state = state
	var tooltip: String = board.enemy_intent_tooltip("enemy_0")
	board.free()
	record.call("gloam_stalker_fade_fallback", landing != F.ENEMY and landing != behind and Paths.manhattan(landing, F.PLAYER) == 1 and tooltip.contains("lands on another adjacent tile if the tile behind you is blocked."),
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
	var tooltip: String = preload("res://scripts/action_icon_library.gd").marked_move_text(buried["enemies"][0]["intent"]["actions"][0])
	record.call("burrow_grub_erupt_fallback", blocked and bool(grub.get("erupt_resolved", false)) and grub["pos"] != mark and tooltip.contains("emerges on the Marked tile or the nearest open tile."),
		"Burrow marked %s; Raise Stone occupied that tile=%s. Grub emerged at %s." % [mark, blocked, grub["pos"]])
