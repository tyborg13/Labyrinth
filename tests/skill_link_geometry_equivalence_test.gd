extends SceneTree
const View = preload("res://scripts/skill_tree_view.gd")
const Reference = preload("res://tests/fixtures/skill_link_bridge_reference.gd")
const Library = preload("res://scripts/skill_tree_library.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
var errors: Array[String]
func _initialize() -> void:
	Parallel.apply_from_environment()
	var current := View.new()
	var reference := Reference.new()
	var actual: Array[Dictionary]
	var expected: Array[Dictionary]
	for target: String in Library.visible_ids():
		for source: String in Library.prerequisites(target):
			var points: PackedVector2Array = current._link_points(source, target)
			var old_points: PackedVector2Array = reference._link_points(source, target)
			_check(points == old_points, "Route must preserve every original point: " + source + ">" + target)
			actual.append({"from_id":source,"to_id":target,"sort_key":source+">"+target,"points":points,"bridge_gaps":[]})
			expected.append({"from_id":source,"to_id":target,"sort_key":source+">"+target,"points":old_points,"bridge_gaps":[]})
	var records: Array[Dictionary] = current._annotate_connection_bridges(actual)
	var old_records: Array[Dictionary] = reference._annotate_connection_bridges(expected)
	_check(records == old_records and actual == expected, "Bounds rejection must preserve original bridge points, order and all gap records")
	var ids: Array[String] = Library.visible_ids()
	var rng := RandomNumberGenerator.new()
	rng.seed = 71819
	for trial: int in range(200):
		var source: String = ids[rng.randi_range(0, ids.size()-1)]
		var target: String = ids[rng.randi_range(0, ids.size()-1)]
		var a := Vector2(rng.randf_range(-300,1500),rng.randf_range(-100,1700))
		var b := Vector2(rng.randf_range(-300,1500),rng.randf_range(-100,1700))
		_check(current._best_route_channel_x(source,target,a,b) == reference._best_route_channel_x(source,target,a,b), "Lattice candidate search must preserve original channel for trial %d" % trial)
	current.free()
	reference.free()
	print("SKILL LINK GEOMETRY EQUIVALENCE RESULT: " + JSON.stringify({"errors":errors,"links":actual.size(),"route_cases":200}))
	quit(0 if errors.is_empty() else 1)
func _check(ok: bool,message: String) -> void:
	if not ok: errors.append(message)
