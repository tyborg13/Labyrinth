extends "res://tools/qa110/whole_run.gd"

const Pair = preload("res://tools/red04/red_audit.gd")
const WALK_SEED: int = 101003
const WALK_DECISION: int = 102

func _start() -> void:
	var sources: Dictionary = {}
	for path: String in ["scripts/pass_forecast_red_tiles.gd", "scripts/pass_forecast_discs.gd", "scripts/combat_engine.gd", "scripts/combat_board_view.gd", "scripts/board_layer_slices.gd", "scripts/board_threat_isolation.gd", "scripts/threat_tiles.gd", "scripts/stage_hover_refresh.gd",
		"scripts/intent_badges.gd", "scripts/enemy_mechanics/lob_view.gd", "scripts/snare_pressure_view.gd", "tools/red04/red_audit.gd"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	_emit("red04_sources", sources)
	await super._start()

func _emit(event: String, data: Dictionary) -> void:
	if event == "qa110_sample" and data.get("checks", {}).has("red"):
		var picture: Dictionary = Pair.paired(scene)
		data["red04"] = Pair.compact(picture)
		data["red04"]["selected"] = scene._selected_card_index >= 0 or scene._player_movement_selected or scene._surface_aim.active() or scene._drag_card_index >= 0
		if hunt_seed == WALK_SEED and data["context"]["decision"] == WALK_DECISION:
			var witness: Dictionary = Pair.repro(scene, false, false)
			data["red04_repro"] = witness
			print("RED04 WALK REPRO: " + JSON.stringify(witness))
	super._emit(event, data)
