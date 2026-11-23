extends SceneTree

const Fx = preload("res://scripts/tile_burst_fx.gd")
const DragonSpell = preload("res://scripts/dragon_spell_presentation.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Lightning = preload("res://scripts/lightning_strike_presentation.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const Suites: Array[String] = [
	"dragon_area_presentation", "dragon_feedback1", "dragon_pressure_mechanics",
	"battlefield_rules", "battlefield_fuel", "en02_enemies",
]
const TILE := Vector2i(1, 0)
const HIDDEN := Vector2i(2, 0)
const PIXEL_SIZE_INDEX: int = 3
const METEOR_CONTACT_PIXELS: String = "a6783595a3161afb750863cab3ae28fa8e3e8f6029bd539bc6b66b8a4753503b"
var _failures: Array[String]
var _clock_usec: int

class BoardFixture extends Control:
	var tile_width: float
	var _scene_front_effect_render_layers_by_tile: Dictionary
	var _scene_back_effect_render_layers_by_tile: Dictionary
	var _visible_units_cache: Array[Dictionary]

	func _tile_width() -> float: return tile_width
	func _tile_center(tile: Vector2i) -> Vector2: return Vector2(tile) * tile_width
	func _board_tile_is_visible_to_player(tile: Vector2i) -> bool: return tile == TILE

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	if OS.get_cmdline_user_args().has("--suites"):
		for suite: String in Suites:
			var errors_before: int = _failures.size()
			await (load("res://tests/suites/%s_suite.gd" % suite) as Script).run(_expect)
			print("FX-15 FOCUSED %s %s" % [suite, "PASS" if errors_before == _failures.size() else "FAIL"])
	else:
		await _verify()
	for failure: String in _failures: printerr(failure)
	print("FX-15 VERIFY %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _verify() -> void:
	var data: Dictionary = Fx.strike_metadata()
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var board := BoardFixture.new()
	viewport.add_child(board)
	var front := Node2D.new()
	board.add_child(front)
	board._scene_front_effect_render_layers_by_tile[TILE] = front
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
	var widths: Array[int] = [100, 126, 147, 184]
	var expected: Array[int] = [1, 2, 4, 6]
	var player := Fx.new(false, true)
	for size: Vector2i in sizes:
		viewport.size = size
		for index: int in widths.size():
			board.tile_width = widths[index]
			player.sync_size(board)
			_expect(player._requested == Vector2i(2, expected[index]), "Strike size %s at %s" % [widths[index], size])
			_expect(player._requested == Fx.choice_for(widths[index], size.y), "Strike and burst cell geometry match")
			for tick: int in 60:
				if player.sheet_index == expected[index]: break
				await process_frame
				player.advance(0.0, -1)
			_expect(player.sheet_index == expected[index] and player.cell_px == 2, "Threaded size settles on the requested sheet")
		print("FX-15 SIZE %s 100/126/147/184 px => 52/60/76/92 cells at 2 px" % size)
	_verify_pixels(data)

	var grid: Array = [["stone", "stone", "stone"]]
	var effects: Dictionary = {
		"skybreak": {"kind": "lightning_strikes", "enemy_type": "zekarion", "intent_id": "skybreak"},
		"board_rule": {"kind": "lightning_strikes"},
		"zekarion": {"kind": "lightning_strikes", "enemy_type": "zekarion"},
		"vyraketh": {"kind": "aoe", "enemy_type": "vyraketh", "action_type": "cinder_marks"},
		"meteorfall": {"kind": "aoe", "enemy_type": "vyraketh", "action_type": "cinder_marks", "from": Vector2i(-1, -1)},
		"icefall": {"kind": "aoe", "en02_mechanic": "icefall_land"},
	}
	var elements: Dictionary = {"skybreak": "lightning", "board_rule": "lightning", "zekarion": "lightning", "vyraketh": "fire", "meteorfall": "fire", "icefall": "ice"}
	var contact_frames: Dictionary = {"lightning": 2, "fire": 6, "ice": 4}
	for name: String in effects:
		var effect: Dictionary = effects[name]
		effect["tiles"] = [TILE, HIDDEN, TILE]
		var element: String = elements[name]
		var cue: Fx.StrikeCue = Fx.strike_cue(effect, 500000, false)
		_expect(cue != null and cue.element == element and cue.contact_frame == contact_frames[element], name + " sheet and contact frame")
		if cue == null: continue
		_expect(cue.row == int(data["rows"][str(data["strike_for_element"][element]) + "_front"]), name + " strike row")
		var plan: Array[Dictionary] = Fx.plan({"name": Fx.for_element(cue.element), "tiles": cue.tiles, "center": HIDDEN, "simultaneous": true}, grid, {}, board._board_tile_is_visible_to_player, false)
		_expect(plan.size() == 1 and plan[0]["tile"] == TILE and is_zero_approx(plan[0]["delay"]), name + " one visible impact at contact")
		_expect(plan.size() == 1 and plan[0]["front"] == int(Fx.metadata()["rows"][element + "_floor_front"]), name + " burst row")
		var fps: float = float(data["fps"])
		for frame: int in range(-1, cue.contact_frame):
			_expect(cue.frame_at((float(frame - cue.contact_frame) + 0.25) / fps, fps) == frame, name + " precontact cell " + str(frame))
		cue.begin(0, _now)
		_clock_usec = 499999
		player.spawn_strikes(board, cue)
		_expect(player._stamps.size() == 1 and player._stamps[0].sample == Vector3i(cue.contact_frame - 1, cue.row, 0), name + " unclipped cell at correct depth and orientation")
		_expect(player._stamps.size() == 1 and player._stamps[0].get_parent() == front, name + " front layer")
		_clock_usec = 500000
		cue.land()
		player.advance(0.0, -1)
		_expect(player._stamps.size() == 1 and player._stamps[0].sample.x == cue.contact_frame, name + " exact contact cell")
		for frame: int in range(cue.contact_frame + 1, int(data["frames"])):
			_expect(cue.frame_at((float(frame - cue.contact_frame) + 0.25) / fps, fps) == frame, name + " postcontact cell " + str(frame))
		player.clear()

		var still: Fx.StrikeCue = Fx.strike_cue(effect, 500000, true)
		still.begin(0, _now)
		player.spawn_strikes(board, still)
		_expect(player._stamps.is_empty(), name + " reduced motion has no falling stamp")
		still.land()
		player.spawn_strikes(board, still)
		_expect(player._stamps.size() == 1 and player._stamps[0].sample.x == cue.contact_frame, name + " reduced contact still")
		await process_frame
		_clock_usec += roundi(float(data["reduced_motion_seconds"]) * 1000000.0)
		player.advance(0.0, -1)
		_expect(player._stamps.is_empty(), name + " reduced contact still expires at catalogue duration")
		var profile: Dictionary = Lightning.profile() if element == "lightning" else Dragon.profile(effect)
		if element != "ice":
			# A null canvas would raise if the old travel or impact submitted commands.
			for progress: float in [0.4, 0.6]:
				DragonSpell.draw_target(null, profile, Vector2.ZERO, Vector2.ZERO, Vector2.ONE, 126.0, progress, false, false, true, true, 0)
		else:
			_expect(Icefall.handles_landing(effect), "Icefall is consumed by the retained strike path")
		print("FX-15 SITE %s => %s row %d, %s burst, contact cell %d" % [name, data["strike_for_element"][element], cue.row, element, cue.contact_frame])
	viewport.queue_free()
	await process_frame

func _verify_pixels(data: Dictionary) -> void:
	var sheet: Dictionary = data["sizes"][PIXEL_SIZE_INDEX]
	var image := Image.new()
	_expect(image.load_png_from_buffer(FileAccess.get_file_as_bytes(sheet["atlas"])) == OK, "Read source bake as indexed bytes")
	image.convert(Image.FORMAT_L8)
	_expect(_sha256(image.get_data()) == sheet["sha256_pixels"], "Indexed 68-cell sheet matches the bake")
	var texture: Texture2D = ResourceLoader.load(sheet["atlas"])
	var imported: Image = texture.get_image()
	_expect(imported != null, "Read the imported strike texture")
	if imported != null:
		imported.convert(Image.FORMAT_L8)
		_expect(imported.get_data() == image.get_data(), "Lossless import preserves the bake's palette bytes")
		image = imported
	var frame := Vector2i(sheet["frame_cells"][0], sheet["frame_cells"][1])
	var origin := Vector2i(data["contact_frame"]["meteor"], data["rows"]["meteor_front"])
	var pixels: PackedByteArray = image.get_region(Rect2i(origin * frame, frame)).get_data()
	_expect(_sha256(pixels) == METEOR_CONTACT_PIXELS, "The exact meteor contact-frame indices match the bake")
	print("FX-15 PIXELS meteor contact %s" % _sha256(pixels))

func _sha256(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func _now() -> int: return _clock_usec

func _expect(ok: bool, reason: String) -> void:
	if not ok: _failures.append(reason)
