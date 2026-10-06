extends Node

signal rest_texture_changed

const ReactionPlayback = preload("res://scripts/cutout_reaction_playback.gd")
const GearVisuals = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const RestBaker = preload("res://scripts/protagonist_cutout/gear_rest_baker.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

## A stable texture RID lets the retained board draw live bones without rebuilding
## its tiles for every breath. Both painted facings stay loaded between turns.
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const REST_PATH: String = "res://assets/units/protagonist_cutout/front/front_assembled_rest_v9.png"
const DEFAULT_GEAR_REST_PATH: String = RestBaker.DEFAULT_PATH
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
const WALK_CYCLE_SECONDS: float = 0.30
const IDLE_CYCLE_SECONDS: float = 0.84
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const MELEE_FRAMES: int = 30
const MELEE_FRAME_SECONDS: float = 1.0 / 60.0

var viewport: SubViewport
var rigs: Dictionary = {}
var facing: String = "front"
var mirrored: bool = false
var clip: String = "idle"
var phase: float = 0.0
var reduced_motion: bool = false
var reduced_motion_source: Callable
var active: bool = true
var _idle_seconds: float = 0.0
var _pose_signature: Array = []
var _equipped: Dictionary = {}
var _gear_signature: String = ""
var _gear_revision: int = 0
var _weapon_motion: String = "sword"
var _offhand_kind: String = ""
var _rest_texture: Texture2D
var _rest_fallback: Texture2D = AssetLoader.load_texture_source_first(REST_PATH)

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "CutoutCanvas"
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	for view: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.name = view.capitalize()
		rig.facing = view
		viewport.add_child(rig)
		if not rig.load_rig():
			push_error("Protagonist cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_rest_fallback = AssetLoader.load_texture_source_first(REST_PATH)
	if _gear_signature.is_empty():
		set_gear(_equipped)
	else:
		_apply_gear()
		_prepare_rest_texture()

func set_gear(equipped: Dictionary) -> void:
	var next_signature: String = GearVisuals.signature(equipped)
	if next_signature == _gear_signature:
		return
	_equipped = GearVisuals.resolve(equipped)
	_gear_signature = next_signature
	_weapon_motion = GearVisuals.weapon_motion(_equipped)
	_offhand_kind = GearVisuals.offhand_kind(_equipped)
	_gear_revision += 1
	_rest_texture = RestBaker.cached(_gear_signature)
	if not rigs.is_empty():
		_apply_gear()
		_prepare_rest_texture()
		rest_texture_changed.emit()

func _apply_gear() -> void:
	for view: String in rigs:
		rigs[view].apply_gear(GearVisuals.ops_for_facing(_equipped, view))
	_pose_signature.clear()
	_apply_pose()

func _prepare_rest_texture() -> void:
	if _rest_texture != null:
		return
	_rest_texture = RestBaker.cached(_gear_signature)
	if _rest_texture == null and is_inside_tree():
		var job: Node = RestBaker.request(get_tree(), _gear_signature, _equipped)
		if job != null and not job.is_connected("baked", _on_rest_baked):
			job.connect("baked", _on_rest_baked)

func _on_rest_baked(signature: String, baked_texture: Texture2D) -> void:
	if signature == _gear_signature and baked_texture != null:
		_rest_texture = baked_texture
		rest_texture_changed.emit()

func rest_texture() -> Texture2D:
	return _rest_texture if _rest_texture != null else _rest_fallback

func weapon_motion() -> String:
	return _weapon_motion

func offhand_kind() -> String:
	return _offhand_kind

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({}, "front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	# Board projection: +x southeast, +y southwest, -x northwest, -y northeast.
	# Diagonal targets resolve to the dominant grid axis, with x breaking ties.
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		return {"facing": "front" if delta.x > 0 else "rear", "mirrored": true}
	return {"facing": "front" if delta.y >= 0 else "rear", "mirrored": false}

static func attack_pose_phase(progress: float) -> float:
	# 180ms lift/hold, a 30ms cut through contact at 210ms, then follow-through
	# and recovery. The accepted painted poses are unchanged; only time changes.
	var keys := PackedVector2Array([Vector2(0, 0), Vector2(0.34, 0.27),
		Vector2(0.36, 0.31), Vector2(0.42, 0.44), Vector2(0.60, 0.60), Vector2(1, 1)])
	for index: int in range(1, keys.size()):
		if progress <= keys[index].x:
			return lerpf(keys[index - 1].y, keys[index].y,
				inverse_lerp(keys[index - 1].x, keys[index].x, clampf(progress, 0, 1)))
	return 1.0

static func attack_trail_phase(progress: float) -> float:
	# Hide the old full-arc effect during preparation. Its bright cut now reaches
	# the target at the same time as the blade and damage, then dissipates.
	if progress < 0.36 or progress >= 0.74:
		return -1.0
	if progress <= 0.42:
		return remap(progress, 0.36, 0.42, 0.0, 0.45)
	return remap(progress, 0.42, 0.74, 0.45, 1.0)

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	reduced_motion = reduce
	active = enabled
	var guard_clip: String = "block_shield" if str(motion.get("clip", "")) == "block" and offhand_kind() == "shield" else ""
	if ReactionPlayback.present(self, motion, guard_clip):
		return
	var delta: Vector2i = motion.get("direction", Vector2i.ZERO)
	if delta != Vector2i.ZERO:
		var direction: Dictionary = direction_for_delta(delta)
		facing = direction["facing"]
		mirrored = bool(direction["mirrored"])
	var previous_clip: String = clip
	clip = str(motion.get("clip", "idle"))
	phase = float(motion.get("phase", 0.0))
	if clip == "attack":
		if phase >= 1.0:
			clip = "idle"
		else:
			match weapon_motion():
				"heavy": clip = "attack_heavy"
				"stab": clip = "attack_stab"
				_: phase = attack_pose_phase(phase)
	if clip in ["cast", "shoot"] and phase >= 1.0 and not reduced_motion:
		clip = "idle"
	if clip == "idle":
		facing = "front"
		mirrored = false
		if previous_clip != "idle":
			_idle_seconds = 0.0
	_apply_pose()

func _process(delta: float) -> void:
	if not active or not is_instance_valid(viewport):
		return
	if get_parent() is CanvasItem and not (get_parent() as CanvasItem).is_visible_in_tree():
		return
	if reduced_motion_source.is_valid():
		var next_reduced: bool = bool(reduced_motion_source.call())
		if next_reduced != reduced_motion:
			reduced_motion = next_reduced
			_apply_pose()
	if clip == "idle" and not reduced_motion:
		_idle_seconds = fposmod(_idle_seconds + delta, IDLE_CYCLE_SECONDS)
		_apply_pose()

func _apply_pose() -> void:
	if rigs.is_empty():
		return
	var ranged_still: bool = reduced_motion and clip in ["cast", "shoot"]
	var shown_clip: String = "death" if clip == "death" else clip if ranged_still else "rest" if reduced_motion else clip
	var shown_phase: float = 1.0 if clip == "death" and reduced_motion else 0.4 if ranged_still else 0.0 if reduced_motion else (_idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase)
	var signature: Array = [facing, mirrored, shown_clip, shown_phase]
	if signature == _pose_signature:
		return
	_pose_signature = signature
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		rig.visible = view == facing
		if not rig.visible:
			continue
		rig.position = Vector2(383, 128) if mirrored else SOURCE_OFFSET
		rig.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
		ReactionPlayback.apply_pose(rig, shown_clip, shown_phase, reduced_motion)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return viewport.get_texture() if viewport != null else null

func source_socket(shot: bool = false, released: bool = false, direction_delta: Vector2i = Vector2i.ZERO) -> Vector2:
	if rigs.is_empty():
		return SOURCE_SIZE * 0.5
	var socket_facing: String = facing
	var socket_mirrored: bool = mirrored
	if released and direction_delta != Vector2i.ZERO:
		var direction: Dictionary = direction_for_delta(direction_delta)
		socket_facing = direction["facing"]
		socket_mirrored = bool(direction["mirrored"])
	var rig: Node2D = rigs[socket_facing]
	var bone_name: String = "crossbow_r" if shot else "hand_l"
	var point: Vector2
	var offset: Vector2 = Vector2.ZERO
	if shot:
		var raw: Array = rig.layout.get("ranged_attachment", {}).get("muzzle_offset", [0, 0])
		offset = Vector2(float(raw[0]), float(raw[1]))
	else:
		offset = Vector2(-2, 5)
	if released:
		var pose: Dictionary = Motion.sample_pose("shoot" if shot else "cast", 0.42, rig.layout, socket_facing)
		point = Motion._world_transform(pose, rig.layout, bone_name) * offset
	else:
		point = rig.to_local((rig.bones[bone_name] as Bone2D).to_global(offset))
	return Vector2(SOURCE_SIZE.x - point.x, point.y) if socket_mirrored else point

func snapshot() -> Dictionary:
	var ranged_still: bool = reduced_motion and clip in ["cast", "shoot"]
	return {"art": "protagonist_cutout_pass9", "facing": facing, "mirrored": mirrored,
		"clip": "death" if clip == "death" else clip if ranged_still else "rest" if reduced_motion else clip,
		"phase": 1.0 if clip == "death" and reduced_motion else 0.4 if ranged_still else 0.0 if reduced_motion else (_idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase),
		"hand_source": source_socket(), "muzzle_source": source_socket(true),
		"crossbow_visible": (rigs[facing].bones["crossbow_r"] as Bone2D).visible if rigs[facing].bones.has("crossbow_r") else false,
		"gear": _gear_signature, "offhand_visible": _offhand_visible(),
		"rig_count": rigs.size(), "texture_id": texture().get_instance_id() if texture() != null else 0}

func _offhand_visible() -> bool:
	if rigs.is_empty():
		return false
	for attachment: Sprite2D in rigs[facing]._gear_attachments:
		if str(attachment.name) == "GearOffhand":
			return attachment.visible
	return false
