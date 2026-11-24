extends "res://tests/pre_battle_fixture.gd"

const BookData = preload("res://scripts/grimoire_library.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const Moves = preload("res://scripts/known_move_text.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Shapes = preload("res://scripts/committed_pattern_shapes.gd")
const Snuff = preload("res://scripts/enemy_mechanics/snuff.gd")

const CREATURE_COUNT: int = 44
const SNUFF_BRAZIER := Vector2i(3, 4)
const LIVE_MOVES: Dictionary = {
	"burrow_grub": "erupt", "wick_shade": "snuff", "last_lamplighter": "snuff",
	"gust_shrike": "dive", "noctyrax": "night_coil", "vaeloryx": "razor_dive",
	"ashen_reaver": "executioners_fall",
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var file: FileAccess = FileAccess.open(OS.get_environment("TXT38_GRIMOIRE"), FileAccess.READ)
	if file == null:
		_fail("Set TXT38_GRIMOIRE to the local txt-36 Grimoire copy")
		quit(1)
		return
	BookData._cache = JSON.parse_string(file.get_as_text())
	_setup()
	var scene: Node = await _instance(_run_with_available_combat(RunEngine.new()))
	scene._close_large_map()
	var entries: Array = BookData.entries().filter(func(entry: Dictionary) -> bool: return entry.get("section") == "creatures")
	_expect(entries.size() == CREATURE_COUNT and entries.size() == GameData.enemies().size(), "Grimoire override covers the full enemy catalog")
	var ids: Array = entries.map(func(entry: Dictionary) -> String: return entry["id"])
	scene._run_state = BookData.unlock_entries(scene._run_state, ids)["state"]
	scene._on_grimoire_button_pressed()
	var book: Control = scene._grimoire_scrim
	var inventory: Dictionary = {}
	var move_count: int = 0
	for entry: Dictionary in entries:
		var enemy_id: String = entry["enemy_id"]
		book._on_grimoire_entry_pressed(entry["id"])
		var moves: Control = book.find_child("GrimoireMoves", true, false)
		var intents: Array = GameData.enemy_def(enemy_id)["intents"]
		_expect(moves != null and moves.get_child_count() == 1 + intents.size() * 2, enemy_id + " uses the full move list")
		for index: int in intents.size():
			var intent: Dictionary = Moves.base_intent(intents[index], intents)
			var rows: Array = Moves.rows(intent, {"type": enemy_id}, {}, true)
			var row: Control = moves.get_child(index * 2 + 1)
			var body: RichTextLabel = row.get_child(1).get_child(1)
			var title: Label = row.get_child(1).get_child(0)
			var time: Label = row.get_child(2)
			_expect(title.text == intent["name"] and time.text == "Time %d" % int(intent["time"]), enemy_id + " move title and Time")
			inventory[enemy_id + "/" + intent["id"]] = {
				"name": title.text, "time": time.text, "visible": body.get_parsed_text(),
				"summary": Moves.summary(intent, rows), "tokens": _describe(rows), "actions": intent["actions"],
			}
			move_count += 1
		await process_frame
	book.close()
	var live: Dictionary = {}
	for enemy_id: String in LIVE_MOVES:
		var intent_id: String = LIVE_MOVES[enemy_id]
		live[enemy_id + "/" + intent_id] = await _inspect_live(scene, enemy_id, intent_id)
	var receipt: Dictionary = {"pages": inventory, "live": live, "swept_path": _measure_dive()}
	var output: FileAccess = FileAccess.open(OS.get_environment("TXT38_INVENTORY"), FileAccess.WRITE)
	if output == null:
		_fail("Set TXT38_INVENTORY to a writable JSON path")
	else:
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	_viewport.queue_free()
	await process_frame
	print("TXT38 INVENTORY: %s (%d creature pages, %d move rows, %d live controls)" %
		["FAIL" if _failed else "PASS", entries.size(), move_count, live.size()])
	quit(int(_failed))

func _describe(rows: Array) -> Array:
	var result: Array = []
	for row: Array in rows:
		for token: Dictionary in row:
			result.append({
				"text": Icons.plain_text_for_tokens([token], true).trim_prefix("· "),
				"kind": token.get("kind", ""), "icon": token.get("icon", ""),
				"value": token.get("value"), "pattern": token.get("pattern", []),
				"tooltip": Icons.token_tooltip(token),
				"display_tooltip": token.get("display_tooltip", ""),
			})
	return result

func _inspect_live(scene: Node, enemy_id: String, intent_id: String) -> Dictionary:
	var state: Dictionary = Fight.state(enemy_id, intent_id)
	var unit: Dictionary = state["enemies"][0]
	if enemy_id == "wick_shade":
		state[Snuff.RELIGHT_KEY] = true
		state["guardian_braziers"] = [{"id": 1, "pos": SNUFF_BRAZIER, "lit": true}]
		unit["intent"] = Snuff.declare(state, unit, unit["intent"])
	scene._pre_battle_preview_run_state = {"combat_state": state}
	var panel: Control = Inspection.build(scene, unit)
	_viewport.add_child(panel)
	await process_frame
	var known: Array = panel.find_child("PreBattleKnownMoves", true, false).get_children()
	var intents: Array = scene._pre_battle_known_enemy_intents(enemy_id)
	var index: int = intents.find_custom(func(intent: Dictionary) -> bool: return intent["id"] == intent_id)
	_expect(index >= 0 and index < known.size(), enemy_id + " has a Known Moves row for " + intent_id)
	if index < 0 or index >= known.size():
		panel.free()
		return {}
	var play: Control = known[index]
	var pre_battle: String = (play.find_child("PreBattleMoveEffect", true, false) as Label).text
	var pre_battle_tooltip: String = play.tooltip_text
	panel.free()
	if intent_id == "erupt":
		unit["burrowed"] = true
		unit["erupt_tile"] = state["player"]["pos"]
	var board: Control = scene.board_view
	board.set_combat_state(state)
	var rows: Array = board._move_rows_for_unit(unit, unit["intent"])
	var tooltip: String = board.enemy_intent_tooltip("enemy_1")
	_expect(not rows.is_empty() and not tooltip.is_empty(), enemy_id + " live combat row and tooltip")
	return {"known_moves": pre_battle, "known_moves_tooltip": pre_battle_tooltip,
		"combat_tokens": _describe(rows), "combat_tooltip": tooltip}

func _measure_dive() -> Dictionary:
	var engine := Combat.new()
	var state: Dictionary = Fight.state("gust_shrike", "dive")
	var plan: Dictionary = engine.enemy_intent_plan(state, 0)
	var path: Array = plan["path"]
	var tiles: Array = plan["projected_attack"]
	var attack: Dictionary = state["enemies"][0]["intent"]["actions"][1].duplicate(true)
	attack["_resolved_path"] = path
	var shape: Array[Vector2i] = Shapes.swept_shape(engine, state, path[-1], attack)
	var expected: Array[Vector2i]
	var distances: Dictionary = {}
	for tile: Vector2i in engine._all_passable_tiles(state):
		var distance: int = Paths.manhattan(tile, path[0])
		for anchor: Vector2i in path:
			distance = mini(distance, Paths.manhattan(tile, anchor))
		if distance <= 1: expected.append(tile)
		if tiles.has(tile): distances[distance] = int(distances.get(distance, 0)) + 1
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	var steps: Array = result["steps"].filter(func(step: Dictionary) -> bool: return step.get("action_type") == "aoe")
	var struck: Array = steps[0]["tiles"] if steps.size() == 1 else []
	_expect(path.size() > 2 and distances.get(1, 0) > 0, "Dive reaches off-axis tiles along a multi-tile path")
	_expect(_same_tiles(expected, shape) and _same_tiles(shape, tiles) and _same_tiles(tiles, struck),
		"Dive shape, forecast and resolved impact match all passable tiles within one tile of the open route")
	var hp_loss: int = int(state["player"]["hp"]) - int(result["state"]["player"]["hp"])
	_expect(hp_loss == 4, "Dive resolves catalog damage on the witness")
	print("TXT38 DIVE: path=%s; impact=%s; distance counts=%s; Health lost=%d" % [path, struck, distances, hp_loss])
	return {"path": path, "impact": struck, "distance_counts": distances, "hp_loss": hp_loss}

func _same_tiles(left: Array, right: Array) -> bool:
	return left.size() == right.size() and left.all(func(tile: Vector2i) -> bool: return right.has(tile))
