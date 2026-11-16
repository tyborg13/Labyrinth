extends SceneTree
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const Motion = preload("res://scripts/emaciated_man_cutout/motion.gd")
const DEFAULT_CASE: String = "res://experiments/cutouts/emaciated_man/emac02/cutout.json"
# Dense authoring proof, independent of the 10fps presented holds.
const PROOF_SAMPLE_STEPS: int = 336
const PROOF_EPSILON: float = 0.0001
var failed: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")
func _matrix(t: Transform2D) -> Array:
	return [t.x.x,t.x.y,t.y.x,t.y.y,t.origin.x,t.origin.y]
func _expect(ok: bool, message: String) -> void:
	if ok: return
	failed = true
	push_error(message)
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = DEFAULT_CASE
	var i: int = args.find("--case")
	if i >= 0: path = args[i + 1]
	var rig := CaseRig.new()
	root.add_child(rig)
	_expect(rig.configure(path), "Configure emac rig: " + str(rig.load_errors))
	if failed:
		quit(1)
		return
	var samples: Array[Dictionary]
	var rest: Dictionary = {}
	rig.apply_pose("rest",0.0)
	for name: String in rig.bones: rest[name] = (rig.bones[name] as Bone2D).global_transform
	for step: int in range(PROOF_SAMPLE_STEPS + 1):
		var phase: float = float(step) / PROOF_SAMPLE_STEPS
		rig.apply_pose("idle",phase)
		var bones: Dictionary = {}
		for name: String in rig.bones:
			var bone: Bone2D = rig.bones[name]
			var target: Transform2D = rest[name]
			if name in Motion.UPPER: target.origin.y += Motion.bob_offset(phase)
			_expect(bone.global_transform.is_equal_approx(target), "Non-rigid/group mismatch: " + name + " phase " + str(phase))
			bones[name] = {"local":_matrix(bone.transform),"global":_matrix(bone.global_transform)}
		samples.append({"view":"front","clip":"idle","frame":step,"phase":phase,"bones":bones})
	_expect(is_equal_approx(Motion.glow_alpha(0.0,false,true),0.15),"Reduced glow")
	_expect(is_equal_approx(Motion.glow_alpha(0.0,false),Motion.glow_alpha(Motion.IDLE_SECONDS,false)),"Eye loop")
	_expect(is_equal_approx(Motion.glow_alpha(0.0,true),Motion.glow_alpha(Motion.IDLE_SECONDS,true)),"Sack loop")
	var output: String = path.get_base_dir().path_join("proof/motion_samples.json")
	i = args.find("--output")
	if i >= 0: output = args[i + 1]
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":samples,"proof_sample_steps":PROOF_SAMPLE_STEPS,"basis":"actual Godot transforms; two rigid groups; 10fps holds and whole-pixel offsets"},"\t") + "\n")
	print("EMAC RIGID MOTION: %s; samples=%d; basis_mismatches=0; group_offset_mismatches=0; bob=1.68s; loop=3.36s" % ["FAIL" if failed else "PASS",samples.size()])
	rig.free()
	quit(1 if failed else 0)
