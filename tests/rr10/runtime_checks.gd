extends SceneTree

## Production renderer, phase seeds, source-pixel units and existing portrait API.
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const CASE: String = "res://experiments/cutouts/hoarfrost_seer/rr10"
const PROOF_PHASE: float = 0.3
const PROOF_SEED: float = 0.37
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _run() -> void:
	var renderer := preload("res://assets/units/hoarfrost_seer_cutout/renderer.gd").new()
	renderer.seed_idle_phase(PROOF_SEED)
	root.add_child(renderer)
	check(is_equal_approx(float(renderer.snapshot()["phase"]),PROOF_SEED),"idle phase seed lost")
	check(renderer.rigs.size()==2,"production must load both approved views")
	renderer.present({"clip":"ward","phase":PROOF_PHASE},false)
	check(renderer.snapshot()["clip"]=="ward","candidate action did not route")
	var atlas: AtlasTexture = preload("res://scripts/maquette_cutout_runtime/portrait.gd").source_texture(renderer,"hoarfrost_seer")
	check(atlas.atlas==renderer.texture(),"portrait does not use the live candidate texture")
	check(atlas.region==Rect2(128,128,255,255),"portrait source registration changed")
	var rig: Node2D = renderer.rigs["front"]
	var polygons: int = 0
	for child: Node in rig.get_children():
		if child is Polygon2D and not str(child.name).begins_with("hidden_"): polygons += 1
	check(polygons==3,"three real joint_meshes were not constructed")
	var other := Rig.new()
	other.case_directory = CASE
	root.add_child(other)
	check(other.load_rig(),"source rig failed to load")
	var baseline: Dictionary = Motion.sample_pose("ward",PROOF_PHASE,rig.layout,"front")
	for scale_value: float in [0.5,1.0,2.0]:
		other.layout["screen_pixel_scale"]=scale_value
		other.apply_authored_pose("ward",PROOF_PHASE)
		var sampled: Dictionary = Motion.sample_pose("ward",PROOF_PHASE,other.layout,"front")
		check(sampled==baseline,"source-pixel action was divided by screen scale")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--bindings-output"):
		var file := FileAccess.open(args[args.find("--bindings-output")+1],FileAccess.WRITE)
		file.store_string(JSON.stringify(preload("bindings.gd").for_case(CASE)))
	for failure: String in failures: push_error(failure)
	print("RR10 RUNTIME: %s (%d checks; headless logic only)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	other.free()
	renderer.free()
	quit(0 if failures.is_empty() else 1)
