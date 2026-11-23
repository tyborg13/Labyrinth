extends "res://tools/gfix34/verify.gd"

const TileBurst = preload("res://scripts/tile_burst_fx.gd")
const NEW_CASES := [
	["ember", "scorch", false, false, "ember", "fire_hit_front"],
	["spark", "arc_flash", false, false, "spark", "lightning_hit_front"],
]
const ROUND_TRIP_SECONDS: float = 0.272

var _impact_stamps: Dictionary

func _take() -> void:
	for config: Array in NEW_CASES:
		_impact_stamps.clear()
		process_frame.connect(_record_impacts)
		var clock: Vector2 = await _case(config, "")
		process_frame.disconnect(_record_impacts)
		var total: float = clock.x * clock.y
		_expect(is_equal_approx(total, ROUND_TRIP_SECONDS), config[0] + " preserves 272 ms")
		var expected_row: int = TileBurst.metadata()["rows"][config[5]]
		_expect(_impact_stamps.values() == [[HERO, expected_row]],
			config[0] + " uses one authored hit on the hero")
		print("MRG-15 TIMING %s frames=%d total=%.6fs impacts=%s expected_row=%d" % [
			config[0], clock.x, total, _impact_stamps.values(), expected_row])
	print("MRG-15 REFLECTION VERIFY: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _sample(config: Array, revision: String, spy: DrawSpy, board: Control, shown: Dictionary) -> void:
	if config.size() == 5 or float(shown["effect_progress"]) < 1.0:
		super._sample(config, revision, spy, board, shown)
		return
	var effect: Dictionary = shown["effect"]
	var fx: RefCounted = board._single_shot_fx
	spy.submitted = false
	_view_script.draw_effect(spy, effect, 1.0)
	_expect(not spy.submitted and not fx._reflected_head.visible and not fx._hits[0].visible
		and not fx._hits[1].visible and _impact_stamps.is_empty(), config[0] + " has no legacy or duplicate contact")
	_expect(effect[View.RETURN_TILE] == HERO, config[0] + " returns to the damaged actor")

func _record_impacts() -> void:
	if not is_instance_valid(_viewport) or _viewport.is_queued_for_deletion():
		return
	for stamp: Node in _scene.board_view._tile_bursts._stamps:
		if stamp.front:
			_impact_stamps[stamp.get_instance_id()] = [stamp.tile, stamp.sample.y]
