extends SceneTree

const Runtime = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const EPSILON: float = 0.0001
var errors: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)

func read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fixture: Dictionary = read(args[args.find("--fixture") + 1])
	for view: String in ["front", "rear"]:
		var layout: Dictionary = read("res://experiments/cutouts/arc_thrall/rr11/layouts/" + view + ".json")
		for expected: Dictionary in fixture["channels"][view]:
			var values: Dictionary = Runtime.channels(fixture["thrall"], expected["clip"], expected["phase"], layout, view)
			for channel: String in ["forward_px", "lift_px"]:
				check(absf(float(values["tube_tip"][channel]) - float(expected[channel])) < EPSILON,
					view + "/" + str(expected["clip"]) + ": " + channel)
		layout = read("res://experiments/cutouts/hoarfrost_seer/rr10/layouts/" + view + ".json")
		var world: Dictionary = Runtime.world_transforms(fixture["release"], "death", fixture["release_phase"], layout, view)
		var item: Transform2D = world["staff"]
		var hand: Transform2D = world["hand_far"]
		var attached: bool = item.origin.distance_to(hand.origin) < EPSILON
		check(attached == (view == "front"), view + ": per-view release isolation")
	for error: String in errors: push_error(error)
	print("RR15 VIEW KEY RUNTIME: %s (%d checks)" % ["PASS" if errors.is_empty() else "FAIL", checks])
	quit(0 if errors.is_empty() else 1)
