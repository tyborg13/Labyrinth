extends RefCounted
## The shared production wind-push slide, without inventing a walk or throw.
static func animate(scene: Control, before: Dictionary, after: Dictionary, actors: Array[Dictionary], base: Dictionary = {}) -> void:
	var engine: RefCounted = scene._combat_engine
	var reduced: bool = scene._reduced_motion_enabled()
	await scene._play_timed_animation_frames(1 if reduced else scene.MOVE_STEP_FRAMES, 0.0 if reduced else scene.MOVE_FRAME_SECONDS, func(frame: int) -> void:
		var progress: float = 1.0 if reduced else float(frame) / float(scene.MOVE_STEP_FRAMES)
		var positions: Dictionary = {}
		for actor: Dictionary in actors:
			var key: String = engine._surface_actor_key(str(actor["kind"]), int(actor["id"]))
			var start: Vector2 = scene.board_view._tile_center(actor["unit"]["pos"])
			var finish: Vector2 = scene.board_view._tile_center(engine._surface_actor(after, str(actor["kind"]), int(actor["id"])).get("pos", actor["unit"]["pos"]))
			positions[key] = start.lerp(finish, progress)
		var shown: Dictionary = base.duplicate()
		shown["effect_progress"] = progress
		shown["unit_world_positions"] = positions
		scene._render_board_state(before, shown))
