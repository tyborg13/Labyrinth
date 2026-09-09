extends "res://scripts/protagonist_cutout/rig.gd"

## Authoring adapter; production rendering and asset ownership remain unchanged.
@export var case_file: String = ""
var config: Dictionary = {}
var case_directory: String = ""
var sampler: Script
var _layer_facing: String = ""
var _layer_nodes: Dictionary = {}
var _layer_defaults: Dictionary = {}

func configure(path: String) -> bool:
	case_file = path
	case_directory = path.get_base_dir()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		load_errors.append("Invalid cutout case: " + path)
		return false
	config = parsed
	sampler = load(_resolve(str(config["motion"]))) as Script
	if sampler == null or not sampler.has_method("sample_pose"):
		load_errors.append("Motion script needs static sample_pose(clip, phase, layout, facing)")
		return false
	facing = str(config["default_facing"])
	return load_rig()

func _layout_path(which: String) -> String:
	return _resolve(str(config["layouts"][which]))

func has_facing(which: String) -> bool:
	return config.get("layouts", {}).has(which) and FileAccess.file_exists(_layout_path(which))

func _resolve(path: String) -> String:
	return path if path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://") else case_directory.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	# The accepted motion's sole-contour reader receives explicit paths too.
	for part: Dictionary in layout.get("parts", []):
		part["file"] = _resolve(str(part["file"]))
	var pose: Dictionary = sampler.call("sample_pose", clip_name, phase_value, layout, facing)
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var override: Dictionary = pose.get(bone_name, {})
		bone.transform = rest_transforms[bone_name]
		bone.position = override.get("position", bone.position)
		bone.rotation = float(override.get("rotation", 0.0))
		bone.scale = override.get("scale", Vector2.ONE)
		bone.skew = float(override.get("skew", 0.0))
		bone.visible = bool(override.get("visible", true))
	_apply_draw_order(clip_name, phase_value)

func _draw_order_targets() -> Dictionary:
	if _layer_facing == facing:
		return _layer_nodes
	_layer_facing = facing
	_layer_nodes.clear()
	_layer_defaults.clear()
	for part_name: String in config.get("draw_order_parts", {}).get(facing, []):
		# Bone and sprite names can coincide (for example foot_l). Only paint
		# nodes own absolute drawing layers; changing the bone cannot reorder it.
		var matches: Array[Node] = find_children(part_name, "Sprite2D", true, false)
		matches.append_array(find_children(part_name, "Polygon2D", true, false))
		if matches.size() != 1:
			load_errors.append("Unknown or ambiguous draw-order paint: " + part_name)
			continue
		var part: CanvasItem = matches[0] as CanvasItem
		_layer_nodes[part_name] = part
		_layer_defaults[part_name] = part.z_index
	return _layer_nodes

func _apply_draw_order(clip_name: String, phase_value: float) -> void:
	var targets: Dictionary = _draw_order_targets()
	if targets.is_empty():
		return
	if not sampler.has_method("sample_draw_order"):
		load_errors.append("Declared draw-order paint needs motion.sample_draw_order")
		return
	var orders: Dictionary = sampler.call("sample_draw_order", clip_name, phase_value, layout, facing)
	for part_name: String in orders:
		if not targets.has(part_name) or not orders[part_name] is int or int(orders[part_name]) < -4096 or int(orders[part_name]) > 4095:
			load_errors.append("Invalid draw-order override: " + part_name)
			return
	for part_name: String in targets:
		(targets[part_name] as CanvasItem).z_index = int(orders.get(part_name, _layer_defaults[part_name]))

func playback_phase(clip_name: String, progress: float) -> float:
	var keys: Array = config["clips"][clip_name].get("phase_curve", [])
	if keys.is_empty():
		return progress
	for index: int in range(1, keys.size()):
		if progress <= float(keys[index][0]):
			return lerpf(float(keys[index-1][1]), float(keys[index][1]), inverse_lerp(float(keys[index-1][0]), float(keys[index][0]), progress))
	return float(keys[-1][1])

func show_frame(clip_name: String, index: int) -> void:
	var specification: Dictionary = config["clips"][clip_name]
	var frames: int = int(specification["frames"])
	var progress: float = float(posmod(index, frames)) / float(frames if specification["loop"] else frames - 1)
	apply_pose(clip_name, playback_phase(clip_name, progress))

func travel_for_frame(clip_name: String, index: int) -> Vector2:
	var specification: Dictionary = config["clips"][clip_name]
	if str(specification.get("travel", "none")) != "motion":
		return Vector2.ZERO
	if not sampler.has_method("walk_cycle_info"):
		load_errors.append("Travel requires motion.walk_cycle_info(layout, facing)")
		return Vector2.ZERO
	var info: Dictionary = sampler.call("walk_cycle_info", layout, facing)
	return Vector2(info["travel_per_cycle"]) * float(index) / float(specification["frames"])

func set_facing(which: String) -> bool:
	if not has_facing(which):
		return false
	facing = which
	return load_rig()

func set_slot_visible(slot: String, value: bool) -> void:
	_slot_visibility(self, slot, value)

func _slot_visibility(node: Node, slot: String, value: bool) -> void:
	for child: Node in node.get_children():
		if child is CanvasItem and str(child.get_meta("equipment_slot", "")) == slot:
			(child as CanvasItem).visible = value
		_slot_visibility(child, slot, value)

func save_editable(path: String) -> Error:
	if has_node("Animations"):
		get_node("Animations").free()
	var player := AnimationPlayer.new()
	player.name = "Animations"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(player)
	player.owner = self
	var library := AnimationLibrary.new()
	for clip_name: String in config["clips"]:
		var specification: Dictionary = config["clips"][clip_name]
		var frames: int = int(specification["frames"])
		var duration: float = float(specification["duration"])
		var animation := Animation.new()
		animation.length = duration
		animation.loop_mode = Animation.LOOP_LINEAR if specification["loop"] else Animation.LOOP_NONE
		var tracks: Dictionary = {}
		for bone_name: String in bones:
			tracks[bone_name] = {}
			for property: String in ["position", "rotation", "scale", "skew", "visible"]:
				var track: int = animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track, NodePath(str(get_path_to(bones[bone_name])) + ":" + property))
				animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST if property == "visible" else Animation.INTERPOLATION_LINEAR)
				if property == "visible":
					animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
				tracks[bone_name][property] = track
		var layer_tracks: Dictionary = {}
		for part_name: String in _draw_order_targets():
			var track: int = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track, NodePath(str(get_path_to(_layer_nodes[part_name])) + ":z_index"))
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
			animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
			layer_tracks[part_name] = track
		for index: int in range(frames + 1):
			var progress: float = minf(1.0, float(index) / float(frames if specification["loop"] else frames-1))
			apply_pose(clip_name, playback_phase(clip_name, progress))
			for bone_name: String in bones:
				for property: String in tracks[bone_name]:
					animation.track_insert_key(tracks[bone_name][property], float(index) * duration / float(frames), bones[bone_name].get(property))
			for part_name: String in layer_tracks:
				animation.track_insert_key(layer_tracks[part_name], float(index) * duration / float(frames), (_layer_nodes[part_name] as CanvasItem).z_index)
		library.add_animation(clip_name, animation)
	player.add_animation_library("", library)
	apply_pose("rest", 0.0)
	set_meta("cutout_facing", facing)
	var packed := PackedScene.new()
	var result: Error = packed.pack(self)
	return ResourceSaver.save(packed, path) if result == OK else result
