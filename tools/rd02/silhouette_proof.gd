extends SceneTree

const Silhouettes = preload("res://scripts/board_occlusion_silhouettes.gd")
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const RealCase = preload("res://tools/rd02/fixture.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/rd-02"
const EPSILON: float = 0.00001
const SETTLE_FRAMES: int = 24
const COMPACT_SIZE := Vector2i(1280, 800) # Proof-only Steam Deck viewport.
const STEADY_FRAMES: int = 10
const LAYOUT_SETTLE_FRAMES: int = 3
const PROOF_ZOOM_RATIO: float = 0.9
const TEST_RECT := Rect2(0, 0, 32, 32)
const CASES: Array = ["hero", "zekarion", "vyraketh", "warband"]
var checks: int = 0
var failures: Array[String]
var samples: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	_test_math()
	for case_name: String in CASES:
		RealCase.install(case_name)
		var canvas: SubViewport = Fixture.make_canvas(self)
		var scene: Node = Fixture.resume(self, canvas)
		for frame: int in range(SETTLE_FRAMES): await process_frame
		var board: Control = scene.get("board_view")
		var overlay: Node2D = board.get("_occlusion_silhouettes")
		_check(overlay != null, "Production board owns overlay")
		_check(overlay.get_index() > (board.get("_foreground_render_layer") as Node).get_index(), "Above Foreground")
		for field: String in ["_effects_telegraph_render_layer", "_effects_render_layer", "_hud_render_layer"]:
			_check(overlay.get_index() < (board.get(field) as Node).get_index(), "Below " + field)
		for layer: Node in board.get("_scene_render_layers"):
			_check(overlay.get_index() > layer.get_index(), "Above " + str(layer.name))
		_check(bool(board.call("_scene_render_layers_match", board.call("_rendered_tiles_in_draw_order"))), "Scene layer match fast path retained")
		var candidates: Array[Dictionary] = Sources.collect(board)
		var unit_count: int = 0
		for entry: Dictionary in candidates:
			if not bool(entry["eligible"]): continue
			if str(entry["kind"]) == "unit":
				unit_count += 1
				var draw: Dictionary = Sources.drawing(board, entry)
				_check(draw["texture"] == board.call("_texture_for_unit", entry["data"]), "Exact current pose texture " + str(entry["key"]))
				_check(draw["rect"] == board.call("_unit_texture_draw_rect", entry["data"], board.call("_unit_center", entry["data"])), "Exact live padded pose rect " + str(entry["key"]))
		_check(unit_count > 0, "Certified fight contains living units")
		overlay.sync_coverage()
		var alpha: RefCounted = overlay.get("alpha_masks")
		alpha.prepare(candidates)
		var expected_key: String = "enemy_1" if case_name == "warband" else "player"
		var found: bool = false
		for index: int in range(candidates.size()):
			if str(candidates[index].get("key", "")) != expected_key: continue
			found = true
			var amount: float = alpha.coverage_for(candidates, index)
			var on: bool = Silhouettes.switched_on(amount, false, true)
			_check(on == (case_name != "hero"), case_name + ": director alpha coverage result")
			_check(overlay.get("entries").has(expected_key) == on, case_name + ": actual overlay follows alpha coverage")
			samples.append({"case": case_name, "key": expected_key, "coverage": amount, "on": on})
			print("RD02 ALPHA COVERAGE %s %s: %.6f (%s)" % [case_name, expected_key, amount, "on" if on else "off"])
		_check(found, case_name + ": proof target present")
		preload("res://tools/rd02/team_outline_checks.gd").run(board, overlay, _check)
		var queries: int = alpha.get("queries")
		overlay.sync_coverage()
		_check(int(alpha.get("queries")) == queries, "Identical geometry reuses alpha coverage")
		var hero_renderer: Node = board.call("unit_cutout_renderer", {"type": "player"})
		var old_phase: float = hero_renderer.get("phase")
		var old_clip: String = hero_renderer.get("clip")
		hero_renderer.set("phase", old_phase + 0.01)
		overlay.submission_changed(false, {"protagonist_motion": true}, {})
		_check(not bool(overlay.get("coverage_dirty")), "Animation phase alone does not recompute alpha coverage")
		hero_renderer.set("clip", "walk" if old_clip != "walk" else "idle")
		overlay.submission_changed(false, {"protagonist_motion": true}, {})
		_check(bool(overlay.get("coverage_dirty")), "Pose-set transition invalidates alpha coverage")
		hero_renderer.set("phase", old_phase)
		hero_renderer.set("clip", old_clip)
		overlay.sync_coverage()
		var active: Dictionary = overlay.get("entries")
		_check(case_name == "hero" or not active.is_empty(), "Covered fight produces silhouettes")
		for key: String in active:
			var entry: Dictionary = active[key]
			samples.append({"key": key, "coverage": entry["coverage"], "on": entry["on"], "kind": entry["source"]["kind"]})
			_check((entry["sprite"] as Sprite2D).material.shader == Silhouettes.Outline, "Dedicated mask shader, normal art unchanged")
			_check_front_mask(board, overlay, key, entry)
		# Actual fade progression on retained sprites, including reversal.
		for entry: Dictionary in active.values(): entry["alpha"] = 0.0
		overlay._process(Silhouettes.FADE_SECONDS * 0.5)
		for entry: Dictionary in active.values(): _check(is_equal_approx(entry["alpha"], 0.5), "Half of director fade duration is half alpha")
		overlay._process(Silhouettes.FADE_SECONDS * 0.5)
		for entry: Dictionary in active.values(): _check(is_equal_approx(entry["alpha"], 1.0), "Full fade reaches director alpha")
		var builds_before: int = overlay.get("coverage_builds")
		var poses_before: int = overlay.get("pose_updates")
		for frame: int in range(STEADY_FRAMES): overlay._process(0.0)
		_check(builds_before == int(overlay.get("coverage_builds")), "Settled frame ticks do not rebuild board coverage")
		_check(poses_before == int(overlay.get("pose_updates")), "Settled frame ticks do not rebind rims or front cut-outs")
		_check(not overlay.is_processing(), "Settled silhouettes disable process")
		root.size = COMPACT_SIZE
		root.content_scale_size = COMPACT_SIZE
		for frame: int in range(LAYOUT_SETTLE_FRAMES): await process_frame
		overlay.sync_coverage()
		_check(canvas.size == COMPACT_SIZE, "Compact Steam Deck viewport")
		_check(bool(board.call("_scene_render_layers_match", board.call("_rendered_tiles_in_draw_order"))), "Compact layout retains painter order")
		board.call("set_navigation_zoom", float(board.get("_navigation_zoom")) * PROOF_ZOOM_RATIO)
		overlay.sync_coverage()
		for entry: Dictionary in overlay.get("entries").values():
			var sprite: Sprite2D = entry["sprite"]
			var radius: Vector2 = sprite.material.get_shader_parameter("radius_source")
			_check((radius * sprite.scale).is_equal_approx(Vector2.ONE * 2.0 * float(board.get("_navigation_zoom"))), "Rim stays 2 px times zoom in compact layout")
		root.size = Fixture.SIZE
		root.content_scale_size = Fixture.SIZE
		for frame: int in range(LAYOUT_SETTLE_FRAMES): await process_frame
		# Mutate a duplicate certified presentation/state through the real board
		# submission path, then restore it; never touch the source save.
		var state: Dictionary = (board.get("combat_state") as Dictionary).duplicate(true)
		var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
		var hidden: Dictionary = shown.duplicate(true)
		hidden["visible_enemy_ids"] = []
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, hidden)
		overlay.sync_coverage()
		for key: String in overlay.get("entries"): _check(not key.begins_with("enemy_"), "Umbra-hidden enemy removed immediately")
		for key: String in overlay.get("team").get("entries"): _check(not key.begins_with("enemy_"), "Umbra-hidden enemy has no normal rim")
		state["player"]["hp"] = 0
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, hidden)
		overlay.sync_coverage()
		_check(not overlay.get("entries").has("player"), "Dead hero has no silhouette")
		_check(not overlay.get("team").get("entries").has("player"), "Dead hero has no normal rim")
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, hidden)
		overlay._process(Silhouettes.FADE_SECONDS)
		var builds: int = overlay.get("coverage_builds")
		for frame: int in range(STEADY_FRAMES): overlay._process(0.0)
		_check(builds == int(overlay.get("coverage_builds")), "No per-frame coverage rebuild")
		canvas.queue_free()
		await process_frame
	for failure: String in failures: push_error(failure)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var file := FileAccess.open(OUTPUT.path_join("proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "samples": samples,
		"coverage": "opaque rest pixels >0.5, masks at 25%", "renderer": DisplayServer.get_name(),
		"target_border_layer": "director accepted existing floor-decal slot"}, "\t"))
	file.close()
	print("RD02 SILHOUETTE PROOF: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])

	quit(0 if failures.is_empty() else 1)

func _test_math() -> void:
	for unit: bool in [true, false]:
		var on: float = Silhouettes.UNIT_ON if unit else Silhouettes.OBJECT_ON
		var off: float = Silhouettes.UNIT_OFF if unit else Silhouettes.OBJECT_OFF
		_check(not Silhouettes.switched_on(on - EPSILON, false, unit), "Below on threshold")
		_check(Silhouettes.switched_on(on, false, unit), "Inclusive on threshold")
		_check(Silhouettes.switched_on(off, true, unit), "Inclusive hysteresis off boundary")
		_check(not Silhouettes.switched_on(off - EPSILON, true, unit), "Below off threshold")
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture: Texture2D = ImageTexture.create_from_image(image)
	var alpha := Alpha.new()
	var sources: Array[Dictionary]
	sources.assign([
		{"key": "target", "kind": "unit", "rect": TEST_RECT, "mask_texture": texture},
		{"kind": "unit", "rect": Rect2(0, 0, 8, 32), "mask_texture": texture},
		{"kind": "unit", "rect": Rect2(4, 0, 8, 32), "mask_texture": texture}])
	alpha.prepare(sources)
	_check(alpha.builds == 1, "Shared textures build one 25% mask")
	_check(sources[0]["mask"]["size"] == Vector2i(8, 8), "Mask dimensions exactly quarter size")
	_check(is_equal_approx(alpha.coverage_for(sources, 0), 0.375), "Alpha union counts opaque pixels once")
	var builds: int = alpha.builds
	var queries: int = alpha.queries
	alpha.prepare(sources)
	alpha.coverage_for(sources, 0)
	_check(alpha.builds == builds and alpha.queries == queries, "Mask and position cache hit")
	image.fill(Color.TRANSPARENT)
	var clear_texture: Texture2D = ImageTexture.create_from_image(image)
	sources[1]["mask_texture"] = clear_texture
	sources[1]["rect"] = TEST_RECT
	sources.remove_at(2)
	alpha.prepare(sources)
	_check(alpha.coverage_for(sources, 0) == 0.0, "Fully overlapping transparent occluder covers zero opaque pixels")
	sources[1]["mask_texture"] = texture
	sources[0]["kind"] = "trap"
	sources[1]["kind"] = "prop"
	alpha.prepare(sources)
	_check(alpha.coverage_for(sources, 0) == 0.0, "Prop alone never silhouettes objects")
	sources[1]["kind"] = "unit"
	_check(alpha.coverage_for(sources, 0) == 1.0, "Unit silhouettes opaque object")
	sources[0]["kind"] = "unit"
	sources[1]["kind"] = "prop"
	_check(alpha.coverage_for(sources, 0) == 1.0, "Prop silhouettes unit regardless of fade tint")
	_check(alpha.coverage_for(sources, 1) == 0.0, "Earlier art never occludes later art")
	var threshold_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	threshold_image.fill(Color(1.0, 1.0, 1.0, 127.0 / 255.0))
	threshold_image.fill_rect(Rect2i(16, 0, 16, 32), Color(1.0, 1.0, 1.0, 128.0 / 255.0))
	var threshold_texture: Texture2D = ImageTexture.create_from_image(threshold_image)
	var threshold_source: Dictionary = {"kind": "unit", "rect": TEST_RECT, "mask_texture": threshold_texture}
	var threshold_mask: Dictionary = alpha.mask_for(threshold_source)
	_check((threshold_mask["points"] as PackedVector2Array).size() == 32, "Only source alpha strictly greater than 0.5 is opaque")
	threshold_source["mask"] = threshold_mask
	_check(not Alpha.opaque_at(threshold_source, Vector2(2, 2)) and Alpha.opaque_at(threshold_source, Vector2(30, 2)), "Alpha occupancy samples opaque half")
	threshold_source["mask_flip"] = true
	_check(Alpha.opaque_at(threshold_source, Vector2(2, 2)) and not Alpha.opaque_at(threshold_source, Vector2(30, 2)), "Mirrored pose mirrors occupancy")
	builds = alpha.builds
	threshold_source["mask_pose"] = "other_facing"
	alpha.mask_for(threshold_source)
	_check(alpha.builds == builds + 1, "Mask cache is keyed by pose set as well as texture")
	_check(Silhouettes.team_color({"kind": "unit", "data": {"role": "enemy"}}) == Color(Palette.DANGER, 0.85), "Enemy DANGER 85%")
	for role: String in ["player", "illusion", "ally", "summon"]:
		_check(Silhouettes.team_color({"kind": "unit", "data": {"role": role}}) == Color(Palette.ALLY, 0.85), "Player side ALLY 85% " + role)
	_check(Silhouettes.team_color({"kind": "trap", "data": {}}) == Color(Palette.TEXT, 0.70), "Object TEXT 70%")
	_check(Silhouettes.WIDTH == 2.0 and Silhouettes.FADE_SECONDS == 0.15, "Director width and fade")

# occ-01: an object rim is hidden under units painted after it. The shader gets
# every such unit whose live drawing reaches the rim, at its live texture/rect.
func _check_front_mask(board: Control, overlay: Node2D, key: String, entry: Dictionary) -> void:
	var source: Dictionary = entry["source"]
	var ink: ShaderMaterial = (entry["sprite"] as Sprite2D).material
	var fronts: Array = entry.get("front", [])
	if str(source["kind"]) == "unit":
		_check(fronts.is_empty() and int(ink.get_shader_parameter("front_count")) == 0, "Unit x-ray has no front cut-out: " + key)
		return
	var sources: Array[Dictionary] = Sources.collect(board)
	var index: int = -1
	for at: int in range(sources.size()):
		if str(sources[at].get("key", "")) == key: index = at
	_check(index >= 0, "Object x-ray is a painter-order source: " + key)
	var expected: Array = overlay.call("front_units", sources, index)
	_check(fronts.size() == expected.size() and not fronts.is_empty(), "Covered object rim knows every unit painted in front of it: " + key)
	_check(int(ink.get_shader_parameter("front_count")) == fronts.size(), "Shader front count: " + key)
	# Floating loot bobs between pose updates, so compare with the rim sprite itself.
	var sprite: Sprite2D = entry["sprite"]
	var size: Vector2 = sprite.scale * Vector2(sprite.texture.get_size())
	var placed: Vector4 = ink.get_shader_parameter("object_rect")
	_check(Vector2(placed.x, placed.y).is_equal_approx(sprite.position - size * 0.5) and Vector2(placed.z, placed.w).is_equal_approx(size), "Cut-out maps the rim sprite's drawn object rect: " + key)
	for slot: int in range(fronts.size()):
		var front: Dictionary = fronts[slot]
		var later: bool = false
		for at: int in range(index + 1, sources.size()): later = later or str(sources[at].get("key", "")) == str(front["key"])
		_check(str(front["kind"]) == "unit" and later, "Only units painted after the object cut its rim: " + key)
		var live: Dictionary = Sources.drawing(board, front)
		var rect: Rect2 = live["rect"]
		var texture: Texture2D = live["texture"]
		_check(ink.get_shader_parameter("front_rect_%d" % slot) == Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y), "Cut-out follows the live unit placement: " + key)
		_check(ink.get_shader_parameter("front_texture_%d" % slot) == ((texture as AtlasTexture).atlas if texture is AtlasTexture else texture), "Cut-out samples the unit's live pose texture: " + key)
		var ring: float = Silhouettes.WIDTH * float(board.get("_navigation_zoom")) if overlay.get("team").get("entries").has(str(front["key"])) else 0.0
		var region: Rect2 = Silhouettes.uv_region(texture)
		_check((ink.get_shader_parameter("front_pad_%d" % slot) as Vector2).is_equal_approx(region.size * ring / rect.size), "Cut-out widens by the front unit's team-rim ring: " + key)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
