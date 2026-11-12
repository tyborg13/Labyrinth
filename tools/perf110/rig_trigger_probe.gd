extends SceneTree
const Rig = preload("res://scripts/crawler_cutout/rig.gd")
const SETTLE_FRAMES: int = 3
const FIXTURE_PHASES := [0.0, 0.0, 0.1, 0.2, 0.2]
var _draws: int = 0
var _setups: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var rig := Rig.new()
	root.add_child(rig)
	rig.load_rig()
	rig.skeleton.bone_setup_changed.connect(func() -> void: _setups += 1)
	for node: Node in rig.get_children():
		if node is Polygon2D: node.draw.connect(func() -> void: _draws += 1)
	for phase: float in FIXTURE_PHASES:
		_draws = 0
		_setups = 0
		rig.apply_pose("idle", phase)
		for frame: int in range(SETTLE_FRAMES): await process_frame
		print("PERF110 RIG TRIGGER: phase=%s draws=%d bone_setups=%d" % [phase, _draws, _setups])
	rig.free()
	quit()
