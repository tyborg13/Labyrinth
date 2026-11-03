extends RefCounted

## Existing combat consumption presentation; heirlooms use their own burn.
## Seeking uses the same sine easing, poses and colours as the original tweens.
static func apply_pose(control: Control, origin: Vector2, origin_scale: Vector2, origin_rotation: float, origin_tint: Color, progress: float, reduced: bool) -> void:
	var t: float = clampf(progress, 0.0, 1.0)
	var in_out: float = Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	var outward: float = in_out if reduced else float(Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_SINE, Tween.EASE_OUT))
	var inward: float = in_out if reduced else float(Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_SINE, Tween.EASE_IN))
	control.scale = origin_scale.lerp(origin_scale * (0.54 if reduced else 0.42), in_out)
	if not reduced: control.rotation = lerpf(origin_rotation, deg_to_rad(-9.0), in_out)
	control.position = origin + Vector2(0.0, (-6.0 if reduced else -24.0) * outward)
	var target: Color = Color.WHITE
	target.g = 0.90 if reduced else 0.84
	target.b = 0.70 if reduced else 0.46
	target.a = 0.0
	control.modulate = origin_tint.lerp(target, inward)

static func play(host: Node, card_id: String, size_hint: Vector2, staged_proxy = null) -> void:
	if host.get("_card_fx_layer") == null or card_id.is_empty():
		host.call("_release_card_proxy", staged_proxy)
		return
	var proxy: Control = staged_proxy as Control if host.call("_node_is_alive", staged_proxy) else null
	var reduced: bool = host.call("_reduced_motion_enabled")
	if proxy == null:
		var start_rect: Rect2 = host.call("_stage_card_rect", size_hint * (1.02 if reduced else 1.08))
		if start_rect.size.x <= 0.0 or start_rect.size.y <= 0.0: return
		proxy = host.call("_spawn_card_proxy", card_id, start_rect)
		host.call("_mount_card_proxy", proxy, host.get("_card_fx_layer"), start_rect)
	proxy.z_index = 1490
	var origin: Vector2 = proxy.position
	var origin_scale: Vector2 = proxy.scale
	var origin_rotation: float = proxy.rotation
	var origin_tint: Color = proxy.modulate
	var seconds: float = float(host.get_script().get_script_constant_map()["CARD_PILE_SECONDS"]) * (0.55 if reduced else 1.0)
	var tween: Tween = host.create_tween()
	tween.tween_method(func(progress: float) -> void:
		if is_instance_valid(proxy): apply_pose(proxy, origin, origin_scale, origin_rotation, origin_tint, progress, reduced)
	, 0.0, 1.0, seconds)
	await tween.finished
	host.call("_release_card_proxy", proxy)
