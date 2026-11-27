extends "res://tools/fel01/resume_probe.gd"
## Headless contracts for the retained board draw on the three Continue fixtures.

const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const Reveal = preload("res://scripts/board_occlusion_reveal.gd")
const Palette = preload("res://scripts/ui_palette.gd")

var _failures: Array[String]
var _checked_states: int = 0
var _solid_sources: int = 0
var _fills: int = 0
var _hovered_sconces: int = 0


func _initialize() -> void:
	OS.set_environment("FEL01_DRY_RUN", "1")
	OS.set_environment("FEL01_WITNESS_ONLY", "0")
	OS.set_environment("FEL01_FIXTURE", "")
	OS.set_environment("FEL01_SAMPLES", "1")
	OS.set_environment("FEL01_FIXTURES", ProjectSettings.globalize_path("res://tools/fel01/samples"))
	super._initialize()


func _run() -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel02_witness_settings.json")
	if not Settings.save_settings(settings):
		_fail("cannot save witness settings")
		return
	var fixtures: PackedStringArray = DirAccess.get_directories_at("res://tools/fel01/samples")
	fixtures.sort()
	for fixture: String in fixtures:
		if not await _fixture(ProjectSettings.globalize_path("res://tools/fel01/samples").path_join(fixture)):
			return
	_check(_checked_states == PROVISIONAL_FIXTURE_COUNT, "resumed three sample states")
	_check(_solid_sources > 0 and _fills > 0 and _hovered_sconces > 0, "witness exercised all positive cases")
	for failure: String in _failures: printerr("FEL02 " + failure)
	var outcome: String = "PASS" if _failures.is_empty() else "FAIL"
	print("FEL02 WITNESS %s states=%d solid_sources=%d fills=%d hovered_sconces=%d failures=%d" %
		[outcome, _checked_states, _solid_sources, _fills, _hovered_sconces, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _capture_phases(scene: Node, id: String, tile: Vector2i) -> bool:
	var board: Control = scene.get("board_view")
	var reveal: Node = board.get("_occlusion_reveal")
	var overlay: Node = board.get("_occlusion_silhouettes")
	var centering: Tween = scene.get("_board_centering_tween")
	while centering != null and centering.is_running(): await process_frame
	await _settle()
	_check(reveal.focus_tile.x < 0 and reveal.targets.is_empty(), id + " has no reveal at rest")
	var sources: Array = overlay.current_sources()
	_check_rest(board, overlay, sources, id)
	await _point(_tile_center(board, tile))
	await _settle()
	_check(scene.get("_hovered_board_tile") == tile and _fade_is_settled(reveal, tile), id + " settles its real pointer reveal")
	var sconces: int = 0
	for target: Dictionary in reveal.targets.values():
		if target["category"] != "pillar": continue
		if board._pillar_torch_texture("left") == null and board._pillar_torch_texture("right") == null: continue
		var pillar_tile: Vector2i = target["tile"]
		var pillar_alpha: float = reveal.prop_alpha("pillar", pillar_tile)
		var sconce_alpha: float
		if board.has_method("_pillar_torch_alpha"):
			sconce_alpha = board._pillar_torch_alpha(pillar_tile)
		else:
			# On fel-01 the foreground tint is floored both before and after reveal.
			var pillar: Texture2D = board.get("_prop_textures")["pillar"]
			var rect: Rect2 = board._prop_draw_rect(pillar, board._prop_rect_for_tile(pillar_tile))
			var tint: Color = board._pillar_torch_tint(board._foreground_blocker_tint("pillar", pillar_tile, rect, board.get("_foreground_obstruction_entries_cache")))
			sconce_alpha = board._pillar_torch_tint(reveal.tint("pillar", pillar_tile, tint)).a
		_check(is_equal_approx(pillar_alpha, Reveal.REVEAL_ALPHA), id + " pillar shaft reveal remains 30%")
		_check(is_equal_approx(sconce_alpha, pillar_alpha), "%s sconce %.2f != pillar %.2f" % [id, sconce_alpha, pillar_alpha])
		sconces += 1
	_check(sconces > 0, id + " hover reaches a pillar with a sconce")
	_hovered_sconces += sconces
	_checked_states += 1
	return true


func _check_rest(board: Control, overlay: Node, sources: Array, id: String) -> void:
	var entries: Dictionary = overlay.get("entries")
	var obstructions: Array = board.get("_foreground_obstruction_entries_cache")
	for source: Dictionary in sources:
		if source["kind"] not in ["prop", "terrain"]: continue
		var category: String = Reveal.category_for(source)
		if category.is_empty(): category = str(source.get("prop_kind", "wall"))
		var tint: Color = board._foreground_blocker_tint(category, source["tile"], source["rect"], obstructions)
		tint = board._occlusion_reveal_tint(category, source["tile"], tint)
		_check(is_equal_approx(tint.a, 1.0), "%s %s %s rest alpha %.2f" % [id, category, str(source["tile"]), tint.a])
		_solid_sources += 1
	for index: int in range(sources.size()):
		var source: Dictionary = sources[index]
		var key: String = source.get("key", "")
		if not entries.has(key): continue
		var entry: Dictionary = entries[key]
		if not bool(entry["on"]): continue
		var kind: String = source["kind"]
		if kind != "unit":
			_check(kind in ["loot", "trap"], "%s unexpected %s rim %s" % [id, kind, key])
			continue
		var expected: float = 0.0
		var blockers: Array[Dictionary]
		for later: int in range(index + 1, sources.size()):
			var blocker: Dictionary = sources[later]
			if blocker["kind"] in ["prop", "terrain"]: blockers.append(blocker)
		if Alpha.coverage(source, blockers) > 0.0 and source["data"].get("role") != "illusion":
			expected = 0.75
			_fills += 1
		var ink: ShaderMaterial = (entry["sprite"] as Sprite2D).material
		var parameter: Variant = ink.get_shader_parameter("fill_alpha")
		var fill: float = 0.0 if parameter == null else float(parameter)
		_check(is_equal_approx(fill, expected), "%s %s fill %.2f != %.2f" % [id, key, fill, expected])
		var rim_color: Color = ink.get_shader_parameter("rim_color")
		var color: Color = Palette.DANGER if source["data"].get("role") == "enemy" else Palette.ALLY
		_check(Color(rim_color, 1.0) == Color(color, 1.0), id + " fill shares " + key + " rim colour")
		for blocker: Dictionary in entry.get("fill_blockers", []):
			_check(blocker["kind"] in ["prop", "terrain"], id + " units never supply fill masks")


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
