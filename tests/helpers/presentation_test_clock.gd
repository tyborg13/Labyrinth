extends Node
## Test-only clock seams. Production source stays untouched; only clock reads
## are replaced in an in-memory script, including scripts supplied by mutations.
const STEP_SECONDS: float = 1.0 / 60.0
const FIXTURE_START_USEC: int = 1000000
const FEEDBACK_START_USEC: int = 1000000000
static var now_usec: int = FIXTURE_START_USEC
var _fractional_usec: float = 0.0

class GlobalScope:
	extends RefCounted
	# run_scoped owns this snapshot outside the body coroutine. Destruction is
	# only a synchronous fallback: awaited callers resume before locals release.
	var clock_usec: int
	var time_scale: float
	var tree: SceneTree
	var paused: bool
	var scripts: Array[Dictionary]
	var audio_buses: Array[Dictionary]
	var router: Node
	var modality: String
	var input_state: Dictionary
	var root_state: Dictionary
	var root_children: Array[Node]
	var storage: Dictionary
	var restored: bool = false
	func restore() -> void:
		_notification(NOTIFICATION_PREDELETE)
	func _notification(what: int) -> void:
		# PREDELETE cannot dispatch another method on its zero-refcount self.
		if what != NOTIFICATION_PREDELETE or restored: return
		restored = true
		# Teardown must precede restoration: a surviving pacing fixture would
		# otherwise overwrite the restored engine scale on its next frame.
		if is_instance_valid(tree):
			for child: Node in tree.root.get_children():
				if not root_children.has(child): child.free()
			for key: String in root_state: tree.root.set(key, root_state[key])
		if is_instance_valid(router):
			router.call("set_modality", modality)
			for key: String in input_state: router.set(key, input_state[key])
		for snapshot: Dictionary in scripts:
			var node: Node = snapshot["node"]
			if not is_instance_valid(node): continue
			for child: Node in node.get_children():
				if not snapshot["children"].has(child): child.free()
			node.set_script(snapshot["script"])
			for key: String in snapshot["properties"]: node.set(key, snapshot["properties"][key])
		for bus: Dictionary in audio_buses:
			var index: int = AudioServer.get_bus_index(bus["name"])
			if index < 0: continue
			AudioServer.set_bus_volume_db(index, bus["volume_db"])
			AudioServer.set_bus_mute(index, bus["mute"])
		preload("res://tests/helpers/presentation_test_clock.gd").now_usec = clock_usec
		var progression = preload("res://scripts/progression_store.gd")
		progression.set_storage_path(storage["profile"])
		progression.set_run_storage_path(storage["run"])
		progression._session_umbra_depth = storage["depth"]
		progression._session_depth_save_failed = storage["depth_failed"]
		var settings = preload("res://scripts/settings_store.gd")
		settings.set_storage_path(storage["settings"])
		settings._applied_reduced_motion = storage["reduced_motion"]
		preload("res://scripts/analytics_store.gd").set_storage_dir(storage["analytics"])
		Engine.time_scale = time_scale
		if is_instance_valid(tree): tree.paused = paused
	func preserve_script(node: Node) -> void:
		var properties: Dictionary = {}
		for property: Dictionary in node.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				properties[property["name"]] = node.get(property["name"])
		scripts.append({"node": node, "script": node.get_script(), "properties": properties.duplicate(true), "children": node.get_children()})
	func preserve_feedback_state(feedback: Node, input_router: Node) -> void:
		preserve_script(feedback)
		assert(router == input_router, "Feedback uses the scoped input router")

static func preserve_globals(tree: SceneTree = null) -> GlobalScope:
	var scope := GlobalScope.new()
	scope.clock_usec = now_usec
	scope.time_scale = Engine.time_scale
	scope.tree = tree
	if tree != null:
		scope.paused = tree.paused
		scope.root_children.assign(tree.root.get_children())
		scope.root_state = {"size": tree.root.size, "gui_embed_subwindows": tree.root.gui_embed_subwindows, "content_scale_factor": tree.root.content_scale_factor}
		scope.router = tree.root.get_node_or_null("InputRouter")
		if scope.router != null:
			scope.modality = str(scope.router.call("modality"))
			for key: String in ["_modality", "_controller_family", "_active_device_id", "_forced_family_for_test", "_forced_modality_for_test", "_last_controller_activity_msec"]:
				scope.input_state[key] = scope.router.get(key)
	for index: int in range(AudioServer.bus_count):
		scope.audio_buses.append({"name": AudioServer.get_bus_name(index), "volume_db": AudioServer.get_bus_volume_db(index), "mute": AudioServer.is_bus_mute(index)})
	var progression = preload("res://scripts/progression_store.gd")
	var settings = preload("res://scripts/settings_store.gd")
	scope.storage = {"profile": progression._storage_path, "run": progression._run_storage_path, "depth": progression._session_umbra_depth, "depth_failed": progression._session_depth_save_failed, "settings": settings.storage_path(), "reduced_motion": settings._applied_reduced_motion, "analytics": preload("res://scripts/analytics_store.gd").storage_dir()}
	return scope

static func run_scoped(tree: SceneTree, body: Callable) -> void:
	# A body may return early (including after a failed expectation). Keep its
	# snapshot here so cleanup finishes before forwarding completion, while the
	# body's coroutine can still retain its own locals and arguments.
	var scope := preserve_globals(tree)
	await body.call(scope)
	scope.restore()

static func clocked_script(original: Script, existing_instance: bool = false) -> GDScript:
	var script := GDScript.new()
	var source: String = source_for(original)
	var lines := source.split("\n")
	for index: int in range(lines.size()):
		if lines[index].begins_with("class_name "): lines[index] = ""
	source = "\n".join(lines)
	if existing_instance: source = source.replace("func _init(", "func _test_original_init(")
	source = source.replace("HitStop.new()", 'preload("res://tests/helpers/presentation_test_clock.gd").clocked_script(HitStop).new()')
	for suffix: String in ["()", "(false)"]:
		source = source.replace('preload("res://scripts/presentation_clock.gd").ticks_usec' + suffix, 'preload("res://tests/helpers/presentation_test_clock.gd").now_usec')
		source = source.replace('preload("res://scripts/presentation_clock.gd").ticks_msec' + suffix, '(preload("res://tests/helpers/presentation_test_clock.gd").now_usec / 1000)')
	source = source.replace("Time.get_ticks_usec()", 'preload("res://tests/helpers/presentation_test_clock.gd").now_usec')
	source = source.replace("Time.get_ticks_msec()", '(preload("res://tests/helpers/presentation_test_clock.gd").now_usec / 1000)')
	script.source_code = source
	assert(script.reload() == OK, "Clock-injected production script compiles")
	return script

static func install_pacing(owner: Node, original: Script) -> Node:
	now_usec = FIXTURE_START_USEC
	var clock := preload("res://tests/helpers/presentation_test_clock.gd").new()
	clock.name = "PresentationTestClock"
	clock.process_priority = -200
	owner.add_child(clock)
	var result: Node = clocked_script(original).new()
	result.install(owner)
	return result

func _process(_delta: float) -> void:
	# Fixed injected unscaled delta makes slow/uncapped hosts equivalent.
	_fractional_usec += STEP_SECONDS * 1000000.0
	var whole_usec: int = int(_fractional_usec)
	_fractional_usec -= whole_usec
	now_usec += whole_usec

static func method_source(script: Script, method: String) -> String:
	var source: String = source_for(script)
	var start: int = source.find("\nfunc " + method + "(")
	assert(start >= 0, "Production method exists: " + method)
	var end: int = source.find("\nfunc ", start + 1)
	return source.substr(start, end - start if end >= 0 else -1)

static func timer(tree: SceneTree, seconds: float) -> SceneTreeTimer:
	return tree.create_timer(seconds)

static func rendered_frames(tree: SceneTree, count: int) -> void:
	# perf-13 (faf148d41) rests hover for completed renders. The dummy
	# renderer needs the same explicit boundary used by hover_rest_cases.
	for frame: int in range(count):
		if DisplayServer.get_name() == "headless":
			await tree.process_frame
			RenderingServer.frame_post_draw.emit()
		else:
			await RenderingServer.frame_post_draw
	# Let the refresh queued by the final boundary run before observing it.
	await tree.process_frame

static func source_for(original: Script) -> String:
	var source: String = original.source_code
	var raw: String = OS.get_environment("LABYRINTH_TIMING_MUTATION")
	if raw.is_empty(): return source
	var mutation: Dictionary = JSON.parse_string(raw)
	if str(mutation.get("path", "")) != original.resource_path: return source
	var anchor: String = str(mutation["before"])
	assert(source.count(anchor) == 1, "Mutation anchor occurs exactly once")
	print("TIMING MUTATION APPLIED: " + str(mutation["name"]))
	return source.replace(anchor, str(mutation["after"]))

static func mutated_script(original: Script) -> Script:
	if OS.get_environment("LABYRINTH_TIMING_MUTATION").is_empty(): return original
	var script := GDScript.new()
	var lines := source_for(original).split("\n")
	for index: int in range(lines.size()):
		if lines[index].begins_with("class_name "): lines[index] = ""
	script.source_code = "\n".join(lines)
	assert(script.reload() == OK, "Mutated production script compiles")
	return script
