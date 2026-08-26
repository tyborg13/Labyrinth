extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")

const INVALID_TARGET_TILE: Vector2i = Vector2i(-1, -1)
const SHORTCUT_ATTACK_TYPES: Array = ["melee", "ranged", "aoe", "push", "pull"]
const DEFAULT_OUTPUT_DIR: String = "res://playtest/headless"
const DEFAULT_SEED_BASE: int = 5052026
const CAMPFIRE_LINGER_HEAL_AMOUNT: int = RunEngine.CAMPFIRE_LINGER_HEAL

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
	if bool(_options.get("show_help", false)):
		_print_help()
		quit(0)
		return
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
		"resume": false,
		"show_help": false
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
				parsed["show_help"] = true
		index += 1
	return parsed

func _print_help() -> void:
	print("Manual headless playtest console")
	print("Usage: godot --headless --path . --script tools/headless_playtest.gd -- [--seed N] [--output-dir res://playtest/headless] [--resume]")
	print("Commands: state, moves, move N, cards, card N, click N, drag N play, walk x,y, target N|x,y, skip, pass, skills, skill SKILL_ID [INDEX], learn SKILL_ID, reward N|heal, relic N, linger, level, leave, rest, note TEXT, new [seed], analytics, help, quit")
	print("Card flow: `card N`/`click N` starts printed text; target prompts commit after `target`. Re-run `cards` after each resolved play because hand indexes can shift.")
	print("Combat movement: `walk x,y` spends the independent movement pool; it may be used before, between, or after card plays.")
	print("Board: P player, 0-9 enemies, I illusion, B box, C crate, H potion, S shield, T trap, # wall/pillar, D door")

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
	file.store_line("- Console command: `%s`" % _notes_command_text())
	file.store_line("- Notes are written by explicit `note ...` commands while playing.\n")

func _notes_command_text() -> String:
	var parts: Array[String] = [
		"godot",
		"--headless",
		"--path",
		".",
		"--script",
		"tools/headless_playtest.gd",
		"--",
		"--seed",
		str(int(_options.get("seed", DEFAULT_SEED_BASE))),
		"--output-dir",
		str(_options.get("output_dir", DEFAULT_OUTPUT_DIR))
	]
	var output_dir: String = str(_options.get("output_dir", DEFAULT_OUTPUT_DIR))
	var analytics_dir: String = str(_options.get("analytics_dir", output_dir.path_join("analytics")))
	if analytics_dir != output_dir.path_join("analytics"):
		parts.append("--analytics-dir")
		parts.append(analytics_dir)
	var notes_path: String = str(_options.get("notes_path", output_dir.path_join("manual_playtest_notes.md")))
	if notes_path != output_dir.path_join("manual_playtest_notes.md"):
		parts.append("--notes")
		parts.append(notes_path)
	var session_path: String = str(_options.get("session_path", output_dir.path_join("manual_session.save")))
	if session_path != output_dir.path_join("manual_session.save"):
		parts.append("--session")
		parts.append(session_path)
	if bool(_options.get("resume", false)):
		parts.append("--resume")
	elif not bool(_options.get("clear_analytics", true)):
		parts.append("--keep-analytics")
	return " ".join(parts)

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
		"walk":
			if parts.size() < 2:
				_print_player_movement()
			else:
				_command_walk(parts[1])
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
		"skills":
			_print_skills()
		"skill":
			_command_skill(parts)
		"learn":
			_command_learn(parts)
		"reward":
			_command_reward(parts)
		"heal":
			_command_reward(PackedStringArray(["reward", "heal"]))
		"relic":
			_command_relic(parts)
		"linger":
			_command_linger()
		"level", "strength":
			_command_level_up(parts)
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
	var carried_progression: Dictionary = _progression.duplicate(true)
	if typeof(_run_state.get("progression", {})) == TYPE_DICTIONARY and not (_run_state.get("progression", {}) as Dictionary).is_empty():
		carried_progression = (_run_state.get("progression", {}) as Dictionary).duplicate(true)
		# The run snapshot can acquire profile-only rewards such as Moltshards, while
		# the console's progression copy remains authoritative for carried embers.
		carried_progression["embers"] = int(_progression.get("embers", carried_progression.get("embers", 0)))
	_progression = ProgressionStore.normalized_data(carried_progression)
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
			_print_campfire_state()
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
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, _run_state.get("current_room", Vector2i.ZERO))
	for index: int in range(moves.size()):
		var coord: Vector2i = moves[index]
		var room: Dictionary = _run_engine.room_metadata(_run_state, coord)
		var connection_text: String = _move_connection_text(current_room, room)
		print("  %d: %s depth %d %s %s%s" % [
			index,
			_coord_text(coord),
			int(room.get("depth", 0)),
			str(room.get("element", ElementData.NONE)),
			str(room.get("type", "")),
			" [%s]" % connection_text if not connection_text.is_empty() else ""
		])
	print("Command: move N")

func _move_connection_text(current_room: Dictionary, destination_room: Dictionary) -> String:
	var destination: Vector2i = destination_room.get("coord", Vector2i.ZERO)
	var current_depth: int = int(current_room.get("depth", 0))
	var destination_depth: int = int(destination_room.get("depth", 0))
	var kind: String = ""
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if connection.get("coord", Vector2i(999, 999)) == destination:
			kind = str(connection.get("kind", ""))
			break
	if destination_depth > current_depth:
		return "outward, deeper"
	if destination_depth == current_depth:
		return "lateral, same depth" if kind.is_empty() else "%s, same depth" % kind
	if destination_depth < current_depth:
		return "inward, lower depth"
	return kind

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

func _print_player_movement() -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Independent movement is only available in combat.")
		return
	var targets: Array[Vector2i] = _combat_engine.player_movement_targets(_combat_state)
	print("Movement %d/%d. Legal destinations: %s" % [
		_combat_engine.player_movement_remaining(_combat_state),
		_combat_engine.player_movement_capacity(_combat_state),
		", ".join(targets.map(func(tile: Vector2i) -> String: return _coord_text(tile))) if not targets.is_empty() else "none"
	])
	print("Command: walk x,y")

func _command_walk(raw: String) -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Not in combat.")
		return
	if not _pending.is_empty():
		print("Finish or cancel the pending card before moving.")
		return
	var coords: PackedStringArray = raw.split(",", false)
	if coords.size() != 2 or not coords[0].strip_edges().is_valid_int() or not coords[1].strip_edges().is_valid_int():
		print("Movement needs a destination: `walk x,y`.")
		_print_player_movement()
		return
	var target: Vector2i = Vector2i(int(coords[0]), int(coords[1]))
	if not _combat_engine.player_movement_targets(_combat_state).has(target):
		print("That movement destination is not legal.")
		_print_player_movement()
		return
	var before_run_state: Dictionary = _run_state.duplicate(true)
	var before_combat_state: Dictionary = _combat_state.duplicate(true)
	var before_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var transition_state: Dictionary = _combat_engine.apply_player_movement(_combat_state, target)
	var movement: Dictionary = transition_state.get("last_player_movement", {}) as Dictionary
	if int(movement.get("spent", 0)) <= 0:
		print("Movement produced no effect.")
		_print_player_movement()
		return
	_combat_state = transition_state.duplicate(true)
	_analytics_reconcile_combat_tracker(before_combat_state, _combat_state)
	_log_card_draws(before_combat_state, _combat_state, before_tracker, _analytics_snapshot_combat_tracker(), "player_movement")
	_analytics_store.write_event("player_moved", _analytics_context(before_combat_state), movement.duplicate(true))
	var outcome: String = _combat_engine.combat_outcome(_combat_state)
	if outcome.is_empty():
		_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	else:
		_run_state = _run_engine.finish_combat(_run_state, _combat_state)
	_sync_combat_state_from_run()
	_log_playable_cards()
	_log_combat_transition(before_run_state, "player_movement", transition_state)
	_append_note("- Moved from %s to %s, spending %d movement (%d remaining).\n" % [
		_coord_text(movement.get("origin", Vector2i.ZERO)),
		_coord_text(movement.get("destination", target)),
		int(movement.get("spent", 0)),
		int(movement.get("remaining_after", 0))
	])
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
	print("Combat %s | turn %d | plays %d%s | movement %d/%d | player %s block %d stone %d%s" % [
		str(_combat_state.get("room_name", "")),
		int(_combat_state.get("turn", 1)),
		plays_remaining,
		_play_pool_suffix(_combat_state),
		_combat_engine.player_movement_remaining(_combat_state),
		_combat_engine.player_movement_capacity(_combat_state),
		_coord_text(player.get("pos", Vector2i.ZERO)),
		int(player.get("block", 0)),
		int(player.get("stoneskin", 0)),
		status_suffix
	])
	print("Intensity: %s" % _elemental_intensity_text(_combat_state))
	print("Order: %s" % _turn_order_text(_combat_state))
	_print_turn_clock()
	_print_manual_skill_summary()
	if plays_remaining <= 0 and not restriction_status.is_empty():
		print("Turn locked by %s." % restriction_status)
	_print_board()
	_print_pickups()
	_print_terrain()
	_print_traps()
	_print_enemies()
	_print_incoming_preview()
	_print_cards()
	if not _pending.is_empty():
		_print_pending()
	else:
		print("Commands: card N, click N, drag N play, walk x,y, skills, skill SKILL_ID [INDEX], pass, note TEXT")

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
	for terrain_var: Variant in _combat_state.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY and int((terrain_var as Dictionary).get("hp", 0)) > 0:
			var terrain: Dictionary = terrain_var
			marks[terrain.get("pos", Vector2i.ZERO)] = "C" if str(terrain.get("kind", "")) == "wooden_crate" else "B"
	for loot_var: Variant in _combat_state.get("loot", []):
		if typeof(loot_var) == TYPE_DICTIONARY and not bool((loot_var as Dictionary).get("claimed", false)):
			var loot: Dictionary = loot_var
			var loot_mark: String = "H" if str(loot.get("kind", "")) == "healing_vial" else "S" if str(loot.get("kind", "")) == "rusty_shield" else "$"
			marks[loot.get("pos", Vector2i.ZERO)] = loot_mark
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

func _print_pickups() -> void:
	var parts: Array[String] = []
	for loot_var: Variant in _combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)):
			continue
		parts.append("%s %s" % [_coord_text(loot.get("pos", Vector2i.ZERO)), _loot_text(loot)])
	if not parts.is_empty():
		print("Pickups: %s" % "; ".join(parts))

func _print_terrain() -> void:
	var parts: Array[String] = []
	for terrain_var: Variant in _combat_state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if int(terrain.get("hp", 0)) <= 0:
			continue
		parts.append("%s %s" % [_coord_text(terrain.get("pos", Vector2i.ZERO)), _terrain_text(terrain)])
	if not parts.is_empty():
		print("Terrain: %s" % "; ".join(parts))

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
	var scheduled_state: Dictionary = _combat_engine.finish_player_activation(_combat_state.duplicate(true))
	var phase: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(scheduled_state)
	var after_state: Dictionary = (phase.get("state", _combat_state) as Dictionary).duplicate(true)
	var before_setup_state: Dictionary = (phase.get("player_turn_before_state", {}) as Dictionary).duplicate(true)
	var after_enemy_state: Dictionary = before_setup_state if not before_setup_state.is_empty() else after_state
	var before_player: Dictionary = _combat_state.get("player", {})
	var headline_bits: Array = _player_loss_bits(before_player, after_enemy_state.get("player", {}))
	if headline_bits.is_empty():
		headline_bits.append("no direct player hit")
	print("If you pass now, enemy phase: %s." % ", ".join(headline_bits))
	var step_lines: Array[String] = _enemy_phase_step_lines(phase.get("steps", []))
	for index: int in range(mini(10, step_lines.size())):
		print("  - %s" % step_lines[index])
	if step_lines.size() > 10:
		print("  - ... %d more enemy steps: %s" % [step_lines.size() - 10, _enemy_phase_step_summary(step_lines, 10)])
	if not before_setup_state.is_empty():
		var setup_bits: Array = _player_loss_bits(before_setup_state.get("player", {}), after_state.get("player", {}))
		var drawn: Array[Dictionary] = _draw_entries_between_states(before_setup_state, after_state)
		if not drawn.is_empty():
			setup_bits.append("drew %s" % _drawn_cards_text(drawn))
		var restriction_status: String = _restriction_text(after_state)
		if not restriction_status.is_empty():
			setup_bits.append(restriction_status)
		var setup_logs: Array[String] = _new_log_lines(before_setup_state, after_state)
		if not setup_bits.is_empty() or not setup_logs.is_empty():
			if setup_bits.is_empty():
				setup_bits.append("ready")
			print("Then next turn setup: %s." % ", ".join(setup_bits))
			for line: String in setup_logs:
				print("  setup: %s" % line)

func _turn_order_text(state: Dictionary) -> String:
	var entries: Array[Dictionary] = _combat_engine.current_turn_order(state, 8)
	var parts: Array[String] = []
	for entry: Dictionary in entries:
		var name: String = str(entry.get("name", "Actor"))
		if bool(entry.get("projected", false)):
			name = "%s projected" % name
		var eta: String = "now" if bool(entry.get("active", false)) else "+%d" % int(entry.get("eta", 0))
		parts.append("%s %s" % [name, eta])
	return " -> ".join(parts)

func _print_turn_clock() -> void:
	if _combat_state.is_empty() or not _combat_engine.is_player_turn(_combat_state):
		return
	print("Round clock: %s." % _player_timing_preview_text(0, "if pass now"))

func _card_timing_preview_text(card: Dictionary) -> String:
	if _combat_state.is_empty() or not _combat_engine.is_player_turn(_combat_state):
		return ""
	var card_time: int = _combat_engine.card_time_cost_from_def(card)
	return _player_timing_preview_text(card_time, "if played")

func _player_timing_preview_text(time_delta: int, label: String) -> String:
	var base: int = _combat_engine.player_base_initiative(_combat_state)
	var spent: int = int(_combat_state.get("player_turn_time_spent", 0))
	var preview_state: Dictionary = _combat_state.duplicate(true)
	if time_delta > 0:
		preview_state["turn_order_preview_time_delta"] = time_delta
	var entries: Array[Dictionary] = _combat_engine.current_turn_order(preview_state, 10)
	var projected_index: int = _projected_player_order_index(entries)
	var eta: int = base + spent + maxi(0, time_delta)
	if projected_index >= 0:
		eta = int((entries[projected_index] as Dictionary).get("eta", eta))
	var formula: String = "base %d + played %d" % [base, spent]
	if time_delta > 0:
		formula += " + this %d" % time_delta
	var parts: Array[String] = ["%s return +%d (%s)" % [label, eta, formula]]
	if projected_index >= 0:
		var before_text: String = _turn_order_before_projected_text(entries, projected_index)
		var after_text: String = _turn_order_after_projected_text(entries, projected_index)
		parts.append("before any queued enemy" if before_text.is_empty() else "after %s" % before_text)
		if not after_text.is_empty():
			parts.append("before %s" % after_text)
	return "; ".join(parts)

func _projected_player_order_index(entries: Array[Dictionary]) -> int:
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		if str(entry.get("kind", "")) == "player" and bool(entry.get("projected", false)):
			return index
	return -1

func _turn_order_before_projected_text(entries: Array[Dictionary], projected_index: int) -> String:
	var labels: Array[String] = []
	for index: int in range(projected_index):
		var entry: Dictionary = entries[index]
		if bool(entry.get("active", false)):
			continue
		labels.append(_turn_order_actor_summary(entry))
	if labels.is_empty():
		return ""
	var limit: int = mini(2, labels.size())
	var visible: Array[String] = []
	for index: int in range(limit):
		visible.append(labels[index])
	if labels.size() > limit:
		visible.append("%d more" % (labels.size() - limit))
	return ", ".join(visible)

func _turn_order_after_projected_text(entries: Array[Dictionary], projected_index: int) -> String:
	for index: int in range(projected_index + 1, entries.size()):
		var entry: Dictionary = entries[index]
		if bool(entry.get("active", false)):
			continue
		return _turn_order_actor_summary(entry)
	return ""

func _turn_order_actor_summary(entry: Dictionary) -> String:
	var name: String = str(entry.get("name", "Actor"))
	if bool(entry.get("projected", false)):
		name = "%s projected" % name
	return "%s +%d" % [name, int(entry.get("eta", 0))]

func _print_cards() -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Cards are only available in combat.")
		return
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	print("Hand: %s" % _deck_summary_text(_combat_state))
	for index: int in range(hand.size()):
		var card_id: String = str(hand[index])
		var modes: Array[String] = []
		if _can_start_card(index, "printed"):
			modes.append("click / drag play")
		var card: Dictionary = _card_def(card_id, _combat_state)
		var timing: String = _card_timing_preview_text(card) if not modes.is_empty() else ""
		var timing_suffix: String = "" if timing.is_empty() else " | %s" % timing
		print("  %d: %s%s [%s] %s%s" % [
			index,
			str(card.get("name", card_id)),
			_card_cost_suffix(card),
			"; ".join(modes) if not modes.is_empty() else "no legal input",
			_action_summary(card.get("actions", [])),
			timing_suffix
		])

func _print_manual_skill_summary() -> void:
	var summaries: Array[String]
	for skill_state: Dictionary in _combat_engine.manual_skill_states(_combat_state):
		var skill_id: String = str(skill_state.get("skill_id", ""))
		summaries.append("%s %s" % [skill_id, _manual_skill_status(skill_id)])
	if not summaries.is_empty():
		print("Manual skills: %s. Use `skills` for details." % ", ".join(summaries))

func _print_skills() -> void:
	var learned_skill_ids: Array[String]
	var progression: Dictionary = _progression
	if str(_run_state.get("mode", "")) == "combat":
		learned_skill_ids = _combat_engine.skill_ids(_combat_state)
	else:
		progression = _run_state.get("progression", _progression) as Dictionary
		learned_skill_ids = ProgressionStore.selected_skill_ids(progression)
		print("Skill points: %d unspent. Use `learn SKILL_ID` outside combat." % ProgressionStore.unspent_skill_points(progression))
	if learned_skill_ids.is_empty():
		print("Learned abilities: none.")
		if str(_run_state.get("mode", "")) != "combat":
			_print_legal_learn_skills(_legal_learn_skill_ids(progression))
		return
	print("Learned abilities (%d):" % learned_skill_ids.size())
	for skill_id: String in learned_skill_ids:
		var activation: String = SkillTreeLibrary.activation_kind(skill_id)
		var status: String = activation.to_upper()
		var command_suffix: String = ""
		if activation == "manual":
			status = _manual_skill_status(skill_id) if str(_run_state.get("mode", "")) == "combat" else "MANUAL"
			command_suffix = " | use %s" % _manual_skill_command(skill_id)
		print("- `%s`: %s [%s]%s — %s" % [
			skill_id,
			SkillTreeLibrary.display_name(skill_id),
			status,
			command_suffix,
			SkillTreeLibrary.description(skill_id)
		])
	if str(_run_state.get("mode", "")) != "combat" and ProgressionStore.unspent_skill_points(progression) > 0:
		_print_legal_learn_skills(_legal_learn_skill_ids(progression))

func _command_learn(parts: PackedStringArray) -> void:
	var mode: String = str(_run_state.get("mode", ""))
	if mode in ["combat", "victory", "defeat", "rested"]:
		print("Abilities can only be learned during an active run outside combat.")
		return
	var active_progression: Dictionary = _run_state.get("progression", _progression) as Dictionary
	var legal_skill_ids: Array[String] = _legal_learn_skill_ids(active_progression)
	if parts.size() != 2:
		print("Use `learn SKILL_ID`.")
		_print_legal_learn_skills(legal_skill_ids)
		return
	var skill_id: String = str(parts[1]).strip_edges().to_lower()
	if not ProgressionStore.can_learn_skill(active_progression, skill_id):
		print("Cannot learn %s. Unspent skill points: %d." % [
			skill_id,
			ProgressionStore.unspent_skill_points(active_progression)
		])
		_print_legal_learn_skills(legal_skill_ids)
		return
	var before_progression: Dictionary = ProgressionStore.normalized_data(active_progression)
	var candidate: Dictionary = ProgressionStore.learn_skill(before_progression, skill_id)
	if not ProgressionStore.save_data(candidate):
		print("Could not save the learned ability; the skill point was not spent.")
		return
	_progression = candidate
	_run_state = _run_engine.apply_progression_update(_run_state, _progression)
	ProgressionStore.save_run_state(_run_state)
	_sync_combat_state_from_run()
	_log_skill_learned(before_progression, _progression, skill_id)
	_append_note("- Progression: learned %s (`%s`); %d skill points remain.\n" % [
		SkillTreeLibrary.display_name(skill_id),
		skill_id,
		ProgressionStore.unspent_skill_points(_progression)
	])
	print("Learned %s (`%s`). %d skill points remain." % [
		SkillTreeLibrary.display_name(skill_id),
		skill_id,
		ProgressionStore.unspent_skill_points(_progression)
	])
	_print_state()

func _command_skill(parts: PackedStringArray) -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Manual abilities are only available in combat.")
		_print_skills()
		return
	if not _pending.is_empty():
		print("Resolve or cancel the pending card before using an ability.")
		return
	if parts.size() < 2:
		print("Use `skill SKILL_ID [INDEX]`.")
		_print_skills()
		return
	var skill_id: String = str(parts[1]).strip_edges().to_lower()
	if not SkillTreeLibrary.has_definition(skill_id):
		print("Unknown ability: %s." % skill_id)
		_print_skills()
		return
	if not _combat_engine.has_skill(_combat_state, skill_id):
		print("%s is not part of this run's learned build." % SkillTreeLibrary.display_name(skill_id))
		return
	if SkillTreeLibrary.activation_kind(skill_id) != "manual":
		print("%s is %s and has no manual command." % [SkillTreeLibrary.display_name(skill_id), SkillTreeLibrary.activation_kind(skill_id)])
		return
	if not _combat_engine.skill_is_ready(_combat_state, skill_id):
		print("%s is not ready (%s)." % [SkillTreeLibrary.display_name(skill_id), _manual_skill_status(skill_id)])
		_print_skill_choices(skill_id)
		return
	var effect_type: String = SkillTreeLibrary.effect_type(skill_id)
	var requires_index: bool = effect_type in ["discard_draw", "discard_recall", "arm_intensity"]
	var choice_index: int = -1
	if requires_index:
		if parts.size() < 3 or not str(parts[2]).strip_edges().is_valid_int():
			print("Use %s." % _manual_skill_command(skill_id))
			_print_skill_choices(skill_id)
			return
		choice_index = int(str(parts[2]).strip_edges())
		if not _skill_choice_indices(skill_id).has(choice_index):
			print("Index %d is not a legal choice for %s." % [choice_index, SkillTreeLibrary.display_name(skill_id)])
			_print_skill_choices(skill_id)
			return
	elif parts.size() >= 3:
		print("%s does not take an index. Use %s." % [SkillTreeLibrary.display_name(skill_id), _manual_skill_command(skill_id)])
		return

	var before_state: Dictionary = _combat_state.duplicate(true)
	var before_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var next_state: Dictionary
	match effect_type:
		"discard_draw":
			next_state = _combat_engine.use_quick_wits(_combat_state, choice_index)
		"discard_recall":
			next_state = _combat_engine.use_encore(_combat_state, choice_index)
		"arm_intensity":
			next_state = _combat_engine.arm_prismatic_instinct(_combat_state, choice_index)
		"preserve_burn":
			next_state = _combat_engine.arm_rehearsed_escape(_combat_state)
		"preserve_item":
			next_state = _combat_engine.arm_makeshift_tool(_combat_state)
		"arm_movement_blink":
			next_state = _combat_engine.arm_ghost_stride(_combat_state)
		"convert_block":
			next_state = _combat_engine.arm_carry_the_guard(_combat_state)
		_:
			print("%s has no headless manual dispatcher for effect `%s`." % [SkillTreeLibrary.display_name(skill_id), effect_type])
			return
	if next_state.is_empty() or next_state == before_state:
		print("%s did not change combat state." % SkillTreeLibrary.display_name(skill_id))
		return

	_combat_state = next_state.duplicate(true)
	_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	_analytics_reconcile_combat_tracker(before_state, _combat_state)
	_log_card_draws(before_state, _combat_state, before_tracker, _analytics_snapshot_combat_tracker(), "skill")
	_log_playable_cards()
	var status: String = _manual_skill_status(skill_id)
	var action_word: String = "Armed" if status == "ARMED" else "Activated"
	print("%s %s (`%s`). Plays %d -> %d; Time spent %d -> %d." % [
		action_word,
		SkillTreeLibrary.display_name(skill_id),
		skill_id,
		_combat_engine.cards_remaining_this_turn(before_state),
		_combat_engine.cards_remaining_this_turn(_combat_state),
		int(before_state.get("player_turn_time_spent", 0)),
		int(_combat_state.get("player_turn_time_spent", 0))
	])
	for log_line: String in _new_log_lines(before_state, _combat_state):
		print("  %s" % log_line)
	_print_state()

func _manual_skill_status(skill_id: String) -> String:
	if str(_run_state.get("mode", "")) != "combat":
		return "MANUAL"
	var flags: Dictionary = _combat_state.get("skill_flags", {}) as Dictionary
	var armed: bool = false
	match SkillTreeLibrary.effect_type(skill_id):
		"arm_intensity":
			armed = bool(flags.get("prismatic_armed", false))
		"preserve_burn":
			armed = bool(flags.get("burn_preserve_armed", false))
		"preserve_item":
			armed = bool(flags.get("item_preserve_armed", false))
		"arm_movement_blink":
			armed = bool(flags.get("movement_blink_armed", false))
		"convert_block":
			armed = bool(flags.get("guard_carry_armed", false))
	if armed:
		return "ARMED"
	if _combat_engine.skill_was_used(_combat_state, skill_id):
		return "SPENT"
	if _combat_engine.skill_is_ready(_combat_state, skill_id):
		return "READY"
	return "WAITING"

func _manual_skill_command(skill_id: String) -> String:
	if SkillTreeLibrary.effect_type(skill_id) in ["discard_draw", "discard_recall", "arm_intensity"]:
		return "`skill %s INDEX`" % skill_id
	return "`skill %s`" % skill_id

func _skill_choice_indices(skill_id: String) -> Array[int]:
	var result: Array[int]
	var effect_type: String = SkillTreeLibrary.effect_type(skill_id)
	if effect_type == "arm_intensity":
		return _combat_engine.prismatic_target_hand_indices(_combat_state)
	var deck: Dictionary = _combat_state.get("deck", {}) as Dictionary
	var cards: Array = deck.get("discard", []) if effect_type == "discard_recall" else deck.get("hand", [])
	for index: int in range(cards.size()):
		if effect_type == "discard_recall" and GameData.card_is_item(str(cards[index])):
			continue
		result.append(index)
	return result

func _print_skill_choices(skill_id: String) -> void:
	var effect_type: String = SkillTreeLibrary.effect_type(skill_id)
	if effect_type not in ["discard_draw", "discard_recall", "arm_intensity"]:
		return
	var zone: String = "discard" if effect_type == "discard_recall" else "hand"
	var cards: Array = ((_combat_state.get("deck", {}) as Dictionary).get(zone, []) as Array)
	var indices: Array[int] = _skill_choice_indices(skill_id)
	if indices.is_empty():
		print("Legal choices: none.")
		return
	print("Legal %s choices:" % zone)
	for index: int in indices:
		var card_id: String = str(cards[index])
		print("- %d: %s (`%s`)" % [index, str(_card_def(card_id, _combat_state).get("name", card_id)), card_id])

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
		if requested not in ["printed", "play"]:
			print("Cards only use their printed actions. Use `card N` or `drag N play`.")
			return
	_start_card_from_input(hand_index, "printed", "click")

func _command_drag(parts: PackedStringArray) -> void:
	if str(_run_state.get("mode", "")) != "combat":
		print("Not in combat.")
		return
	if parts.size() < 3:
		print("Drag needs a card and lane: `drag N play`.")
		_print_cards()
		return
	var hand_index: int = int(parts[1])
	var lane: String = parts[2].strip_edges().to_lower()
	if lane == "printed":
		lane = "play"
	if lane != "play":
		print("Unknown drag lane: %s. Cards only use the play lane." % lane)
		return
	_start_card_from_input(hand_index, "printed", "drag play")

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
	return _combat_engine.card_play_actions(card_id, _combat_state)

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
				var skip_allowed_when_empty: bool = _target_action_can_skip(action, actions) and bool(_preview_actions(working_state, str(_pending.get("card_id", "")), actions, cursor + 1, effect_seen).get("playable", false))
				if skip_allowed_when_empty:
					_pending["state"] = working_state
					_pending["action_index"] = cursor
					_pending["effect_seen"] = effect_seen
					_pending["target_tiles"] = _vector2i_array([])
					_pending["skip_allowed"] = true
					_print_pending()
					return
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
	var target_label: String = _target_label_at_tile((_pending.get("state", {}) as Dictionary), tile)
	if not target_label.is_empty():
		return "%s at %s" % [target_label, _coord_text(tile)]
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
		if _enemy_footprint_tiles(enemy).has(tile):
			return "enemy %d" % live_index
		live_index += 1
	return ""

func _target_label_at_tile(state: Dictionary, tile: Vector2i) -> String:
	var enemy_label: String = _enemy_label_at_tile(state, tile)
	if not enemy_label.is_empty():
		return enemy_label
	var terrain: Dictionary = _terrain_at_tile(state, tile)
	if not terrain.is_empty():
		return _terrain_label(terrain)
	var trap: Dictionary = _trap_at_tile(state, tile)
	if not trap.is_empty():
		return "%s trap" % ElementData.name(str(trap.get("element", ElementData.NONE)))
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
		var move_gain: String = _movement_gain_text(
			(_pending.get("state", {}) as Dictionary),
			((_pending.get("actions", []) as Array)[int(_pending.get("action_index", 0))] as Dictionary),
			move_target
		)
		var move_bits: Array[String] = []
		if not move_risk.is_empty():
			move_bits.append(move_risk)
		if not move_gain.is_empty():
			move_bits.append(move_gain)
		var move_suffix: String = "" if move_bits.is_empty() else ", %s" % ", ".join(move_bits)
		return "(shortcut: %s%s, then %s)" % [move_text, move_suffix, _target_hint(state, action, choice.get("tile", INVALID_TARGET_TILE))]
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
	_combat_state = _combat_engine.finish_player_card(resolved_state, hand_index, _combat_engine.card_plays_spent_for_actions(actions), {"play_mode": "play"})
	if GameData.card_consumes_on_play(card_id):
		_run_state = _run_engine.consume_equipped_item_card(_run_state, card_id)
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
	_append_note("- Played %s: %s.\n" % [card_id, _card_delta_text(before_combat_state, transition_state, actions)])
	_print_card_resolution(card_id, before_combat_state, transition_state, actions, targets)
	_pending = {}
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
	var scheduled_state: Dictionary = _combat_engine.finish_player_activation(_combat_state)
	var phase: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(scheduled_state)
	var after_phase_state: Dictionary = (phase.get("state", {}) as Dictionary).duplicate(true)
	_log_enemy_status_ticks(phase, after_phase_state)
	var hp_before: int = int((before_combat_state.get("player", {}) as Dictionary).get("hp", 0))
	var before_draw_state: Dictionary = (phase.get("player_turn_before_state", {}) as Dictionary).duplicate(true)
	var after_enemy_state: Dictionary = before_draw_state if not before_draw_state.is_empty() else after_phase_state
	var hp_after_enemy: int = int((after_enemy_state.get("player", {}) as Dictionary).get("hp", 0))
	var outcome: String = _combat_engine.combat_outcome(after_phase_state)
	_combat_state = after_phase_state
	var next_turn_state: Dictionary = {}
	if outcome.is_empty() and not before_draw_state.is_empty():
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

func _command_linger() -> void:
	if str(_run_state.get("mode", "")) != "campfire":
		print("Not at campfire.")
		return
	var hp_before: int = int(_run_state.get("player_hp", 0))
	_run_state = _run_engine.leave_campfire(_run_state, CAMPFIRE_LINGER_HEAL_AMOUNT)
	var hp_after: int = int(_run_state.get("player_hp", hp_before))
	_sync_combat_state_from_run()
	_append_note("- Campfire: lingered, healed %d, and continued with %d unbanked embers.\n" % [
		maxi(0, hp_after - hp_before),
		int(_run_state.get("unbanked_embers", 0))
	])
	_print_state()

func _command_level_up(parts: PackedStringArray) -> void:
	if str(_run_state.get("mode", "")) != "campfire":
		print("Not at campfire.")
		return
	_sync_progression_from_run()
	if parts.size() != 1:
		print("Use `level`; spend banked points separately with `learn SKILL_ID`.")
		return
	if not ProgressionStore.can_level_up(_progression):
		print("Cannot level. Held embers %d, next cost %d." % [
			_run_engine.held_embers(_run_state),
			ProgressionStore.next_level_cost(_progression)
		])
		return
	var before_progression: Dictionary = _progression.duplicate(true)
	var level_cost: int = ProgressionStore.next_level_cost(before_progression)
	var held_embers_before: int = _run_engine.held_embers(_run_state)
	_progression = ProgressionStore.purchase_level(_progression)
	ProgressionStore.save_data(_progression)
	_run_state = _run_engine.apply_progression_update(_run_state, _progression, false)
	_run_state = _run_engine.leave_campfire(_run_state, 0)
	ProgressionStore.save_run_state(_run_state)
	_sync_combat_state_from_run()
	_log_level_up(before_progression, _progression, level_cost)
	_append_note("- Campfire: reached level %d, banked one skill point, and continued with %d unbanked embers.\n" % [
		int(_progression.get("level", 1)),
		int(_run_state.get("unbanked_embers", 0))
	])
	print("Level %d -> %d; held embers %d -> %d (spent %d). Skill points: %d unspent." % [
		int(before_progression.get("level", 1)),
		int(_progression.get("level", 1)),
		held_embers_before,
		_run_engine.held_embers(_run_state),
		level_cost,
		ProgressionStore.unspent_skill_points(_progression)
	])
	_print_state()

func _command_rest() -> void:
	if str(_run_state.get("mode", "")) != "campfire":
		print("Not at campfire.")
		return
	var banked: int = _run_engine.held_embers(_run_state)
	_sync_progression_from_run()
	_progression = ProgressionStore.set_embers(_progression, banked)
	_progression = ProgressionStore.mark_rested_at_fire(_progression)
	ProgressionStore.save_data(_progression)
	_run_state = _run_engine.clear_held_embers(_run_state)
	_run_state["mode"] = "rested"
	_run_state["game_over"] = true
	_run_state["progression"] = _progression.duplicate(true)
	_log_run_ended("rested")
	_append_note("- Campfire: rested and banked %d embers.\n" % banked)
	_print_state()

func _print_campfire_state() -> void:
	_sync_progression_from_run()
	var hp_before: int = int(_run_state.get("player_hp", 0))
	var max_hp: int = maxi(1, int(_run_state.get("player_max_hp", 1)))
	var hp_after_linger: int = mini(max_hp, hp_before + CAMPFIRE_LINGER_HEAL_AMOUNT)
	var held_embers: int = _run_engine.held_embers(_run_state)
	var next_cost: int = ProgressionStore.next_level_cost(_progression)
	var level_status: String = "available"
	if ProgressionStore.is_max_level(_progression):
		level_status = "maximum level"
	elif not ProgressionStore.can_level_up(_progression):
		level_status = "need %d embers" % next_cost
	print("Campfire choices:")
	print("- `linger`: heal %d and continue (%d/%d -> %d/%d HP)." % [
		CAMPFIRE_LINGER_HEAL_AMOUNT,
		hp_before,
		max_hp,
		hp_after_linger,
		max_hp
	])
	print("- `level`: spend embers, bank one skill point, and continue (%s)." % level_status)
	if ProgressionStore.unspent_skill_points(_progression) > 0:
		print("- `learn SKILL_ID`: spend one of %d banked skill points now." % ProgressionStore.unspent_skill_points(_progression))
	print("- `rest`: bank/carry %d held embers and end this run." % held_embers)
	print("- `leave`: continue without taking a campfire benefit.")
	_print_legal_learn_skills(_legal_learn_skill_ids(_progression))

func _legal_learn_skill_ids(progression: Dictionary) -> Array[String]:
	if ProgressionStore.unspent_skill_points(progression) <= 0:
		var no_skill_ids: Array[String]
		return no_skill_ids
	return ProgressionStore.available_skill_ids(progression)

func _print_legal_learn_skills(skill_ids: Array[String]) -> void:
	if skill_ids.is_empty():
		print("Legal abilities: none.")
		return
	print("Legal abilities:")
	for skill_id: String in skill_ids:
		print("- `%s`: %s — %s" % [
			skill_id,
			SkillTreeLibrary.display_name(skill_id),
			SkillTreeLibrary.description(skill_id)
		])

func _sync_progression_from_run() -> void:
	var run_progression: Dictionary = _progression.duplicate(true)
	if typeof(_run_state.get("progression", {})) == TYPE_DICTIONARY:
		run_progression = (_run_state.get("progression", {}) as Dictionary).duplicate(true)
	_progression = ProgressionStore.set_embers(run_progression, _run_engine.held_embers(_run_state))
	_run_state["progression"] = _progression.duplicate(true)

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
	if not _combat_state.is_empty():
		_combat_state = _combat_engine.normalize_player_movement_pool(_combat_state)
		_run_state["combat_state"] = _combat_state.duplicate(true)

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
		"initiative_clock": int(combat_state.get("initiative_clock", 0)),
		"current_actor_kind": str((combat_state.get("current_actor", {}) as Dictionary).get("kind", "")),
		"current_actor_key": str((combat_state.get("current_actor", {}) as Dictionary).get("actor_key", "")),
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
		"equipped_items": (_run_state.get("equipped_items", []) as Array).duplicate(true),
		"item_inventory": (_run_state.get("item_inventory", []) as Array).duplicate(true),
		"driver": "manual_headless"
	})

func _log_run_ended(outcome: String) -> void:
	_analytics_store.write_event("run_ended", _analytics_context(_combat_state), {
		"outcome": outcome,
		"turns_spent": int(_run_state.get("turns_spent", 0)),
		"unbanked_embers": int(_run_state.get("unbanked_embers", 0)),
		"mode": str(_run_state.get("mode", ""))
	})

func _log_level_up(before_progression: Dictionary, after_progression: Dictionary, cost: int) -> void:
	_analytics_store.write_event("progression_level_up", _analytics_context(_combat_state), {
		"level_before": int(before_progression.get("level", 1)),
		"level_after": int(after_progression.get("level", 1)),
		"skill_ids": ProgressionStore.selected_skill_ids(after_progression),
		"unspent_skill_points_before": ProgressionStore.unspent_skill_points(before_progression),
		"unspent_skill_points_after": ProgressionStore.unspent_skill_points(after_progression),
		"cost": cost,
		"held_embers_after": int(after_progression.get("embers", 0)),
		"room": _run_state.get("current_room", Vector2i.ZERO)
	})

func _log_skill_learned(before_progression: Dictionary, after_progression: Dictionary, skill_id: String) -> void:
	_analytics_store.write_event("progression_skill_learned", _analytics_context(_combat_state), {
		"skill_id": skill_id,
		"skill_ids": ProgressionStore.selected_skill_ids(after_progression),
		"unspent_skill_points_before": ProgressionStore.unspent_skill_points(before_progression),
		"unspent_skill_points_after": ProgressionStore.unspent_skill_points(after_progression),
		"room": _run_state.get("current_room", Vector2i.ZERO)
	})

func _log_combat_started(reason: String) -> void:
	_analytics_store.write_event("combat_started", _analytics_context(_combat_state), {
		"reason": reason,
		"room_name": str(_combat_state.get("room_name", "")),
		"room_type": str(_combat_state.get("room_type", "")),
		"room_coord": _combat_state.get("room_coord", Vector2i.ZERO),
		"elemental_intensity": _combat_engine.elemental_intensities(_combat_state),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"equipped_items": (_run_state.get("equipped_items", []) as Array).duplicate(true),
		"item_inventory": (_run_state.get("item_inventory", []) as Array).duplicate(true),
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
		if not printed_playable:
			continue
		playable_logged[instance_id] = true
		_analytics_store.write_event("card_became_playable", _analytics_context(_combat_state, card_id, instance_id), {
			"hand_index": index,
			"printed_playable": printed_playable,
			"attack_playable": false,
			"move_playable": false
		})
	_analytics_tracker["playable_logged"] = playable_logged

func _card_play_payload(card_id: String, before_state: Dictionary, resolved_state: Dictionary, actions: Array, targets: Array[Vector2i]) -> Dictionary:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = resolved_state.get("player", {})
	var before_pos: Vector2i = before_player.get("pos", Vector2i.ZERO)
	var after_pos: Vector2i = after_player.get("pos", Vector2i.ZERO)
	var printed_card: Dictionary = _card_def(card_id, before_state)
	var capacity_delta: int = _card_play_capacity_value(resolved_state) - _card_play_capacity_value(before_state)
	var intensity_before: Dictionary = _combat_engine.elemental_intensities(before_state)
	var intensity_after: Dictionary = _combat_engine.elemental_intensities(resolved_state)
	var flurry_plays_spent: int = _combat_engine.card_plays_spent_for_actions(actions)
	var flurry_played: bool = bool(printed_card.get("flurry", false))
	var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, resolved_state)
	return {
		"play_mode": "printed",
		"flurry": flurry_played,
		"flurry_plays_spent": flurry_plays_spent if flurry_played else 0,
		"printed_health_cost": int(printed_card.get("health_cost", 0)),
		"consume_on_play": GameData.card_consumes_on_play(card_id),
		"item_card": GameData.card_is_item(card_id),
		"enemy_hp_damage": _enemy_damage_between(before_state, resolved_state),
		"enemy_block_removed": _enemy_block_removed_between(before_state, resolved_state),
		"enemy_stoneskin_removed": _enemy_stoneskin_removed_between(before_state, resolved_state),
		"terrain_hp_damage": _terrain_damage_between(before_state, resolved_state),
		"terrain_destroyed": _terrain_destroyed_between(before_state, resolved_state),
		"traps_triggered": triggered_traps.size(),
		"triggered_trap_damage": _triggered_trap_damage(triggered_traps),
		"pickups_collected": _picked_loot_between(before_state, resolved_state).size(),
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
		"card_time": _combat_engine.card_time_cost_from_def(printed_card),
		"turn_time_spent_before": int(before_state.get("player_turn_time_spent", 0)),
		"turn_time_spent_after": int(resolved_state.get("player_turn_time_spent", int(before_state.get("player_turn_time_spent", 0)) + _combat_engine.card_time_cost_from_def(printed_card))),
		"player_base_initiative": _combat_engine.player_base_initiative(before_state),
		"pierce_actions": _pierce_action_count(actions),
		"enemy_defense_bypassed": _enemy_defense_bypassed_between(before_state, resolved_state, actions),
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

func _analytics_comparable_actions(actions: Array) -> Array:
	var result: Array = []
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			result.append(action_var)
			continue
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		action.erase("orientation")
		action.erase("force_direction")
		action.erase("_flurry_repeat_index")
		action.erase("_flurry_repeat_count")
		result.append(action)
	return result

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
	print("Resolved %s: %s" % [str(_card_def(card_id, before_state).get("name", card_id)), _card_delta_text(before_state, after_state, actions)])
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

func _pierce_action_count(actions: Array) -> int:
	var count: int = 0
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if not bool(action.get("pierce", false)):
			continue
		if str(action.get("type", "")) in ["melee", "ranged", "aoe", "push", "pull"]:
			count += 1
	return count

func _enemy_defense_bypassed_between(before_state: Dictionary, after_state: Dictionary, actions: Array) -> int:
	if _pierce_action_count(actions) <= 0:
		return 0
	var total: int = 0
	var after_by_id: Dictionary = _enemies_by_id(after_state)
	for before_enemy: Dictionary in _live_enemies(before_state):
		var enemy_id: int = int(before_enemy.get("id", -1))
		if not after_by_id.has(enemy_id):
			continue
		var after_enemy: Dictionary = after_by_id[enemy_id]
		var hp_loss: int = maxi(0, int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0)))
		if hp_loss <= 0:
			continue
		var before_defense: int = maxi(0, int(before_enemy.get("block", 0))) + maxi(0, int(before_enemy.get("stoneskin", 0)))
		total += mini(hp_loss, before_defense)
	return total

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
	var headline: Array = _player_loss_bits(before_player, after_enemy_player)
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

func _player_loss_bits(before_player: Dictionary, after_player: Dictionary) -> Array:
	var bits: Array = []
	var hp_loss: int = maxi(0, int(before_player.get("hp", 0)) - int(after_player.get("hp", 0)))
	var block_loss: int = maxi(0, int(before_player.get("block", 0)) - int(after_player.get("block", 0)))
	if hp_loss > 0:
		bits.append("-%d HP" % hp_loss)
	if block_loss > 0:
		bits.append("-%d block" % block_loss)
	var status_delta: String = _player_status_delta_text(before_player, after_player)
	if not status_delta.is_empty():
		bits.append(status_delta)
	return bits

func _enemy_phase_step_lines(steps: Array) -> Array[String]:
	var lines: Array[String] = []
	for step_var: Variant in steps:
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var text: String = _enemy_step_text(step_var as Dictionary)
		if not text.is_empty():
			lines.append(text)
	return lines

func _enemy_phase_step_summary(lines: Array[String], start_index: int) -> String:
	var samples: Array[String] = []
	for index: int in range(start_index, mini(lines.size(), start_index + 3)):
		samples.append(lines[index])
	if lines.size() > start_index + samples.size():
		samples.append("%d later" % (lines.size() - start_index - samples.size()))
	return " | ".join(samples)

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
			var terrain_losses: String = _terrain_losses_text(step.get("terrain_losses", []))
			if not terrain_losses.is_empty():
				bits.append(terrain_losses)
			var triggered_traps: String = _triggered_traps_text(step.get("triggered_traps", []))
			if not triggered_traps.is_empty():
				bits.append(triggered_traps)
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

func _terrain_losses_text(losses: Array) -> String:
	var parts: Array[String] = []
	for loss_var: Variant in losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var hp_loss: int = int(loss.get("hp_loss", loss.get("amount", 0)))
		if hp_loss <= 0:
			continue
		parts.append("%s -%d HP" % [str(loss.get("kind", "terrain")).replace("_", " "), hp_loss])
	return ", ".join(parts)

func _triggered_traps_text(traps: Array) -> String:
	var parts: Array[String] = []
	for trap_var: Variant in traps:
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		parts.append("%s %s" % [_coord_text(trap.get("pos", Vector2i.ZERO)), _trap_text(trap)])
	if parts.is_empty():
		return ""
	return "triggered " + " / ".join(parts)

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
	parts.append("%d time" % int(card.get("time", 5)))
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
			var state: Dictionary = (_pending.get("state", _combat_state) as Dictionary)
			return "%s dmg %d range %d%s%s" % [action_type, _combat_engine.final_damage_for_player_action(state, action), int(action.get("range", 0)), suffix, _aoe_tiles_suffix(state, action)]
		"move", "blink", "illusion":
			return "%s range %d%s" % [action_type, int(action.get("range", 0)), suffix]
		"block", "stoneskin", "heal", "draw", "card_play":
			return "%s %d%s" % [action_type, int(action.get("amount", 0)), suffix]
		"intensity":
			var element_id: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
			return "%s intensity +%d%s" % [ElementData.name(element_id), int(action.get("amount", 0)), suffix]
		_:
			return action_type + suffix

func _deck_summary_text(state: Dictionary) -> String:
	var deck: Dictionary = state.get("deck", {})
	var hand_count: int = (deck.get("hand", []) as Array).size()
	var draw_count: int = (deck.get("draw", []) as Array).size()
	var discard_count: int = (deck.get("discard", []) as Array).size()
	var burned_count: int = (deck.get("burned", []) as Array).size()
	var next_fatigue: int = int(deck.get("fatigue_base", CombatEngine.FATIGUE_BASE_DAMAGE)) + int(deck.get("cycles", 0))
	return "%d/%d, draw %d, discard %d, burned %d, next fatigue %d on reshuffle" % [
		hand_count,
		CombatEngine.MAX_HAND_SIZE,
		draw_count,
		discard_count,
		burned_count,
		next_fatigue
	]

func _aoe_tiles_suffix(state: Dictionary, action: Dictionary) -> String:
	if state.is_empty() or str(action.get("type", "")) != "aoe" or int(action.get("range", 0)) > 0:
		return ""
	var tiles: Array[Vector2i] = _combat_engine.aoe_tiles_for_player_action(state, action)
	if tiles.is_empty():
		return ""
	var labels: Array[String] = []
	for tile: Vector2i in tiles:
		var target_label: String = _target_label_at_tile(state, tile)
		labels.append("%s at %s" % [target_label, _coord_text(tile)] if not target_label.is_empty() else _coord_text(tile))
	return " hits %s" % ", ".join(labels)

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
	if bool(action.get("pierce", false)):
		extras.append("pierce")
	if bool(action.get("immobilize", false)):
		extras.append("immobilize")
	for status_key: String in ["burn", "freeze", "shock", "poison", "chain", "push", "pull"]:
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
	if bool(bonus.get("immobilize", false)):
		parts.append("immobilize")
	if bool(bonus.get("pierce", false)):
		parts.append("pierce")
	return ", ".join(parts)

func _target_hint(state: Dictionary, action: Dictionary, target: Vector2i) -> String:
	var after_state: Dictionary = _combat_engine.apply_player_action(state, action, target)
	var damage: int = _enemy_damage_between(state, after_state)
	var defense_bypassed: int = _enemy_defense_bypassed_between(state, after_state, [action])
	var block_removed: int = _enemy_block_removed_between(state, after_state)
	var stoneskin_removed: int = _enemy_stoneskin_removed_between(state, after_state)
	var terrain_damage: int = _terrain_damage_between(state, after_state)
	var terrain_destroyed: int = _terrain_destroyed_between(state, after_state)
	var triggered_traps: Array[Dictionary] = _triggered_traps_between(state, after_state)
	var kills: int = _kills_between(state, after_state)
	var hp_delta: int = int((after_state.get("player", {}) as Dictionary).get("hp", 0)) - int((state.get("player", {}) as Dictionary).get("hp", 0))
	var block_delta: int = int((after_state.get("player", {}) as Dictionary).get("block", 0)) - int((state.get("player", {}) as Dictionary).get("block", 0))
	var move_risk: String = _movement_risk_text(state, action, target, [], false)
	var intensity_delta: String = _intensity_delta_text(state, after_state)
	var picked_loot: String = _picked_loot_text_between(state, after_state)
	var bits: Array[String] = []
	if damage > 0:
		bits.append("%d dmg" % damage)
	if defense_bypassed > 0:
		bits.append("pierced %d defense" % defense_bypassed)
	if block_removed > 0:
		bits.append("%d block" % block_removed)
	if stoneskin_removed > 0:
		bits.append("%d stone" % stoneskin_removed)
	if terrain_damage > 0:
		bits.append("%d terrain dmg" % terrain_damage)
	if terrain_destroyed > 0:
		bits.append("%d terrain broken" % terrain_destroyed)
	if not triggered_traps.is_empty():
		bits.append(_triggered_traps_text(triggered_traps))
		if damage <= 0 and terrain_damage <= 0:
			bits.append("trap-only blast; no enemy hit")
	if kills > 0:
		bits.append("%d kill" % kills)
	if hp_delta != 0:
		bits.append("%+d hp" % hp_delta)
	if block_delta > 0:
		bits.append("+%d block" % block_delta)
	if not picked_loot.is_empty():
		bits.append(picked_loot)
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

func _card_delta_text(before_state: Dictionary, after_state: Dictionary, actions: Array = []) -> String:
	var bits: Array[String] = []
	var damage: int = _enemy_damage_between(before_state, after_state)
	var enemy_block_removed: int = _enemy_block_removed_between(before_state, after_state)
	var enemy_stoneskin_removed: int = _enemy_stoneskin_removed_between(before_state, after_state)
	var terrain_damage: int = _terrain_damage_between(before_state, after_state)
	var terrain_destroyed: int = _terrain_destroyed_between(before_state, after_state)
	var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, after_state)
	var picked_loot: String = _picked_loot_text_between(before_state, after_state)
	var kills: int = _kills_between(before_state, after_state)
	var hp_delta: int = int((after_state.get("player", {}) as Dictionary).get("hp", 0)) - int((before_state.get("player", {}) as Dictionary).get("hp", 0))
	var block_delta: int = int((after_state.get("player", {}) as Dictionary).get("block", 0)) - int((before_state.get("player", {}) as Dictionary).get("block", 0))
	var move_delta: int = _player_move_distance_between(before_state, after_state)
	var drawn: int = _draw_entries_between_states(before_state, after_state).size()
	var card_plays_delta: int = maxi(0, _card_play_capacity_value(after_state) - _card_play_capacity_value(before_state))
	var illusions_created: int = _illusions_created_between(before_state, after_state)
	var intensity_delta: String = _intensity_delta_text(before_state, after_state)
	var defense_bypassed: int = _enemy_defense_bypassed_between(before_state, after_state, actions)
	var enemy_status: String = _status_breakdown_text(_enemy_status_added_breakdown(before_state, after_state))
	var player_status: String = _player_status_delta_text(before_state.get("player", {}), after_state.get("player", {}))
	if damage > 0:
		bits.append("%d damage" % damage)
	if defense_bypassed > 0:
		bits.append("pierced %d defense" % defense_bypassed)
	if enemy_block_removed > 0:
		bits.append("%d block removed" % enemy_block_removed)
	if enemy_stoneskin_removed > 0:
		bits.append("%d stone removed" % enemy_stoneskin_removed)
	if terrain_damage > 0:
		bits.append("%d terrain damage" % terrain_damage)
	if terrain_destroyed > 0:
		bits.append("%d terrain broken" % terrain_destroyed)
	if not triggered_traps.is_empty():
		bits.append("%d trap blast" % triggered_traps.size())
		if damage <= 0 and terrain_damage <= 0:
			bits.append("trap-only; no enemy hit")
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
	if not picked_loot.is_empty():
		bits.append(picked_loot)
	return ", ".join(bits) if not bits.is_empty() else "low impact"

func _status_text(unit: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in ["burn", "freeze", "shock", "stoneskin"]:
		if int(unit.get(key, 0)) > 0:
			parts.append("%s=%d" % [key, int(unit.get(key, 0))])
	if bool(unit.get("immobilize", false)):
		parts.append("immobilize")
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
	if bool(restrictions.get("immobilized", false)):
		parts.append("immobilized: movement locked")
	var pending: String = str(state.get("pending_player_trap_restriction", ""))
	if not pending.is_empty():
		parts.append("pending trap %s" % pending)
	return "[" + "; ".join(parts) + "]" if not parts.is_empty() else ""

func _player_status_delta_text(before_player: Dictionary, after_player: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in ["burn", "freeze", "shock"]:
		var delta: int = int(after_player.get(key, 0)) - int(before_player.get(key, 0))
		if delta > 0:
			parts.append(_player_status_gain_text(key, delta))
	if bool(after_player.get("immobilize", false)) and not bool(before_player.get("immobilize", false)):
		parts.append("+immobilize (movement locked next turn)")
	var before_poison: int = int((before_player.get("poison", {}) as Dictionary).get("damage", 0))
	var after_poison: int = int((after_player.get("poison", {}) as Dictionary).get("damage", 0))
	if after_poison > before_poison:
		parts.append("+%d poison" % (after_poison - before_poison))
	return ", ".join(parts)

func _player_status_gain_text(status: String, amount: int) -> String:
	match status:
		"freeze":
			return "+%d freeze (next turn locked; incoming damage doubled while active)" % amount
		"shock":
			return "+%d shock (next turn action-limited)" % amount
		"burn":
			return "+%d burn (HP tick)" % amount
		_:
			return "+%d %s" % [amount, status]

func _status_breakdown_text(breakdown: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in ["burn", "freeze", "shock", "poison", "immobilize"]:
		var amount: int = int(breakdown.get(key, 0))
		if amount > 0:
			var text: String = "+immobilize" if key == "immobilize" else "+%d %s" % [amount, key]
			parts.append(text)
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

func _movement_gain_text(state: Dictionary, action: Dictionary, target: Vector2i) -> String:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["move", "blink"] or target == INVALID_TARGET_TILE:
		return ""
	var after_state: Dictionary = _combat_engine.apply_player_action(state, action, target)
	var bits: Array[String] = []
	var hp_delta: int = int((after_state.get("player", {}) as Dictionary).get("hp", 0)) - int((state.get("player", {}) as Dictionary).get("hp", 0))
	var block_delta: int = int((after_state.get("player", {}) as Dictionary).get("block", 0)) - int((state.get("player", {}) as Dictionary).get("block", 0))
	if hp_delta > 0:
		bits.append("+%d HP" % hp_delta)
	if block_delta > 0:
		bits.append("+%d block" % block_delta)
	var picked_loot: String = _picked_loot_text_between(state, after_state)
	if not picked_loot.is_empty():
		bits.append(picked_loot)
	if bits.is_empty():
		return ""
	return "move gain: %s" % ", ".join(bits)

func _loot_text(loot: Dictionary) -> String:
	match str(loot.get("kind", "")):
		"healing_vial":
			return "Healing potion: Heal %d" % int(loot.get("amount", 0))
		"rusty_shield":
			return "Rusty shield: Gain %d block" % int(loot.get("amount", 0))
	return "Loot"

func _terrain_label(terrain: Dictionary) -> String:
	return "wooden crate" if str(terrain.get("kind", "")) == "wooden_crate" else "wooden box"

func _terrain_text(terrain: Dictionary) -> String:
	return "%s HP %d/%d, blocks movement, LoS open, attackable" % [
		_terrain_label(terrain),
		int(terrain.get("hp", 0)),
		int(terrain.get("max_hp", 1))
	]

func _terrain_at_tile(state: Dictionary, tile: Vector2i) -> Dictionary:
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if int(terrain.get("hp", 0)) <= 0:
			continue
		if terrain.get("pos", Vector2i(-1, -1)) == tile:
			return terrain
	return {}

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
		parts.append("%d adjacent blast dmg" % int(trap.get("damage", 0)))
	for key: String in ["burn", "freeze", "shock", "poison"]:
		if int(trap.get(key, 0)) > 0:
			parts.append("%s %d" % [key, int(trap.get(key, 0))])
	parts.append("attackable")
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

func _enemy_footprint_tiles(enemy: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = enemy.get("pos", Vector2i(-1, -1))
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _live_terrain(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY and int((terrain_var as Dictionary).get("hp", 0)) > 0:
			result.append(terrain_var as Dictionary)
	return result

func _enemies_by_id(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY:
			var enemy: Dictionary = enemy_var
			result[int(enemy.get("id", -1))] = enemy
	return result

func _terrain_by_id(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY:
			var terrain: Dictionary = terrain_var
			result[str(terrain.get("id", ""))] = terrain
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

func _terrain_damage_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var total: int = 0
	var after_by_id: Dictionary = _terrain_by_id(after_state)
	for before_terrain: Dictionary in _live_terrain(before_state):
		var terrain_id: String = str(before_terrain.get("id", ""))
		if after_by_id.has(terrain_id):
			total += maxi(0, int(before_terrain.get("hp", 0)) - int((after_by_id[terrain_id] as Dictionary).get("hp", 0)))
	return total

func _terrain_destroyed_between(before_state: Dictionary, after_state: Dictionary) -> int:
	var destroyed: int = 0
	var after_by_id: Dictionary = _terrain_by_id(after_state)
	for before_terrain: Dictionary in _live_terrain(before_state):
		var terrain_id: String = str(before_terrain.get("id", ""))
		if after_by_id.has(terrain_id) and int((after_by_id[terrain_id] as Dictionary).get("hp", 0)) <= 0:
			destroyed += 1
	return destroyed

func _triggered_traps_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_ids: Dictionary = {}
	for after_trap_var: Variant in after_state.get("traps", []):
		if typeof(after_trap_var) != TYPE_DICTIONARY:
			continue
		var after_trap: Dictionary = after_trap_var
		after_ids[str(after_trap.get("id", ""))] = true
	var triggered: Array[Dictionary] = []
	for before_trap_var: Variant in before_state.get("traps", []):
		if typeof(before_trap_var) != TYPE_DICTIONARY:
			continue
		var before_trap: Dictionary = before_trap_var
		var trap_id: String = str(before_trap.get("id", ""))
		if trap_id.is_empty() or after_ids.has(trap_id):
			continue
		triggered.append(before_trap)
	return triggered

func _triggered_trap_damage(triggered_traps: Array[Dictionary]) -> int:
	var total: int = 0
	for trap: Dictionary in triggered_traps:
		total += maxi(0, int(trap.get("damage", 0)))
	return total

func _picked_loot_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_claimed: Dictionary = {}
	for after_loot_var: Variant in after_state.get("loot", []):
		if typeof(after_loot_var) != TYPE_DICTIONARY:
			continue
		var after_loot: Dictionary = after_loot_var
		if bool(after_loot.get("claimed", false)):
			after_claimed[_loot_key(after_loot)] = true
	var picked: Array[Dictionary] = []
	for before_loot_var: Variant in before_state.get("loot", []):
		if typeof(before_loot_var) != TYPE_DICTIONARY:
			continue
		var before_loot: Dictionary = before_loot_var
		if bool(before_loot.get("claimed", false)):
			continue
		if after_claimed.has(_loot_key(before_loot)):
			picked.append(before_loot)
	return picked

func _picked_loot_text_between(before_state: Dictionary, after_state: Dictionary) -> String:
	var picked: Array[Dictionary] = _picked_loot_between(before_state, after_state)
	if picked.is_empty():
		return ""
	var parts: Array[String] = []
	for loot: Dictionary in picked:
		parts.append(_loot_text(loot))
	return "picked " + " / ".join(parts)

func _loot_key(loot: Dictionary) -> String:
	var loot_id: String = str(loot.get("id", ""))
	if not loot_id.is_empty():
		return loot_id
	var pos: Vector2i = loot.get("pos", Vector2i.ZERO)
	return "%s:%d:%d" % [str(loot.get("kind", "")), pos.x, pos.y]

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
	var result: Dictionary = {"burn": 0, "freeze": 0, "shock": 0, "poison": 0, "immobilize": 0}
	var after_by_id: Dictionary = _enemies_by_id(after_state)
	for before_enemy: Dictionary in _live_enemies(before_state):
		var enemy_id: int = int(before_enemy.get("id", -1))
		if not after_by_id.has(enemy_id):
			continue
		var after_enemy: Dictionary = after_by_id[enemy_id]
		for status: String in ["burn", "freeze", "shock"]:
			result[status] = int(result.get(status, 0)) + maxi(0, int(after_enemy.get(status, 0)) - int(before_enemy.get(status, 0)))
		if bool(after_enemy.get("immobilize", false)) and not bool(before_enemy.get("immobilize", false)):
			result["immobilize"] = int(result.get("immobilize", 0)) + 1
		result["poison"] = int(result.get("poison", 0)) + maxi(0, int((after_enemy.get("poison", {}) as Dictionary).get("damage", 0)) - int((before_enemy.get("poison", {}) as Dictionary).get("damage", 0)))
	return result

func _player_status_added_breakdown(before_state: Dictionary, after_state: Dictionary) -> Dictionary:
	var result: Dictionary = {"burn": 0, "freeze": 0, "shock": 0, "poison": 0, "immobilize": 0}
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	for status: String in ["burn", "freeze", "shock"]:
		result[status] = maxi(0, int(after_player.get(status, 0)) - int(before_player.get(status, 0)))
	if bool(after_player.get("immobilize", false)) and not bool(before_player.get("immobilize", false)):
		result["immobilize"] = 1
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
