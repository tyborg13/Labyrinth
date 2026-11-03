extends SceneTree

const Proof = preload("res://spec/peer_benchmark/roar-01/proof_data.gd")
const Arrival = preload("res://scripts/dragon_arrival.gd")
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Contact sheets require the director's window server; use pose_check.gd for headless proof")
		quit(1)
		return
	root.size = Proof.SCREEN
	root.content_scale_size = Proof.SCREEN
	var output: String = Proof.value("output-dir", Proof.OUTPUT).path_join("contact_sheets")
	DirAccess.make_dir_recursive_absolute(output)
	var records: Array[Dictionary]
	for id: String in Proof.IDS:
		var actor: Node = Proof.renderer(id)
		root.add_child(actor)
		actor.set_process(false)
		var sheet: Image = Image.create(Proof.CANVAS.x * (Proof.PHASES.size() + 5), Proof.CANVAS.y * 2, false, Image.FORMAT_RGBA8)
		var folder: String = output.path_join(id)
		DirAccess.make_dir_recursive_absolute(folder)
		for row: int in range(2):
			var state: Dictionary = Proof.state(id, Vector2i(1, 3) if row == 0 else Vector2i(3, 1))
			for col: int in range(Proof.PHASES.size()):
				var phase: float = Proof.PHASES[col]
				actor.call("present", Arrival.opening_motion(state, state["enemies"][0], phase), false)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var frame: Image = (actor.call("texture") as Texture2D).get_image()
				_check(frame.get_size() == Proof.CANVAS, id + " native viewport size")
				var bounds: Rect2i = frame.get_used_rect()
				_check(bounds.has_area() and Rect2i(Vector2i.ZERO, Proof.CANVAS).encloses(bounds.grow(2)), id + " full pose inside fixed canvas")
				var name: String = "%s_%02d_%s.png" % ["mirrored_front" if row == 1 else "front", col, str(phase).replace(".", "p")]
				_check(frame.save_png(folder.path_join(name)) == OK, "Save " + name)
				sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, Proof.CANVAS), Vector2i(col * Proof.CANVAS.x, row * Proof.CANVAS.y))
				records.append({"dragon": id, "phase": phase, "mirrored": row == 1, "frame": folder.path_join(name), "snapshot": actor.call("snapshot")})
			var baseline_index: int = 0
			for baseline: Array in Proof.BASELINES[id]:
				var rig: Node = actor.get("rigs")["front"]
				rig.call("apply_pose", baseline[0], float(baseline[1]))
				(actor.get("viewport") as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var frame: Image = (actor.call("texture") as Texture2D).get_image()
				var name: String = "%s_baseline_%s_%s.png" % ["mirrored_front" if row == 1 else "front", baseline[0], str(baseline[1]).replace(".", "p")]
				_check(frame.save_png(folder.path_join(name)) == OK, "Save approved clip baseline " + id)
				sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, Proof.CANVAS), Vector2i((Proof.PHASES.size() + baseline_index) * Proof.CANVAS.x, row * Proof.CANVAS.y))
				records.append({"dragon": id, "role": "approved_baseline", "clip": baseline[0], "phase": baseline[1], "mirrored": row == 1, "frame": folder.path_join(name)})
				baseline_index += 1
		_check(sheet.save_png(output.path_join(id + "_roar_contact_sheet.png")) == OK, "Save " + id + " sheet")
		actor.free()
	var manifest := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"source_art": OS.get_environment("LABYRINTH_CEL_LOOK"), "viewport": [512, 512], "screen": [1920, 1080], "ui_scale": 1.0, "columns": Proof.PHASES + ["approved baseline 1", "approved baseline 2", "approved baseline 3 if applicable", "approved baseline 4 if applicable", "approved baseline 5 if applicable"], "baselines": Proof.BASELINES, "rows": ["front", "mirrored_front"], "frames": records, "errors": failures}, "\t"))
	manifest.close()
	for failure: String in failures: push_error(failure)
	print(output)
	print("ROAR CONTACT SHEETS: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
