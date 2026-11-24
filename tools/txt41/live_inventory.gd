extends "res://tools/txt38/inventory.gd"
## Complement txt-38's actual Grimoire capture with every live move.

const ACTION_ICONS = preload("res://scripts/action_icon_library.gd")
const BATTLE_INSPECTION = preload("res://scripts/pre_battle_inspection_view.gd")
const KNOWN_MOVES = preload("res://scripts/known_move_text.gd")
const LOOP_CONTEXT = preload("res://scripts/tooltip_loop_context.gd")
const EXPECTED_MOVE_COUNT: int = 137

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Usage: live_inventory.gd -- <output.json>")
		quit(2)
		return
	_setup()
	var scene: Node = await _instance(_run_with_available_combat(RunEngine.new()))
	scene._close_large_map()
	var board: Control = scene.board_view
	var results: Dictionary = {}
	for enemy_id: String in GameData.enemies():
		var intents: Array = GameData.enemy_def(enemy_id)["intents"]
		for raw_intent: Dictionary in intents:
			var intent_id: String = raw_intent["id"]
			var state: Dictionary = Fight.state(enemy_id, intent_id)
			var unit: Dictionary = state["enemies"][0]
			if intent_id == "erupt":
				unit["burrowed"] = true
				unit["erupt_tile"] = state["player"]["pos"]
			var catalog: Dictionary = KNOWN_MOVES.base_intent(raw_intent, intents)
			var plate: Control = BATTLE_INSPECTION.build_move(scene, catalog, LOOP_CONTEXT.enemy_unit(unit), unit, state)
			var effect: Label = plate.find_child("PreBattleMoveEffect", true, false)
			var known: Dictionary = {"text": effect.text, "tooltip": plate.tooltip_text}
			plate.free()

			board.set_combat_state(state)
			var rows: Array = board._move_rows_for_unit(unit, unit["intent"])
			var tooltip: String = board.enemy_intent_tooltip("enemy_1")
			results[enemy_id + "/" + intent_id] = {
				"known": known,
				"combat_tokens": _describe(rows),
				"combat_tooltip": tooltip,
			}
	_expect(results.size() == EXPECTED_MOVE_COUNT, "Every catalog move has a live control receipt")
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		_fail("Cannot write the live inventory")
	else:
		file.store_string(JSON.stringify(results, "\t") + "\n")
		file.close()
	_viewport.queue_free()
	await process_frame
	print("TXT41 LIVE INVENTORY: %s (%d Known Moves controls and combat intents)" %
		["FAIL" if _failed else "PASS", results.size()])
	quit(int(_failed))
