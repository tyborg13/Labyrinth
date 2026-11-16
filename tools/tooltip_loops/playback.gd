extends RefCounted
const SIZE := Vector2i(1920, 1080)
const Settings = preload("res://scripts/settings_store.gd")
const Biomes = preload("res://scripts/biome_library.gd")
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const SETTLE_FRAMES: int = 12 # Debug warmup, outside recording.
const READY_FRAME_LIMIT: int = 300 # Debug startup/centering watchdog.
const MASK_SETTLE_FRAMES: int = 3 # Renderer submissions after the recording mask.

static func canvas(tree: SceneTree) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	return viewport

static func instance(tree: SceneTree, viewport: SubViewport, fixture: Dictionary, recording: bool, speed: String = "normal") -> Node:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["combat_speed"] = speed
	Settings.save_settings(settings) # Task-runner HOME only; _ready reads this same player setting.
	Settings.apply_settings(settings, null, false)
	var biome: String = str(Fixture.BIOMES.get(fixture["id"], Fixture.Tip03.BIOMES.get(fixture["id"], Fixture.Tip04.BIOMES.get(fixture["id"], Biomes.default_biome()))))
	Biomes.set_inspection_override(biome)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	if recording:
		var board: Node = scene.find_child("CombatBoard", true, false)
		board.set_script(preload("res://tools/tooltip_loops/record_board.gd"))
	if scene.get_script() == null:
		scene.free()
		return null
	viewport.add_child(scene)
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
	scene.call("_load_run_state", fixture["run"])
	scene.call("_close_dialogue")
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
	for frame: int in range(READY_FRAME_LIMIT):
		var centering: Tween = scene.get("_board_centering_tween")
		if scene.call("initial_presentation_is_ready") and (centering == null or not centering.is_valid() or not centering.is_running()): break
		await tree.process_frame
	if recording:
		var board: Control = scene.get("board_view")
		# Keep only the production board subtree. Mask the surrounding HUD and
		# backdrop, preserving ancestor transforms and every board child/VFX.
		_hide_except(scene, board)
		board.set_tooltips_enabled(false)
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scene.set_process_input(false)
		scene.set_process_unhandled_input(false)
		# Hiding BoardBackdrop changes the production board's background contract.
		# Resubmit it before frame zero, not at the first action after the idle.
		scene.call("_render_board_state", fixture["state"], {})
		for frame: int in range(MASK_SETTLE_FRAMES):
			await tree.process_frame
			if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	return scene

static func _hide_except(node: Node, board: Node) -> void:
	if node == board: return
	for child: Node in node.get_children():
		if child == board or child.is_ancestor_of(board): _hide_except(child, board)
		elif child is CanvasItem: child.hide()
		elif child is CanvasLayer: child.visible = false

static func play(scene: Node, result: Dictionary, completion: Dictionary) -> void:
	scene.set("_animation_lock", true)
	await scene.get_tree().create_timer(0.4).timeout
	var pacing: Node = scene.get("_combat_pacing")
	for beat: Dictionary in result["beats"]:
		if beat["kind"] == "room_rule":
			pacing.begin_enemies()
			await Fixture.Tip04.play(scene, beat)
		elif beat["kind"] == "rule":
			pacing.begin_enemies()
			# The ordinary loss-feedback painter owns numbers, reactions and timing;
			# feed the rule's real struck tiles to its existing lightning effect.
			var shown: Dictionary = rule_presentation(scene, beat)
			await scene.call("_animate_floating_text_presentation", beat["after"], shown)
		elif beat["kind"] == "enemy":
			pacing.begin_enemies()
			await scene.call("_animate_enemy_phase_steps", beat["before"].duplicate(true), beat["steps"], beat["after"])
		else:
			pacing.begin_card()
			scene.call("_begin_player_popup_timeline")
			await scene.call("_animate_player_action_step", beat["before"], beat["after"], str(beat.get("card", "")), beat["action"], beat["target"], beat["chain_hits"])
			await scene.call("_finish_player_popup_timeline", beat["after"])
		scene.call("_render_board_state", beat["after"], {})
		if beat["kind"] in ["enemy", "rule", "room_rule"]: await pacing.finish_enemies()
		else: pacing.end_scope()
	completion["done"] = true

static func crop_rect(board: Control) -> Rect2i:
	var bounds := Rect2()
	var first: bool = true
	for y: int in range(3):
		for x: int in range(4):
			for vertex: Vector2 in board._tile_polygon(Vector2i(x, y)):
				var point: Vector2 = board.get_global_transform_with_canvas() * vertex
				if first: bounds = Rect2(point, Vector2.ZERO); first = false
				else: bounds = bounds.expand(point)
	var width: float = bounds.size.x * 282.0 / 258.0
	var extent := Vector2(width, width * 168.0 / 282.0)
	return Rect2i(Rect2(bounds.get_center() - extent * 0.5, extent))

static func rule_presentation(scene: Node, beat: Dictionary) -> Dictionary:
	var shown: Dictionary = scene.call("_enemy_loss_feedback_presentation_between_states", beat["before"], beat["after"], "lightning")
	# The normal impact helper strips its effect after creating decals. Reuse
	# the production Lightning Strikes painter for both real rule-fuel tiles.
	shown["effect"] = {"kind": "lightning_strikes", "element": "lightning", "tiles": beat["tiles"], "source_kind": "battlefield_rule"}
	return shown
