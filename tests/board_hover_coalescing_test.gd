extends SceneTree

class HoverScene extends "res://scripts/run_scene.gd":
	var stage_calls: int = 0
	var context_calls: int = 0
	var presented: Vector2i = Vector2i(-1, -1)
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: super._exit_tree()
	func _notification(_what: int) -> void: pass
	func _board_hover_stage_refresh_needed(_tile: Vector2i) -> bool: return true
	func _pass_preview_hover_can_change() -> bool: return true
	func _refresh_stage_view() -> void:
		stage_calls += 1
		presented = _hovered_board_tile
	func _update_action_context_copy(_preview: Dictionary = {}) -> void: context_calls += 1

var failures: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	scene.set_script(HoverScene)
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set("_run_state", {"mode": "combat"})
	for x: int in range(8): scene._on_board_tile_hovered(Vector2i(x, 2))
	check(scene.get("_hovered_board_tile") == Vector2i(7, 2), "Targeting updates synchronously to the last input")
	check(scene.stage_calls == 0 and scene.context_calls == 0, "Hover presentation waits for the input batch")
	await process_frame
	await process_frame
	check(scene.stage_calls == 1 and scene.context_calls == 1 and scene.presented == Vector2i(7, 2), "One presentation uses the last tile")
	scene._on_board_tile_hovered(Vector2i(3, 3))
	scene.set("_animation_lock", true)
	await process_frame
	await process_frame
	check(scene.stage_calls == 1 and scene.context_calls == 1, "An action that starts in the same input batch supersedes invisible hover work")
	scene.set("_animation_lock", false)
	scene._on_board_tile_hovered(Vector2i(5, 5))
	await process_frame
	await process_frame
	check(scene.stage_calls == 2 and scene.context_calls == 2 and scene.presented == Vector2i(5, 5), "Input after unlock schedules a fresh presentation")
	scene._on_board_tile_hovered(Vector2i(1, 1))
	scene.set("_dialogue_active", true)
	await process_frame
	await process_frame
	check(scene.stage_calls == 2, "Dialogue supersedes an outstanding hover")
	scene.set("_dialogue_active", false)
	scene._on_board_tile_hovered(Vector2i(1, 2))
	root.remove_child(scene)
	await process_frame
	await process_frame
	check(scene.stage_calls == 2 and not scene.get("_board_hover_refresh_pending"), "Detached scenes cancel queued presentation")
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.stage_calls == 2, "Reattachment cannot revive an obsolete hover")
	scene._on_board_tile_hovered(Vector2i(2, 2))
	await process_frame
	await process_frame
	check(scene.stage_calls == 3, "Reattached scene accepts new input")
	scene._on_board_tile_hovered(Vector2i(2, 3))
	scene.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(scene), "Queued deletion safely cancels deferred presentation")
	print("TEST RESULT: %s — board hover input-batch coalescing" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
