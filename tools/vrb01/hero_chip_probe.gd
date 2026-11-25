extends "res://tools/pla03/sentence_face_probe.gd"

const PoolFixture = preload("res://tests/suites/card_pool_overhaul_suite.gd")
const TOOLTIP_OFFSET := Vector2(16, 16)
const TOOLTIP_LAYER: int = 50
const CHIP_CASES: Dictionary = {
	"sworn_oath": {"icon": "next_attack", "copy": "Your next attack this turn deals 3 more damage."},
	"galvanize": {"icon": "quicken", "copy": "Your next card this turn costs 2 less Time."},
}

func _capture_cards(ids: Array, _capture_grid: bool = true) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	_viewport.add_child(instance)
	await _settle()
	var engine := CombatEngine.new()
	for card_id: String in ids:
		if not CHIP_CASES.has(card_id):
			_check_proof(false, "No post-play chip fixture for " + card_id)
			continue
		await _load_combat(instance, [card_id, "brace"])
		var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
		run_state["combat_state"] = PoolFixture._play_first(engine, instance.get("_combat_state"), [])
		instance.call("_load_run_state", run_state)
		await _settle()
		await _capture_chip(instance.get("board_view"), card_id, CHIP_CASES[card_id])
	instance.queue_free()
	await _settle()

func _capture_chip(board: Control, card_id: String, expected: Dictionary) -> void:
	var plate: RefCounted = board.get("plate_visibility")
	for unit: Dictionary in plate.call("actors"):
		if unit.get("key") != "player": continue
		for entry: Dictionary in plate.call("status_entries", unit):
			if entry.get("icon") != expected["icon"]: continue
			var hit_point: Vector2 = (entry["rect"] as Rect2).get_center()
			var tooltip: String = board.call("_get_tooltip", hit_point)
			_check_proof(tooltip == expected["copy"], card_id + " chip routes the approved tooltip")
			if tooltip != expected["copy"]: return
			var panel: Control = board.call("_make_custom_tooltip", tooltip)
			_check_proof(panel != null, card_id + " builds the live board tooltip")
			if panel == null: return
			var overlay := CanvasLayer.new()
			overlay.layer = TOOLTIP_LAYER
			_viewport.add_child(overlay)
			overlay.add_child(panel)
			panel.position = board.get_global_transform_with_canvas() * hit_point + TOOLTIP_OFFSET
			var shot: String = "chip_" + card_id
			_manifest[shot] = {"icon": entry["icon"], "tooltip": tooltip}
			print("HERO CHIP %s: %s" % [card_id, tooltip])
			await _shoot(shot)
			overlay.queue_free()
			return
	_check_proof(false, card_id + " renders a post-play hero chip")
