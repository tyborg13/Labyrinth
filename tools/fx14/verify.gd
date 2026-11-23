extends SceneTree
## Headless data and installed-board assertions. GPU comparison is in native.gd.

const Shot = preload("res://scripts/shot_fx.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Run = preload("res://scripts/run_scene.gd")
const Attack = preload("res://scripts/attack_fx_library.gd")
const Fixtures = preload("res://tools/fx14/fixtures.gd")
const BOARD_PROOF_SIZE := Vector2i(1920, 1080)
const BAKED_ARROW_52_SHA256: String = "61ad8eb4cb439405bf2fd2308a9df19f10fd69c1456f271618024a025f27d515"

var _checks: int
var _failures: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_verify_inventory()
	_verify_geometry_and_clocks()
	_verify_bake()
	await _verify_board()
	if "--affected" in OS.get_cmdline_user_args():
		_verify_affected_suites()
	print("FX-14 VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(mini(1, _failures))

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)

func _verify_inventory() -> void:
	var meta: Dictionary = Shot.metadata()
	var live: int = 0
	for card: String in Fixtures.cards():
		var definition: Dictionary = Fixtures.cards()[card]
		for action: Dictionary in definition.get("actions", []):
			if Fixtures.single_candidate(action):
				var effect: Dictionary = Fixtures.card_effect(card, action)
				var expected: String = meta["shot_for_card"].get(card, _expected_element(effect))
				_verify_mapping(effect, expected, card)
				live += 1
	for enemy: String in Fixtures.enemies():
		var definition: Dictionary = Fixtures.enemies()[enemy]
		for intent: Dictionary in definition.get("intents", []):
			for action: Dictionary in intent.get("actions", []):
				if Fixtures.single_candidate(action):
					var effect: Dictionary = Fixtures.enemy_effect(enemy, intent, action)
					var id: String = intent["id"]
					var expected: String = meta["shot_for_enemy_intent"].get(enemy + ":" + id, meta["shot_for_intent"].get(id, _expected_element(effect)))
					_verify_mapping(effect, expected, enemy + ":" + id)
					live += 1
	print("FX-14 DATA: %d ranged and distant-force action rows" % live)
	_expect(live >= 60, "Walk the entire live card and enemy shot inventory")
	var dull: Dictionary = Fixtures.named_card("dull_bolt")
	_expect(Shot.resolve(dull) == "pale", "Dull Bolt with the default hand effect")
	dull["protagonist_ranged_motion"] = "bow"
	_expect(Shot.resolve(dull) == "arrow", "Dull Bolt with a bow")
	dull["protagonist_ranged_motion"] = "repeater"
	_expect(Shot.resolve(dull) == "arrow", "Dull Bolt with a repeater")
	dull["illusion_echo"] = true
	dull["protagonist_ranged"] = ""
	_expect(Shot.resolve(dull) == "arrow", "Illusion uses the delivered hero shot")
	dull["preview"] = true
	_expect(Shot.resolve(dull).is_empty(), "Aim previews keep their path")
	var no_shot: Dictionary = Fixtures.named_card("root_snare")
	_expect(Shot.resolve(no_shot).is_empty(), "An explicit empty mapping stops element fallback")
	no_shot["kind"] = "aoe"
	_expect(Shot.resolve(no_shot).is_empty(), "Targeted areas keep their travel")
	var chain: Dictionary = Fixtures.named_card("refraction")
	chain["chain_index"] = 1
	_expect(Shot.resolve(chain).is_empty(), "Later chain delivery keeps its drawing")
	var shot: Dictionary = Fixtures.named_card("hurl_spear")
	shot["noctyrax_breath"] = true
	_expect(Shot.resolve(shot).is_empty(), "Noctyrax breath keeps its drawing")

func _expected_element(effect: Dictionary) -> String:
	var kind: String = effect["action_type"]
	var element: String = effect["element"]
	if element in ["fire", "lightning"]:
		if kind in ["pull", "push"]: return ""
		return "ember" if element == "fire" else "spark"
	if kind == "pull":
		return "hook"
	if kind == "push" and element in ["", "none"]:
		return "blade"
	return Shot.metadata()["shot_for_element"].get(element, "")

func _verify_mapping(effect: Dictionary, expected: String, label: String) -> void:
	var meta: Dictionary = Shot.metadata()
	if not Shot.Dragon.profile(effect).is_empty():
		expected = ""
	_expect(Shot.resolve(effect) == expected, "%s should resolve to %s" % [label, expected])
	if expected.is_empty():
		return
	var hit: String = meta["shots"][expected]["hit"]
	for size: Dictionary in meta["sizes"]:
		if expected in ["ember", "spark"]:
			_expect(size["shots"].has(expected) and hit.is_empty(), "%s has flight and uses a separate contact burst on %s" % [label, size["atlas"]])
		else:
			_expect(size["shots"].has(expected) and size["shots"][hit]["kind"] == "hit", "%s has shot and hit on %s" % [label, size["atlas"]])

func _verify_geometry_and_clocks() -> void:
	# Project the 16 adjacent/near-adjacent 2:1 isometric directions onto screen.
	var expected := PackedInt32Array([2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 0])
	var tiles: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(1, 1),
		Vector2i(2, 3), Vector2i(1, 3), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-3, -1), Vector2i(-3, -2), Vector2i(-1, -1),
		Vector2i(-2, -3), Vector2i(-1, -3), Vector2i(0, -1), Vector2i(1, -1),
	]
	for index: int in tiles.size():
		var tile: Vector2i = tiles[index]
		var direction := Vector2(tile.x - tile.y, (tile.x + tile.y) * 0.5)
		_expect(Shot.heading(direction) == expected[index], "Heading for tile delta %s" % str(tile))

	var from := Vector2(10, 20)
	var to := Vector2(110, 60)
	_expect(Shot.path(from, to, 18.0, 0.0) == from, "Path starts at the release socket")
	_expect(Shot.path(from, to, 18.0, 0.5) == Vector2(60, 22), "Path reaches the authored midflight lift")
	_expect(Shot.path(from, to, 18.0, 1.0) == to, "Path reaches the original contact anchor")
	_expect(Shot.tangent(from, to, 18.0, 0.0).y < 0.0 and Shot.tangent(from, to, 18.0, 1.0).y > 0.0, "Heading follows rising and falling tangent")
	_expect(is_equal_approx(Shot.travel_progress(0.5, 0.0, 1.0, 2.0), 0.25), "Travel applies the director ease")
	var rows: Dictionary = Shot.metadata()["sizes"][0]["shots"]
	var spin: Dictionary = rows["die"]
	for tick: int in range(18):
		var age: float = (float(tick) + 0.1) / 18.0
		_expect(Shot.frame_rect(spin, Vector2.RIGHT, age, 0.0).x / spin["frame_cells"] == tick % 8, "Spin clock tick %d" % tick)
		_expect(Shot.frame_rect(spin, Vector2.RIGHT, age, 0.0, 3).x / spin["frame_cells"] == (tick + 3) % 8, "Second die is three frames ahead")
	var net: Dictionary = rows["net"]
	_expect(Shot.frame_rect(net, Vector2.RIGHT, 0.0, 0.5).x / net["frame_cells"] == 4, "Net opens by distance")
	_expect(Shot.frame_rect(net, Vector2.RIGHT, 0.0, 1.0).x / net["frame_cells"] == 7, "Net fully open frame")
	var pale: Dictionary = rows["pale"]
	_expect(Shot.frame_rect(pale, Vector2.RIGHT, 0.10, 0.0).y == pale["y"] + pale["frame_cells"], "Heading flicker advances to row 1")
	for frame: int in range(8):
		_expect(Shot.hit_frame((float(frame) + 0.1) / 30.0, false) == frame, "Hit clock frame %d" % frame)
	_expect(Shot.hit_frame(8.0 / 30.0, false) == -1, "Hit ends rather than holding")
	_expect(Shot.hit_frame(0.179, true) == 1 and Shot.hit_frame(0.180, true) == -1, "Reduced hit is frame 1 for 180 ms")
	var run := Run.new()
	for id: String in ["hurl_spear", "icicle_lance", "rockburst", "razor_gale"]:
		var effect: Dictionary = Fixtures.named_card(id)
		var style: String = Attack.style_for_effect(effect)
		var frames: int = Attack.animation_frame_count(effect, 12, false)
		var legacy: float = run._attack_feedback_start_progress(effect)
		var contact: float = Shot.contact_for(effect)
		_expect(ceili(legacy * frames) == ceili(contact * frames), "%s keeps the first feedback frame" % id)
		_expect(Shot.travel_progress(contact, Shot.release_for(style), contact, 1.4) == 1.0, "%s finishes flight at contact" % id)
	run.free()
	var spans := PackedVector2Array([Vector2(0.2, 0.4), Vector2(0.6, 0.8)])
	var delta := Vector2(100, 0)
	_expect(Shot.span_contains(spans, Shot.clipped_progress(0.35, Vector2.ZERO, delta)), "Visible center")
	_expect(not Shot.span_contains(spans, Shot.clipped_progress(0.35, Vector2(10, 0), delta)), "Head extending into a dark gap")
	_expect(not Shot.span_contains(spans, Shot.clipped_progress(0.65, Vector2(-10, 0), delta)), "Tail extending into a dark gap")
	_expect(Shot.span_contains(spans, Shot.clipped_progress(0.59, Vector2(10, 0), delta)), "Cell can reach a second visible island")
	for height: int in [1080, 800]:
		for row: Vector2i in [Vector2i(100, 1), Vector2i(126, 2), Vector2i(147, 4), Vector2i(184, 6)]:
			_expect(Shot.sheet_choice(float(row.x), height) == Vector2i(2, row.y), "Sheet choice at %d px and %d px height" % [row.x, height])
	var moved := Vector2(75, 12)
	_expect(Shot.hook_head(from, to, 0.0, 0.4, null) == to, "Hook is taut at contact")
	_expect(Shot.hook_head(from, to, 0.2, 0.4, moved) == moved, "Hook stays on the displaced target")
	_expect(Shot.hook_head(from, to, 0.2, 0.4, null) == from.lerp(to, 0.5), "Hook retracts over the authored fraction")

func _verify_bake() -> void:
	for size: Dictionary in Shot.metadata()["sizes"]:
		var image: Image = Shot._read_sheet(size["atlas"]) as Image
		_expect(image != null and image.get_format() == Image.FORMAT_L8, "Atlas retains single-channel indices")
		if image == null:
			continue
		_expect(_sha256(image.get_data()) == size["sha256_pixels"], "Decoded indices match the director bake for " + size["atlas"])
		if int(size["tile_cells"]) == 52:
			var frame: Vector3i = Shot.frame_rect(size["shots"]["arrow"], Vector2.RIGHT, 0.0, 0.0)
			var pixels: Image = image.get_region(Rect2i(frame.x, frame.y, frame.z, frame.z))
			_expect(_sha256(pixels.get_data()) == BAKED_ARROW_52_SHA256, "Arrow at heading zero matches the direct bake")

func _sha256(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func _verify_board() -> void:
	# The headless root is 64×36. Use a real-sized framebuffer for both
	# atlas selection and the overlap/clearance checks.
	var surface := SubViewport.new()
	surface.size = BOARD_PROOF_SIZE
	root.add_child(surface)
	var board := Board.new()
	board.size = Vector2(BOARD_PROOF_SIZE)
	surface.add_child(board)
	await process_frame
	board.set_process(false)
	var effect: Dictionary = Fixtures.named_card("chain_lock")
	effect["action_type"] = "pull"
	var state: Dictionary = Fixtures.state_for(effect)
	board.set_combat_state(state, [], [], Vector2i.ZERO, "", "", {}, {}, {"effect": effect, "effect_progress": 0.35})
	var fx: Shot = board.get("_single_shot_fx")
	_expect(fx._sheet >= 0 and fx._heads[0].visible and fx._links.visible and not fx._shadow.visible, "Live board binds hook and one chain quad during travel")
	var attached: Vector2 = board._tile_center(Fixtures.TARGET) + Vector2(-36.0, -15.0)
	board.set_combat_state(state, [], [], Vector2i.ZERO, "", "", {}, {}, {
		"effect": effect, "effect_progress": 0.70, "unit_world_positions": {"enemy_1": attached},
	})
	_expect(fx._heads[0].position.is_equal_approx(attached + Vector2(0, -24)), "Hook follows the board's moving body anchor")
	_expect(fx._hits[0].visible, "Contact emits a retained hit")
	board.set_combat_state(state)
	fx.advance(0.166)
	_expect(fx._hits[0].visible and not fx._heads[0].visible, "Hit outlives the action descriptor")
	fx.advance(0.104)
	_expect(not fx._hits[0].visible, "Hit ends on its own clock")
	board.set_combat_state(state, [], [], Vector2i.ZERO, "", "", {}, {}, {
		"effect": effect, "effect_progress": 1.0, "reduced_motion": true,
	})
	_expect(fx._hits[0].visible and not fx._heads[0].visible and not fx._links.visible and not fx._shadow.visible, "Reduced motion draws only a hit at contact")
	fx.advance(0.180)
	_expect(not fx._hits[0].visible, "Reduced motion hit expires")
	_verify_caster_depth(board, fx)
	var previous: int = fx._sheet
	var viewport: Viewport = board.get_viewport()
	var render_height: int = roundi(viewport.get_visible_rect().size.y * viewport.get_stretch_transform().get_scale().y)
	var target_px: float = 184.0 if Shot.sheet_choice(100.0, render_height).y == previous else 100.0
	var desired_width: float = target_px / fx._physical_scale.x
	fx.sync_size(desired_width)
	_expect(fx._loader != null and fx._sheet == previous, "Resize requests one sheet and retains the previous texture")
	for _frame: int in range(120):
		await process_frame
		fx._finish_resize()
		if fx._sheet != previous:
			break
	_expect(fx._sheet == fx._desired_sheet and fx._sheet != previous, "Resize installs the staged sheet once the thread completes")
	surface.queue_free()
	await process_frame

func _verify_caster_depth(board: Board, fx: Shot) -> void:
	var body := Rect2(20.0, 20.0, 20.0, 20.0)
	var ink := Rect2(-6.0, -6.0, 12.0, 12.0)
	_expect(Shot.frame_overlaps_body(Vector2(43.0, 30.0), ink, 2, body), "Overlapping shot stays behind its caster")
	_expect(not Shot.frame_overlaps_body(Vector2(46.0, 30.0), ink, 2, body), "Touching shot edge clears its caster")
	_expect(Shot.chain_overlaps_body(Vector2.ZERO, Vector2(100, 100), 12.0, ink, ink, 2, body), "A link crosses the caster during diagonal travel")
	_expect(not Shot.chain_overlaps_body(Vector2.ZERO, Vector2(100, 100), 12.0, ink, ink, 2, Rect2(5, 80, 10, 10)), "A chain quad corner is not a link overlap")
	_expect(not Shot.chain_overlaps_body(Vector2.ZERO, Vector2(12, 0), 12.0, ink, ink, 2, body), "A link at the chain endpoint is not drawn")

	var effect: Dictionary = Fixtures.named_card("chain_lock")
	effect["protagonist_ranged"] = ""
	effect["to"] = Vector2i(6, 4)
	var state: Dictionary = Fixtures.state_for(effect)
	var released: Dictionary = {"effect": effect, "effect_progress": Shot.DEFAULT_RELEASE}
	board.set_combat_state(state, [], [], Vector2i.ZERO, "", "", {}, {}, released)
	var rear: CanvasItem = board._scene_back_effect_render_layers_by_tile[Fixtures.HERO]
	_expect(fx._heads[0].get_parent() == rear, "Hook head starts in the hero's rear painter pass")
	_expect(fx._heads[0].position.is_equal_approx(board._tile_center(Fixtures.HERO) + Vector2(0, -24)), "Depth leaves the launch point intact")
	board.set_combat_state(state, [], [], Vector2i.ZERO, "", "", {}, {}, {"effect": effect, "effect_progress": 0.65})
	_expect(fx._heads[0].get_parent() == fx._above_bodies, "Hook head returns to the front pass once clear")
	_expect(fx._links.get_parent() == rear and fx._links.visible, "Chain remains behind the hero while its head is in front")
	fx.release_depth_parent(rear)
	_expect(fx._links.get_parent() == fx._above_bodies, "Retiring a tile returns the chain to its persistent pass")

	var enemy: Dictionary = Fixtures.named_enemy("hollow_mimic", "shade_bolt")
	enemy["from"] = Vector2i(6, 4)
	state = Fixtures.state_for(enemy)
	released = {"effect": enemy, "effect_progress": Shot.DEFAULT_RELEASE}
	board.set_combat_state(state, [], [], Vector2i.ZERO, "", "", {}, {}, released)
	_expect(fx._heads[0].get_parent() == board._scene_back_effect_render_layers_by_tile[enemy["from"]], "Enemy shot starts behind its own caster")
	board.set_combat_state(state, [], [], Vector2i.ZERO, "", "", {}, {}, {"effect": enemy, "effect_progress": 0.65})
	_expect(fx._heads[0].get_parent() == fx._above_bodies, "Enemy shot returns to the front pass once clear")

	var echo: Dictionary = Fixtures.named_card("hurl_spear")
	var illusion_tile := Vector2i(4, 3)
	echo["illusion_echo"] = true
	echo["protagonist_ranged"] = ""
	echo["from"] = illusion_tile
	state = Fixtures.state_for(echo)
	state["illusions"] = [{"id": 1, "pos": illusion_tile, "hp": 4, "max_hp": 4}]
	board.set_combat_state(state, [], [], Vector2i.ZERO, "", "", {}, {}, {"effect": echo, "effect_progress": Shot.DEFAULT_RELEASE})
	_expect(fx._heads[0].get_parent() == board._scene_back_effect_render_layers_by_tile[illusion_tile], "Echo shot uses the Illusion's body and rear pass")

func _verify_affected_suites() -> void:
	var before: int = _checks
	var failures_before: int = _failures
	preload("res://tests/suites/umbra_action_animation_suite.gd").run(_expect)
	preload("res://tests/suites/chain_attack_suite.gd").run(_expect)
	preload("res://tests/suites/actor_presentation_suite.gd").run(_expect)
	print("FX-14 AFFECTED SUITES: %s (%d checks, %d failures)" % [
		"PASS" if _failures == failures_before else "FAIL", _checks - before, _failures - failures_before,
	])
