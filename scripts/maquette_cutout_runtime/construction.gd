extends RefCounted

## Workers own parsing, mesh conversion and operand compilation. Publication
## and retention are main-thread-only. Actor pose/LRU caches remain private.
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const StableSkin = preload("stable_skin.gd")

class Source extends RefCounted:
	var data: RigData.Data
	var skins: Dictionary = {}
	var meshes: Dictionary = {}
	var family: String = ""

static var _sources: Dictionary = {}
static var _owners: Dictionary = {}
static var fallback_constructions: int = 0
static var fallback_paths: Dictionary = {}
static var _build_frames: Dictionary = {}
static var build_peak_usec: int = 0
static var build_frame_peak_usec: int = 0

static func record_build(started: int) -> void:
	var elapsed: int = Time.get_ticks_usec() - started
	var frame: int = Engine.get_process_frames()
	if not _build_frames.has(frame): _build_frames.clear()
	_build_frames[frame] = int(_build_frames.get(frame, 0)) + elapsed
	build_peak_usec = maxi(build_peak_usec, elapsed)
	build_frame_peak_usec = maxi(build_frame_peak_usec, int(_build_frames[frame]))

static func reset_metrics() -> void:
	fallback_constructions = 0
	fallback_paths.clear()
	_build_frames.clear()
	build_peak_usec = 0
	build_frame_peak_usec = 0

static func metrics() -> Dictionary:
	return {"fallbacks": fallback_constructions, "fallback_paths": fallback_paths.duplicate(), "build_peak_usec": build_peak_usec, "build_frame_peak_usec": build_frame_peak_usec, "retained_sources": _sources.size()}

static func cached(path: String) -> Source:
	var found: Source = _sources.get(path)
	return found if found != null and found.data.modified == FileAccess.get_modified_time(path) else null

static func prepare_owned_source(path: String) -> Source:
	var result := Source.new()
	result.family = path.trim_prefix("res://assets/units/").get_slice("/", 0).trim_suffix("_cutout")
	result.data = RigData.prepare_owned_source(path)
	if not result.data.error.is_empty(): return result
	var layout: Dictionary = result.data.layout
	var meshes: Array = layout.get("joint_meshes", [])
	for mesh: Dictionary in meshes:
		var name: String = str(mesh.get("name", "PaintedJoint"))
		result.meshes[name] = mesh
		if bool(layout.get("stable_source_raster", false)):
			result.skins[name] = StableSkin.new(mesh, layout["joints"])
	# Runtime mesh submission borrows Data.meshes. Drop the redundant JSON
	# arrays on this private worker, after float64 skin operands are compiled.
	# Packed arrays share the ordinary loader's exact GPU buffers via COW;
	# rigid-cap discovery still traverses the same ordered weight names.
	var cape: Dictionary = layout.get("cape_mesh", {})
	if not cape.is_empty(): _compact(cape, result.data.meshes["cape"])
	for index: int in range(meshes.size()): _compact(meshes[index], result.data.meshes["joint:%d" % index])
	return result

static func _compact(mesh: Dictionary, prepared: Dictionary) -> void:
	mesh["vertices"] = prepared["vertices"]
	mesh["uvs"] = prepared["uvs"]
	mesh["triangles"] = prepared["triangles"]
	mesh["weights"] = prepared["weights"]

static func publish(path: String, source: Source) -> Source:
	if source == null or source.data == null or not source.data.error.is_empty(): return null
	if source.data.modified != FileAccess.get_modified_time(path): return null
	var found: Source = cached(path)
	if found != null: return found
	# A live older rig keeps its own source. Publish this worker's compact
	# source for new actors without compacting someone else's live layout.
	RigData._sources[path] = weakref(source.data)
	_sources[path] = source
	return source

static func ensure_source(path: String) -> Source:
	if not path.begins_with("res://assets/units/"): return null
	var found: Source = cached(path)
	if found != null:
		RigData._sources[path] = weakref(found.data)
		return found
	fallback_constructions += 1
	fallback_paths[path] = int(fallback_paths.get(path, 0)) + 1
	return publish(path, prepare_owned_source(path))

static func new_skin(path: String, mesh_name: String, data: Dictionary, joints: Dictionary) -> RefCounted:
	var found: Source = cached(path)
	var prepared: RefCounted = found.skins.get(mesh_name) if found != null and is_same(found.meshes.get(mesh_name), data) else null
	return StableSkin.new(data, joints, prepared)

static func retain_for(owner: int, families: PackedStringArray) -> void:
	_owners[owner] = families
	_prune()

static func release_owner(owner: int) -> void:
	_owners.erase(owner)
	_prune()

static func _prune() -> void:
	var allowed: Dictionary = {}
	for families: PackedStringArray in _owners.values():
		for family: String in families: allowed[family] = true
	for path: String in _sources.keys():
		if not allowed.has((_sources[path] as Source).family): _sources.erase(path)
