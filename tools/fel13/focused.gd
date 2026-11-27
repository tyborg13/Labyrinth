extends RefCounted

const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const Overlay = preload("res://scripts/board_occlusion_silhouettes.gd")
const AddedSubjects = preload("res://tools/fel13/added_subjects.gd")
const NativeContent = preload("res://tools/fel13/native_content.gd")
const TRAP := "trap:fel13_trap:(2, 2)"
const TRAP_TILE := Vector2i(2, 2)
const LOOT := "loot:fel13_loot:(4, 2)"
const ICE := "surface:(5, 5)"
const RUBBLE := "surface:(4, 1)"
const EXIT := "exit:(4, 1)"

var checks: int = 0
var failures: int = 0

func run(session: SceneTree) -> void:
	_expect(Overlay.CONTENT_SHOW_ALPHA == 0.75, "content uses approved on-cell alpha")
	_expect(Overlay.switched_on(0.30, false, false), "turns on at 0.30")
	_expect(not Overlay.switched_on(0.299, false, false), "off stays off in the band")
	_expect(Overlay.switched_on(0.22, true, false), "on stays on at 0.22")
	_expect(not Overlay.switched_on(0.219, true, false), "turns off below 0.22")
	_expect(Overlay.FADE_SECONDS == 0.15, "uses fel-02 fade")
	var probe := Alpha.new()
	var mask_image := Image.create_empty(8, 4, false, Image.FORMAT_RGBA8)
	mask_image.fill_rect(Rect2i(0, 0, 4, 4), Color.WHITE)
	var sample: Dictionary = {"kind": "prop", "rect": Rect2(0, 0, 8, 4), "mask": probe.mask_from_image(mask_image, "half")}
	_expect(Alpha.opaque_at(sample, Vector2(1.0, 1.0)), "opaque prop pixels included")
	_expect(not Alpha.opaque_at(sample, Vector2(7.0, 1.0)), "transparent prop pixels excluded")
	_expect(not Alpha.blocks({"kind": "surface"}, {"kind": "unit"}), "surfaces do not x-ray characters")
	_expect(Alpha.blocks({"kind": "trap"}, {"kind": "unit"}), "character blocks trap rim")
	_expect(Alpha.blocks({"kind": "loot"}, {"kind": "prop"}), "prop blocks ordinary loot")
	_check_pixel_metric()
	if not await session.open_fixture("P1"):
		session.quit(1)
		return
	var board: Control = session.board
	var overlay: Node = board.get("_occlusion_silhouettes")
	await _check_layout_recovery(session)
	_check_release_painters(session)
	var reveal: Node = board.get("_occlusion_reveal")
	var tile := Vector2i(3, 3)
	_expect(_checker(overlay, TRAP), "completely hidden trap receives checker")
	_expect(_rim(overlay, TRAP), "completely hidden trap receives pale rim")
	var screen: Dictionary = overlay.get("_content_tiles").get(TRAP_TILE, {})
	_expect(not screen.is_empty(), "static checker owns a retained scene tile pass")
	if not screen.is_empty():
		var ink: ShaderMaterial = screen["ink"]
		_expect(ink.get_shader_parameter("grid") == overlay._board_fill_grid(), "content shares the unit grid")
		var painter: Control = screen["painter"]
		var blocker: Control = board.get("_scene_render_layers_by_tile").get(tile)
		var bodies_in_front: bool = true
		for body: Control in overlay.team.bodies.values():
			if body.get_parent() == blocker and body.get_index() < painter.get_index(): bodies_in_front = false
		_expect(painter.get_parent() == blocker and bodies_in_front,
			"checker draws after the blocking tile's props and before its retained bodies")
		overlay.content_show_through_enabled = false
		_expect(not painter.visible and _rim(overlay, TRAP), "native comparison disables the checker alone")
		overlay.content_show_through_enabled = true
		_expect(painter.visible and painter.material == ink, "native comparison restores the same checker material")
		var rear: Texture2DArray = ink.get_shader_parameter("hidden_mask")
		var builds: int = overlay.coverage_builds
		await session.settle()
		_expect(builds == overlay.coverage_builds, "idle scene reuses coverage")
		_expect(ink.get_shader_parameter("hidden_mask") == rear, "idle scene reuses checker masks")
	await session.point(session.tile_point(TRAP_TILE))
	await session.settle()
	var prop_alpha: float = reveal.prop_alpha("pillar", tile)
	_expect(is_equal_approx(prop_alpha, 0.30), "occ-02 pillar reaches 30 percent")
	if not screen.is_empty():
		var data: Texture2D = screen["ink"].get_shader_parameter("content_factors")
		var blockers: Array = screen["blockers"]
		var column: int = blockers.find_custom(func(mask: Dictionary) -> bool:
			return mask["tile"] == tile and mask["category"] == "pillar")
		var bound_alpha: float = data.get_image().get_pixel(column, 1).r if column >= 0 else -1.0
		_expect(is_equal_approx(bound_alpha, prop_alpha), "checker reveal multiplier %.3f matches %.3f" % [bound_alpha, prop_alpha])

	var without_trap: Dictionary = board.combat_state.duplicate(true)
	without_trap["traps"].clear()
	board.set_combat_state(without_trap, [], [], Vector2i(-1, -1), "", "", board.exit_tiles, board.exit_icon_ids, board.presentation)
	await session.process_frame
	await session.process_frame
	_expect(not _checker(overlay, TRAP) and not _rim(overlay, TRAP), "trap removal invalidates show-through in the next frame")
	await session.point(session.NO_POINTER)
	AddedSubjects.present(board, "P1")
	await session.settle()
	_expect(_checker(overlay, AddedSubjects.REFUGE) and not _rim(overlay, AddedSubjects.REFUGE), "refuge perimeter behind the pillar receives the floor checker")
	var dark: Dictionary = board.combat_state.duplicate(true)
	dark["guardian_braziers"][0]["lit"] = false
	AddedSubjects.submit(board, dark, board.presentation)
	await session.settle()
	_expect(not _checker(overlay, AddedSubjects.REFUGE), "a dark brazier clears its refuge source")
	await session.close_fixture()
	if not await session.open_fixture("P2"):
		session.quit(1)
		return
	board = session.board
	overlay = board.get("_occlusion_silhouettes")
	AddedSubjects.present(board, "P2")
	await session.settle()
	_expect(_checker(overlay, AddedSubjects.DEATH_SITE) and _rim(overlay, AddedSubjects.DEATH_SITE), "death-site Embers use the pickup checker and rim")
	var without_embers: Dictionary = board.presentation.duplicate(false)
	without_embers.erase("death_site_embers")
	AddedSubjects.submit(board, board.combat_state, without_embers)
	await session.settle()
	_expect(not _checker(overlay, AddedSubjects.DEATH_SITE) and not _rim(overlay, AddedSubjects.DEATH_SITE), "clearing the presentation entry clears the pickup passes")
	await session.close_fixture()
	if not await session.open_fixture("P4"):
		session.quit(1)
		return
	overlay = session.board.get("_occlusion_silhouettes")
	_expect(_rim(overlay, TRAP) and not _checker(overlay, TRAP), "hero produces only a trap rim")
	_expect(_rim(overlay, LOOT) and not _checker(overlay, LOOT), "enemy produces only a loot rim")
	_expect(not _checker(overlay, ICE), "Ice behind the Warden gets no checker")
	await session.close_fixture()
	if not await session.open_fixture("P6"):
		session.quit(1)
		return
	overlay = session.board.get("_occlusion_silhouettes")
	_expect(not _checker(overlay, RUBBLE) and not _rim(overlay, RUBBLE), "Rubble stays in the census without checker or rim")
	_expect(_checker(overlay, EXIT), "crate over exit threshold supplies a checker")
	await session.close_fixture()
	print("FEL13 FOCUSED %s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	session.quit(0 if failures == 0 else 1)

func _check_pixel_metric() -> void:
	var grid := Vector4(5, 7, 2, 2)
	_expect(NativeContent.on_cell(Vector2(4.5, 6.5), grid) and not NativeContent.on_cell(Vector2(4.5, 7.5), grid),
		"pixel audit follows the board grid on both sides of the origin")
	var changed := PackedByteArray([76, 76, 76, 255, 77, 78, 77, 255, 36, 0, 0, 255, 37, 0, 0, 255])
	var baseline := PackedByteArray([0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255])
	var clear := PackedByteArray([80, 80, 80, 255, 80, 80, 80, 255, 0, 0, 0, 255, 0, 0, 0, 255])
	var on := PackedInt32Array([0, 4])
	var off := PackedInt32Array([8, 12])
	_expect(NativeContent.compare(changed, baseline, clear, on, off, 1.0) == Vector2(0.5, 0.5),
		"pixel audit uses inclusive 16 from the blend and exclusive 12 off")
	_expect(NativeContent.compare(baseline, baseline, clear, on, off, 1.0) == Vector2.ZERO,
		"a blank checker cannot pass the blend gate when clear differs")
	_expect(NativeContent.compare(baseline, baseline, baseline, on, off, 1.0) == Vector2(1.0, 0.0),
		"matching dark paint no longer needs an arbitrary contrast delta")
	_expect(NativeContent.forbidden_share(changed, baseline, off, {}) == 0.5, "excluded paint counts any changed sample")
	var image := Image.create_empty(4, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(1, 0, Color(1.0, 1.0, 1.0, 127.0 / 255.0))
	image.set_pixel(2, 0, Color(1.0, 1.0, 1.0, 128.0 / 255.0))
	image.set_pixel(3, 0, Color.WHITE)
	var geometry: Dictionary = Alpha.new().fill_geometry({"kind": "trap", "rect": Rect2(0, 0, 4, 1),
		"mask_texture": ImageTexture.create_from_image(image)})
	_expect(not Alpha.fill_contains(geometry, Vector2(1.5, 0.5)) and Alpha.fill_contains(geometry, Vector2(2.5, 0.5)),
		"sprite fill uses full-resolution texels and includes half opacity")

func _check_release_painters(session: SceneTree) -> void:
	var board: Control = session.board
	var world: Control = board.get("_dynamic_render_layer")
	var pulse := func() -> float: return 0.5
	board.set_umbra_tutorial_outline(pulse)
	var contours: Array = world.call("_umbra_tutorial_boundary", {TRAP_TILE: true})
	var prompt: Script = board.get_script().get_script_constant_map()["TutorialPrompt"]
	_expect(world.get("_umbra_tutorial_pulse") == pulse and contours.size() == 1 and contours[0].size() == 4
		and prompt.spotlight_halo_distance(pulse.call(), false) > 0.0, "release tutorial spotlight binds the prompt and traces a closed tile contour")
	board.set_umbra_tutorial_outline(Callable())
	var effects: Control = board.get("_effects_render_layer")
	effects.call("_draw_tile_damage_numeral", ThemeDB.fallback_font, Vector2.ZERO, "1", 24.0, 16, Color.WHITE, Color.BLACK, 1.0)
	var labels: RefCounted = effects.get("_label_ink")
	labels.finish_numbers(effects)
	_expect((labels.get("_number_canvas") as RID).is_valid() and (labels.feedback_canvas(effects) as RID).is_valid(),
		"release damage numerals and floating labels use retained canvases")

func _check_layout_recovery(session: SceneTree) -> void:
	var board: Control = session.board
	var fit: Rect2 = board.presentation["board_fit_rect"]
	var exclusions: Array[Rect2] = board.presentation["board_fit_exclusions"]
	var legacy: Rect2 = board.presentation["board_legacy_fit_rect"]
	# Model the early capture boundary and the later deferred framing publish.
	board.set_room_framing(Rect2(0.0, 0.0, fit.size.x, 1.0), exclusions, legacy)
	_expect(board._tile_width() == 1.0, "reproduced the provisional one-pixel board fit")
	var before: int = Engine.get_process_frames()
	board.call_deferred("set_room_framing", fit, exclusions, legacy)
	var settled: bool = await session.require_board_layout("P1-deferred-fit")
	_expect(settled and Engine.get_process_frames() - before >= session.STABLE_LAYOUT_FRAMES,
		"probe waits for the deferred fit and ten stable frames")


func _checker(overlay: Node, key: String) -> bool:
	return bool(overlay.get("_content_entries").get(key, {}).get("on", false))

func _rim(overlay: Node, key: String) -> bool:
	return bool(overlay.get("entries").get(key, {}).get("on", false))

func _expect(ok: bool, description: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	printerr("FEL13 ASSERT ", description)
