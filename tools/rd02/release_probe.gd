extends Node

const Overlay = preload("res://scripts/board_occlusion_silhouettes.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const FIXTURE_SIZE := Vector2(1920, 1080)
var failures: int = 0

func _ready() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_check(OS.has_feature("release") and not OS.has_feature("editor"), "Actual release template")
	_check(Overlay.switched_on(0.30, false, true), "Threshold callable compiles in release")
	_check(Overlay.team_color({"kind": "unit", "data": {"role": "player"}}) == Color(Palette.ALLY, 0.85), "Palette in release")
	var board := Board.new()
	board.size = FIXTURE_SIZE
	add_child(board)
	var overlay: Node2D = board.get("_occlusion_silhouettes")
	_check(overlay != null, "Runtime creates overlay in release")
	overlay.sync_coverage()
	_check(overlay.get("entries").is_empty(), "Empty board supported")
	var payload: Resource = get_meta("fixture")
	var state: Dictionary = payload.get_meta("run_state")["combat_state"]
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"board_framing_mode": "combat"})
	overlay.sync_coverage()
	overlay._process(0.15)
	_check(overlay.get("entries").size() >= 3, "Real certified fight creates outlines in release")
	var live_rigs: int = 0
	for entry: Dictionary in overlay.get("entries").values():
		var sprite: Sprite2D = entry["sprite"]
		_check(sprite.material.shader == Overlay.Outline, "Shader instantiated in release")
		if sprite.texture is ViewportTexture: live_rigs += 1
	_check(live_rigs >= 2, "Hero and enemy live rig textures available in release")
	var team: RefCounted = overlay.get("team")
	_check(team.get("entries").size() == board.call("_visible_units").size(), "Every living visible unit has depth-slot team rim in release")
	for key: String in team.get("entries"):
		var rim: Sprite2D = team.get("entries")[key]["sprite"]
		var unit: Dictionary = team.get("entries")[key]["unit"]
		_check(rim.material.get_shader_parameter("rim_color") == Overlay.TeamOutlines.color_for(unit), "80% team palette in release")
		_check(rim.get_parent().get_parent() == board.get("_scene_render_layers_by_tile")[team.get("entries")[key]["tile"]], "Own unit depth slot in release")
	board.call("set_unit_outline_alpha_multiplier", "player", 0.5)
	_check(is_equal_approx(team.get("entries")["player"]["base_alpha"], 0.4), "Outline multiplier hook works in release")
	board.queue_free()
	print("RD02 RELEASE TEMPLATE: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
