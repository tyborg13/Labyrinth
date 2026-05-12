extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const INVALID_TARGET_TILE: Vector2i = Vector2i(-1, -1)
const FALLBACK_ATTACK: Array = [{"type": "melee", "damage": 2, "range": 1}]
const FALLBACK_MOVE: Array = [{"type": "move", "range": 2}]
const SHORTCUT_ATTACK_TYPES: Array = ["melee", "ranged", "aoe", "push", "pull"]
const DEFAULT_OUTPUT_DIR: String = "res://playtest/headless"
const DEFAULT_SEED_BASE: int = 5052026

var _run_engine: RunEngine = RunEngine.new()
var _combat_engine: CombatEngine = CombatEngine.new()
var _analytics_store: AnalyticsStore
var _options: Dictionary = {}
var _run_state: Dictionary = {}
var _combat_state: Dictionary = {}
var _progression: Dictionary = {}
var _pending: Dictionary = {}
var _analytics_tracker: Dictionary = {}
var _run_number: int = 0
var _notes_path: String = ""
var _session_path: String = ""
var _running: bool = true

func _initialize() -> void:
	_options = _parse_args()
	_setup_paths()
	ProgressionStore.set_storage_path(str(_options.get("output_dir", DEFAULT_OUTPUT_DIR)).path_join("manual_progression.json"))
	ProgressionStore.set_run_storage_path(str(_options.get("output_dir", DEFAULT_OUTPUT_DIR)).path_join("manual_run.save"))
	AnalyticsStore.set_storage_dir(str(_options.get("analytics_dir", DEFAULT_OUTPUT_DIR.path_join("analytics"))))
	if bool(_options.get("clear_analytics", true)):
		AnalyticsStore.clear_storage()
	_analytics_store = AnalyticsStore.new()
	_progression = ProgressionStore.default_data()
	_init_notes_file()
	if bool(_options.get("resume", false)) and _load_session():
		_print_state()
	else:
		_start_new_run(int(_options.get("seed", DEFAULT_SEED_BASE)))
	_repl()
	_save_session()
	quit(0)

func _parse_args() -> Dictionary:
	var parsed: Dictionary = {
		"seed": DEFAULT_SEED_BASE,
		"output_dir": DEFAULT_OUTPUT_DIR,
		"analytics_dir": DEFAULT_OUTPUT_DIR.path_join("analytics"),
		"notes_path": DEFAULT_OUTPUT_DIR.path_join("manual_playtest_notes.md"),
		"session_path": DEFAULT_OUTPUT_DIR.path_join("manual_session.save"),
		"clear_analytics": true,
		"resume": false
	}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		var arg: String = args[index]
		match arg:
			"--seed":
				index += 1
				parsed["seed"] = int(args[index])
			"--output-dir":
				index += 1
				parsed["output_dir"] = args[index]
				parsed["analytics_dir"] = str(parsed["output_dir"]).path_join("analytics")
				parsed["notes_path"] = str(parsed["output_dir"]).path_join("manual_playtest_notes.md")
				parsed["session_path"] = str(parsed["output_dir"]).path_join("manual_session.save")
			"--analytics-dir":
				index += 1
				parsed["analytics_dir"] = args[index]
			"--notes":
				index += 1
				parsed["notes_path"] = args[index]
			"--session":
				index += 1
				parsed["session_path"] = args[index]
			"--keep-analytics":
				parsed["clear_analytics"] = false
			"--resume":
				parsed["resume"] = true
				parsed["clear_analytics"] = false
			"--help":
				_print_help()
				quit(0)
		index += 1
	return parsed

func _print_help() -> void:
	print("Manual headless playtest console")
	print("Usage: godot --headless --path . --script tools/headless_playtest.gd -- [--seed N] [--output-dir res://playtest/headless] [--resume]")
	print("Commands: state, moves, move N, cards, card N, click N, drag N play|attack|move, target N|x,y, skip, pass, reward N|heal, relic N, leave, rest, note TEXT, new [seed], analytics, help, quit")

func _setup_paths() -> void:
	var output_dir: String = str(_options.get("output_dir", DEFAULT_OUTPUT_DIR))
	_notes_path = str(_options.get("notes_path", output_dir.path_join("manual_playtest_notes.md")))
	_session_path = str(_options.get("session_path", output_dir.path_join("manual_session.save")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(_options.get("analytics_dir", output_dir.path_join("analytics")))))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_notes_path.get_base_dir()))

func _init_notes_file() -> void:
	if FileAccess.file_exists(_notes_path) and bool(_options.get("resume", false)):
		return
	var file: FileAccess = FileAccess.open(_notes_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write notes file: %s" % _notes_path)
		return
	file.store_string("# Manual Headless Playtest Notes\n\n")
	file.store_line("- Started: %s" % _timestamp_utc_iso())
	file.store_line("- Console command: `godot --headless --path . --script tools/headless_playtest.gd -- --seed N`")
	file.store_line("- Notes are written by explicit `note ...` commands while playing.\n")

func _repl() -> void:
	_print_help()
	var needs_prompt: bool = true
	while _running:
		if needs_prompt:
			print("")
			print(">")
			needs_prompt = false
		var raw: String = OS.read_string_from_stdin()
		if raw.is_empty():
			OS.delay_msec(50)
			continue
		for line: String in raw.split("\n", false):
			var command: String = line.strip_edges()
			if command.is_empty():
				continue
			_handle_command(command)
			if not _running:
				break
		needs_prompt = true

func _handle_command(command: String) -> void:
	var parts: PackedStringArray = command.split(" ", false, 2)
	var verb: String = parts[0].to_lower()
	match verb:
		"help", "?":
			_print_help()
		"state", "s":
			_print_state()
		"moves", "m":
			_print_moves()
		"move":
			if parts.size() < 2:
				_print_moves()
			else:
				_command_move(int(parts[1]))
		"cards", "hand", "h":
			_print_cards()
		"card", "click", "play":
			_command_card(parts)
		"drag":
			_command_drag(parts)
		"target", "t":
			if parts.size() < 2:
				_print_pending()
			else:
				_command_target(parts[1])
		"skip":
			_command_skip()
		"cancel":
			_pending = {}
			print("Cancelled pending card.")
			_print_state()
		"pass", "end":
			_command_pass()
		"reward":
			_command_reward(parts)
		"heal":
			_command_reward(PackedStringArray(["reward", "heal"]))
		"relic":
			_command_relic(parts)
		"leave":
			_command_leave()
		"rest":
			_command_rest()
		"note", "n":
			var note_text: String = command.substr(verb.length()).strip_edges()
			_append_note(note_text)
		"new":
			var seed: int = DEFAULT_SEED_BASE + _run_number * 101
			if parts.size() >= 2:
				seed = int(parts[1])
			_start_new_run(seed)
		"analytics":
			_print_analytics_summary()
		"save":
			_save_session()
			print("Saved session.")
		"quit", "q":
			_running = false
		_:
			print("Unknown command: %s" % verb)
			_print_help()
	_save_session()

func _start_new_run(seed: int) -> void:
	_run_number += 1
	_pending = {}
	_analytics_tracker = {}
	_progression = ProgressionStore.default_data()
	_run_state = _ensure_run_analytics_metadata(_run_engine.create_new_run(seed, _progression), _run_number)
	_sync_combat_state_from_run()
	_log_run_started()
	_append_note("## Run %d - seed %d\n" % [_run_number, seed], false)
	print("Started run %d, seed %d." % [_run_number, seed])
	_print_state()

func _print_state() -> void:
	var mode: String = str(_run_state.get("mode", ""))
	print("Run %d | seed %d | mode %s | HP %d/%d | embers %d | deck %d" % [
		_run_number,
		int(_run_state.get("seed", 0)),
		mode,
		int(_run_state.get("player_hp", 0)),
		int(_run_state.get("player_max_hp", 0)),
		int(_run_state.get("unbanked_embers", 0)),
		(_run_state.get("deck_cards", []) as Array).size()
	])
	match mode:
		"room":
			_print_room_state()
		"combat":
			_print_combat_state()
		"reward":
			_print_reward_state()
		"treasure":
			_print_relic_state()
		"campfire":
			print("Campfire. Commands: `leave` to continue, `rest` to bank and end.")
		"victory", "defeat", "rested":
			print("Run ended: %s. Use `new [seed]` for another run." % mode)
		_:
			print("Unhandled mode: %s" % mode)

func _print_room_state() -> void:
	var current: Vector2i = _run_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = _run_engine.room_metadata(_run_state, current)
	print("Room %s | depth %d | %s %s" % [
		_coord_text(current),
		int(room.get("depth", 0)),
		str(room.get("element", ElementData.NONE)),
		str(room.get("type", ""))
	])
	_print_moves()

func _print_moves() -> void:
	if str(_run_state.get("mode", "")) != "room":
		print("Moves are only available in room mode.")
		return
	var moves: Array[Vector2i] = _run_engine.available_moves(_run_state)
	if moves.is_empty():
		print("No legal room moves.")
		return
	print("Moves:")
	for index: int in range(moves.size()):
		var coord: Vector2i = moves[index]
		var room: Dictionary = _run_engine.room_metadata(_run_state, coord)
		print("  %d: %s depth %d %s %s" % [
			index,
			_coord_text(coord),
			int(room.get("depth", 0)),
			str(room.get("element", ElementData.NONE)),
			str(room.get("type", ""))
		])
	print("Command: move N")

func _command_move(index: int) -> void:
	if str(_run_state.get("mode", "")) != "room":
		print("Not in room mode.")
		return
	var moves: Array[Vector2i] = _run_engine.available_moves(_run_state)
	if index < 0 or index >= moves.size():
		print("Bad move index.")
		_print_moves()
		return
	var previous: Dictionary = _run_state.duplicate(true)
	_run_state = _run_engine.move_to_room(_run_state, moves[index])
	_sync_combat_state_from_run()
	if str(_run_state.get("mode", "")) == "combat":
		_attach_new_combat_analytics(previous, "room_move")
	_append_note("- Moved to %s: %s.\n" % [_coord_text(moves[index]), _room_label(_run_engine.room_metadata(_run_state, moves[index]))])
	_print_state()

func _print_combat_state() -> void:
	var player: Dictionary = _combat_state.get("player", {})
	var plays_remaining: int = _combat_engine.cards_remaining_this_turn(_combat_state)
	var player_status: String = _status_text(player)
	var restriction_status: String = _restriction_text(_combat_state)
	var status_suffix: String = ""
	if not player_status.is_empty():
		status_suffix += " " + player_status
	if not restriction_status.is_empty():
		status_suffix += " " + restriction_status
	print("Combat %s | turn %d | plays %d%s | player %s block %d stone %d%s" % [
		str(_combat_state.get("room_name", "")),
		int(_combat_state.get("turn", 1)),
		plays_remaining,
		_play_pool_suffix(_combat_state),
		_coord_text(player.get("pos", Vector2i.ZERO)),
		int(player.get("block", 0)),
		int(player.get("stoneskin", 0)),
		status_suffix
	])
	print("Intensity: %s" % _elemental_intensity_text(_combat_state))
	if plays_remaining <= 0 and not restriction_status.is_empty():
		print("Turn locked by %s." % restriction_status)
	_print_board()
	_print_traps()
	_print_enemies()
	_print_incoming_preview()
	_print_cards()
	if not _pending.is_empty():
		_print_pending()
	else:
		print("Commands: card N, click N, drag N play|attack|move, pass, note TEXT")

func _print_board() -> void:
	var grid: Array = _combat_state.get("grid", [])
	if grid.is_empty():
		return
	var marks: Dictionary = {}
	var player: Dictionary = _combat_state.get("player", {})
	marks[player.get("pos", Vector2i.ZERO)] = "P"
	for trap_var: Variant in _combat_state.get("traps", []):
		if typeof(trap_var) == TYPE_DICTIONARY:
			marks[(trap_var as Dictionary).get("pos", Vector2i.ZERO)] = "T"
	for loot_var: Variant in _combat_state.get("loot", []):
		if typeof(loot_var) == TYPE_DICTIONARY:
			marks[(loot_var as Dictionary).get("pos", Vector2i.ZERO)] = "$"
	for illusion_var: Variant in _combat_state.get("illusions", []):
		if typeof(illusion_var) == TYPE_DICTIONARY and int((illusion_var as Dictionary).get("hp", 0)) > 0:
			marks[(illusion_var as Dictionary).get("pos", Vector2i.ZERO)] = "I"
	var enemy_number: int = 0
	for enemy_var: Variant in _combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		if int(enemy.get("hp", 0)) <= 0:
			continue
		marks[enemy.get("pos", Vector2i.ZERO)] = str(enemy_number % 10)
		enemy_number += 1
	print("Board:")
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		var cells: Array[String] = []
		for x: int in range(row.size()):
			var tile: Vector2i = Vector2i(x, y)
			if marks.has(tile):
				cells.append(str(marks[tile]))
				continue
			match str(row[x]):
				"wall", "pillar":
					cells.append("#")
				"door":
					cells.append("D")
				_:
					cells.append(".")
		print("  %d %s" % [y, " ".join(cells)])
	print("    0 1 2 3 4 5 6 7 8")

func _print_enemies() -> void:
	print("Enemies:")
	var live_index: int = 0
	for enemy_var: Variant in _combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		if int(enemy.get("hp", 0)) <= 0:
			continue
		var enemy_def: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
		var intent: Dictionary = enemy.get("intent", {})
		print("  %d: %s at %s HP %d/%d block %d %s intent %s: %s" % [
			live_index,
			str(enemy_def.get("name", enemy.get("type", "enemy"))),
			_coord_text(enemy.get("pos", Vector2i.ZERO)),
			int(enemy.get("hp", 0)),
			int(enemy.get("max_hp", 0)),
			int(enemy.get("block", 0)),
			_status_text(enemy),
			str(intent.get("name", "")),
			_enemy_actions_summary(intent.get("actions", []))
		])
		live_index += 1

func _print_traps() -> void:
	var traps: Array = _combat_state.get("traps", [])
	if traps.is_empty():
		return
	var parts: Array[String] = []
	for trap_var: Variant in traps:
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		parts.append("%s %s" % [_coord_text(trap.get("pos", Vector2i.ZERO)), _trap_text(trap)])
	if not parts.is_empty():
		print("Traps: %s" % "; ".join(parts))

func _print_incoming_preview() -> void:
	if _combat_state.is_empty() or str(_run_state.get("mode", "")) != "combat":
		return
	var phase: Dictionary = _combat_engine.resolve_enemy_phase_with_steps(_combat_state.duplicate(true))
	var after_state: Dictionary = (phase.get("state", _combat_state) as Dictionary).duplicate(true)
	var before_player: Dictionary = _combat_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var hp_loss: int = maxi(0, int(before_player.get("hp", 0)) - int(after_player.get("hp", 0)))
	var block_loss: int = maxi(0, int(before_player.get("block", 0)) - int(after_player.get("block", 0)))
	var status_delta: String = _player_status_delta_text(before_player, after_player)
	var headline_bits: Array[String] = []
	if hp_loss > 0:
		headline_bits.append("-%d HP" % hp_loss)
	if block_loss > 0:
		headline_bits.append("-%d block" % block_loss)
	if not status_delta.is_empty():
		headline_bits.append(status_delta)
	if headline_bits.is_empty():
		headline_bits.append("no direct player hit")
	print("If you pass now: %s." % ", ".join(headline_bits))
	var step_lines: Array[String] = _enemy_phase_step_lines(phase.get("steps", []))
	for index: int in range(mini(6, step_lines.size())):
		print("  - %s" % step_lines[index])
	if step_lines.size() > 6:
		print("  - ... %d more enemy steps" % (step_lines.size() - 6))

func _print_cards() -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Cards are only available in combat.")
		return
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	print("Hand:")
	for index: int in range(hand.size()):
		var card_id: String = str(hand[index])
		var modes: Array[String] = []
		if _can_start_card(index, "printed"):
			modes.append("click")
		if _can_start_card(index, "attack"):
			modes.append("drag attack")
		if _can_start_card(index, "move"):
			modes.append("drag move")
		if _can_start_card(index, "printed"):
			modes.append("drag play")
		var card: Dictionary = _card_def(card_id, _combat_state)
		print("  %d: %s%s [%s] %s" % [
			index,
			str(card.get("name", card_id)),
			_card_cost_suffix(card),
			"; ".join(modes) if not modes.is_empty() else "no legal input",
			_action_summary(card.get("actions", []))
		])

func _command_card(parts: PackedStringArray) -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Not in combat.")
		return
	if parts.size() < 2:
		_print_cards()
		return
	var hand_index: int = int(parts[1])
	if parts.size() >= 3:
		var requested: String = parts[2].strip_edges().to_lower()
		if requested in ["attack", "move", "fallback_attack", "fallback_move"]:
			print("In the game, fallback attack/move is selected by dragging into a lane. Use `drag %d %s`." % [hand_index, "attack" if requested.contains("attack") else "move"])
			return
		if requested not in ["printed", "play"]:
			print("Clicking a card only uses its printed text. Use `drag N play|attack|move` for drag lanes.")
			return
	_start_card_from_input(hand_index, "printed", "click")

func _command_drag(parts: PackedStringArray) -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Not in combat.")
		return
	if parts.size() < 3:
		print("Drag needs a card and lane: `drag N play|attack|move`.")
		_print_cards()
		return
	var hand_index: int = int(parts[1])
	var lane: String = parts[2].strip_edges().to_lower()
	if lane == "printed":
		lane = "play"
	if lane == "fallback_attack":
		lane = "attack"
	if lane == "fallback_move":
		lane = "move"
	var mode: String = "printed" if lane == "play" else lane
	if lane not in ["play", "attack", "move"]:
		print("Unknown drag lane: %s. Use play, attack, or move." % lane)
		return
	_start_card_from_input(hand_index, mode, "drag %s" % lane)

func _start_card_from_input(hand_index: int, mode: String, input_label: String) -> void:
	if not _can_start_card(hand_index, mode):
		print("That card/mode is not legal right now.")
		_print_cards()
		return
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	var card_id: String = str(hand[hand_index])
	_pending = {
		"hand_index": hand_index,
		"card_id": card_id,
		"mode": mode,
		"input_label": input_label,
		"actions": _actions_for_card_mode(card_id, mode),
		"action_index": 0,
		"state": _combat_state.duplicate(true),
		"targets": _vector2i_array([]),
		"effect_seen": false,
		"skip_allowed": false,
		"target_tiles": _vector2i_array([])
	}
	_continue_pending()

func _can_start_card(hand_index: int, mode: String) -> bool:
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return false
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id: String = str(hand[hand_index])
	var preview: Dictionary = _preview_actions(_combat_state, card_id, _actions_for_card_mode(card_id, mode), 0, false)
	return bool(preview.get("playable", false))

func _actions_for_card_mode(card_id: String, mode: String) -> Array:
	match mode:
		"attack":
			return FALLBACK_ATTACK.duplicate(true)
		"move":
			return FALLBACK_MOVE.duplicate(true)
		_:
			return (_card_def(card_id, _combat_state).get("actions", []) as Array).duplicate(true)

func _continue_pending() -> void:
	if _pending.is_empty():
		return
	var working_state: Dictionary = (_pending.get("state", {}) as Dictionary).duplicate(true)
	var actions: Array = (_pending.get("actions", []) as Array)
	var cursor: int = int(_pending.get("action_index", 0))
	var effect_seen: bool = bool(_pending.get("effect_seen", false))
	while cursor < actions.size():
		var action: Dictionary = actions[cursor]
		if not _combat_engine.player_action_can_resolve(working_state, action):
			if _combat_engine.player_action_needs_target(action):
				var targets: Array[Vector2i] = _pending.get("targets", [])
				targets.append(INVALID_TARGET_TILE)
				_pending["targets"] = targets
			cursor += 1
			continue
		if str(action.get("type", "")) == "aoe" and int(action.get("range", 0)) <= 0:
			if _combat_engine.valid_targets_for_player_action(working_state, action).is_empty():
				cursor += 1
				continue
			working_state = _combat_engine.apply_player_action(working_state, action)
			effect_seen = true
			cursor += 1
			continue
		if _combat_engine.player_action_needs_target(action):
			var target_tiles: Array[Vector2i] = _combat_engine.valid_targets_for_player_action(working_state, action)
			var playable_targets: Array[Vector2i] = []
			for target: Vector2i in target_tiles:
				var next_state: Dictionary = _combat_engine.apply_player_action(working_state, action, target)
				var continuation: Dictionary = _preview_actions(next_state, str(_pending.get("card_id", "")), actions, cursor + 1, true)
				if bool(continuation.get("playable", false)):
					playable_targets.append(target)
			var skip_allowed: bool = _target_action_can_skip(action, actions) and bool(_preview_actions(working_state, str(_pending.get("card_id", "")), actions, cursor + 1, effect_seen).get("playable", false))
			_pending["state"] = working_state
			_pending["action_index"] = cursor
			_pending["effect_seen"] = effect_seen
			_pending["target_tiles"] = _vector2i_array(playable_targets)
			_pending["skip_allowed"] = skip_allowed
			if playable_targets.is_empty() and skip_allowed:
				cursor += 1
				var skip_targets: Array[Vector2i] = _pending.get("targets", [])
				skip_targets.append(INVALID_TARGET_TILE)
				_pending["targets"] = skip_targets
				continue
			_print_pending()
			return
		var before_state: Dictionary = working_state.duplicate(true)
		working_state = _combat_engine.apply_player_action(working_state, action)
		if JSON.stringify(before_state) != JSON.stringify(working_state):
			effect_seen = true
		cursor += 1
	_pending["state"] = working_state
	_pending["action_index"] = cursor
	_pending["effect_seen"] = effect_seen
	if effect_seen:
		_commit_pending()
	else:
		print("Card produced no effect.")
		_pending = {}
		_print_state()

func _print_pending() -> void:
	if _pending.is_empty():
		print("No pending card.")
		return
	var action: Dictionary = (_pending.get("actions", []) as Array)[int(_pending.get("action_index", 0))]
	print("Pending %s via %s | action %d/%d: %s" % [
		str(_card_def(str(_pending.get("card_id", "")), _combat_state).get("name", _pending.get("card_id", ""))),
		str(_pending.get("input_label", "click")),
		int(_pending.get("action_index", 0)) + 1,
		(_pending.get("actions", []) as Array).size(),
		_action_text(action)
	])
	var choices: Array = _pending_target_choices()
	if choices.is_empty():
		print("No legal targets.")
	else:
		print("Targets:")
		for index: int in range(choices.size()):
			var choice: Dictionary = choices[index]
			var tile: Vector2i = choice.get("tile", INVALID_TARGET_TILE)
			print("  %d: %s %s" % [index, _pending_choice_label(choice), _pending_choice_hint(choice)])
	if bool(_pending.get("skip_allowed", false)):
		print("Skip would omit this action and continue: %s" % _action_text(action))
		print("Command: target N|eN|x,y, skip, cancel")
	else:
		print("Command: target N|eN|x,y, cancel")

func _command_target(raw: String) -> void:
	if _pending.is_empty():
		print("No pending card.")
		return
	var choices: Array = _pending_target_choices()
	var choice: Dictionary = {}
	var chosen: Vector2i = INVALID_TARGET_TILE
	var normalized: String = raw.strip_edges().to_lower()
	if normalized.begins_with("enemy") or normalized.begins_with("e"):
		var enemy_text: String = normalized.substr(5).strip_edges() if normalized.begins_with("enemy") else normalized.substr(1).strip_edges()
		chosen = _live_enemy_tile_by_index((_pending.get("state", {}) as Dictionary), int(enemy_text))
		choice = _choice_for_target_tile(choices, chosen)
	elif raw.contains(","):
		var coords: PackedStringArray = raw.split(",", false)
		if coords.size() == 2:
			chosen = Vector2i(int(coords[0]), int(coords[1]))
		choice = _choice_for_target_tile(choices, chosen)
	else:
		var index: int = int(raw)
		if index >= 0 and index < choices.size():
			choice = choices[index]
			chosen = choice.get("tile", INVALID_TARGET_TILE)
	if choice.is_empty():
		print("That target is not legal.")
		_print_pending()
		return
	if str(choice.get("kind", "")) == "shortcut":
		_apply_pending_shortcut(choice)
		return
	var action: Dictionary = (_pending.get("actions", []) as Array)[int(_pending.get("action_index", 0))]
	var working_state: Dictionary = (_pending.get("state", {}) as Dictionary).duplicate(true)
	working_state = _combat_engine.apply_player_action(working_state, action, chosen)
	var selected: Array[Vector2i] = _pending.get("targets", [])
	selected.append(chosen)
	_pending["targets"] = selected
	_pending["state"] = working_state
	_pending["action_index"] = int(_pending.get("action_index", 0)) + 1
	_pending["effect_seen"] = true
	_continue_pending()

func _pending_target_choices() -> Array:
	var choices: Array = []
	if _pending.is_empty():
		return choices
	var shortcut_plans: Dictionary = _shortcut_attack_plans_for_pending()
	for tile_var: Variant in shortcut_plans.keys():
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		choices.append({
			"kind": "shortcut",
			"tile": tile_var,
			"plan": shortcut_plans[tile_var]
		})
	for target: Vector2i in _vector2i_array(_pending.get("target_tiles", [])):
		if shortcut_plans.has(target):
			continue
		choices.append({
			"kind": "target",
			"tile": target
		})
	return choices

func _pending_choice_label(choice: Dictionary) -> String:
	var tile: Vector2i = choice.get("tile", INVALID_TARGET_TILE)
	var enemy_label: String = _enemy_label_at_tile((_pending.get("state", {}) as Dictionary), tile)
	if not enemy_label.is_empty():
		return "%s at %s" % [enemy_label, _coord_text(tile)]
	return _coord_text(tile)

func _choice_for_target_tile(choices: Array, tile: Vector2i) -> Dictionary:
	for choice_var: Variant in choices:
		if typeof(choice_var) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = choice_var
		if candidate.get("tile", INVALID_TARGET_TILE) != tile:
			continue
		if str(candidate.get("kind", "")) == "shortcut":
			return candidate
		if candidate.is_empty():
			continue
		return candidate
	return {}

func _enemy_label_at_tile(state: Dictionary, tile: Vector2i) -> String:
	var live_index: int = 0
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if enemy.get("pos", Vector2i.ZERO) == tile:
			return "enemy %d" % live_index
		live_index += 1
	return ""

func _live_enemy_tile_by_index(state: Dictionary, target_index: int) -> Vector2i:
	var live_index: int = 0
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if live_index == target_index:
			return enemy.get("pos", INVALID_TARGET_TILE)
		live_index += 1
	return INVALID_TARGET_TILE

func _pending_choice_hint(choice: Dictionary) -> String:
	var kind: String = str(choice.get("kind", "target"))
	if kind == "shortcut":
		var plan: Dictionary = choice.get("plan", {})
		var move_target: Vector2i = plan.get("move_target", INVALID_TARGET_TILE)
		var action: Dictionary = plan.get("action", {})
		var state: Dictionary = (plan.get("state", {}) as Dictionary).duplicate(true)
		var move_text: String = "skip move" if move_target.x < 0 else "move %s" % _coord_text(move_target)
		var move_risk: String = _movement_risk_text(
			(_pending.get("state", {}) as Dictionary),
			((_pending.get("actions", []) as Array)[int(_pending.get("action_index", 0))] as Dictionary),
			move_target,
			_vector2i_array(plan.get("path_tiles", []))
		)
		var risk_suffix: String = "" if move_risk.is_empty() else ", %s" % move_risk
		return "(shortcut: %s%s, then %s)" % [move_text, risk_suffix, _target_hint(state, action, choice.get("tile", INVALID_TARGET_TILE))]
	var action: Dictionary = (_pending.get("actions", []) as Array)[int(_pending.get("action_index", 0))]
	return _target_hint((_pending.get("state", {}) as Dictionary), action, choice.get("tile", INVALID_TARGET_TILE))

func _shortcut_attack_plans_for_pending() -> Dictionary:
	var plans: Dictionary = {}
	if _pending.is_empty():
		return plans
	var actions: Array = _pending.get("actions", [])
	var action_index: int = int(_pending.get("action_index", -1))
	if action_index < 0 or action_index >= actions.size():
		return plans
	var action: Dictionary = actions[action_index]
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["move", "blink"]:
		return plans
	var preview_state: Dictionary = (_pending.get("state", {}) as Dictionary).duplicate(true)
	if preview_state.is_empty():
		return plans
	var player_tile: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var card_id: String = str(_pending.get("card_id", ""))
	for move_target: Vector2i in _vector2i_array(_pending.get("target_tiles", [])):
		var after_move_state: Dictionary = _combat_engine.apply_player_action(preview_state, action, move_target)
		var path_tiles: Array[Vector2i] = _vector2i_array([move_target]) if action_type == "blink" else _combat_engine.path_for_player_action(preview_state, action, move_target)
		var move_distance: int = PathUtils.manhattan(player_tile, move_target) if action_type == "blink" else maxi(0, path_tiles.size() - 1)
		_collect_shortcut_attack_plans(plans, card_id, actions, action_index, after_move_state, move_target, move_target, move_distance, path_tiles)
	if bool(_pending.get("skip_allowed", false)):
		_collect_shortcut_attack_plans(plans, card_id, actions, action_index, preview_state, INVALID_TARGET_TILE, player_tile, 0, [])
	return plans

func _collect_shortcut_attack_plans(plans: Dictionary, card_id: String, actions: Array, action_index: int, base_state: Dictionary, move_target: Vector2i, move_tile: Vector2i, move_distance: int, path_tiles: Array[Vector2i]) -> void:
	var followup: Dictionary = _next_shortcut_attack_step(base_state, actions, action_index + 1)
	if followup.is_empty():
		return
	var followup_state: Dictionary = followup.get("state", {})
	var followup_action: Dictionary = followup.get("action", {})
	var followup_index: int = int(followup.get("action_index", -1))
	for enemy_tile: Vector2i in _combat_engine.valid_targets_for_player_action(followup_state, followup_action):
		var after_attack_state: Dictionary = _combat_engine.apply_player_action(followup_state, followup_action, enemy_tile)
		var continuation: Dictionary = _preview_actions(after_attack_state, card_id, actions, followup_index + 1, true)
		if not bool(continuation.get("playable", false)):
			continue
		var trap_risk: int = _shortcut_path_trap_risk(base_state, path_tiles)
		var existing: Dictionary = plans.get(enemy_tile, {})
		if not existing.is_empty():
			var existing_trap_risk: int = int(existing.get("trap_risk", 999999))
			if trap_risk > existing_trap_risk:
				continue
			if trap_risk == existing_trap_risk:
				var existing_distance: int = int(existing.get("move_distance", 99999))
				var existing_path_length: int = _vector2i_array(existing.get("path_tiles", [])).size()
				if move_distance > existing_distance:
					continue
				if move_distance == existing_distance and path_tiles.size() >= existing_path_length:
					continue
		plans[enemy_tile] = {
			"state": followup_state.duplicate(true),
			"move_target": move_target,
			"move_tile": move_tile,
			"move_distance": move_distance,
			"trap_risk": trap_risk,
			"path_tiles": path_tiles.duplicate(),
			"action_index": followup_index,
			"action": followup_action.duplicate(true)
		}

func _shortcut_path_trap_risk(state: Dictionary, path_tiles: Array[Vector2i]) -> int:
	var risk: int = 0
	for tile: Vector2i in path_tiles:
		var trap: Dictionary = _trap_at_tile(state, tile)
		if trap.is_empty():
			continue
		risk += 1000
		risk += int(trap.get("damage", 0)) * 10
		for key: String in ["burn", "freeze", "shock", "poison"]:
			risk += int(trap.get(key, 0)) * 5
	return risk

func _next_shortcut_attack_step(state: Dictionary, actions: Array, action_index: int) -> Dictionary:
	var working_state: Dictionary = state.duplicate(true)
	var cursor: int = action_index
	while cursor < actions.size():
		var action: Dictionary = actions[cursor]
		if not _combat_engine.player_action_can_resolve(working_state, action):
			cursor += 1
			continue
		if _combat_engine.player_action_needs_target(action):
			var action_type: String = str(action.get("type", ""))
			if action_type not in SHORTCUT_ATTACK_TYPES:
				return {}
			return {
				"state": working_state,
				"action_index": cursor,
				"action": action
			}
		working_state = _combat_engine.apply_player_action(working_state, action)
		cursor += 1
	return {}

func _apply_pending_shortcut(choice: Dictionary) -> void:
	var plan: Dictionary = choice.get("plan", {})
	if plan.is_empty():
		print("That shortcut is not legal.")
		_print_pending()
		return
	var move_target: Vector2i = plan.get("move_target", INVALID_TARGET_TILE)
	var attack_target: Vector2i = choice.get("tile", INVALID_TARGET_TILE)
	var previous_action_index: int = int(_pending.get("action_index", 0))
	var selected: Array[Vector2i] = _pending.get("targets", [])
	selected.append(move_target)
	_append_skipped_targets(selected, previous_action_index + 1, int(plan.get("action_index", 0)))
	selected.append(attack_target)
	_pending["targets"] = selected
	_pending["state"] = _combat_engine.apply_player_action((plan.get("state", {}) as Dictionary).duplicate(true), plan.get("action", {}), attack_target)
	_pending["action_index"] = int(plan.get("action_index", 0)) + 1
	_pending["effect_seen"] = true
	_continue_pending()

func _append_skipped_targets(targets: Array[Vector2i], start_action_index: int, end_action_index: int) -> void:
	var actions: Array = _pending.get("actions", [])
	var safe_start: int = maxi(0, start_action_index)
	var safe_end: int = mini(end_action_index, actions.size())
	for index: int in range(safe_start, safe_end):
		if _combat_engine.player_action_needs_target(actions[index]):
			targets.append(INVALID_TARGET_TILE)

func _command_skip() -> void:
	if _pending.is_empty() or not bool(_pending.get("skip_allowed", false)):
		print("Skip is not available.")
		return
	var selected: Array[Vector2i] = _pending.get("targets", [])
	selected.append(INVALID_TARGET_TILE)
	_pending["targets"] = selected
	_pending["action_index"] = int(_pending.get("action_index", 0)) + 1
	_continue_pending()

func _commit_pending() -> void:
	var before_run_state: Dictionary = _run_state.duplicate(true)
	var before_combat_state: Dictionary = _combat_state.duplicate(true)
	var before_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var resolved_state: Dictionary = (_pending.get("state", {}) as Dictionary).duplicate(true)
	var card_id: String = str(_pending.get("card_id", ""))
	var hand_index: int = int(_pending.get("hand_index", -1))
	var instance_id: String = _analytics_hand_instance_id(hand_index)
	var actions: Array = (_pending.get("actions", []) as Array).duplicate(true)
	var targets: Array[Vector2i] = _vector2i_array(_pending.get("targets", []))
	_combat_state = _combat_engine.finish_player_card(resolved_state, hand_index)
	_analytics_reconcile_combat_tracker(before_combat_state, _combat_state)
	_log_card_draws(before_combat_state, _combat_state, before_tracker, _analytics_snapshot_combat_tracker(), "card_effect")
	var outcome: String = _combat_engine.combat_outcome(_combat_state)
	var transition_state: Dictionary = _combat_state.duplicate(true)
	_log_card_played(card_id, instance_id, before_combat_state, transition_state, actions, targets)
	if outcome.is_empty():
		_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	else:
		_run_state = _run_engine.finish_combat(_run_state, _combat_state)
	_sync_combat_state_from_run()
	_log_playable_cards()
	_log_combat_transition(before_run_state, "card_play", transition_state)
	_append_note("- Played %s as %s: %s.\n" % [card_id, str(_pending.get("mode", "")), _card_delta_text(before_combat_state, transition_state)])
	_print_card_resolution(card_id, before_combat_state, transition_state, actions, targets)
	_pending = {}
	if str(_run_state.get("mode", "")) == "combat" and _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		_resolve_enemy_round("auto_end_turn")
	else:
		_print_state()

func _command_pass() -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Not in combat.")
		return
	_pending = {}
	_resolve_enemy_round("pass")

func _resolve_enemy_round(reason: String) -> void:
	var before_run_state: Dictionary = _run_state.duplicate(true)
	var before_combat_state: Dictionary = _combat_state.duplicate(true)
	var before_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var phase: Dictionary = _combat_engine.resolve_enemy_phase_with_steps(_combat_state)
	var after_enemy_state: Dictionary = (phase.get("state", {}) as Dictionary).duplicate(true)
	_log_enemy_status_ticks(phase, after_enemy_state)
	var hp_before: int = int((before_combat_state.get("player", {}) as Dictionary).get("hp", 0))
	var hp_after_enemy: int = int((after_enemy_state.get("player", {}) as Dictionary).get("hp", 0))
	var outcome: String = _combat_engine.combat_outcome(after_enemy_state)
	_combat_state = after_enemy_state
	var before_draw_state: Dictionary = _combat_state.duplicate(true)
	var next_turn_state: Dictionary = {}
	if outcome.is_empty():
		_combat_state = _combat_engine.prepare_next_player_turn(_combat_state)
		next_turn_state = _combat_state.duplicate(true)
		_analytics_reconcile_combat_tracker(before_draw_state, _combat_state)
		_log_card_draws(before_draw_state, _combat_state, before_tracker, _analytics_snapshot_combat_tracker(), "turn_draw")
		_log_playable_cards()
		outcome = _combat_engine.combat_outcome(_combat_state)
	var transition_state: Dictionary = _combat_state.duplicate(true)
	if outcome.is_empty():
		_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	else:
		_run_state = _run_engine.finish_combat(_run_state, _combat_state)
	_sync_combat_state_from_run()
	_log_combat_transition(before_run_state, reason, transition_state)
	_append_note("- Enemy round: %d HP lost, mode now %s.\n" % [maxi(0, hp_before - hp_after_enemy), str(_run_state.get("mode", ""))])
	_print_enemy_round_resolution(phase, before_combat_state, after_enemy_state, before_draw_state, next_turn_state)
	_print_state()

func _print_reward_state() -> void:
	var reward: Dictionary = _run_state.get("pending_reward", {})
	print("Reward | heal %d | ember amount %d" % [int(reward.get("heal_amount", 0)), int(reward.get("ember_amount", 0))])
	var cards: Array = reward.get("cards", [])
	for index: int in range(cards.size()):
		var card_id: String = str(cards[index])
		var card: Dictionary = GameData.card_def(card_id)
		print("  %d: %s%s (%s) %s" % [index, str(card.get("name", card_id)), _card_cost_suffix(card), str(card.get("rarity", "")), _action_summary(card.get("actions", []))])
	print("Commands: reward N, reward heal")

func _command_reward(parts: PackedStringArray) -> void:
	if str(_run_state.get("mode", "")) != "reward":
		print("Not in reward mode.")
		return
	var reward: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	var hp_before: int = int(_run_state.get("player_hp", 0))
	if parts.size() < 2:
		_print_reward_state()
		return
	if parts[1].to_lower() == "heal":
		_run_state = _run_engine.skip_reward_for_heal(_run_state)
		_sync_combat_state_from_run()
		_log_reward_choice("heal_skip", "", reward, hp_before, int(_run_state.get("player_hp", hp_before)))
		_append_note("- Reward: skipped for heal to %d/%d.\n" % [int(_run_state.get("player_hp", 0)), int(_run_state.get("player_max_hp", 0))])
		_print_state()
		return
	var index: int = int(parts[1])
	var cards: Array = reward.get("cards", [])
	if index < 0 or index >= cards.size():
		print("Bad reward index.")
		_print_reward_state()
		return
	var card_id: String = str(cards[index])
	_run_state = _run_engine.claim_card_reward(_run_state, card_id)
	_sync_combat_state_from_run()
	_log_reward_choice("card", card_id, reward, hp_before, int(_run_state.get("player_hp", hp_before)))
	_append_note("- Reward: took %s.\n" % str(GameData.card_def(card_id).get("name", card_id)))
	_print_state()

func _print_relic_state() -> void:
	var relics: Array = _run_state.get("pending_relics", [])
	print("Relics:")
	for index: int in range(relics.size()):
		var relic_id: String = str(relics[index])
		var relic: Dictionary = GameData.relic_def(relic_id)
		print("  %d: %s - %s" % [index, str(relic.get("name", relic_id)), str(relic.get("description", ""))])
	print("Command: relic N")

func _command_relic(parts: PackedStringArray) -> void:
	if str(_run_state.get("mode", "")) != "treasure":
		print("Not in treasure mode.")
		return
	if parts.size() < 2:
		_print_relic_state()
		return
	var relics: Array = _run_state.get("pending_relics", [])
	var index: int = int(parts[1])
	if index < 0 or index >= relics.size():
		print("Bad relic index.")
		_print_relic_state()
		return
	var relic_id: String = str(relics[index])
	_run_state = _run_engine.claim_relic(_run_state, relic_id)
	_sync_combat_state_from_run()
	_append_note("- Treasure: took %s.\n" % str(GameData.relic_def(relic_id).get("name", relic_id)))
	_print_state()

func _command_leave() -> void:
	if str(_run_state.get("mode", "")) != "campfire":
		print("Not at campfire.")
		return
	_append_note("- Campfire: left with %d unbanked embers.\n" % int(_run_state.get("unbanked_embers", 0)))
	_run_state = _run_engine.leave_campfire(_run_state)
	_sync_combat_state_from_run()
	_print_state()

func _command_rest() -> void:
	if str(_run_state.get("mode", "")) != "campfire":
		print("Not at campfire.")
		return
	var banked: int = _run_engine.bankable_embers(_run_state)
	_progression = ProgressionStore.add_embers(_progression, banked)
	_progression = ProgressionStore.mark_rested_at_fire(_progression)
	_run_state = _run_engine.consume_banked_embers(_run_state)
	_run_state["mode"] = "rested"
	_run_state["game_over"] = true
	_log_run_ended("rested")
	_append_note("- Campfire: rested and banked %d embers.\n" % banked)
	_print_state()

func _preview_actions(state: Dictionary, card_id: String, actions: Array, action_index: int, has_effect: bool) -> Dictionary:
	var working_state: Dictionary = state.duplicate(true)
	var cursor: int = action_index
	var effect_seen: bool = has_effect or action_index > 0
	while cursor < actions.size():
		var action: Dictionary = actions[cursor]
		if not _combat_engine.player_action_can_resolve(working_state, action):
			cursor += 1
			continue
		if str(action.get("type", "")) == "aoe" and int(action.get("range", 0)) <= 0:
			if _combat_engine.valid_targets_for_player_action(working_state, action).is_empty():
				cursor += 1
				continue
			working_state = _combat_engine.apply_player_action(working_state, action)
			effect_seen = true
			cursor += 1
			continue
		if _combat_engine.player_action_needs_target(action):
			var skip_allowed: bool = _target_action_can_skip(action, actions)
			var skip_playable: bool = false
			if skip_allowed:
				skip_playable = bool(_preview_actions(working_state, card_id, actions, cursor + 1, effect_seen).get("playable", false))
			var valid_targets: Array[Vector2i] = []
			for target_tile: Vector2i in _combat_engine.valid_targets_for_player_action(working_state, action):
				var next_state: Dictionary = _combat_engine.apply_player_action(working_state, action, target_tile)
				var continuation: Dictionary = _preview_actions(next_state, card_id, actions, cursor + 1, true)
				if bool(continuation.get("playable", false)):
					valid_targets.append(target_tile)
			if valid_targets.is_empty() and skip_playable:
				cursor += 1
				continue
			return {"playable": not valid_targets.is_empty(), "complete": false}
		working_state = _combat_engine.apply_player_action(working_state, action)
		effect_seen = true
		cursor += 1
	return {"playable": effect_seen, "complete": true}

func _target_action_can_skip(action: Dictionary, actions: Array) -> bool:
	if bool(action.get("required", false)):
		return false
	if bool(action.get("optional", false)):
		return true
	return actions.size() > 1

func _sync_combat_state_from_run() -> void:
	_combat_state = (_run_state.get("combat_state", {}) as Dictionary).duplicate(true)

func _ensure_run_analytics_metadata(run_state: Dictionary, run_number: int) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var analytics: Dictionary = (next_state.get("analytics", {}) as Dictionary).duplicate(true)
	analytics["run_id"] = "manual_%02d_%d" % [run_number, int(next_state.get("seed", 0))]
	analytics["combat_counter"] = int(analytics.get("combat_counter", 0))
	next_state["analytics"] = analytics
	return next_state

func _attach_new_combat_analytics(previous_run_state: Dictionary, reason: String) -> void:
	var analytics: Dictionary = (_run_state.get("analytics", {}) as Dictionary).duplicate(true)
	analytics["combat_counter"] = int(analytics.get("combat_counter", 0)) + 1
	_run_state["analytics"] = analytics
	var combat_analytics: Dictionary = (_combat_state.get("analytics", {}) as Dictionary).duplicate(true)
	combat_analytics["combat_id"] = "%s_c%03d" % [str(analytics.get("run_id", "")), int(analytics.get("combat_counter", 0))]
	_combat_state["analytics"] = combat_analytics
	_run_state["combat_state"] = _combat_state.duplicate(true)
	_analytics_initialize_combat_tracker(_combat_state)
	_log_combat_started(reason)
	_log_card_draws({}, _combat_state, {}, _analytics_snapshot_combat_tracker(), "opening_hand")
	_log_playable_cards()

func _analytics_context(combat_state: Dictionary = _combat_state, card_id: String = "", card_instance_id: String = "") -> Dictionary:
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary) if not combat_state.is_empty() else {}
	var combat_analytics: Dictionary = (combat_state.get("analytics", {}) as Dictionary).duplicate(true)
	var run_analytics: Dictionary = (_run_state.get("analytics", {}) as Dictionary).duplicate(true)
	var context: Dictionary = {
		"run_id": str(run_analytics.get("run_id", "")),
		"combat_id": str(combat_analytics.get("combat_id", "")),
		"turn": int(combat_state.get("turn", 0)),
		"room_depth": int(combat_state.get("room_depth", 0)),
		"room_element": str(combat_state.get("room_element", "")),
		"player_hp": int(player.get("hp", _run_state.get("player_hp", -1))),
		"player_max_hp": int(player.get("max_hp", _run_state.get("player_max_hp", -1))),
		"deck_size": int((_run_state.get("deck_cards", []) as Array).size()),
		"card_id": card_id,
		"card_instance_id": card_instance_id
	}
	if not combat_state.is_empty():
		context["elemental_intensity"] = _combat_engine.elemental_intensities(combat_state)
	return context

func _log_run_started() -> void:
	_analytics_store.write_event("run_started", _analytics_context({}), {
		"seed": int(_run_state.get("seed", 0)),
		"run_index": int(_run_state.get("run_index", 0)),
		"player_start_hp": int(_run_state.get("player_hp", 0)),
		"player_max_hp": int(_run_state.get("player_max_hp", 0)),
		"starting_deck": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"driver": "manual_headless"
	})

func _log_run_ended(outcome: String) -> void:
	_analytics_store.write_event("run_ended", _analytics_context(_combat_state), {
		"outcome": outcome,
		"turns_spent": int(_run_state.get("turns_spent", 0)),
		"unbanked_embers": int(_run_state.get("unbanked_embers", 0)),
		"mode": str(_run_state.get("mode", ""))
	})

func _log_combat_started(reason: String) -> void:
	_analytics_store.write_event("combat_started", _analytics_context(_combat_state), {
		"reason": reason,
		"room_name": str(_combat_state.get("room_name", "")),
		"room_type": str(_combat_state.get("room_type", "")),
		"room_coord": _combat_state.get("room_coord", Vector2i.ZERO),
		"elemental_intensity": _combat_engine.elemental_intensities(_combat_state),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"opening_hand": _analytics_zone_cards(_combat_state, "hand")
	})

func _log_combat_transition(previous_run_state: Dictionary, reason: String, transition_combat_state: Dictionary) -> void:
	var previous_mode: String = str(previous_run_state.get("mode", "room"))
	var next_mode: String = str(_run_state.get("mode", "room"))
	if previous_mode == "combat" and next_mode != "combat" and not transition_combat_state.is_empty():
		_analytics_store.write_event("combat_ended", _analytics_context(transition_combat_state), {
			"reason": reason,
			"outcome": _combat_engine.combat_outcome(transition_combat_state),
			"turn": int(transition_combat_state.get("turn", 0)),
			"room_embers": int(transition_combat_state.get("room_embers", 0)),
			"remaining_player_hp": int((transition_combat_state.get("player", {}) as Dictionary).get("hp", 0))
		})
		if next_mode == "reward":
			var reward: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
			_analytics_store.write_event("reward_offered", _analytics_context(transition_combat_state), {
				"reason": reason,
				"offered_cards": (reward.get("cards", []) as Array).duplicate(true),
				"heal_amount": int(reward.get("heal_amount", 0)),
				"ember_amount": int(reward.get("ember_amount", 0))
			})
		elif next_mode in ["victory", "defeat"]:
			_log_run_ended(next_mode)
		_analytics_tracker = {}

func _log_reward_choice(choice_kind: String, card_id: String, reward: Dictionary, hp_before: int, hp_after: int) -> void:
	_analytics_store.write_event("reward_choice", _analytics_context({}, card_id), {
		"choice_kind": choice_kind,
		"selected_card_id": card_id,
		"offered_cards": (reward.get("cards", []) as Array).duplicate(true),
		"heal_amount": int(reward.get("heal_amount", 0)),
		"ember_amount": int(reward.get("ember_amount", 0)),
		"player_hp_before": hp_before,
		"player_hp_after": hp_after
	})

func _log_card_played(card_id: String, instance_id: String, before_state: Dictionary, resolved_state: Dictionary, actions: Array, targets: Array[Vector2i]) -> void:
	_analytics_store.write_event("card_played", _analytics_context(before_state, card_id, instance_id), _card_play_payload(card_id, before_state, resolved_state, actions, targets))

func _log_enemy_status_ticks(phase: Dictionary, combat_state: Dictionary) -> void:
	for step_var: Variant in phase.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		var kind: String = str(step.get("kind", ""))
		if kind not in ["status_damage", "status"]:
			continue
		_analytics_store.write_event("enemy_status_tick", _analytics_context(combat_state), {
			"kind": kind,
			"actor_key": str(step.get("actor_key", "")),
			"actor_name": str(step.get("actor_name", "")),
			"label": str(step.get("label", "")),
			"amount": int(step.get("amount", 0)),
			"text": str(step.get("text", "")),
			"tile": step.get("tile", Vector2i(-1, -1))
		})

func _analytics_initialize_combat_tracker(combat_state: Dictionary) -> void:
	var tracker: Dictionary = {
		"combat_id": str((combat_state.get("analytics", {}) as Dictionary).get("combat_id", "")),
		"next_instance_seq": 1,
		"playable_logged": {},
		"zones": {}
	}
	var zones: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var zone_cards: Array[String] = _analytics_zone_cards(combat_state, zone)
		var zone_ids: Array[String] = []
		for _card_id: String in zone_cards:
			zone_ids.append(_analytics_next_card_instance_id(tracker))
		zones[zone] = zone_ids
	tracker["zones"] = zones
	_analytics_tracker = tracker

func _analytics_snapshot_combat_tracker() -> Dictionary:
	return _analytics_tracker.duplicate(true)

func _analytics_zone_cards(state: Dictionary, zone: String) -> Array[String]:
	var cards: Array[String] = []
	var zone_values: Array = ((state.get("deck", {}) as Dictionary).get(zone, []) as Array)
	for card_id_var: Variant in zone_values:
		cards.append(str(card_id_var))
	return cards

func _analytics_zone_ids(tracker: Dictionary, zone: String) -> Array:
	if tracker.is_empty():
		return []
	return ((tracker.get("zones", {}) as Dictionary).get(zone, []) as Array).duplicate(true)

func _analytics_hand_instance_id(hand_index: int) -> String:
	var hand_ids: Array = _analytics_zone_ids(_analytics_tracker, "hand")
	if hand_index < 0 or hand_index >= hand_ids.size():
		return ""
	return str(hand_ids[hand_index])

func _analytics_reconcile_combat_tracker(before_state: Dictionary, after_state: Dictionary) -> void:
	if _analytics_tracker.is_empty():
		_analytics_initialize_combat_tracker(after_state)
		return
	var cross_pool: Dictionary = {}
	var same_zone_ids: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var before_cards: Array[String] = _analytics_zone_cards(before_state, zone)
		var before_ids: Array = _analytics_zone_ids(_analytics_tracker, zone)
		var after_cards: Array[String] = _analytics_zone_cards(after_state, zone)
		var same_zone_pool: Dictionary = {}
		for index: int in range(mini(before_cards.size(), before_ids.size())):
			_analytics_enqueue_instance_id(same_zone_pool, before_cards[index], str(before_ids[index]))
		var assigned_ids: Array[String] = []
		for card_id: String in after_cards:
			assigned_ids.append(_analytics_take_from_pool(same_zone_pool, card_id))
		same_zone_ids[zone] = assigned_ids
		for pool_card_id_var: Variant in same_zone_pool.keys():
			for leftover_id_var: Variant in same_zone_pool[pool_card_id_var]:
				_analytics_enqueue_instance_id(cross_pool, str(pool_card_id_var), str(leftover_id_var))
	_update_analytics_zone_ids_from_pool(after_state, same_zone_ids, cross_pool)

func _update_analytics_zone_ids_from_pool(after_state: Dictionary, zone_ids: Dictionary, cross_pool: Dictionary) -> void:
	var next_zones: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var after_cards: Array[String] = _analytics_zone_cards(after_state, zone)
		var resolved_ids: Array = (zone_ids.get(zone, []) as Array).duplicate(true)
		for index: int in range(resolved_ids.size()):
			if not str(resolved_ids[index]).is_empty():
				continue
			var card_id: String = after_cards[index]
			var instance_id: String = _analytics_take_from_pool(cross_pool, card_id)
			if instance_id.is_empty():
				instance_id = _analytics_next_card_instance_id(_analytics_tracker)
			resolved_ids[index] = instance_id
		next_zones[zone] = resolved_ids
	_analytics_tracker["zones"] = next_zones

func _analytics_enqueue_instance_id(pool: Dictionary, card_id: String, instance_id: String) -> void:
	if not pool.has(card_id):
		pool[card_id] = []
	(pool[card_id] as Array).append(instance_id)

func _analytics_take_from_pool(pool: Dictionary, card_id: String) -> String:
	if not pool.has(card_id) or (pool[card_id] as Array).is_empty():
		return ""
	var queue: Array = pool[card_id]
	var instance_id: String = str(queue[0])
	queue.remove_at(0)
	pool[card_id] = queue
	return instance_id

func _analytics_next_card_instance_id(tracker: Dictionary) -> String:
	var next_seq: int = int(tracker.get("next_instance_seq", 1))
	tracker["next_instance_seq"] = next_seq + 1
	return "%s_i%03d" % [str(tracker.get("combat_id", "combat")), next_seq]

func _log_card_draws(before_state: Dictionary, after_state: Dictionary, before_tracker: Dictionary, after_tracker: Dictionary, reason: String) -> void:
	var before_hand_ids: Dictionary = {}
	for instance_id_var: Variant in _analytics_zone_ids(before_tracker, "hand"):
		before_hand_ids[str(instance_id_var)] = true
	var after_hand_ids: Array = _analytics_zone_ids(after_tracker, "hand")
	var after_hand_cards: Array[String] = _analytics_zone_cards(after_state, "hand")
	for index: int in range(mini(after_hand_ids.size(), after_hand_cards.size())):
		var instance_id: String = str(after_hand_ids[index])
		if before_hand_ids.has(instance_id):
			continue
		var card_id: String = after_hand_cards[index]
		_analytics_store.write_event("card_drawn", _analytics_context(after_state, card_id, instance_id), {
			"reason": reason,
			"hand_index": index,
			"hand_size": after_hand_cards.size(),
			"draw_pile_size": _analytics_zone_cards(after_state, "draw").size()
		})

func _log_playable_cards() -> void:
	if _combat_state.is_empty() or _analytics_tracker.is_empty():
		return
	var playable_logged: Dictionary = (_analytics_tracker.get("playable_logged", {}) as Dictionary).duplicate(true)
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	var hand_ids: Array = _analytics_zone_ids(_analytics_tracker, "hand")
	for index: int in range(mini(hand.size(), hand_ids.size())):
		var instance_id: String = str(hand_ids[index])
		if bool(playable_logged.get(instance_id, false)):
			continue
		var card_id: String = str(hand[index])
		var printed_playable: bool = _can_start_card(index, "printed")
		var attack_playable: bool = _can_start_card(index, "attack")
		var move_playable: bool = _can_start_card(index, "move")
		if not printed_playable and not attack_playable and not move_playable:
			continue
		playable_logged[instance_id] = true
		_analytics_store.write_event("card_became_playable", _analytics_context(_combat_state, card_id, instance_id), {
			"hand_index": index,
			"printed_playable": printed_playable,
			"attack_playable": attack_playable,
			"move_playable": move_playable
		})
	_analytics_tracker["playable_logged"] = playable_logged

func _card_play_payload(card_id: String, before_state: Dictionary, resolved_state: Dictionary, actions: Array, targets: Array[Vector2i]) -> Dictionary:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = resolved_state.get("player", {})
	var before_pos: Vector2i = before_player.get("pos", Vector2i.ZERO)
	var after_pos: Vector2i = after_player.get("pos", Vector2i.ZERO)
	var printed_card: Dictionary = _card_def(card_id, before_state)
	var printed_actions: Array = (printed_card.get("actions", []) as Array).duplicate(true)
	var capacity_delta: int = _card_play_capacity_value(resolved_state) - _card_play_capacity_value(before_state)
	var intensity_before: Dictionary = _combat_engine.elemental_intensities(before_state)
	var intensity_after: Dictionary = _combat_engine.elemental_intensities(resolved_state)
	var play_mode: String = "printed"
	if JSON.stringify(actions) != JSON.stringify(printed_actions):
		play_mode = "attack" if JSON.stringify(actions) == JSON.stringify(FALLBACK_ATTACK) else "move" if JSON.stringify(actions) == JSON.stringify(FALLBACK_MOVE) else "custom"
	return {
		"play_mode": play_mode,
		"printed_health_cost": int(printed_card.get("health_cost", 0)),
		"enemy_hp_damage": _enemy_damage_between(before_state, resolved_state),
		"enemy_block_removed": _enemy_block_removed_between(before_state, resolved_state),
		"enemy_stoneskin_removed": _enemy_stoneskin_removed_between(before_state, resolved_state),
		"kills_secured": _kills_between(before_state, resolved_state),
		"player_hp_delta": int(after_player.get("hp", 0)) - int(before_player.get("hp", 0)),
		"player_heal_gained": maxi(0, int(after_player.get("hp", 0)) - int(before_player.get("hp", 0))),
		"player_block_gained": maxi(0, int(after_player.get("block", 0)) - int(before_player.get("block", 0))),
		"player_stoneskin_gained": maxi(0, int(after_player.get("stoneskin", 0)) - int(before_player.get("stoneskin", 0))),
		"move_distance": absi(after_pos.x - before_pos.x) + absi(after_pos.y - before_pos.y),
		"cards_drawn": _draw_entries_between_states(before_state, resolved_state).size(),
		"card_plays_gained": maxi(0, capacity_delta),
		"card_plays_remaining_before": _combat_engine.cards_remaining_this_turn(before_state),
		"card_plays_remaining_after": _combat_engine.cards_remaining_this_turn(resolved_state),
		"net_card_plays_remaining_delta": _combat_engine.cards_remaining_this_turn(resolved_state) - _combat_engine.cards_remaining_this_turn(before_state),
		"card_plays_spent": maxi(0, int(resolved_state.get("cards_played_this_turn", 0)) - int(before_state.get("cards_played_this_turn", 0))),
		"death_bonus_card_plays_gained": maxi(0, int(resolved_state.get("death_bonus_card_plays_this_turn", 0)) - int(before_state.get("death_bonus_card_plays_this_turn", 0))),
		"card_action_plays_gained": maxi(0, int(resolved_state.get("card_play_bonus_this_turn", 0)) - int(before_state.get("card_play_bonus_this_turn", 0))),
		"elemental_intensity_before": intensity_before,
		"elemental_intensity_after": intensity_after,
		"elemental_intensity_gained": _elemental_intensity_delta(intensity_before, intensity_after),
		"illusions_created": _illusions_created_between(before_state, resolved_state),
		"illusion_health_created": _illusion_health_created_between(before_state, resolved_state),
		"enemy_status_applied": _enemy_status_added_breakdown(before_state, resolved_state),
		"player_status_applied": _player_status_added_breakdown(before_state, resolved_state),
		"selected_targets": targets.duplicate(true),
		"actions": actions.duplicate(true)
	}

func _print_analytics_summary() -> void:
	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	var counts: Dictionary = {}
	var card_plays: Dictionary = {}
	var outcomes: Dictionary = {}
	for event: Dictionary in events:
		var event_type: String = str(event.get("event_type", ""))
		_count(counts, event_type)
		if event_type == "card_played":
			_count(card_plays, str(event.get("card_id", "")))
		if event_type == "run_ended":
			_count(outcomes, str((event.get("payload", {}) as Dictionary).get("outcome", "")))
	print("Analytics events: %d | %s" % [events.size(), _counts_text(counts)])
	print("Run outcomes: %s" % _counts_text(outcomes))
	print("Card plays: %s" % _counts_text(card_plays))

func _print_card_resolution(card_id: String, before_state: Dictionary, after_state: Dictionary, actions: Array, targets: Array[Vector2i]) -> void:
	print("Resolved %s: %s" % [str(_card_def(card_id, before_state).get("name", card_id)), _card_delta_text(before_state, after_state)])
	print("  plays: %s" % _card_play_economy_text(before_state, after_state))
	var skipped: Array[String] = _skipped_action_lines(actions, targets)
	for line: String in skipped:
		print("  skipped: %s" % line)
	for line: String in _new_death_reward_lines(before_state, after_state):
		print("  reward: %s" % line)
	var log_lines: Array[String] = _new_log_lines(before_state, after_state)
	for line: String in log_lines:
		print("  log: %s" % line)
	var drawn: Array[Dictionary] = _draw_entries_between_states(before_state, after_state)
	if not drawn.is_empty():
		print("  drew: %s" % _drawn_cards_text(drawn))
	var restriction_status: String = _restriction_text(after_state)
	if not restriction_status.is_empty():
		print("  restrictions now: %s" % restriction_status)

func _play_pool_suffix(state: Dictionary) -> String:
	var death_bonus: int = int(state.get("death_bonus_card_plays_this_turn", 0))
	var card_bonus: int = int(state.get("card_play_bonus_this_turn", 0))
	if death_bonus <= 0 and card_bonus <= 0:
		return ""
	var parts: Array[String] = []
	parts.append("spent %d/%d" % [int(state.get("cards_played_this_turn", 0)), _card_play_capacity_value(state)])
	if death_bonus > 0:
		parts.append("kill +%d" % death_bonus)
	if card_bonus > 0:
		parts.append("card +%d" % card_bonus)
	return " (%s)" % ", ".join(parts)

func _card_play_economy_text(before_state: Dictionary, after_state: Dictionary) -> String:
	var before_remaining: int = _combat_engine.cards_remaining_this_turn(before_state)
	var after_remaining: int = _combat_engine.cards_remaining_this_turn(after_state)
	var spent_delta: int = maxi(0, int(after_state.get("cards_played_this_turn", 0)) - int(before_state.get("cards_played_this_turn", 0)))
	var death_bonus_delta: int = maxi(0, int(after_state.get("death_bonus_card_plays_this_turn", 0)) - int(before_state.get("death_bonus_card_plays_this_turn", 0)))
	var card_bonus_delta: int = maxi(0, int(after_state.get("card_play_bonus_this_turn", 0)) - int(before_state.get("card_play_bonus_this_turn", 0)))
	var capacity_delta: int = _card_play_capacity_value(after_state) - _card_play_capacity_value(before_state)
	var details: Array[String] = []
	if spent_delta > 0:
		details.append("spent %d" % spent_delta)
	if death_bonus_delta > 0:
		details.append("+%d from kill" % death_bonus_delta)
	if card_bonus_delta > 0:
		details.append("+%d from card text" % card_bonus_delta)
	if capacity_delta > death_bonus_delta + card_bonus_delta:
		details.append("+%d other capacity" % (capacity_delta - death_bonus_delta - card_bonus_delta))
	if details.is_empty():
		details.append("no play spent")
	return "remaining %d -> %d (%s)" % [before_remaining, after_remaining, ", ".join(details)]

func _card_play_capacity_value(state: Dictionary) -> int:
	return (
		int(state.get("cards_per_turn", 2))
		+ int(state.get("death_bonus_card_plays_this_turn", 0))
		+ int(state.get("card_play_bonus_this_turn", 0))
	)

func _new_death_reward_lines(before_state: Dictionary, after_state: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var before_rewards: Array = before_state.get("death_rewards", [])
	var after_rewards: Array = after_state.get("death_rewards", [])
	for index: int in range(before_rewards.size(), after_rewards.size()):
		if typeof(after_rewards[index]) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = after_rewards[index]
		var enemy_def: Dictionary = GameData.enemy_def(str(reward.get("type", "")))
		var bits: Array[String] = []
		var embers: int = int(reward.get("embers", 0))
		var card_plays: int = int(reward.get("card_plays", 0))
		if embers > 0:
			bits.append("+%d embers" % embers)
		if card_plays > 0:
			bits.append("+%d play" % card_plays)
		elif bool(reward.get("summoned", false)):
			bits.append("summoned: no play bonus")
		if bits.is_empty():
			bits.append("no combat reward")
		lines.append("%s %s" % [str(enemy_def.get("name", reward.get("type", "enemy"))), ", ".join(bits)])
	return lines

func _print_enemy_round_resolution(phase: Dictionary, before_state: Dictionary, after_enemy_state: Dictionary, before_draw_state: Dictionary, next_turn_state: Dictionary) -> void:
	var before_player: Dictionary = before_state.get("player", {})
	var after_enemy_player: Dictionary = after_enemy_state.get("player", {})
	var hp_loss: int = maxi(0, int(before_player.get("hp", 0)) - int(after_enemy_player.get("hp", 0)))
	var block_loss: int = maxi(0, int(before_player.get("block", 0)) - int(after_enemy_player.get("block", 0)))
	var headline: Array[String] = []
	if hp_loss > 0:
		headline.append("-%d HP" % hp_loss)
	if block_loss > 0:
		headline.append("-%d block" % block_loss)
	var status_delta: String = _player_status_delta_text(before_player, after_enemy_player)
	if not status_delta.is_empty():
		headline.append(status_delta)
	if headline.is_empty():
		headline.append("no direct player loss")
	print("Enemy phase resolved: %s." % ", ".join(headline))
	for line: String in _enemy_phase_step_lines(phase.get("steps", [])):
		print("  - %s" % line)
	if next_turn_state.is_empty():
		return
	var setup_logs: Array[String] = _new_log_lines(before_draw_state, next_turn_state)
	var drawn: Array[Dictionary] = _draw_entries_between_states(before_draw_state, next_turn_state)
	var setup_bits: Array[String] = []
	var next_player: Dictionary = next_turn_state.get("player", {})
	var hp_setup_delta: int = int(next_player.get("hp", 0)) - int((before_draw_state.get("player", {}) as Dictionary).get("hp", 0))
	if hp_setup_delta != 0:
		setup_bits.append("%+d HP" % hp_setup_delta)
	if not drawn.is_empty():
		setup_bits.append("drew %s" % _drawn_cards_text(drawn))
	var restriction_status: String = _restriction_text(next_turn_state)
	if not restriction_status.is_empty():
		setup_bits.append(restriction_status)
	if setup_bits.is_empty():
		setup_bits.append("ready")
	print("Next turn setup: %s." % ", ".join(setup_bits))
	for line: String in setup_logs:
		print("  log: %s" % line)

func _enemy_phase_step_lines(steps: Array) -> Array[String]:
	var lines: Array[String] = []
	for step_var: Variant in steps:
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var text: String = _enemy_step_text(step_var as Dictionary)
		if not text.is_empty():
			lines.append(text)
	return lines

func _enemy_step_text(step: Dictionary) -> String:
	var kind: String = str(step.get("kind", ""))
	var actor: String = str(step.get("actor_name", "Enemy"))
	match kind:
		"intent":
			return "%s prepares %s" % [actor, str(step.get("intent_name", "Action"))]
		"move":
			return "%s %s %s -> %s" % [actor, str(step.get("label", "moves")).to_lower(), _coord_text(step.get("from", Vector2i.ZERO)), _coord_text(step.get("to", Vector2i.ZERO))]
		"block":
			return "%s gains %d block" % [actor, int(step.get("amount", 0))]
		"stoneskin":
			return "%s gains %d stoneskin" % [actor, int(step.get("amount", 0))]
		"heal":
			return "%s heals %d" % [actor, int(step.get("amount", 0))]
		"status_damage":
			return "%s takes %d from %s" % [actor, int(step.get("amount", 0)), str(step.get("text", step.get("label", "status")))]
		"status":
			return "%s is %s" % [actor, str(step.get("text", step.get("label", "status")))]
		"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
			var bits: Array[String] = []
			var losses: String = _target_losses_text(step.get("target_losses", []))
			if not losses.is_empty():
				bits.append(losses)
			if step.get("player_from", Vector2i.ZERO) != step.get("player_to", Vector2i.ZERO):
				bits.append("moves player %s -> %s" % [_coord_text(step.get("player_from", Vector2i.ZERO)), _coord_text(step.get("player_to", Vector2i.ZERO))])
			if not str(step.get("status_text", "")).is_empty():
				bits.append(str(step.get("status_text", "")))
			if bits.is_empty():
				bits.append("no hit")
			return "%s %s: %s" % [actor, str(step.get("label", kind)).to_lower(), ", ".join(bits)]
		"summon":
			return "%s summons %d" % [actor, int(step.get("amount", 0))]
		_:
			return ""

func _target_losses_text(losses: Array) -> String:
	var parts: Array[String] = []
	for loss_var: Variant in losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var who: String = "player" if str(loss.get("kind", "")) == "player" else "illusion"
		var bits: Array[String] = []
		if int(loss.get("hp_loss", 0)) > 0:
			bits.append("-%d HP" % int(loss.get("hp_loss", 0)))
		if int(loss.get("block_loss", 0)) > 0:
			bits.append("-%d block" % int(loss.get("block_loss", 0)))
		if int(loss.get("stoneskin_loss", 0)) > 0:
			bits.append("-%d stone" % int(loss.get("stoneskin_loss", 0)))
		if not bits.is_empty():
			parts.append("%s %s" % [who, "/".join(bits)])
	return ", ".join(parts)

func _skipped_action_lines(actions: Array, targets: Array[Vector2i]) -> Array[String]:
	var lines: Array[String] = []
	var target_index: int = 0
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if not _combat_engine.player_action_needs_target(action):
			continue
		if target_index >= targets.size():
			continue
		var target: Vector2i = targets[target_index]
		target_index += 1
		if target == INVALID_TARGET_TILE:
			lines.append(_action_text(action))
	return lines

func _new_log_lines(before_state: Dictionary, after_state: Dictionary) -> Array[String]:
	var before_log: Array = before_state.get("log", [])
	var after_log: Array = after_state.get("log", [])
	var start: int = 0
	var max_overlap: int = mini(before_log.size(), after_log.size())
	for overlap: int in range(max_overlap, -1, -1):
		var matches: bool = true
		for offset: int in range(overlap):
			if str(before_log[before_log.size() - overlap + offset]) != str(after_log[offset]):
				matches = false
				break
		if matches:
			start = overlap
			break
	var lines: Array[String] = []
	for index: int in range(start, after_log.size()):
		lines.append(str(after_log[index]))
	return lines

func _drawn_cards_text(drawn: Array[Dictionary]) -> String:
	var names: Array[String] = []
	for entry: Dictionary in drawn:
		var card_id: String = str(entry.get("card_id", ""))
		names.append(str(_card_def(card_id).get("name", card_id)))
	return ", ".join(names)

func _save_session() -> void:
	var file: FileAccess = FileAccess.open(_session_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_var({
		"run_state": _run_state,
		"combat_state": _combat_state,
		"progression": _progression,
		"pending": _pending,
		"analytics_tracker": _analytics_tracker,
		"run_number": _run_number
	}, false)

func _load_session() -> bool:
	if not FileAccess.file_exists(_session_path):
		return false
	var file: FileAccess = FileAccess.open(_session_path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = file.get_var(false)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var session: Dictionary = data
	_run_state = (session.get("run_state", {}) as Dictionary).duplicate(true)
	_combat_state = (session.get("combat_state", {}) as Dictionary).duplicate(true)
	_progression = (session.get("progression", {}) as Dictionary).duplicate(true)
	_pending = (session.get("pending", {}) as Dictionary).duplicate(true)
	_analytics_tracker = (session.get("analytics_tracker", {}) as Dictionary).duplicate(true)
	_run_number = int(session.get("run_number", 0))
	return not _run_state.is_empty()

func _append_note(text: String, bullet: bool = true) -> void:
	if text.strip_edges().is_empty():
		return
	var file: FileAccess = FileAccess.open(_notes_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	if bullet:
		var clean_text: String = text.strip_edges()
		file.store_line(clean_text if clean_text.begins_with("- ") else "- %s" % clean_text)
	else:
		file.store_string(text)
	print("Noted.")

func _card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	if not state.is_empty() and (state.has("card_upgrades") or state.has("card_mods")):
		return GameData.card_def_for_progression(card_id, state)
	return GameData.card_def_for_progression(card_id, _progression)

func _card_cost_suffix(card: Dictionary) -> String:
	var parts: Array[String] = []
	if int(card.get("health_cost", 0)) > 0:
		parts.append("cost %d HP" % int(card.get("health_cost", 0)))
	if bool(card.get("burn", false)):
		parts.append("exhaust")
	return "" if parts.is_empty() else " (" + ", ".join(parts) + ")"

func _room_label(room: Dictionary) -> String:
	return "depth %d %s %s" % [int(room.get("depth", 0)), str(room.get("element", ElementData.NONE)), str(room.get("type", ""))]

func _action_summary(actions: Array) -> String:
	var parts: Array[String] = []
	for action_var: Variant in actions:
		if typeof(action_var) == TYPE_DICTIONARY:
			parts.append(_action_text(action_var as Dictionary))
	return "; ".join(parts)

func _enemy_actions_summary(actions: Array) -> String:
	var parts: Array[String] = []
	for action_var: Variant in actions:
		if typeof(action_var) == TYPE_DICTIONARY:
			parts.append(_enemy_action_text(action_var as Dictionary))
	return "; ".join(parts)

func _enemy_action_text(action: Dictionary) -> String:
	var action_type: String = str(action.get("type", ""))
	var suffix: String = _keyword_suffix(action)
	match action_type:
		"move_toward", "move_away":
			return "%s %d%s" % [action_type, int(action.get("range", 0)), suffix]
		"melee", "ranged", "aoe", "push", "pull":
			var amount_text: String = ""
			if action_type in ["push", "pull"]:
				amount_text = " force %d" % int(action.get("amount", 0))
			return "%s dmg %d range %d%s%s" % [action_type, int(action.get("damage", 0)), int(action.get("range", 0)), amount_text, suffix]
		"block", "stoneskin", "heal_self":
			return "%s %d%s" % [action_type, int(action.get("amount", 0)), suffix]
		"lightning_strikes":
			return "lightning %d x%d%s" % [int(action.get("damage", 0)), int(action.get("count", 0)), suffix]
		"summon_minions":
			return "summon %d %s" % [int(action.get("count", 0)), str(action.get("minion_type", "minions"))]
		_:
			return action_type + suffix

func _action_text(action: Dictionary) -> String:
	var action_type: String = str(action.get("type", ""))
	var suffix: String = _keyword_suffix(action)
	match action_type:
		"melee", "ranged", "aoe", "push", "pull":
			return "%s dmg %d range %d%s" % [action_type, _combat_engine.final_damage_for_player_action((_pending.get("state", _combat_state) as Dictionary), action), int(action.get("range", 0)), suffix]
		"move", "blink", "illusion":
			return "%s range %d%s" % [action_type, int(action.get("range", 0)), suffix]
		"block", "stoneskin", "heal", "draw", "card_play":
			return "%s %d%s" % [action_type, int(action.get("amount", 0)), suffix]
		"intensity":
			var element_id: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
			return "%s intensity +%d%s" % [ElementData.name(element_id), int(action.get("amount", 0)), suffix]
		_:
			return action_type + suffix

func _keyword_suffix(action: Dictionary) -> String:
	var extras: Array[String] = []
	var requirement: Dictionary = _combat_engine.action_intensity_requirement(action)
	if not requirement.is_empty():
		extras.append("requires %s %d+" % [
			ElementData.name(str(requirement.get("element", ElementData.NONE))),
			int(requirement.get("amount", 0))
		])
	var bonus: Dictionary = _combat_engine.action_intensity_bonus(action)
	if not bonus.is_empty():
		var bonus_text: String = _intensity_bonus_text(action, bonus)
		if not bonus_text.is_empty():
			extras.append("%s %d+: %s" % [
				ElementData.name(str(bonus.get("element", ElementData.NONE))),
				int(bonus.get("threshold", 0)),
				bonus_text
			])
	for status_key: String in ["burn", "freeze", "shock", "poison", "chain"]:
		if int(action.get(status_key, 0)) > 0:
			extras.append("%s %d" % [status_key, int(action.get(status_key, 0))])
	if int(action.get("self_damage", 0)) > 0:
		extras.append("self %d" % int(action.get("self_damage", 0)))
	return "" if extras.is_empty() else " +" + ", ".join(extras)

func _intensity_bonus_text(action: Dictionary, bonus: Dictionary) -> String:
	var parts: Array[String] = []
	if int(bonus.get("damage", 0)) > 0:
		parts.append("+%d dmg" % int(bonus.get("damage", 0)))
	if int(bonus.get("amount", 0)) > 0 and str(action.get("type", "")) in ["push", "pull"]:
		parts.append("+%d %s" % [int(bonus.get("amount", 0)), str(action.get("type", ""))])
	for status_key: String in ["burn", "freeze", "shock", "poison", "chain", "push", "pull"]:
		if int(bonus.get(status_key, 0)) > 0:
			parts.append("+%d %s" % [int(bonus.get(status_key, 0)), status_key])
	if bool(bonus.get("pierce", false)):
		parts.append("pierce")
	return ", ".join(parts)

func _target_hint(state: Dictionary, action: Dictionary, target: Vector2i) -> String:
	var after_state: Dictionary = _combat_engine.apply_player_action(state, action, target)
	var damage: int = _enemy_damage_between(state, after_state)
	var block_removed: int = _enemy_block_removed_between(state, after_state)
	var stoneskin_removed: int = _enemy_stoneskin_removed_between(state, after_state)
	var kills: int = _kills_between(state, after_state)
	var hp_delta: int = int((after_state.get("player", {}) as Dictionary).get("hp", 0)) - int((state.get("player", {}) as Dictionary).get("hp", 0))
	var move_risk: String = _movement_risk_text(state, action, target, [], false)
	var intensity_delta: String = _intensity_delta_text(state, after_state)
	var bits: Array[String] = []
	if damage > 0:
		bits.append("%d dmg" % damage)
	if block_removed > 0:
		bits.append("%d block" % block_removed)
	if stoneskin_removed > 0:
		bits.append("%d stone" % stoneskin_removed)
	if kills > 0:
		bits.append("%d kill" % kills)
	if hp_delta != 0:
		bits.append("%+d hp" % hp_delta)
	if not intensity_delta.is_empty():
		bits.append(intensity_delta)
	if not move_risk.is_empty():
		bits.append(move_risk)
	if bits.is_empty():
		bits.append(str(action.get("type", "")))
	return "(" + ", ".join(bits) + ")"

func _elemental_intensity_text(state: Dictionary) -> String:
	if state.is_empty():
		return "none"
	var parts: Array[String] = []
	var intensities: Dictionary = _combat_engine.elemental_intensities(state)
	for element_id: String in ElementData.all_elements():
		parts.append("%s %d" % [ElementData.name(element_id), int(intensities.get(element_id, 0))])
	return " | ".join(parts)

func _elemental_intensity_delta(before_intensity: Dictionary, after_intensity: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		var gained: int = int(after_intensity.get(element_id, 0)) - int(before_intensity.get(element_id, 0))
		if gained > 0:
			result[element_id] = gained
	return result

func _intensity_delta_text(before_state: Dictionary, after_state: Dictionary) -> String:
	var delta: Dictionary = _elemental_intensity_delta(
		_combat_engine.elemental_intensities(before_state),
		_combat_engine.elemental_intensities(after_state)
	)
	if delta.is_empty():
		return ""
	var parts: Array[String] = []
	for element_id: String in ElementData.all_elements():
		var amount: int = int(delta.get(element_id, 0))
		if amount > 0:
			parts.append("+%d %s intensity" % [amount, ElementData.name(element_id)])
	return ", ".join(parts)

func _card_delta_text(before_state: Dictionary, after_state: Dictionary) -> String:
	var bits: Array[String] = []
	var damage: int = _enemy_damage_between(before_state, after_state)
	var enemy_block_removed: int = _enemy_block_removed_between(before_state, after_state)
	var enemy_stoneskin_removed: int = _enemy_stoneskin_removed_between(before_state, after_state)
	var kills: int = _kills_between(before_state, after_state)
	var hp_delta: int = int((after_state.get("player", {}) as Dictionary).get("hp", 0)) - int((before_state.get("player", {}) as Dictionary).get("hp", 0))
	var block_delta: int = int((after_state.get("player", {}) as Dictionary).get("block", 0)) - int((before_state.get("player", {}) as Dictionary).get("block", 0))
	var move_delta: int = _player_move_distance_between(before_state, after_state)
	var drawn: int = _draw_entries_between_states(before_state, after_state).size()
	var card_plays_delta: int = maxi(0, _card_play_capacity_value(after_state) - _card_play_capacity_value(before_state))
	var illusions_created: int = _illusions_created_between(before_state, after_state)
	var intensity_delta: String = _intensity_delta_text(before_state, after_state)
	var enemy_status: String = _status_breakdown_text(_enemy_status_added_breakdown(before_state, after_state))
	var player_status: String = _status_breakdown_text(_player_status_added_breakdown(before_state, after_state))
	if damage > 0:
		bits.append("%d damage" % damage)
	if enemy_block_removed > 0:
		bits.append("%d block removed" % enemy_block_removed)
	if enemy_stoneskin_removed > 0:
		bits.append("%d stone removed" % enemy_stoneskin_removed)
	if kills > 0:
		bits.append("%d kills" % kills)
	if hp_delta != 0:
		bits.append("%+d HP" % hp_delta)
	if block_delta > 0:
		bits.append("+%d block" % block_delta)
	if move_delta > 0:
		bits.append("moved %d" % move_delta)
	if drawn > 0:
		bits.append("drew %d" % drawn)
	if card_plays_delta > 0:
		bits.append("+%d play" % card_plays_delta)
	if illusions_created > 0:
		bits.append("%d illusion" % illusions_created)
	if not intensity_delta.is_empty():
		bits.append(intensity_delta)
	if not enemy_status.is_empty():
		bits.append("enemy %s" % enemy_status)
	if not player_status.is_empty():
		bits.append("player %s" % player_status)
	return ", ".join(bits) if not bits.is_empty() else "low impact"

func _status_text(unit: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in ["burn", "freeze", "shock", "stoneskin"]:
		if int(unit.get(key, 0)) > 0:
			parts.append("%s=%d" % [key, int(unit.get(key, 0))])
	if unit.has("poison") and int((unit.get("poison", {}) as Dictionary).get("damage", 0)) > 0:
		parts.append("poison=%d" % int((unit.get("poison", {}) as Dictionary).get("damage", 0)))
	return "[" + ", ".join(parts) + "]" if not parts.is_empty() else ""

func _restriction_text(state: Dictionary) -> String:
	var restrictions: Dictionary = state.get("player_turn_restrictions", {})
	var parts: Array[String] = []
	if bool(restrictions.get("frozen", false)):
		parts.append("frozen: no move and turn locked")
	if bool(restrictions.get("shocked", false)):
		parts.append("shocked: limited actions")
	var pending: String = str(state.get("pending_player_trap_restriction", ""))
	if not pending.is_empty():
		parts.append("pending trap %s" % pending)
	return "[" + "; ".join(parts) + "]" if not parts.is_empty() else ""

func _player_status_delta_text(before_player: Dictionary, after_player: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in ["burn", "freeze", "shock"]:
		var delta: int = int(after_player.get(key, 0)) - int(before_player.get(key, 0))
		if delta > 0:
			parts.append("+%d %s" % [delta, key])
	var before_poison: int = int((before_player.get("poison", {}) as Dictionary).get("damage", 0))
	var after_poison: int = int((after_player.get("poison", {}) as Dictionary).get("damage", 0))
	if after_poison > before_poison:
		parts.append("+%d poison" % (after_poison - before_poison))
	return ", ".join(parts)

func _status_breakdown_text(breakdown: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in ["burn", "freeze", "shock", "poison"]:
		var amount: int = int(breakdown.get(key, 0))
		if amount > 0:
			parts.append("+%d %s" % [amount, key])
	return ", ".join(parts)

func _movement_risk_text(state: Dictionary, action: Dictionary, target: Vector2i, path_override: Array = [], include_hp: bool = true) -> String:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["move", "blink"] or target == INVALID_TARGET_TILE:
		return ""
	var path: Array[Vector2i] = _vector2i_array(path_override)
	if path.is_empty():
		path = _vector2i_array([target]) if action_type == "blink" else _combat_engine.path_for_player_action(state, action, target)
	var trap_bits: Array[String] = []
	for index: int in range(path.size()):
		if action_type == "move" and index == 0:
			continue
		var tile: Vector2i = path[index]
		var trap: Dictionary = _trap_at_tile(state, tile)
		if trap.is_empty():
			continue
		trap_bits.append("%s %s" % [_coord_text(tile), _trap_text(trap)])
	if trap_bits.is_empty():
		return ""
	var bits: Array[String] = ["traps " + " / ".join(trap_bits)]
	if include_hp:
		var after_state: Dictionary = _combat_engine.apply_player_action(state, action, target)
		var hp_delta: int = int((after_state.get("player", {}) as Dictionary).get("hp", 0)) - int((state.get("player", {}) as Dictionary).get("hp", 0))
		if hp_delta != 0:
			bits.append("%+d hp" % hp_delta)
		var status_delta: String = _player_status_delta_text(state.get("player", {}), after_state.get("player", {}))
		if not status_delta.is_empty():
			bits.append(status_delta)
	return "move risk: %s" % ", ".join(bits)

func _trap_at_tile(state: Dictionary, tile: Vector2i) -> Dictionary:
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if trap.get("pos", Vector2i(-1, -1)) == tile:
			return trap
	return {}

func _trap_text(trap: Dictionary) -> String:
	var parts: Array[String] = ["%s trap" % ElementData.name(str(trap.get("element", ElementData.NONE)))]
	if int(trap.get("damage", 0)) > 0:
		parts.append("%d dmg" % int(trap.get("damage", 0)))
	for key: String in ["burn", "freeze", "shock", "poison"]:
		if int(trap.get(key, 0)) > 0:
			parts.append("%s %d" % [key, int(trap.get(key, 0))])
	return " ".join(parts)

func _player_move_distance_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var before_pos: Vector2i = (before_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var after_pos: Vector2i = (after_state.get("player", {}) as Dictionary).get("pos", before_pos)
	return absi(after_pos.x - before_pos.x) + absi(after_pos.y - before_pos.y)

func _live_enemies(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY and int((enemy_var as Dictionary).get("hp", 0)) > 0:
			result.append(enemy_var as Dictionary)
	return result

func _enemies_by_id(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY:
			var enemy: Dictionary = enemy_var
			result[int(enemy.get("id", -1))] = enemy
	return result

func _enemy_damage_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var total: int = 0
	var after_by_id: Dictionary = _enemies_by_id(after_state)
	for before_enemy: Dictionary in _live_enemies(before_state):
		var enemy_id: int = int(before_enemy.get("id", -1))
		if after_by_id.has(enemy_id):
			total += maxi(0, int(before_enemy.get("hp", 0)) - int((after_by_id[enemy_id] as Dictionary).get("hp", 0)))
	return total

func _enemy_block_removed_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var total: int = 0
	var after_by_id: Dictionary = _enemies_by_id(after_state)
	for before_enemy: Dictionary in _live_enemies(before_state):
		var enemy_id: int = int(before_enemy.get("id", -1))
		if after_by_id.has(enemy_id):
			total += maxi(0, int(before_enemy.get("block", 0)) - int((after_by_id[enemy_id] as Dictionary).get("block", 0)))
	return total

func _enemy_stoneskin_removed_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var total: int = 0
	var after_by_id: Dictionary = _enemies_by_id(after_state)
	for before_enemy: Dictionary in _live_enemies(before_state):
		var enemy_id: int = int(before_enemy.get("id", -1))
		if after_by_id.has(enemy_id):
			total += maxi(0, int(before_enemy.get("stoneskin", 0)) - int((after_by_id[enemy_id] as Dictionary).get("stoneskin", 0)))
	return total

func _kills_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var kills: int = 0
	var after_by_id: Dictionary = _enemies_by_id(after_state)
	for before_enemy: Dictionary in _live_enemies(before_state):
		var enemy_id: int = int(before_enemy.get("id", -1))
		if after_by_id.has(enemy_id) and int((after_by_id[enemy_id] as Dictionary).get("hp", 0)) <= 0:
			kills += 1
	return kills

func _illusions_created_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var before_ids: Dictionary = {}
	for illusion_var: Variant in before_state.get("illusions", []):
		if typeof(illusion_var) == TYPE_DICTIONARY:
			before_ids[int((illusion_var as Dictionary).get("id", -1))] = true
	var count: int = 0
	for illusion_var: Variant in after_state.get("illusions", []):
		if typeof(illusion_var) == TYPE_DICTIONARY:
			var illusion: Dictionary = illusion_var
			if int(illusion.get("hp", 0)) > 0 and not before_ids.has(int(illusion.get("id", -1))):
				count += 1
	return count

func _illusion_health_created_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var before_ids: Dictionary = {}
	for illusion_var: Variant in before_state.get("illusions", []):
		if typeof(illusion_var) == TYPE_DICTIONARY:
			before_ids[int((illusion_var as Dictionary).get("id", -1))] = true
	var total: int = 0
	for illusion_var: Variant in after_state.get("illusions", []):
		if typeof(illusion_var) == TYPE_DICTIONARY:
			var illusion: Dictionary = illusion_var
			if int(illusion.get("hp", 0)) > 0 and not before_ids.has(int(illusion.get("id", -1))):
				total += int(illusion.get("max_hp", illusion.get("hp", 0)))
	return total

func _enemy_status_added_breakdown(before_state: Dictionary, after_state: Dictionary) -> Dictionary:
	var result: Dictionary = {"burn": 0, "freeze": 0, "shock": 0, "poison": 0}
	var after_by_id: Dictionary = _enemies_by_id(after_state)
	for before_enemy: Dictionary in _live_enemies(before_state):
		var enemy_id: int = int(before_enemy.get("id", -1))
		if not after_by_id.has(enemy_id):
			continue
		var after_enemy: Dictionary = after_by_id[enemy_id]
		for status: String in ["burn", "freeze", "shock"]:
			result[status] = int(result.get(status, 0)) + maxi(0, int(after_enemy.get(status, 0)) - int(before_enemy.get(status, 0)))
		result["poison"] = int(result.get("poison", 0)) + maxi(0, int((after_enemy.get("poison", {}) as Dictionary).get("damage", 0)) - int((before_enemy.get("poison", {}) as Dictionary).get("damage", 0)))
	return result

func _player_status_added_breakdown(before_state: Dictionary, after_state: Dictionary) -> Dictionary:
	var result: Dictionary = {"burn": 0, "freeze": 0, "shock": 0, "poison": 0}
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	for status: String in ["burn", "freeze", "shock"]:
		result[status] = maxi(0, int(after_player.get(status, 0)) - int(before_player.get(status, 0)))
	result["poison"] = maxi(0, int((after_player.get("poison", {}) as Dictionary).get("damage", 0)) - int((before_player.get("poison", {}) as Dictionary).get("damage", 0)))
	return result

func _draw_entries_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_counts: Dictionary = {}
	for card_id_var: Variant in (before_state.get("deck", {}) as Dictionary).get("hand", []):
		var card_id: String = str(card_id_var)
		before_counts[card_id] = int(before_counts.get(card_id, 0)) + 1
	var after_hand: Array = (after_state.get("deck", {}) as Dictionary).get("hand", [])
	var drawn: Array[Dictionary] = []
	for index: int in range(after_hand.size()):
		var card_id: String = str(after_hand[index])
		var remaining: int = int(before_counts.get(card_id, 0))
		if remaining > 0:
			before_counts[card_id] = remaining - 1
			continue
		drawn.append({"card_id": card_id, "index": index, "total": after_hand.size()})
	return drawn

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _coord_text(coord: Vector2i) -> String:
	return "(%d,%d)" % [coord.x, coord.y]

func _count(counts: Dictionary, key: String) -> void:
	if key.is_empty():
		return
	counts[key] = int(counts.get(key, 0)) + 1

func _counts_text(counts: Dictionary) -> String:
	if counts.is_empty():
		return "none"
	var keys: Array[String] = []
	for key_var: Variant in counts.keys():
		keys.append(str(key_var))
	keys.sort()
	var parts: Array[String] = []
	for key: String in keys:
		parts.append("%s=%d" % [key, int(counts.get(key, 0))])
	return ", ".join(parts)

func _timestamp_utc_iso() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(now.get("year", 1970)),
		int(now.get("month", 1)),
		int(now.get("day", 1)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0))
	]
