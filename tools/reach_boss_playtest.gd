extends "res://tools/board_surface_playtest.gd"

# Uses the same legal-action policy and manual-harness action boundaries, with
# an explicit isolated boss start. No tactical edits occur after this setup.
const Rooms = preload("res://scripts/room_generator.gd")
const Dragons = preload("res://scripts/dragon_boss_library.gd")

func _start_new_run(seed: int) -> void:
	super._start_new_run(seed)
	var boss: String = "zekarion"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--boss": boss = args[index + 1]
	var order: Array[String] = Dragons.elemental_boss_order(seed)
	var depth: int = 24 if boss == "noctyrax" else (order.find(boss) + 1) * 4
	assert(depth > 0 and GameData.enemy_def(boss).get("boss_bar", false), "Use a production boss id")
	var coord := Vector2i(depth, 0)
	var meta: Dictionary = {"coord": coord, "depth": depth, "type": "boss", "boss_id": boss, "element": GameData.enemy_def(boss).get("element", "none"), "revealed": true, "visited": true, "cleared": false}
	_run_state["current_room"] = coord
	_run_state["rooms"]["%d,0" % depth] = meta
	var layout: Dictionary = Rooms.new().generate_room(seed, meta, Vector2i.RIGHT)
	if boss == "noctyrax":
		_run_state["attuned_magic_cards"] = ["guiding_flare", "lantern_shot", "glowstone_ward", "prism_sight", "dawnstep", "daybreak"]
		_run_state = _run_engine._rebuild_deck_cards(_run_state)
	_run_state["current_room_layout"] = layout
	_run_state["combat_state"] = _combat_engine.create_combat(seed, layout, {"hp": 24, "max_hp": 24, "deck_cards": _run_state["deck_cards"], "relics": [], "hand_size": 7, "cards_per_turn": 2, "draw_per_turn": 2})
	_run_state["mode"] = "combat"
	_sync_combat_state_from_run()
	_log_combat_started("isolated_boss_reach_screen")
	_append_note("Isolated production boss %s at depth %d, starter gear and 24 HP. No victory-rate claim; this deliberately does not simulate acquired whole-run gear. Noctyrax uses six existing Radiance spells.\n" % [boss, depth])
	_print_state()
