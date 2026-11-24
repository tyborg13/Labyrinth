extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Moves = preload("res://scripts/known_move_text.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: Dictionary = Data.enemies()
	var report: Dictionary = {}
	for enemy_id: String in catalog:
		var unit: Dictionary = {"type": enemy_id}
		var intents: Array = Data.enemy_def(enemy_id).get("intents", [])
		var lines: Array = []
		for raw: Dictionary in intents:
			var intent: Dictionary = Moves.base_intent(raw, intents)
			var rows: Array = Moves.rows(intent, unit, {}, true)
			lines.append({"id": intent["id"], "name": intent["name"], "text": Moves.summary(intent, rows)})
		report[enemy_id] = lines
	print("TXT35 MOVES " + JSON.stringify(report))
	quit()
