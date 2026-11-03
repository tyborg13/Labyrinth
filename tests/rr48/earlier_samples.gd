extends SceneTree

const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rows: Array[Dictionary]
	var rigs: int = 0
	for type: String in Presentation.CREATURES:
		if type == "ashen_reaver": continue # This comparison owns the earlier roster only.
		var data: Dictionary = preload("res://scripts/maquette_cutout_runtime/action.gd").data_for(type)
		if data.get("rig", "") != "humanoid_v2": continue
		rigs += 1
		for view: String in data["view_tracks"]:
			var renderer: Node = Presentation.renderer_script(type).new()
			var rig: Node2D = renderer._new_rig()
			renderer.free()
			rig.facing = view
			root.add_child(rig)
			assert(rig.load_rig(), str(rig.load_errors))
			rig.layout["step_distance_px"] = 96.0
			rig.layout["screen_pixel_scale"] = 2.0
			for clip: String in data["clips"]:
				var count: int = roundi(float(data["clips"][clip]["seconds"]) * 60.0)
				for frame: int in range(count):
					rig.apply_pose(clip, float(frame) / maxi(1, count - 1))
					var bones: Dictionary = {}
					for name: String in rig.bones:
						var t: Transform2D = rig.bones[name].transform
						bones[name] = [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]
					rows.append({"type":type,"view":view,"clip":clip,"frame":frame,"bones":bones})
			rig.free()
	FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(JSON.stringify(rows))
	print("RR48 EARLIER POSE SAMPLES: PASS (%d rigs; %d frames)" % [rigs, rows.size()])
	quit()
