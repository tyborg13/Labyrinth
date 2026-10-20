extends "res://tests/rr11/action_direction.gd"

## Study-only overrides live in Motion's process-local cache. No director or
## compiled motion file is written. --logic-only records real snapped poses.
const CASE_DIRECTORY := "res://experiments/cutouts/arc_thrall/rr11"
const STUDY_DIRECTORY := "res://experiments/cutouts/arc_thrall/rr27/tether_study"
const CANDIDATES := {"current": [206, 63], "A": [65, 153], "B": [47, 121], "C": [59, 46], "D": [19, 101]}
const PHASES := [0.0, 0.1, 0.2, 0.3, 0.35, 0.5]
const PROOF_SIZE := Vector2i(1920, 1080)
const NATIVE_SIZE := Vector2i(512, 512)
const PROOF_ORIGIN := Vector2(576, 0)
const PROOF_ZOOM := Vector2(3, 3)
var _canvas: SubViewport
var _proof: SubViewport
var _study_rows: Array[Dictionary]

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--write-uid"):
		# Generate only this new source's sidecar, without scanning/importing
		# the other engineers' units or the proof image output directories.
		var uid_path: String = get_script().resource_path + ".uid"
		if not FileAccess.file_exists(uid_path):
			var uid_file := FileAccess.open(uid_path, FileAccess.WRITE)
			uid_file.store_string(ResourceUID.id_to_text(ResourceUID.create_id()) + "\n")
			uid_file.close()
		print("RR27 STUDY SIDECAR: PASS")
		quit(0)
		return
	var logic_only: bool = args.has("--logic-only")
	var feedback: bool = args.has("--feedback-1")
	var candidates: Dictionary = CANDIDATES.duplicate(true)
	var phases: Array = PHASES.duplicate()
	var expected_hashes: Dictionary = {}
	var candidate_hashes: Dictionary = {}
	var study_directory: String = STUDY_DIRECTORY
	if feedback:
		study_directory = STUDY_DIRECTORY.path_join("feedback1")
		var request: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(study_directory.path_join("request.json")))
		candidates = request["candidates"]
		phases = request["phases"]
		expected_hashes = request["compiled_sha256"]
	if not logic_only and DisplayServer.get_name() == "headless":
		push_error("RR27 Tether native study requires the director's windowed renderer")
		quit(1)
		return
	var output: String = study_directory.path_join("cpu" if logic_only else "native")
	if args.has("--output"): output = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var path: String = CASE_DIRECTORY.path_join("compiled_motion.json")
	var approved: Dictionary = Motion.data_for({"motion_data": path}).duplicate(true)
	var input_bindings: Dictionary = preload("res://tests/rr10/bindings.gd").for_case(CASE_DIRECTORY)
	if not logic_only:
		root.size = PROOF_SIZE
		root.content_scale_size = PROOF_SIZE
		DisplayServer.window_set_size(PROOF_SIZE)
		_canvas = _viewport(NATIVE_SIZE)
		_proof = _viewport(PROOF_SIZE)
		var background := ColorRect.new()
		background.color = Color("1e1e24")
		background.size = Vector2(PROOF_SIZE)
		_proof.add_child(background)
	for candidate: String in candidates:
		var data: Dictionary = approved.duplicate(true)
		if feedback:
			var candidate_path: String = study_directory.path_join(candidate + "_compiled.json")
			candidate_hashes[candidate] = FileAccess.get_sha256(candidate_path)
			if candidate_hashes[candidate] != expected_hashes[candidate]: errors.append("Changed candidate motion: " + candidate)
			data = JSON.parse_string(FileAccess.get_file_as_string(candidate_path))
		else:
			for track: Dictionary in data["view_tracks"]["rear"]["tether"]:
				if track["source"] not in ["tube_tip.forward_px", "tube_tip.lift_px"]: continue
				var value: float = float(candidates[candidate][0 if track["channel"] == "forward_px" else 1])
				for key: Dictionary in track["keys"]:
					if float(key["value"]) != 0.0: key["value"] = value
		Motion._cache[path] = data
		var rig := Rig.new()
		rig.case_directory = CASE_DIRECTORY
		rig.facing = "rear"
		rig.position = SOURCE_ORIGIN
		(root if logic_only else _canvas).add_child(rig)
		if not rig.load_rig(): errors.append(str(rig.load_errors))
		for index: int in range(phases.size()):
			var phase: float = phases[index]
			rig.apply_pose("tether", phase)
			var row: Dictionary = record(rig, "rear", "tether", phase, index, "presented")
			row["candidate"] = candidate
			row["forward_px"] = candidates[candidate][0]
			row["lift_px"] = candidates[candidate][1]
			if not logic_only:
				await process_frame
				await RenderingServer.frame_post_draw
				var image: Image = _canvas.get_texture().get_image()
				var file: String = "%s_%02d.png" % [candidate, index]
				if image.save_png(output.path_join(file)) != OK: errors.append("Cannot save " + file)
				row["file"] = file
				row["sha256"] = FileAccess.get_sha256(output.path_join(file))
				# Real isolated surfaces support an objective silhouette-overlap
				# measurement without inferring it from bones or a flattened image.
				for name: String in ["torso", "upper_near", "tube"]:
					var target: Node2D = _part(rig, name)
					for part: Dictionary in rig.layout["parts"]: _part(rig, str(part["name"])).visible = part["name"] == name
					await process_frame
					await RenderingServer.frame_post_draw
					var isolated_file: String = "%s_%02d_%s.png" % [candidate, index, name]
					if target == null or _canvas.get_texture().get_image().save_png(output.path_join(isolated_file)) != OK:
						errors.append("Cannot save " + isolated_file)
					row[name + "_file"] = isolated_file
					row[name + "_sha256"] = FileAccess.get_sha256(output.path_join(isolated_file))
				for part: Dictionary in rig.layout["parts"]: _part(rig, str(part["name"])).visible = true
				if phase == 0.5:
					var preview := Sprite2D.new()
					preview.texture = ImageTexture.create_from_image(image)
					preview.centered = false
					preview.scale = PROOF_ZOOM
					# The full source canvas is cropped only by this proof camera;
					# the native 512px image and final 3x sheets remain complete.
					preview.position = PROOF_ORIGIN - Vector2(0, SOURCE_ORIGIN.y * PROOF_ZOOM.y)
					_proof.add_child(preview)
					await process_frame
					await RenderingServer.frame_post_draw
					if _proof.get_texture().get_image().save_png(output.path_join(candidate + "_proof.png")) != OK:
						errors.append("Cannot save 1920x1080 proof")
					preview.free()
			_study_rows.append(row)
		rig.free()
	Motion._cache[path] = approved
	if preload("res://tests/rr10/bindings.gd").for_case(CASE_DIRECTORY) != input_bindings:
		errors.append("Study modified approved inputs")
	write_report(output.path_join("samples.json"), {"ok": errors.is_empty(), "native_pixels": not logic_only,
		"inputs": input_bindings, "phases": phases, "candidates": candidates, "samples": _study_rows,
		"feedback_1": feedback,
		"candidate_compiled_sha256": candidate_hashes,
		"errors": errors, "ui_scale": 1.0, "proof_size": [1920, 1080]})
	print("RR27 TETHER STUDY %s: %s (%d poses; in-memory keys only)" % ["LOGIC" if logic_only else "NATIVE", "PASS" if errors.is_empty() else "FAIL", _study_rows.size()])
	quit(0 if errors.is_empty() else 1)

func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	return viewport

func _part(rig: Node2D, name: String) -> Node2D:
	var node: Node2D = rig.get_node_or_null(NodePath(name))
	if node != null: return node
	for part: Dictionary in rig.layout["parts"]:
		if part["name"] == name: return rig.bones[part["bone"]].get_node(NodePath(name))
	return null
