extends "res://tools/inspection_fixture.gd"

const Fx = preload("res://scripts/tile_burst_fx.gd")
const Rules = preload("res://scripts/burst_rules.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Attack = preload("res://scripts/attack_fx_library.gd")
const Center := Vector2i(4, 4)
const OFF_BOARD := Vector2i(-1, 4)
const WALL := Vector2i(4, 3)
const UNSEEN := Vector2i(4, 5)
const CONTACT := Vector2i(5, 4)
const OTHER := Vector2i(3, 4)
const FRAME_MEASUREMENT_LIMIT_MS: float = 0.25
const MEASUREMENT_SAMPLES: int = 180
const FPS: float = 60.0
const BENCHMARK_SIZE := Vector2i(1920, 1080)
const PALETTE_CENTER := Vector2i(960, 540)
const PALETTE_FIT := Vector2i(2, 3)
const ASYNC_SETTLE_FRAMES: int = 120

var _checks: int
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_verify")

func _verify() -> void:
	var before: Dictionary = _state()
	_verify_sizes()
	_verify_palette()
	_verify_selection()
	_verify_plan(before)
	_verify_pacing()
	await _verify_board(before)
	if DisplayServer.get_name() != "headless":
		await _verify_framebuffer_palette()
	for message: String in _failures: push_error(message)
	print("FX-12 VERIFY: %d checks, %d failures" % [_checks, _failures.size()])
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _state() -> Dictionary:
	var grid: Array = []
	for y: int in 9:
		var row: Array = []
		for x: int in 10:
			row.append("wall" if x == 0 or x == 9 or y == 0 or y == 8 else "stone")
		grid.append(row)
	grid[WALL.y][WALL.x] = "wall"
	var layout: Dictionary = {
		"name": "FX-12 proof", "type": "combat", "coord": Vector2i(1, 1),
		"depth": 1, "element": "none", "umbra_stage": "clear", "grid": grid,
		"player_start": Center, "terrain": [], "traps": [], "loot": [],
		"enemies": [{"id": 1, "type": "crawler", "pos": CONTACT, "hp": 10, "max_hp": 10}],
	}
	return _combat_engine.create_combat(40417, layout, {
		"hp": 40, "max_hp": 40, "deck_cards": ["quick_stab", "whirlwind_slash"], "hand_size": 1,
	})

func _expect(ok: bool, label: String) -> void:
	_checks += 1
	if not ok: _failures.append(label)

func _verify_sizes() -> void:
	var expected: Array = [[Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 4), Vector2i(2, 6)],
		[Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 4), Vector2i(2, 6)]]
	var widths: Array[int] = [100, 126, 147, 184]
	var heights: Array[int] = [1080, 800]
	for resolution: int in heights.size():
		for i: int in widths.size():
			var selected: Vector2i = Fx.choice_for(widths[i], heights[resolution])
			var sheet: Dictionary = Fx.metadata()["sizes"][selected.y]
			print("FX-12 FIT height=%d tile_px=%d cell_px=%d sheet=%d" % [heights[resolution], widths[i], selected.x, int(sheet["tile_cells"][0])])
			_expect(selected == expected[resolution][i], "integer fit at height %s, tile width %s" % [heights[resolution], widths[i]])
	_expect(Fx.choice_for(29.0, 1080).x == 1, "small tiles select a one-pixel cell")
	_expect(Fx.choice_for(226.0, 1080).x == 3, "large tiles select a three-pixel cell")

func _verify_palette() -> void:
	var data: Dictionary = Fx.metadata()
	var entries: int = 0
	var image: Image
	for sheet: Dictionary in data["sizes"]:
		var source: Image = Image.load_from_file(sheet["atlas"])
		source.convert(Image.FORMAT_L8)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(source.get_data())
		_expect(digest.finish().hex_encode() == sheet["sha256_pixels"], "baked bytes %s" % sheet["atlas"])
		if int(sheet["tile_cells"][0]) == 68:
			var texture: Texture2D = ResourceLoader.load(sheet["atlas"]) if ResourceLoader.exists(sheet["atlas"]) else ImageTexture.create_from_image(source)
			image = texture.get_image()
			if image == null: image = source
			image.convert(Image.FORMAT_L8)
			_expect(image.get_data() == source.get_data(), "active texture preserves all bake indices")
			var frame_cells := Vector2i(sheet["frame_cells"][0], sheet["frame_cells"][1])
			var row: int = int(data["rows"]["fire_hit_front"])
			for y: int in frame_cells.y:
				for x: int in frame_cells.x:
					var index: int = image.get_pixel(x, row * frame_cells.y + y).r8
					if index == 0: continue
					entries += 1
					if Fx._palette[index].to_html() != Color(data["palette"][index]).to_html():
						_expect(false, "frame 0 palette entry %d" % index)
	_expect(entries > 0, "fire contact frame has palette pixels")
	print("FX-12 PALETTE fire_hit_front frame=0 coloured_texels=%d" % entries)

func _verify_selection() -> void:
	var area: Dictionary = {"type": "aoe", "range": 0, "element": "none"}
	var effect: Dictionary = {"kind": "aoe", "range": 0, "element": "none"}
	_expect(Fx.select_player({"base_card_id": "windlass_volley"}, "copy", area, effect) == "volley", "upgraded copy maps by base card")
	_expect(Fx.select_player({}, "unknown", area, effect) == "steel" and Fx.for_element("unknown") == "steel", "element and fallback")
	for kind: String in ["detonate", "destroy_illusion", "burst_terrain"]:
		var name: String = Fx.select_player({}, "unknown", {"type": kind, "element": "none", "_detonate_surface": "fire"}, effect)
		_expect(name == {"detonate": "fire", "destroy_illusion": "light", "burst_terrain": "impact"}[kind], kind + " row selection")
		print("FX-12 SELECTION %s=%s" % [kind, name])
	_expect(Fx.select_enemy({"kind": "aoe", "intent_id": "crushing_step"}) == "impact", "intent override")
	_expect(Fx.select_enemy({"kind": "aoe", "intent_id": "bile_burst", "element": "fire"}) == "earth", "intent override wins over the element")
	_expect(Fx.select_enemy({"kind": "lightning_strikes"}) == "lightning", "ordinary lightning strikes")
	_expect(Fx.select_enemy({"kind": "lightning_strikes", "enemy_type": "zekarion"}).is_empty(), "dragon profile exclusion")
	_expect(Fx.select_player({}, "unknown", {"type": "ranged"}, {"kind": "ranged", "element": "ice"}).is_empty(), "single target exclusion")
	var targeted: Dictionary = {"type": "aoe", "kind": "aoe", "range": 2, "element": "fire"}
	_expect(Fx.select_player({}, "cinder_bloom", targeted, targeted).is_empty(), "targeted Fire uses existing drawing")
	var replace_list: Array = Fx.metadata()["replace_targeted"]
	replace_list.append("fire")
	var enabled: String = Fx.select_player({}, "cinder_bloom", targeted, targeted)
	replace_list.pop_back()
	_expect(enabled == "fire", "targeted Fire can be replaced through director data")
	targeted["element"] = "ice"
	_expect(Fx.select_player({}, "rime_shard", targeted, targeted) == "ice", "targeted Ice uses new drawing")
	var events: Array = [
		{"tile": Center, "kind": "surface_created", "surface": "ice", "feedback_element": "ice"},
		{"tile": Center, "kind": "surface_replaced", "surface": "ice", "feedback_element": "ice", "break_surface": "fire"},
		{"tile": CONTACT, "kind": "surface_created", "surface": "ice", "feedback_element": "ice"},
	]
	var replaced: Array = Fx.without_replaced_impacts(events, Center, "ice")
	_expect(replaced.size() == 2 and replaced[0]["break_surface"] == "fire" and replaced[0]["feedback_element"] == "" and replaced[1] == events[2],
		"targeted replacement removes local impact and leaves unrelated feedback intact")

func _verify_plan(before: Dictionary) -> void:
	var after: Dictionary = before.duplicate(true)
	after["enemies"][0]["hp"] = 0
	var hits: Dictionary = Fx.hit_tiles(before, after)
	var spec: Dictionary = {"name": "steel", "center": Center, "tiles": [Center, OFF_BOARD, WALL, UNSEEN, CONTACT, OTHER, CONTACT]}
	var visible := func(tile: Vector2i) -> bool: return tile != UNSEEN
	var plans: Array[Dictionary] = Fx.plan(spec, before["grid"], hits, visible, false)
	_expect(plans.size() == 3 and plans[0]["tile"] == Center and plans[1]["tile"] == CONTACT and plans[2]["tile"] == OTHER, "visible valid area, nearest first, duplicate ignored")
	if plans.size() == 3:
		_expect(not plans[0]["hit"] and plans[1]["hit"] and not plans[2]["hit"], "empty tile and defeated occupant split")
		_expect(is_equal_approx(plans[2]["delay"], 0.033), "adjacent contact delay")
		var data: Dictionary = Fx.metadata()["rows"]
		_expect(plans[1]["rear"] == data["steel_hit_rear"] and plans[1]["front"] == data["steel_hit_front"] and plans[2]["rear"] == data["steel_floor_rear"], "rear and front rows match bake")
		print("FX-12 PLAN ", plans)
	after = before.duplicate(true)
	after["enemies"][0]["stagger"] = 2
	_expect(Fx.hit_tiles(before, after).is_empty(), "Stagger-only area is all floor")
	var armour: Dictionary = before.duplicate(true)
	armour["player"]["frost_armor"] = 1
	armour["defiance_remaining"] = 1
	_expect(Fx.hit_tiles(armour, after).has(Center), "Mantle and Defiance loss count as a hit")
	for pool: String in ["hp", "block", "stoneskin", "frost_armor"]:
		var old: Dictionary = before.duplicate(true)
		old["enemies"][0][pool] = 5
		var result: Dictionary = old.duplicate(true)
		result["enemies"][0][pool] = 4
		_expect(Fx.hit_tiles(old, result).has(CONTACT), "%s loss marks occupant tile" % pool)
	var terrain: Dictionary = before.duplicate(true)
	terrain["terrain"] = [{"id": "crate", "pos": OTHER, "hp": 1}]
	_expect(Fx.hit_tiles(terrain, before).has(OTHER), "broken terrain counts as a hit")
	var moved: Dictionary = before.duplicate(true)
	moved["player"]["pos"] = OTHER
	moved["player"]["hp"] -= 1
	_expect(Fx.hit_tiles(before, moved, Callable(), true).has(OTHER), "trap damage lands at the walking actor's arrival tile")
	var sweep_center := Vector2i(4, 6)
	var sweep: Dictionary = {"name": "steel", "center": sweep_center, "sweep": Vector2i.UP,
		"tiles": [sweep_center + Vector2i.LEFT, sweep_center + Vector2i.DOWN, sweep_center + Vector2i.UP, sweep_center + Vector2i.RIGHT]}
	var all_visible := func(_tile: Vector2i) -> bool: return true
	plans = Fx.plan(sweep, before["grid"], {}, all_visible, false)
	var clockwise: Array = []
	for entry: Dictionary in plans: clockwise.append(entry["tile"] - sweep_center)
	_expect(clockwise == [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT], "steel sweep begins at facing and advances clockwise")
	_expect(is_equal_approx(plans[3]["delay"], 0.08) and is_equal_approx(plans[1]["delay"], 0.08 / 3.0), "steel sweep spans authored timing")
	print("FX-12 SWEEP ", clockwise)
	for entry: Dictionary in Fx.plan(sweep, before["grid"], {}, all_visible, true):
		_expect(entry["delay"] == 0.0, "reduced motion has no tile delay")
	var area: Array[Vector2i]
	for y: int in range(1, 8):
		for x: int in range(1, 9): area.append(Vector2i(x, y))
	plans = Fx.plan({"name": "earth", "center": Center, "tiles": area}, before["grid"], {}, all_visible, false)
	_expect(plans.size() == 24 and plans[0]["tile"] == Center and is_equal_approx(plans[23]["delay"], 0.08), "24 nearest tiles with capped delay")
	_expect(Fx.trap_specs([{"pos": Center, "element": "ice"}], before)[0]["tiles"] == Rules.cross(before, Center), "trap uses its cross")
	var event: Dictionary = {"kind": "detonate", "surface": "ice", "burst_sources": [Center], "burst_tiles": Rules.cross(before, Center)}
	_expect(Fx.event_specs([event], true)[0]["name"] == "ice", "consumed Ice selects Ice")
	event["kind"] = "powder_keg_burst"
	event["tile"] = Center
	_expect(Fx.event_specs([event], true)[0]["name"] == "impact", "terrain cross selects Impact")

func _verify_pacing() -> void:
	var cards: Array[String] = ["whirlwind_slash", "tremor", "frost_nova", "rime_shard", "cinder_bloom"]
	var base_counts: Array[int] = [6, 6, 6, 42, 48]
	var run_script: Script = load("res://scripts/run_scene.gd")
	var fallback_frames: int = run_script.get_script_constant_map()["ATTACK_FRAMES"]
	var fallback_seconds: float = run_script.get_script_constant_map()["ATTACK_FRAME_SECONDS"]
	for i: int in cards.size():
		var card: Dictionary = GameData.card_def(cards[i])
		var action: Dictionary = card["actions"][0]
		var effect: Dictionary = {"kind": "aoe", "action_type": "aoe", "range": action["range"], "element": action["element"]}
		var base: int = Attack.animation_frame_count(effect, fallback_frames, false)
		var seconds: float = Attack.animation_frame_seconds(effect, fallback_seconds, false)
		var name: String = Fx.select_player(card, cards[i], action, effect)
		effect[Fx.ACTIVE] = not name.is_empty()
		effect[Fx.REPLACE_TARGETED] = effect[Fx.ACTIVE] and Fx.replaces_elemental_area(effect)
		var frames: int = Attack.animation_frame_count(effect, fallback_frames, false)
		_expect(base == base_counts[i] and frames == base and Attack.animation_frame_seconds(effect, fallback_seconds, false) == seconds,
			"%s preserves authored frame count and duration" % cards[i])
		print("FX-12 PACING %s base=%d burst=%d seconds_per_frame=%.5f" % [cards[i], base, frames, seconds])

func _verify_board(source: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = BENCHMARK_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var board: Control = Board.new()
	viewport.add_child(board)
	board.size = Vector2(BENCHMARK_SIZE)
	var state: Dictionary = source.duplicate(true)
	state["grid"][WALL.y][WALL.x] = "stone"
	board.set_combat_state(state)
	var action: Dictionary = GameData.card_def("tremor")["actions"][0]
	var tiles: Array = _combat_engine.aoe_tiles_for_player_action(state, action, Center)
	var specs: Array = [{"name": "earth", "center": Center, "tiles": tiles}]
	board.present_tile_bursts(specs, state, state, true)
	var layer: Fx = board._tile_bursts
	_expect(tiles.size() == 13 and layer._stamps.size() == 26, "Tremor spawns exactly two retained stamps per tile")
	for stamp: Fx.Stamp in layer._stamps:
		var parents: Dictionary = board._scene_front_effect_render_layers_by_tile if stamp.front else board._scene_back_effect_render_layers_by_tile
		_expect(stamp.get_parent() == parents[stamp.tile], "burst stamp is attached to the tile's painter slot")
		_expect(stamp.visible and stamp.sample.x == 3 and stamp.sample.z == (stamp.tile.x + stamp.tile.y) % 2, "reduced-motion frame and parity")
	var next: Dictionary = state.duplicate(true)
	next["enemies"][0]["hp"] -= 1
	board.set_combat_state(next, [], [], Center, "", "", {}, {}, {"umbra_visible_tiles": [Center]})
	_expect(layer._stamps.size() == 26 and layer._stamps.filter(func(stamp: Fx.Stamp) -> bool: return stamp.visible).size() == 2, "retained after state swap, hidden outside updated sight")
	layer.advance(0.179, -1)
	_expect(layer.has_active(), "reduced motion still active before 180 ms")
	layer.advance(0.002, -1)
	_expect(not layer.has_active(), "reduced motion expires at 180 ms")
	board.set_combat_state(state)
	var total_usec: int
	var check_count: int
	for sample: int in MEASUREMENT_SAMPLES:
		if not layer.has_active():
			board.present_tile_bursts(specs, state, state, false)
		var start: int = Time.get_ticks_usec()
		layer.advance(1.0 / FPS, -1)
		total_usec += Time.get_ticks_usec() - start
		check_count += 1
	var ms: float = float(total_usec) / check_count / 1000.0
	print("FX-12 CPU Tremor 13 tiles headless retained tick mean=%.5f ms samples=%d limit=%.2f ms" % [ms, check_count, FRAME_MEASUREMENT_LIMIT_MS])
	_expect(ms < FRAME_MEASUREMENT_LIMIT_MS, "Tremor retained tick CPU budget")
	var old_index: int = layer.sheet_index
	var old_cell_px: int = layer.cell_px
	var next_index: int = (old_index + 1) % (Fx.metadata()["sizes"] as Array).size()
	layer._requested = Vector2i(old_cell_px + 1, next_index)
	layer._request_sheet()
	_expect(layer.sheet_index == old_index and layer.cell_px == old_cell_px, "pending resize keeps the active sheet at its own cell size")
	for frame: int in ASYNC_SETTLE_FRAMES:
		if layer.sheet_index == next_index: break
		await process_frame
	_expect(layer.sheet_index == next_index and layer.cell_px == old_cell_px + 1, "threaded sheet reaches the new size")
	board.clear_tile_bursts()
	_expect(not layer.has_active(), "board clear drops live stamps")
	viewport.queue_free()
	await process_frame

func _verify_framebuffer_palette() -> void:
	var viewport := SubViewport.new()
	viewport.size = BENCHMARK_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var data: Dictionary = Fx.metadata()
	var sheet: Dictionary = data["sizes"][PALETTE_FIT.y]
	var texture: Texture2D = load(sheet["atlas"])
	var layer := Fx.new()
	layer._use_sheet(texture, PALETTE_FIT)
	var stamp := Fx.Stamp.new()
	stamp.position = Vector2(PALETTE_CENTER)
	stamp.material = layer.ink
	viewport.add_child(stamp)
	var row: int = int(data["rows"]["fire_hit_front"])
	stamp.set_instance_shader_parameter("frame_row_mirror", Vector3i(0, row, 0))
	var cells := Vector2i(sheet["frame_cells"][0], sheet["frame_cells"][1])
	var anchor := Vector2i(sheet["tile_centre_cell"][0], sheet["tile_centre_cell"][1])
	var origin: Vector2i = PALETTE_CENTER - anchor * PALETTE_FIT.x
	var source: Image = texture.get_image()
	await process_frame
	await RenderingServer.frame_post_draw
	var actual: Image = viewport.get_texture().get_image()
	var mismatches: int
	for y: int in cells.y:
		for x: int in cells.x:
			var index: int = source.get_pixel(x, row * cells.y + y).r8
			var expected: Color = Color(data["palette"][index])
			for dy: int in PALETTE_FIT.x:
				for dx: int in PALETTE_FIT.x:
					var pixel: Vector2i = origin + Vector2i(x, y) * PALETTE_FIT.x + Vector2i(dx, dy)
					var colour: Color = actual.get_pixelv(pixel)
					if (index == 0 and colour.a8 != 0) or (index != 0 and colour.to_html() != expected.to_html()):
						mismatches += 1
	_expect(mismatches == 0, "real palette pixels match the indexed bake")
	print("FX-12 FRAMEBUFFER PALETTE %d mismatched pixels" % mismatches)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: int = args.find("--palette-png")
	if output >= 0 and output + 1 < args.size():
		var path: String = args[output + 1]
		_expect(actual.save_png(path) == OK, "write palette framebuffer")
		print(path)
	viewport.queue_free()
	await process_frame
