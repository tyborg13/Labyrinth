extends SceneTree
## Call-level proof of the shared tile-depth route; native pixels are separate.
const Bolts = preload("res://scripts/lightning_strike_presentation.gd")
const Typed = preload("res://scripts/typed_arrays.gd")
const PROOF_TILES: Array = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
const PROOF_PROGRESS: float = 2.0 / 3.0
const PROOF_GATE_OFFSET: float = 0.001
var failures: Array[String]

class Recorder extends "res://scripts/combat_board_view.gd":
	var art_calls: Array[Dictionary]
	func _draw_dragon_area_depth(effect: Dictionary, tile: Vector2i, progress: float, foreground: bool) -> void:
		art_calls.append({"effect": effect, "tile": tile, "progress": progress, "foreground": foreground})
	func _draw_elemental_spell_scene(_style: String, _progress: float, _target: Vector2, _reduced: bool) -> void:
		art_calls.append({"forbidden_full_spell_scene": true})
	func _draw_lightning_impact(_center: Vector2, _ground: Vector2, _progress: float, _alpha: float, _reduced: bool) -> void:
		art_calls.append({"forbidden_full_spell_scene": true})

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var board := Recorder.new()
	board.size = Vector2(1920, 1080)
	board.combat_state = preload("res://tests/suites/en02_enemies_suite.gd").fixture(preload("res://scripts/combat_engine.gd").new(), "crawler")
	var witnesses: Array[Dictionary]
	for dragon: bool in [false, true]:
		var effect: Dictionary = {"kind": "lightning_strikes", "tiles": Typed.vector2i(PROOF_TILES)}
		if dragon: effect.merge({"enemy_type": "zekarion", "action_type": "lightning_strikes", "zekarion_cutout": true})
		_check(board._dragon_full_area_fx(effect), "rule and Skybreak use the same full-area route")
		for reduced: bool in [false, true]:
			board.art_calls.clear()
			board.presentation = {"effect": effect, "effect_progress": PROOF_PROGRESS, "reduced_motion": reduced}
			_check(board._effect_uses_elemental_scene_depth(effect), "each strike is depth-composited around its actor")
			var depth: Array[Vector2i] = board._elemental_scene_depth_tiles_for_presentation(board.presentation)
			for tile: Vector2i in Typed.vector2i(PROOF_TILES):
				_check(depth.has(tile), "every struck tile has a depth pass")
				board._draw_elemental_scene_depth_pass(tile, false)
				board._draw_elemental_scene_depth_pass(tile, true)
			_check(board.art_calls.size() == PROOF_TILES.size() * 2, "exactly rear/front shared sky-bolt calls on every tile")
			for entry: Dictionary in board.art_calls:
				_check(not entry.has("forbidden_full_spell_scene"), "no full-size spell composition on board strikes")
				_check(is_equal_approx(float(entry.get("progress", -1.0)), PROOF_PROGRESS), "all struck tiles share the same authored clock")
			witnesses.append({"dragon": dragon, "reduced": reduced, "calls": board.art_calls.duplicate(true)})
	_check(not Bolts.revealed({"zekarion_cutout": true}, Bolts.ZEKARION_REVEAL - PROOF_GATE_OFFSET, false), "cutout hidden before 0.38")
	_check(Bolts.revealed({"zekarion_cutout": true}, Bolts.ZEKARION_REVEAL, false), "cutout revealed at 0.38")
	_check(Bolts.revealed({"zekarion_cutout": true}, 0.0, true), "existing reduced-motion reveal bypass")
	_check(Bolts.profile() == {"geometry": "meteor", "element": "lightning"}, "same canonical Skybreak geometry")
	var directory: String = "/private/tmp/labyrinth_codex/atk-14/feedback3"
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("art-routing.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"headless_semantics_only": true, "witnesses": witnesses, "failures": failures}, "  "))
	file.close()
	board.free()
	for failure: String in failures: push_error(failure)
	print("ATK14 F3 ART ROUTING: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
