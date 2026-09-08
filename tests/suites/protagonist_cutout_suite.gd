extends RefCounted

const Cutout = preload("res://scripts/protagonist_cutout/renderer.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	tree.root.add_child(board)
	await tree.process_frame
	var renderer: Node = board.get("_protagonist_renderer") as Node
	expect.call(renderer != null, "Gameplay board owns a live cutout renderer")
	if renderer == null:
		board.queue_free()
		return
	var initial: Dictionary = renderer.call("snapshot")
	var texture: Texture2D = renderer.call("texture")
	var expected_facings: Array[String] = ["front", "front", "rear", "rear"]
	var expected_mirrors: Array[bool] = [false, true, false, true]
	var directions: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for index: int in range(directions.size()):
		for clip: String in ["walk", "attack"]:
			renderer.call("present", {"clip": clip, "phase": 0.42, "direction": directions[index]}, false)
			var sample: Dictionary = renderer.call("snapshot")
			expect.call(sample["facing"] == expected_facings[index] and sample["mirrored"] == expected_mirrors[index], "Cutout faces the actual board travel/attack direction %s" % directions[index])
			expect.call(sample["rig_count"] == 2 and sample["texture_id"] == initial["texture_id"], "Facing/action switches retain two loaded rigs and one texture RID")
			renderer.call("present", {}, false)
			sample = renderer.call("snapshot")
			expect.call(sample["clip"] == "idle" and sample["facing"] == "front" and not sample["mirrored"], "Idle returns to the unmirrored front default after every direction")
	renderer.call("present", {"clip": "attack", "phase": 0.8}, false)
	renderer.call("present", {"clip": "attack", "phase": 1.0}, false)
	expect.call(renderer.call("snapshot")["clip"] == "idle" and renderer.call("snapshot")["facing"] == "front" and not renderer.call("snapshot")["mirrored"], "Completed melee returns to front idle while floating damage text finishes")
	var phase_before: float = float(renderer.call("snapshot")["phase"])
	renderer.call("_process", 0.1)
	expect.call(float(renderer.call("snapshot")["phase"]) > phase_before, "Idle advances on its own between game-state submissions")
	renderer.call("present", {"clip": "walk", "direction": Vector2i(1, 0), "phase": 0.3}, true)
	renderer.call("_process", 0.7)
	expect.call(renderer.call("snapshot")["clip"] == "rest" and is_zero_approx(float(renderer.call("snapshot")["phase"])), "Reduced motion retains new paint in a stable pose with the requested facing")
	var player: Dictionary = {"type": "player", "key": "player", "role": "player", "pos": Vector2i(2, 2), "hp": 24}
	board.call("_ensure_unit_assets_for_type", "player")
	var idle_frames: Array = board.call("_unit_idle_frames", player)
	var death_frames: Array = board.call("_unit_death_frames", player)
	expect.call(idle_frames.is_empty() and death_frames.is_empty(), "The production player does not load legacy idle or death atlases")
	for state: String in ["idle", "walk", "attack", "block", "damage", "death", "blink", "spell"]:
		var unit: Dictionary = player.duplicate(true)
		if state == "death":
			unit["hp"] = 0
			unit["death_animation"] = true
			unit["death_progress"] = 0.4
		expect.call(board.call("_texture_for_unit", unit) == texture, "%s keeps the cutout texture instead of restoring legacy art" % state)
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", player)
	expect.call(str(anchor.get_meta("asset_source_path", "")) == Cutout.REST_PATH, "HUD/shadow source is the accepted cutout rest paint")
	var frame: Rect2 = board.call("_unit_draw_rect_for_center", player, Vector2.ZERO)
	var drawing: Rect2 = board.call("_unit_texture_draw_rect", player, Vector2.ZERO)
	expect.call((drawing.position + drawing.size * Vector2(128, 128) / 512.0).is_equal_approx(frame.position), "Padded animation canvas preserves exact source registration")
	expect.call((drawing.size * 255.0 / 512.0).is_equal_approx(frame.size), "Padding does not shrink the character or inflate HUD/obstruction bounds")
	for progress: float in [0.0, 0.5, 0.8, 1.0]:
		var dying: Dictionary = player.duplicate(true)
		dying.merge({"hp": 0, "death_animation": true, "death_progress": progress}, true)
		var death_drawing: Rect2 = board.call("_unit_texture_draw_rect", dying, Vector2.ZERO)
		var source_floor: Vector2 = death_drawing.position + death_drawing.size * (Cutout.SOURCE_OFFSET + Cutout.SOURCE_SIZE * Vector2(0.5, 1.0)) / Vector2(Cutout.CANVAS_SIZE)
		expect.call(source_floor.distance_to(Vector2(frame.get_center().x, frame.end.y)) < 0.001, "Defeat keeps the source body floor on its tile instead of anchoring to transparent viewport padding")
	for ghost_scale: float in [0.55, 0.85, 1.2]:
		var ghost_drawing: Rect2 = board.call("_unit_texture_draw_rect", player, Vector2.ZERO, ghost_scale)
		var source_floor: Vector2 = ghost_drawing.position + ghost_drawing.size * (Cutout.SOURCE_OFFSET + Cutout.SOURCE_SIZE * Vector2(0.5, 1.0)) / Vector2(Cutout.CANVAS_SIZE)
		expect.call(source_floor.distance_to(Vector2(frame.get_center().x, frame.end.y)) < 0.001, "Blink echo scaling keeps the body floor anchored independently of transparent viewport padding")
	for facing: String in ["front", "rear"]:
		var rig: Node2D = renderer.get("rigs")[facing] as Node2D
		var layout: Dictionary = rig.get("layout")
		expect.call((rig.get("bones") as Dictionary).size() == 21, "%s retains all 21 accepted painted joints" % facing)
		for part: Dictionary in layout["parts"]:
			expect.call(str(part["file"]).begins_with("res://assets/units/protagonist_cutout/") and AssetLoader.load_texture(part["file"]) != null, "Every runtime part is a loadable production asset")
		var bob_pose: Dictionary = Motion.sample_pose("idle", 0.40, layout, facing)
		for bone: String in ["torso", "head", "hand_l"]:
			var bob_world: Transform2D = Motion._world_transform(bob_pose, layout, bone)
			var anchor_values: Array = layout["joints"][bone]["position"]
			expect.call(bob_world.origin.is_equal_approx(Vector2(anchor_values[0], anchor_values[1]) + Vector2(0, 2)), "Idle moves torso, head and free hand together in a clear two-pixel bob")
		for bone: String in ["thigh_r", "shin_r", "foot_r", "thigh_l", "shin_l", "foot_l"]:
			var bob_world: Transform2D = Motion._world_transform(bob_pose, layout, bone)
			expect.call(bob_world.x.is_equal_approx(Vector2.RIGHT) and bob_world.y.is_equal_approx(Vector2.DOWN), "Idle leaves leg paint stable rather than shimmering through IK")
		for sample_index: int in range(49):
			var walk_t: float = float(sample_index) / 48.0
			var walk_pose: Dictionary = Motion.sample_pose("walk", walk_t, layout, facing)
			for foot: String in ["foot_r", "foot_l"]:
				var world: Transform2D = Motion._world_transform(walk_pose, layout, foot)
				var step: Dictionary = Motion.walk_foot_state(walk_t, foot, layout, facing)
				expect.call(world.origin.distance_to(step["target"]) < 0.2, "Long-stride leg reaches its authored foot target without pulling the boot apart")
				if bool(step["contact"]) and float(step["cycle_phase"]) < 0.58:
					var later: Dictionary = Motion.walk_foot_state(walk_t + 0.01, foot, layout, facing)
					var travel: Vector2 = Motion.walk_cycle_info(layout, facing)["travel_per_cycle"]
					expect.call((later["ground"] + travel * 0.01).distance_to(step["ground"]) < 0.001, "Planted support foot exactly cancels board travel through the longer stride")
		var idle_end: Dictionary = Motion.sample_pose("idle", 0.999999, layout, facing)
		for bone: String in ["head", "cape_mid", "cape_tip"]:
			expect.call(absf(float(idle_end[bone]["rotation"])) < 0.0001, "Idle cloth/head return continuously to neutral at the loop seam")
		for sample_index: int in range(13):
			var t: float = float(sample_index) / 12.0
			for clip: String in ["idle", "attack"]:
				var pose: Dictionary = Motion.sample_pose(clip, t, layout, facing)
				for foot: String in ["foot_r", "foot_l"]:
					var world: Transform2D = Motion._world_transform(pose, layout, foot)
					var painted: Array = layout["joints"][foot]["position"]
					expect.call(world.origin.distance_to(Vector2(painted[0], painted[1])) < 0.15, "%s %s keeps %s planted at phase %.2f" % [facing, clip, foot, t])
	expect.call(Cutout.WALK_CYCLE_SECONDS > 0.24 and Cutout.walk_cycle_distance() >= 75.0, "Longer strides lower the old shuffle cadence")
	expect.call(Cutout.walk_cycle_distance() / Cutout.WALK_CYCLE_SECONDS > 250.0, "Longer strides cover ground faster despite the lower step rate")
	expect.call(Cutout.attack_pose_phase(0.42) >= 0.41, "Sword passes through the cut by the existing melee contact threshold")
	expect.call(Cutout.attack_pose_phase(0.36) <= 0.31, "The sword holds anticipation until the short aggressive cut")
	expect.call(is_equal_approx(Cutout.attack_pose_phase(1.0), 1.0), "Melee finishes in the accepted neutral pose")
	expect.call(Cutout.attack_trail_phase(0.30) < 0.0, "The slash trail must not precede the blade during preparation")
	expect.call(Cutout.attack_trail_phase(0.42) > 0.3 and Cutout.attack_trail_phase(0.42) < 0.6, "The bright slash coincides with melee contact")
	expect.call(Cutout.attack_trail_phase(1.0) < 0.0, "The slash clears before returning to idle")
	var scene: Node = load("res://scripts/run_scene.gd").new()
	for card_id: String in ["whirlwind_slash", "grave_cleave", "tombsplitter", "sweeping_haft"]:
		var action: Dictionary = GameData.card_def(card_id)["actions"][0]
		expect.call(AttackFxLibrary.protagonist_uses_melee_motion(action), card_id + " triggers the cutout swing through its self-centered AoE action")
	for action: Dictionary in [{"type": "ranged", "range": 3}, {"type": "aoe", "range": 4}, {"type": "block"}]:
		expect.call(not AttackFxLibrary.protagonist_uses_melee_motion(action), "Ranged, targeted AoE and defensive actions retain idle")
	var sweep: Dictionary = {"kind": "aoe", "action_type": "aoe", "range": 0, "protagonist_melee": true, "from": Vector2i(3, 3), "to": Vector2i(3, 3)}
	var sweep_motion: Dictionary = scene.call("_protagonist_attack_motion", sweep, 0.38)
	expect.call(is_equal_approx(float(sweep_motion["phase"]), 0.42) and sweep_motion["direction"] == Vector2i.ZERO, "Area melee contacts at its original 0.38 boundary and retains its current facing")
	expect.call(AttackFxLibrary.animation_frame_count(sweep, 6, false) == 6 and is_equal_approx(AttackFxLibrary.animation_frame_seconds(sweep, 0.04, false), 0.04), "Area melee preserves the existing 0.24-second action clock")
	expect.call(float(scene.call("_attack_feedback_elapsed_seconds", sweep, 0.37, 6, 0.04, false)) < 0.0 and is_zero_approx(float(scene.call("_attack_feedback_elapsed_seconds", sweep, 0.38, 6, 0.04, false))), "Area damage becomes visible once at the unchanged contact boundary")
	scene.free()
	board.queue_free()
	await tree.process_frame
