extends "res://tests/pre_battle_fixture.gd"
const Evidence = preload("res://tools/emaciated_man_cutout/game_evidence.gd")
const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Portrait = preload("res://scripts/npc_portrait_region.gd")
const Motion = preload("res://scripts/emaciated_man_cutout/motion.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const OUTPUT: String = "user://probes/emac02"
# Fixed proof time only, independent of elapsed startup and renderer speed.
const PROOF_SECONDS: float = 0.84
const PROOF_HERO_TILE := Vector2i(3, 3)
var _verify_only: bool = false
var _native_actors: Array[Dictionary]
var _default_actors: Array[Dictionary]

func _initialize() -> void:
	_setup()
	_verify_only = OS.get_cmdline_user_args().has("--verify-only")
	call_deferred("_run")

func _run() -> void:
	ProgressionStore.save_data(Fixture.profile())
	var state: Dictionary = Fixture.state()
	# Existing decline path keeps the portrait visible without the boon modal.
	state = Boons.choose(RunEngine.new(), state, "")
	var scene: Node = await _instance(state)
	var map_scrim: Control = scene.get("_large_map_scrim") as Control
	if map_scrim != null and map_scrim.visible: scene.call("_close_large_map")
	scene.call("_close_dialogue")
	await _settle()
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
	_default_actors = Evidence.actors(board)
	_expect(scene.call("_board_fit_rect") == scene.call("_legacy_board_fit_rect"), "Waypoint uses existing room bounds, not hidden combat-hand geometry")
	_expect(float(board.call("_tile_width")) > 1.0, "Waypoint must not hit the one-pixel framing clamp")
	_expect(is_equal_approx(float(board.call("_tile_width")),149.413848876953), "Round-1 waypoint framing scale stays unchanged")
	for row: Dictionary in _default_actors:
		_expect(row["body_visible"] and row["true_scale"], "Production waypoint actor has a true-scale body: " + str(row["key"]))
	if not _verify_only: await _capture(OUTPUT.path_join("central_waypoint_default.png"))
	for row: Dictionary in _default_actors:
		if row["type"] == "emaciated_man":
			_expect(is_equal_approx(float(row["shadow_foot"][1]),float(row["canvas_ground_y"])), "Contact shadow stays at the unchanged 254/255 ground line")
	_place_proof_hero(scene)
	var actor: Dictionary = {}
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("type", "")) == "emaciated_man": actor = unit
	_expect(not actor.is_empty(), "Central Waypoint includes the Emaciated Man")
	var renderer: Node = board.call("unit_cutout_renderer", actor)
	_expect(renderer != null, "Actual board routes NPC to the new cutout")
	if renderer == null:
		quit(1)
		return
	_expect((board.get("_idle_frames_by_type") as Dictionary).get("emaciated_man", []).is_empty(), "Old sheet is not loaded")
	_expect(board.call("_texture_for_unit", actor) == renderer.call("texture"), "Actual texture submission uses the live cutout")
	_expect((board.call("_unit_hud_anchor_texture", actor) as Texture2D).get_size() == Vector2(255, 255), "Footing and shadow use the neutral 255-canvas rest")
	board.set_process(false)
	renderer.call("present", PROOF_SECONDS, false)
	board.call("_queue_dynamic_redraw")
	await _settle()
	if not _verify_only:
		await _capture(OUTPUT.path_join("central_waypoint.png"))
		_native_actors = await Evidence.native_pixels(self, _viewport, board, OUTPUT)
		for row: Dictionary in _native_actors:
			_expect(bool(row["pixels_visible"]), "Actual waypoint pixels must contain " + str(row["key"]) + ": " + str(row))
	scene.call("_speak_to_emaciated_man")
	scene.call("_complete_current_dialogue_line")
	await _settle()
	_place_proof_hero(scene)
	board.set_process(false)
	renderer.call("present", PROOF_SECONDS, false)
	board.call("_queue_dynamic_redraw")
	await _settle()
	var portrait: TextureRect = scene.get("_dialogue_portrait")
	var atlas: AtlasTexture = portrait.texture as AtlasTexture
	_expect(atlas != null, "Actual dialogue uses an atlas portrait")
	if atlas != null:
		_expect(atlas.region == Portrait.region(GameData.npc_def("emaciated_man"), atlas.atlas.get_size()), "Dialogue reads the per-NPC crop")
		_expect(is_equal_approx(atlas.region.size.x, 1.9 * float(renderer.rig.layout["portrait_head_width"])), "Bust uses head shell width, excluding the back drape")
		_expect(atlas.region.end.y < float(renderer.rig.layout["joints"]["near_hand"]["position"][1]), "Bust crop excludes the seated hands and sack")
	if not _verify_only: await _capture(OUTPUT.path_join("dialogue_portrait.png"))
	# Reduce motion through the board's normal presentation, then check the
	# exact rest pose and steady pulse without changing saved state or gameplay.
	var reduced: Dictionary = (board.get("presentation") as Dictionary).duplicate()
	reduced["reduced_motion"] = true
	board.set("presentation", reduced)
	preload("res://scripts/emaciated_man_cutout/presentation.gd").sync(board)
	_expect(renderer.call("snapshot")["clip"] == "rest", "Reduced motion holds rest")
	_expect(is_equal_approx(Motion.glow_alpha(PROOF_SECONDS, true, true), 0.15), "Reduced glow is steady")
	board.call("_queue_dynamic_redraw")
	await _settle()
	if not _verify_only: await _capture(OUTPUT.path_join("reduced_motion.png"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":not _failed,"size":[1920,1080],"ui_scale":1.0,"cel_look":preload("res://scripts/cel_look.gd").mode,"proof_seconds":PROOF_SECONDS,"proof_hero_tile":[PROOF_HERO_TILE.x,PROOF_HERO_TILE.y],"npc":GameData.npc_def("emaciated_man"),"snapshot":renderer.call("snapshot"),"verify_only":_verify_only,"default_actors":_default_actors,"native_actors":_native_actors,"tile_width":board.call("_tile_width")},"\t"))
	print("EMAC GAME PROBE: %s; waypoint=cutout; dialogue=portrait_region; reduced=rest; sheet=unused" % ("FAIL" if _failed else "PASS"))
	print(ProjectSettings.globalize_path(OUTPUT))
	scene.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame
	quit(1 if _failed else 0)

func _place_proof_hero(scene: Node) -> void:
	var display: Dictionary = scene.call("_board_display_state").duplicate(true)
	display["player"]["pos"] = PROOF_HERO_TILE
	scene.call("_render_board_state", display, scene.call("_stage_chrome_presentation"), false)
