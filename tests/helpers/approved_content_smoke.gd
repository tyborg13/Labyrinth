extends SceneTree

## One manifest, also mounted in a production-only PCK. No authoring fixtures.
const MANIFEST: String = "res://tests/approved_asset_pins.json"
const PROOF_SIZE := Vector2(1920, 1080)
const POSE_PHASE: float = 0.42
const PHASE_SAMPLE_OFFSET: float = 0.25
const REGISTRATION_TOLERANCE: float = 0.0001
var _errors: Array[String]

class ApprovedMaquetteRig extends "res://scripts/maquette_cutout_runtime/rig.gd":
	var approved_root: String
	func base_path() -> String:
		return approved_root

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--pack"):
		_pack(manifest, args[args.find("--pack") + 1])
	else:
		_check(not DirAccess.dir_exists_absolute("res://tools"), "No authoring tools in pack")
		_check(not DirAccess.dir_exists_absolute("res://experiments"), "No experiment assets in pack")
		_check_roster(manifest)
		_check_registration(manifest)
		_check_torches(manifest)
		for path: String in manifest["runtime_resources"]:
			_check(load("res://" + path) != null, "Resource loads: " + path)
	for message: String in _errors: printerr(message)
	print("APPROVED CONTENT SMOKE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _pack(manifest: Dictionary, output: String) -> void:
	var pack := PCKPacker.new()
	_check(pack.pck_start(output) == OK, "Open production pack")
	for directory: String in manifest["export_roots"]:
		_pack_directory(pack, "res://" + directory)
	for path: String in [MANIFEST, "res://tests/helpers/approved_content_smoke.gd"]:
		_check(pack.add_file(path, path) == OK, "Pack " + path)
	var config: String = "user://approved-content-project.godot"
	FileAccess.open(config, FileAccess.WRITE).store_string("config_version=5\n[application]\nconfig/name=\"Approved Content Smoke\"\n")
	_check(pack.add_file("res://project.godot", config) == OK, "Pack project")
	var cache: String = "user://approved-content-class-cache.cfg"
	FileAccess.open(cache, FileAccess.WRITE).store_string("list=Array[Dictionary]([])\n")
	_check(pack.add_file("res://.godot/global_script_class_cache.cfg", cache) == OK, "Pack isolated class cache")
	_check(pack.flush() == OK, "Close production pack")

func _pack_directory(pack: PCKPacker, directory: String) -> void:
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() in ["gd", "gdshader", "png", "svg", "webp", "jpg", "json", "ogg", "wav", "ttf", "tres", "tscn"]:
			var path: String = directory.path_join(file)
			_check(pack.add_file(path, path) == OK, "Pack " + path)
	for child: String in DirAccess.get_directories_at(directory):
		_pack_directory(pack, directory.path_join(child))

func _check_roster(manifest: Dictionary) -> void:
	for row: Dictionary in manifest["roster"]:
		var script: Script = load("res://" + str(row["rig_script"])) as Script
		_check(script != null and script.can_instantiate(), str(row["actor"]) + " rig script loads")
		if script == null or not script.can_instantiate(): continue
		for facing: String in row["facings"]:
			var rig: Node2D = ApprovedMaquetteRig.new() if row.has("base_directory") else script.new()
			if row.has("base_directory"): rig.set("approved_root", "res://" + str(row["base_directory"]))
			if row.has("character_id"): rig.set("character_id", row["character_id"])
			rig.set("facing", facing)
			root.add_child(rig)
			var label: String = str(row["actor"]) + "/" + facing
			var loaded: bool = rig.call("load_rig")
			_check(loaded and (rig.get("load_errors") as PackedStringArray).is_empty(), label + " loads all rig resources")
			var bones: Dictionary = rig.get("bones")
			_check(not bones.is_empty(), label + " skeleton is nonempty")
			if loaded:
				for clip: String in row.get("clips", [row["clip"]]):
					rig.call("apply_pose", clip, POSE_PHASE)
					for bone: Bone2D in bones.values():
						var transform: Transform2D = bone.transform
						_check(transform.x.is_finite() and transform.y.is_finite() and transform.origin.is_finite(), label + "/" + clip + " finite transform")
			rig.free()

func _check_registration(manifest: Dictionary) -> void:
	const Actor = preload("res://scripts/actor_presentation.gd")
	const Board = preload("res://scripts/combat_board_view.gd")
	var board := Board.new()
	board.size = PROOF_SIZE
	for actor: String in manifest["registration"]:
		var row: Dictionary = manifest["registration"][actor]
		for facing: String in ["front", "rear"]:
			var values: Array = row[facing]
			var anchor := Vector2(values[0], values[1])
			_check(Actor.floor_anchor(actor, facing).distance_to(anchor) < REGISTRATION_TOLERANCE, actor + " approved " + facing + " floor registration")
			var heights: Array = row["height"]
			_check(is_equal_approx(Actor.height_above_floor(actor, facing), float(heights[1 if facing == "rear" else 0])), actor + " painted-rest HUD height")
		# Neutral placement uses the production board path and approved front anchor.
		board.call("_ensure_unit_assets_for_type", actor)
		var unit: Dictionary = {"type":actor, "role":"enemy"}
		var center := PROOF_SIZE * 0.5
		var texture: Texture2D = board.call("_unit_hud_anchor_texture", unit)
		_check(texture != null, actor + " placement texture loads")
		var rect: Rect2 = board.call("_unit_draw_rect_for_texture", unit, center, texture)
		var front: Array = row["front"]
		_check((rect.position + Vector2(front[0], front[1]) * rect.size / Actor.SOURCE_SIZE).distance_to(center) < REGISTRATION_TOLERANCE, actor + " placement uses approved support")

	var enemies: Dictionary = preload("res://scripts/game_data.gd").enemies()
	for actor: String in manifest["enemy_art"]:
		for field: String in manifest["enemy_art"][actor]:
			_check(enemies[actor].get(field) == manifest["enemy_art"][actor][field], actor + " approved " + field)
	for actor: String in manifest["ground_contact"]:
		for facing: String in manifest["ground_contact"][actor]:
			var expected: Dictionary = manifest["ground_contact"][actor][facing]
			var actual: Dictionary = Actor.GROUND_CONTACT[actor][facing]
			for field: String in ["from", "to"]:
				_check(actual[field] == Vector2(expected[field][0], expected[field][1]), actor + " ground contact " + field)
			for field: String in ["half_width", "alpha"]:
				_check(is_equal_approx(float(actual[field]), float(expected[field])), actor + " ground contact " + field)
	board.free()

func _check_torches(manifest: Dictionary) -> void:
	const Board = preload("res://scripts/combat_board_view.gd")
	var board := Board.new()
	board.size = PROOF_SIZE
	board.set_process(false)
	board.set("combat_state", {"grid":[["pillar"]]})
	var timing: Dictionary = manifest["torch_animation"]
	_check(is_equal_approx(Board.COLUMN_TORCH_IDLE_FRAME_SECONDS, timing["frame_seconds"]), "Approved torch frame timing")
	for row: Dictionary in manifest["animated_sheets"]:
		board.set("_biome_id", row["biome"])
		board.call("_load_pillar_idle_assets")
		var side: String = row["side"]
		var frames: Array = board.call("_pillar_torch_idle_frames_for_side", side)
		_check(frames.size() == int(timing["frames"]), str(row["biome"]) + " animated torch sheet loads")
		var seen: Dictionary = {}
		for index: int in range(int(timing["frames"])):
			board.set("_idle_elapsed", (float(index) + PHASE_SAMPLE_OFFSET) * float(timing["frame_seconds"]))
			var actual: int = board.call("_pillar_torch_idle_frame_index", side)
			_check(actual == (index + (int(timing["right_offset"]) if side == "right" else 0)) % int(timing["frames"]), "B8 torch phase advances: " + str(row["biome"]) + "/" + side)
			if actual < frames.size():
				_check(board.call("_pillar_torch_texture", side) == frames[actual], "B8 production selects the advancing torch texture")
			seen[actual] = true
		_check(seen.size() == int(timing["frames"]), "B8 visits every torch phase")
	board.free()

func _check(ok: bool, message: String) -> void:
	if not ok: _errors.append(message)
