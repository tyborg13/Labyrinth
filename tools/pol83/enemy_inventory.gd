extends SceneTree
## Export one-line text that reaches the shared panel from creature move UI.

const Board = preload("res://scripts/combat_board_view.gd")
const Battlefield = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const Data = preload("res://scripts/game_data.gd")
const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const Loops = preload("res://scripts/tooltip_loop_context.gd")
const KnownMove = preload("res://scripts/known_move_text.gd")
const Patterns = preload("res://scripts/pattern_text.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const Split = preload("res://scripts/enemy_mechanics/split_trait_text.gd")
const Traits = preload("res://scripts/enemy_mechanics/unit_traits.gd")
const WarbandProof = preload("res://tests/helpers/txt08_combat_proof.gd")

var _rows: Dictionary

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Usage: enemy_inventory.gd -- <output.json>")
		quit(2)
		return
	var board := Board.new()
	var host: Node = RunScene.instantiate()
	var intents: int = 0
	for id: String in Data.enemies():
		var unit: Dictionary = {"type": id}
		_record_traits(unit, {})
		var known_moves: Array = Data.enemy_def(id).get("intents", [])
		for intent: Dictionary in known_moves:
			var witness: String = "%s / %s" % [id, intent["name"]]
			var state: Dictionary = Fight.state(id, intent["id"])
			var enemy: Dictionary = state["enemies"][0]
			var source: Dictionary = Loops.enemy_unit(enemy)
			_record_chips(board, state, enemy, witness)
			var instance: Dictionary = Battlefield.instance_for(id, int(enemy["id"]))
			if instance.has("at_half_health"):
				Battlefield.HalfHealth.replace_values(instance, instance["at_half_health"])
				state["battlefield_rule"] = instance
				_record_chips(board, state, enemy, witness + " (half Health)")
			var plate: Control = Inspection.build_move(host, KnownMove.base_intent(intent, known_moves), source)
			_record("Pre-battle Known Moves", plate.tooltip_text, witness, source, plate.get("loop_term"))
			plate.free()
			intents += 1
	var warband: Dictionary = WarbandProof.barrage_run(preload("res://scripts/progression_store.gd").default_data())["combat_state"]
	var slagmaster: Dictionary = warband["enemies"][0]
	_record_chips(board, warband, slagmaster, "Slagmaster / Lob Slag")
	_record_traits(slagmaster, warband)
	_record_beats()
	board.free()
	host.free()
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write inventory: %s" % FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(JSON.stringify(_rows, "  ") + "\n")
	file.close()
	print("POL83 ENEMY INVENTORY: %d enemy IDs, %d moves" % [Data.enemies().size(), intents])
	quit()

func _record_traits(unit: Dictionary, state: Dictionary) -> void:
	var traits: Array[Dictionary] = Traits.tokens(unit, state)
	for token: Dictionary in [Burst.trait_token(unit), Split.trait_token(unit)]:
		if not token.is_empty(): traits.append(token)
	for token: Dictionary in traits:
		_record("Pre-battle Traits", Inspection.trait_details(token), str(unit["type"]),
			Loops.enemy_unit(unit), str(token.get("glossary_key", token.get("icon", ""))))

func _record_chips(board: Control, state: Dictionary, enemy: Dictionary, witness: String) -> void:
	board.combat_state = state
	var source: Dictionary = Loops.enemy_unit(enemy)
	for row: Array in board._move_rows_for_unit(enemy, enemy["intent"]):
		for token: Dictionary in row:
			var detail: String = Icons.token_tooltip(token)
			var term: String = ""
			if token.get("kind") not in ["text", "aoe_pattern"]:
				detail = str(token.get("display_tooltip", detail))
				term = str(token.get("glossary_key", token.get("icon", "")))
			_record("Combat chip", detail, witness, source, term)

func _record_beats() -> void:
	var data: Dictionary = Battlefield.data()
	var names: Dictionary = {}
	for rule: Dictionary in data["rules"]:
		names[rule["id"]] = rule["name"]
	for id: String in data["instances"]:
		var instance: Dictionary = data["instances"][id]
		for stage: Dictionary in [instance, instance.get("at_half_health", {})]:
			if stage.is_empty(): continue
			var sentence: String = stage["sentence"]
			if Patterns.display_rules(sentence) != sentence: continue
			var witness: String = id if stage == instance else id + " (half Health)"
			_record("Initiative rail", "%s — %s" % [names[instance["rule"]], sentence], witness, {}, "")

func _record(screen: String, detail: String, witness: String, source: Dictionary, term: String) -> void:
	var text: String = detail.strip_edges()
	if text.is_empty() or text.contains("\n"): return
	if text.right(1) not in [".", "!", "?"] and text.split(" ", false).size() <= 4: return
	if term.is_empty(): term = Loops.term_in(text, source)
	if Registry.media_available(Registry.find(term, source)): return
	if not _rows.has(screen): _rows[screen] = {}
	var where: Array = _rows[screen].get(text, [])
	if not where.has(witness): where.append(witness)
	_rows[screen][text] = where
