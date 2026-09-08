extends RefCounted

const Cutout = preload("res://scripts/protagonist_cutout/renderer.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

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
			expect.call(sample["clip"] == "idle" and sample["facing"] == expected_facings[index] and sample["mirrored"] == expected_mirrors[index], "Idle retains the most recent facing")
	renderer.call("present", {"clip": "attack", "phase": 0.8}, false)
	renderer.call("present", {"clip": "attack", "phase": 1.0}, false)
	expect.call(renderer.call("snapshot")["clip"] == "idle", "Completed melee resumes idle while floating damage text finishes")
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
	for facing: String in ["front", "rear"]:
		var rig: Node2D = renderer.get("rigs")[facing] as Node2D
		var layout: Dictionary = rig.get("layout")
		expect.call((rig.get("bones") as Dictionary).size() == 21, "%s retains all 21 accepted painted joints" % facing)
		for part: Dictionary in layout["parts"]:
			expect.call(str(part["file"]).begins_with("res://assets/units/protagonist_cutout/") and AssetLoader.load_texture(part["file"]) != null, "Every runtime part is a loadable production asset")
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
	expect.call(Cutout.WALK_CYCLE_SECONDS < 0.3, "The accepted 2/3-second gait is accelerated by more than twice")
	expect.call(Cutout.attack_pose_phase(0.42) >= 0.41, "Sword passes through the cut by the existing melee contact threshold")
	expect.call(Cutout.attack_pose_phase(0.36) <= 0.31, "The sword holds anticipation until the short aggressive cut")
	expect.call(is_equal_approx(Cutout.attack_pose_phase(1.0), 1.0), "Melee finishes in the accepted neutral pose")
	expect.call(Cutout.attack_trail_phase(0.30) < 0.0, "The slash trail must not precede the blade during preparation")
	expect.call(Cutout.attack_trail_phase(0.42) > 0.3 and Cutout.attack_trail_phase(0.42) < 0.6, "The bright slash coincides with melee contact")
	expect.call(Cutout.attack_trail_phase(1.0) < 0.0, "The slash clears before returning to idle")
	board.queue_free()
	await tree.process_frame
