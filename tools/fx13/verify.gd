extends "res://tools/fx12/verify.gd"
## Headless playback, indexed atlas and focused integration proof.

const FloatText = preload("res://scripts/floating_combat_text.gd")
const Buff = preload("res://scripts/card_buff_playback.gd")
const Maneuver = preload("res://scripts/maneuver_rules.gd")
const MantleCard: String = "crystal_mantle"
const ConvertCard: String = "shrug_off"
const BODY_ORIGIN := Vector2i(6, 5)
const SAMPLE_FRAME: int = 5
const GAIN_AMOUNT: int = 3
const EPSILON_SECONDS: float = 0.0001

var _board: Control
var _body: Fx

func _verify() -> void:
	if OS.get_cmdline_user_args().has("--focused"):
		preload("res://tests/suites/maneuver_suite.gd").run(_expect)
		preload("res://tests/suites/illusion_terrain_suite.gd").run(_expect)
		await preload("res://tests/suites/combat_pacing_regression_suite.gd").run(self, _expect)
	else:
		await _verify_self_effects()
	for failure: String in _failures: push_error(failure)
	print("FX-13 %s: %d checks, %d failures" % ["FOCUSED" if OS.get_cmdline_user_args().has("--focused") else "VERIFY", _checks, _failures.size()])
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _verify_self_effects() -> void:
	var viewport := SubViewport.new()
	viewport.size = BENCHMARK_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	_board = Board.new()
	viewport.add_child(_board)
	_board.size = Vector2(BENCHMARK_SIZE)
	var state: Dictionary = _state()
	state["enemies"][0]["pos"] = BODY_ORIGIN
	state["enemies"][0]["footprint"] = Vector2i(2, 2)
	_submit(state, [])
	_body = _board._self_bursts
	_expect(_body != _board._tile_bursts and _body.ink != _board._tile_bursts.ink, "Each catalogue has its own atlas material.")
	_verify_self_palette()
	_verify_card_gains(state)
	_verify_sequence(state)
	_verify_footprint(state)
	_verify_status_and_boundaries(state)
	_verify_creation_stamps(state)
	_board.clear_tile_bursts()
	_expect(not _body.has_active(), "Clearing removes both sheet sets.")
	viewport.queue_free()
	await process_frame

func _submit(state: Dictionary, texts: Array, elapsed: float = 0.0, options: Dictionary = {}) -> void:
	var shown: Dictionary = options.duplicate(false)
	shown["floating_texts"] = FloatText.animate_entries(texts, elapsed, bool(options.get("reduced_motion", false)))
	_board.set_combat_state(state, [], [], Center, "", "", {}, {}, shown)

func _verify_self_palette() -> void:
	var catalog: Dictionary = Fx.self_metadata()
	for sheet: Dictionary in catalog["sizes"]:
		var texture: Texture2D = ResourceLoader.load(sheet["atlas"])
		_expect(texture != null, "Imported sheet exists: " + str(sheet["atlas"]))
		if texture == null: continue
		var source: Image = texture.get_image()
		source.convert(Image.FORMAT_L8)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(source.get_data())
		_expect(digest.finish().hex_encode() == sheet["sha256_pixels"], "Lossless imported indices: " + str(sheet["atlas"]))
	var sheet: Dictionary = catalog["sizes"][_body.sheet_index]
	var image: Image = (_body.ink.get_shader_parameter("atlas") as Texture2D).get_image()
	var palette: PackedColorArray = _body.ink.get_shader_parameter("palette")
	_expect(palette.size() == Fx.PALETTE_SIZE, "The shader receives exactly 64 palette entries.")
	var width: int = int(sheet["frame_cells"][0])
	var height: int = int(sheet["frame_cells"][1])
	for name: String in ["block", "stoneskin", "heal", "empower", "mantle", "illusion", "summon", "expose"]:
		var coloured: int = 0
		var matched: bool = true
		for half: String in ["_rear", "_front"]:
			var row: int = int(catalog["rows"][name + half])
			for y: int in height:
				for x: int in width:
					var index: int = image.get_pixel(SAMPLE_FRAME * width + x, row * height + y).r8
					if index == 0: continue
					coloured += 1
					matched = matched and palette[index].to_html() == str(catalog["palette"][index])
		_expect(coloured > 0 and matched, "%s frame %d decodes exactly to the baked palette." % [name, SAMPLE_FRAME])
		print("FX-13 PALETTE %s frame=%d coloured_texels=%d" % [name, SAMPLE_FRAME, coloured])

func _verify_card_gains(state: Dictionary) -> void:
	for kind: String in ["block", "stoneskin", "heal"]:
		_expect(FloatText.resource_entry(kind, Center, 0).get("gain", "") == "", kind + " zero lacks a gain.")
		_expect(FloatText.resource_entry(kind, Center, -GAIN_AMOUNT).get("gain", "") == "", kind + " loss lacks a gain.")
		var entry: Dictionary = FloatText.resource_entry(kind, Center, GAIN_AMOUNT)
		_verify_landing(state, entry, kind)
		for loss: int in [-GAIN_AMOUNT, 0]:
			_body.clear()
			_submit(state, [FloatText.resource_entry(kind, Center, loss)])
			_expect(not _body.has_active(), kind + " loss or zero starts no stamp.")
	for card: String in ["whetstone", "hourglass_sand", "bristle", MantleCard, ConvertCard]:
		var actions: Array = GameData.card_def(card)["actions"]
		var kind: String = {"whetstone": "next_attack", "hourglass_sand": "quicken", "bristle": "retaliate",
			MantleCard: "mantle", ConvertCard: "convert_block_to_stoneskin"}[card]
		var before: Dictionary = state.duplicate(true)
		before["player"]["block"] = GameData.fixed_point_amount(GAIN_AMOUNT)
		for action: Dictionary in actions:
			if action["type"] != kind: continue
			var after: Dictionary = _combat_engine.apply_player_action(before, action)
			if card in [MantleCard, ConvertCard]:
				var entry: Dictionary = Maneuver.presentation_entry(before, after, action, Center)
				_verify_landing(after, entry, "mantle" if card == MantleCard else "stoneskin")
			else:
				var entries: Array = Buff.presentation(before, after, action, Color.WHITE)["floating_texts"]
				_expect(entries.size() == 1 and entries[0].get("gain") == kind, card + " emits its resolved gain tag.")
				if not entries.is_empty(): _verify_landing(after, entries[0], "empower")
	var loss: Dictionary = state.duplicate(true)
	loss["player"][Maneuver.MANTLE_FIELD] = GAIN_AMOUNT
	_expect(not Maneuver.presentation_entry(loss, state, {"type": "mantle"}, Center).has("gain"), "Mantle loss lacks a gain.")

func _verify_landing(state: Dictionary, entry: Dictionary, effect: String) -> void:
	_body.clear()
	_submit(state, [entry], -FloatText.TARGET_FRAME_SECONDS)
	_expect(not _body.has_active(), effect + " waits for the number's first frame.")
	_submit(state, [entry])
	var stamp: Fx.Stamp = _front(effect)
	_expect(_body._stamps.size() == 2 and is_instance_valid(stamp), effect + " submits a rear/front pair.")
	if not is_instance_valid(stamp): return
	_expect(stamp.tile == Center and stamp.birth_frame == Engine.get_process_frames() and stamp.sample == Vector3i(0, int(Fx.self_metadata()["rows"][effect + "_front"]), 0), effect + " starts frame zero on the number's tile without mirroring.")
	_submit(state, [entry], FloatText.TARGET_FRAME_SECONDS)
	_expect(_body._stamps.size() == 2, effect + " does not replay on later number frames.")

func _verify_sequence(state: Dictionary) -> void:
	_body.clear()
	var entries: Array = [
		FloatText.resource_entry("heal", Center, GAIN_AMOUNT),
		FloatText.resource_entry("stoneskin", Center, GAIN_AMOUNT),
		FloatText.resource_entry("block", Center, GAIN_AMOUNT),
	]
	_submit(state, entries)
	var first: Fx.Stamp = _front("stoneskin")
	var second: Fx.Stamp = _front("block")
	_expect(_body._stamps.size() == 4 and _front("heal") == null, "At most two effects in authored order.")
	if not is_instance_valid(first) or not is_instance_valid(second): return
	var delay: float = float(Fx.self_metadata()["second_on_tile_delay_seconds"])
	_expect(first.visible and not second.visible and is_equal_approx(second.birth - first.birth, delay), "Second effect is scheduled at the exact baked delay.")
	_body.advance(delay - EPSILON_SECONDS, -1)
	_expect(not second.visible, "Second effect is hidden before its birth.")
	_body.advance(2.0 * EPSILON_SECONDS, -1)
	_expect(second.visible and second.sample.x == 0, "Second effect starts at frame zero.")
	_submit(state, entries, delay + EPSILON_SECONDS)
	_expect(_body._stamps.size() == 4, "Later staggered numbers do not restart a submitted batch.")
	_body.clear()
	for entry: Dictionary in entries:
		entry.erase("screen_layout_id")
	_submit(state, entries, 0.0, {"reduced_motion": true})
	for stamp: Fx.Stamp in _body._stamps:
		_expect(stamp.visible and stamp.sample.x == int(Fx.self_metadata()["reduced_motion_frame"]), "Both reduced-motion effects start together at the authored still.")
	_body.advance(float(Fx.self_metadata()["reduced_motion_seconds"]) + EPSILON_SECONDS, -1)
	_expect(not _body.has_active(), "Reduced-motion stills expire at the authored time.")

func _verify_footprint(state: Dictionary) -> void:
	_body.clear()
	var far_corner: Vector2i = BODY_ORIGIN + Vector2i.ONE
	var origin_center: Vector2 = (_board._tile_center(BODY_ORIGIN) + _board._tile_center(far_corner)) * 0.5
	_submit(state, [FloatText.resource_entry("block", far_corner, GAIN_AMOUNT)])
	_expect(_body._stamps.size() == 2, "A 2×2 recipient has one pair.")
	for stamp: Fx.Stamp in _body._stamps:
		var layers: Dictionary = _board._scene_front_effect_render_layers_by_tile if stamp.front else _board._scene_back_effect_render_layers_by_tile
		_expect(stamp.tile == BODY_ORIGIN and stamp.position == origin_center and stamp.get_parent() == layers[far_corner], "2×2 stamp is centred on the full footprint in the body's layer.")
	_body.clear()
	_submit(state, [FloatText.resource_entry("block", BODY_ORIGIN, GAIN_AMOUNT)], 0.0, {"visible_enemy_ids": []})
	_expect(not _body.has_active(), "A hidden unit on a visible tile has no effect.")
	_submit(state, [FloatText.resource_entry("block", BODY_ORIGIN, GAIN_AMOUNT)], 0.0, {"umbra_visible_tiles": [Center]})
	_expect(not _body.has_active(), "A hidden tile has no effect.")

func _verify_status_and_boundaries(state: Dictionary) -> void:
	_body.clear()
	_submit(state, [])
	var after: Dictionary = state.duplicate(true)
	after["enemies"][0]["expose"] = GAIN_AMOUNT
	after["player"]["expose"] = GAIN_AMOUNT
	_submit(after, [])
	_expect(_body._stamps.size() == 4, "Resolved Expose gains on enemy and hero have a body cue without a float.")
	_body.clear()
	_submit(state, [])
	_expect(not _body.has_active(), "Dropping Expose has no cue.")
	after = state.duplicate(true)
	after["player"]["hp"] += GAIN_AMOUNT
	_submit(after, [FloatText.resource_entry("heal", Center, GAIN_AMOUNT)], 0.0, {"effect": {"kind": "melee"}})
	_expect(_body._stamps.size() == 2 and _front("heal") != null, "Inline attack healing starts with its float once.")
	_body.clear()
	var turn: Dictionary = after.duplicate(true)
	turn["player_turn_ending"] = true
	turn["player"]["block"] = GAIN_AMOUNT
	_submit(turn, [])
	_expect(_front("block") != null, "End-turn Block lands at the resolved presentation boundary.")
	_body.clear()
	var start: Dictionary = turn.duplicate(true)
	start["player_turn_ending"] = false
	start["player"]["stoneskin"] = GAIN_AMOUNT
	_submit(start, [])
	_expect(_front("stoneskin") != null, "Start-turn Stoneskin lands at the resolved presentation boundary.")

func _verify_creation_stamps(state: Dictionary) -> void:
	_board.clear_tile_bursts()
	_submit(state, [])
	_board.present_self_burst("illusion", {"pos": OTHER}, false)
	_board.present_self_burst("summon", {"pos": CONTACT}, false)
	_expect(_front("illusion") != null and _front("summon") != null and _front("illusion").birth_frame == _front("summon").birth_frame, "Creation uses retained pairs on the first submission frame.")
	_expect(is_equal_approx(Fx.reveal_seconds("illusion", false), 0.1333) and is_equal_approx(Fx.reveal_seconds("summon", false), 0.1667), "Reveals use director timing.")
	_expect(Fx.reveal_seconds("illusion", true) == 0.0 and Fx.reveal_seconds("summon", true) == 0.0, "Reduced motion has no reveal delay.")

func _front(effect: String) -> Fx.Stamp:
	var row: int = Fx.self_metadata()["rows"][effect + "_front"]
	for stamp: Fx.Stamp in _body._stamps:
		if stamp.front and stamp.sample.y == row: return stamp
	return null
