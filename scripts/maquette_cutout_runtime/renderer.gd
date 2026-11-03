extends Node

const CommonRig = preload("rig.gd")
const Motion = preload("motion.gd")
const Pixels = preload("pixel_presentation.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
const NATIVE_FPS: float = 60.0
var character_id: String = "shale_bloomer"
var viewport: SubViewport
var rigs: Dictionary = {}
var facing: String = "front"
var mirrored: bool = false
var clip: String = "idle"
var phase: float = 0.0
var active: bool = true
var reduced_motion: bool = false
var screen_pixel_scale: float = 1.0
var step_distance_px: float = 0.0
var root_forward_override: Dictionary = {}
var _idle_seconds: float = 0.0
var _recovering_hit: bool = false
var _pose_signature: Array = []
var _render_signature: Array = []
var _fresh_subclass_state: Dictionary = {}
var _canvas_geometry_cache: Dictionary = {}

func _ready() -> void:
	_capture_prepared_subclass_state()
	viewport = SubViewport.new()
	viewport.name = "MaquetteCanvas"
	viewport.size = borrow_canvas_geometry()["size"]
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	for view: String in _rig_views():
		var rig: Node2D = _new_rig()
		rig.name = view.capitalize()
		rig.facing = view
		viewport.add_child(rig)
		if not rig.load_rig(): push_error("Maquette cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

## Optional transparent capacity; the logical painted canvas remains 255px.
func canvas_geometry() -> Dictionary:
	return {"offset": SOURCE_OFFSET, "size": CANVAS_SIZE}

## Capacity is immutable for a concrete adapter. Draw consumers borrow this
## declaration; they must not allocate or mutate a geometry dictionary per unit.
func borrow_canvas_geometry() -> Dictionary:
	if _canvas_geometry_cache.is_empty(): _canvas_geometry_cache = canvas_geometry()
	return _canvas_geometry_cache

func _rig_views() -> Array[String]:
	var result: Array[String]
	result.assign(["front", "rear"])
	return result

func _new_rig() -> Node2D:
	var rig := CommonRig.new()
	rig.character_id = character_id
	return rig

func motion_data() -> Dictionary:
	return Motion.data_for({"motion_data": "res://assets/units/" + character_id + "_cutout/compiled_motion.json"})

## LiveActor seeds before tree entry; use the protected compiled clock rather
## than a second UI duration. _ready applies this phase to both loaded rigs.
func seed_idle_phase(value: float) -> void:
	_idle_seconds = fposmod(value, 1.0) * float(motion_data()["clips"]["idle"]["seconds"])
	_apply_pose()

## Prepared canvases enter the roster in exactly the same state as new().
## Reset both signatures so a warmed rear pose cannot survive adoption.
func reset_prepared_state() -> void:
	_reset_prepared_subclass_state()
	facing = "front"
	mirrored = false
	clip = "idle"
	phase = 0.0
	active = true
	reduced_motion = false
	screen_pixel_scale = 1.0
	step_distance_px = 0.0
	root_forward_override = {}
	_idle_seconds = 0.0
	_recovering_hit = false
	_pose_signature = []
	_render_signature = []
	_apply_pose()

## Capture subclass constructor values without changing protected adapters.
## Exclude shared fields: viewport/rig ownership survives adoption, while the
## shared playback fields have their explicit reset above.
func _capture_prepared_subclass_state() -> void:
	var shared: Script = load("res://scripts/maquette_cutout_runtime/renderer.gd")
	var shared_fields: Dictionary = {}
	for property: Dictionary in shared.get_script_property_list(): shared_fields[property["name"]] = true
	for property: Dictionary in get_script().get_script_property_list():
		var field: String = str(property["name"])
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not shared_fields.has(field):
			_fresh_subclass_state[field] = get(field)
	_fresh_subclass_state = _fresh_subclass_state.duplicate(true)

## Subclasses can override this hook for custom ownership/reset needs. The
## default restores their fresh value state before the shared pose applies.
func _reset_prepared_subclass_state() -> void:
	var fresh: Dictionary = _fresh_subclass_state.duplicate(true)
	for field: String in fresh: set(field, fresh[field])

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	active = enabled
	reduced_motion = reduce
	var requested: String = str(motion.get("clip", "idle"))
	if clip == "death" and requested != "death": return
	if clip == "hit" and requested == "idle" and phase < 1.0:
		_recovering_hit = true
		_apply_pose()
		return
	_recovering_hit = false
	clip = requested if motion_data()["clips"].has(requested) else "idle"
	phase = clampf(float(motion.get("phase", 0.0)), 0.0, 1.0)
	screen_pixel_scale = float(motion.get("screen_pixel_scale", screen_pixel_scale))
	step_distance_px = float(motion.get("step_distance_px", 0.0))
	root_forward_override = motion.get("root_forward_override", {})
	if clip not in ["hit", "death"]:
		var delta: Vector2i = motion.get("direction", Vector2i.ZERO)
		if delta != Vector2i.ZERO:
			var direction: Dictionary = Facing.direction_for_delta(delta)
			facing = str(direction["facing"])
			mirrored = bool(direction["mirrored"])
	_apply_pose()

func _process(delta: float) -> void:
	if clip == "hit" and _recovering_hit and not reduced_motion:
		phase = minf(1.0, phase + delta / float(motion_data()["clips"]["hit"]["seconds"]))
		if phase >= 1.0:
			clip = "idle"
			_idle_seconds = 0.0
		_apply_pose()
		return
	if not active or reduced_motion or clip != "idle": return
	if get_parent() is CanvasItem and not (get_parent() as CanvasItem).is_visible_in_tree(): return
	_idle_seconds = fposmod(_idle_seconds + delta, float(motion_data()["clips"]["idle"]["seconds"]))
	_apply_pose()

func _apply_pose() -> void:
	if rigs.is_empty(): return
	var shown: String = _shown_clip()
	var progress: float = _shown_phase()
	# Preserve the requested director/seed clock for existing consumers. The
	# actual painted cache uses the stepped clock; held frames need no redraw.
	_pose_signature = [facing, mirrored, shown, progress, screen_pixel_scale, step_distance_px, root_forward_override]
	var signature: Array = [facing, mirrored, shown, Pixels.phase_for(motion_data(), shown, progress), screen_pixel_scale, step_distance_px, root_forward_override]
	if signature == _render_signature: return
	var registration_changed: bool = _render_signature.is_empty() or _render_signature[0] != facing or _render_signature[1] != mirrored
	_render_signature = signature
	if registration_changed and get_parent() != null and get_parent().has_method("_invalidate_maquette_pixel_centers"):
		get_parent().call("_invalidate_maquette_pixel_centers")
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		rig.visible = view == facing
		if not rig.visible: continue
		rig.transform = Pixels.canvas_transform(canvas_geometry()["offset"], SOURCE_SIZE, mirrored)
		rig.layout["screen_pixel_scale"] = screen_pixel_scale
		rig.layout["step_distance_px"] = step_distance_px
		var override: Dictionary = root_forward_override.duplicate(false)
		if not override.is_empty() and mirrored:
			var axis: Vector2 = override["axis"]
			override["axis"] = Vector2(-axis.x, axis.y)
		rig.layout["root_forward_override"] = override
		rig.apply_pose(shown, progress)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return viewport.get_texture() if is_instance_valid(viewport) else null

func source_socket() -> Vector2:
	var rig: Node2D = rigs.get(facing)
	var bone: Bone2D = rig.bones.get("core")
	return bone.global_position - (canvas_geometry()["offset"] as Vector2) if bone != null else SOURCE_SIZE / 2.0

func snapshot() -> Dictionary:
	return {"art": character_id + "_maquette", "clip": clip, "shown_clip": _shown_clip(), "phase": _shown_phase(),
		"presented_phase": Pixels.phase_for(motion_data(), _shown_clip(), _shown_phase()),
		"facing": facing, "mirrored": mirrored, "active": active, "rig_count": rigs.size(),
		"reduced_motion": reduced_motion,
		"screen_pixel_scale": screen_pixel_scale, "step_distance_px": step_distance_px,
		"texture_id": texture().get_instance_id() if texture() != null else 0}

func _shown_clip() -> String:
	return "death" if clip == "death" else "rest" if reduced_motion else clip

func _shown_phase() -> float:
	return 1.0 if reduced_motion and clip == "death" else 0.0 if reduced_motion else _idle_seconds / float(motion_data()["clips"]["idle"]["seconds"]) if clip == "idle" else phase
