extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const AUDIT_ROOM_DEPTH: int = 1
const OUTPUT: String = "/private/tmp/labyrinth_codex/brs-01/roster_rows.txt"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var report: Dictionary = audit()
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + OUTPUT)
		quit(1)
		return
	file.store_string(str(report["text"]))
	file.close()
	print("ROSTER AUDIT: %d enemies; %d intents; %d flagged; %s" % [int(report["enemy_count"]), int(report["intent_count"]), int(report["flagged"]), OUTPUT])
	quit()

static func audit() -> Dictionary:
	var lines := PackedStringArray()
	var number := RegEx.create_from_string("[0-9]")
	var flagged: int = 0
	var count: int = 0
	var host := preload("res://scripts/run_scene.gd").new()
	var ids: Array = Data.enemies().keys()
	ids.sort()
	for id: String in ids:
		var battle: Dictionary = preload("res://tests/suites/en01_enemies_suite.gd").fixture([id])
		battle["room_depth"] = AUDIT_ROOM_DEPTH
		host._pre_battle_preview_run_state = {"combat_state": battle}
		lines.append("ENEMY %s | %s" % [id, str(Data.enemies()[id].get("name", ""))])
		for intent: Dictionary in host._pre_battle_known_enemy_intents(id):
			count += 1
			var shown: Dictionary = preload("res://scripts/enemy_mechanics/marked_strike.gd").presentation_intent(host._combat_engine, battle, battle["enemies"][0], intent)
			var rows: Array = Inspection.move_rows(shown)
			var text: String = Icons.plain_text_for_rows(rows)
			if text.is_empty(): text = "Recovers." if (shown.get("actions", []) as Array).is_empty() else "Special action"
			var tooltip: String = Inspection.move_tooltip(rows)
			lines.append("  INTENT %s | %s | TIME %d" % [str(intent.get("id", "")), str(intent.get("name", "")), int(intent.get("time", 0))])
			lines.append("    ROW " + text.replace("\n", " / "))
			for row: Array in rows:
				for token: Dictionary in row:
					lines.append("    TOKEN " + JSON.stringify(token))
					lines.append("      TOOLTIP " + Icons.token_tooltip(token).replace("\n", " / "))
			if number.search(text) == null and tooltip.is_empty():
				flagged += 1
				lines.append("    FLAG_NO_NUMBER_AND_NO_TOOLTIP")
	lines.append("ROSTER AUDIT: %d enemies; %d intents; %d flagged" % [ids.size(), count, flagged])
	host.free()
	return {"text": "\n".join(lines) + "\n", "enemy_count": ids.size(), "intent_count": count, "flagged": flagged}
