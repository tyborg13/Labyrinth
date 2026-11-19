extends RefCounted
## Stage the committed hit, slide and contact for the recording camera.
const Slide = preload("res://scripts/forced_displacement_view.gd")
const Fixture = preload("res://tools/tooltip_loops/tip07_fixture.gd")
const RecordBoard = preload("res://tools/tooltip_loops/record_board.gd")

var slide_frame: int = -1
var impact_frame: int = -1
var _gliding: bool = false

static func play(scene: Control, beat: Dictionary) -> void:
	var before: Dictionary = beat["before"]
	var after: Dictionary = beat["after"]
	var mover: Dictionary = before["enemies"][0]
	var landed: Dictionary = after
	var collisions: Array[Dictionary] = Fixture.collision_events(before, after)
	if not collisions.is_empty():
		# Recover the pre-contact presentation snapshot from the real damage
		# receipt. Only the final contact beat submits that event and its losses.
		var event: Dictionary = collisions[0]
		landed = after.duplicate(true)
		landed["surface_events"] = before.get("surface_events", [])
		landed["surface_event_sequence"] = before.get("surface_event_sequence", 0)
		landed["enemies"][0]["hp"] += event["target_damage"]
		landed["enemies"][1]["hp"] += event["blocker_damage"]
	var hit: Dictionary = landed.duplicate(true)
	hit["enemies"][0]["pos"] = mover["pos"]
	await scene._animate_player_action_step(before, hit, beat["card"], beat["action"], beat["target"], beat["chain_hits"])
	var actors: Array[Dictionary]
	actors.append({"kind": "enemy", "id": mover["id"], "unit": hit["enemies"][0]})
	await Slide.animate(scene, hit, landed, actors)
	if not collisions.is_empty():
		await scene._animate_surface_change(landed, after)

func observe(board: Control, fixture: Dictionary, result: Dictionary, frame: int) -> void:
	var before: Dictionary = fixture["state"]
	var mover: Dictionary = before["enemies"][0]
	var landed: Dictionary = result["final"]["enemies"][0]
	var key: String = "enemy_%d" % int(mover["id"])
	var shown: Dictionary = board.presentation
	var positions: Dictionary = shown.get("unit_world_positions", {})
	_gliding = positions.has(key)
	if _gliding and slide_frame < 0:
		var start: Vector2 = board._tile_center(mover["pos"])
		var end: Vector2 = board._tile_center(landed["pos"])
		var point: Vector2 = positions[key]
		if not point.is_equal_approx(start) and not point.is_equal_approx(end):
			slide_frame = frame
	if impact_frame >= 0 or fixture["id"] != Fixture.COLLISION or _gliding:
		return
	var progress: float = shown.get("surface_feedback_progress", 0.0)
	if progress <= 0.0 or progress >= 1.0:
		return
	for event: Dictionary in shown.get("surface_feedback_events", []):
		if event.get("kind") != "force_collision" or event.get("tile") != landed["pos"]:
			continue
		var numbers: Dictionary = {}
		for entry: Dictionary in shown.get("floating_texts", []):
			if float(entry.get("alpha", 1.0)) > 0.0:
				numbers[entry.get("reaction_actor_key", "")] = RecordBoard.audit_number_label(entry)
		var blocker_key: String = "enemy_%d" % int(before["enemies"][1]["id"])
		if numbers.get(key) == "-%d" % int(event["target_damage"]) and numbers.get(blocker_key) == "-%d" % int(event["blocker_damage"]):
			impact_frame = frame

func report(fixture: Dictionary, result: Dictionary, board: Control, failures: Array[String]) -> Dictionary:
	var id: String = fixture["id"]
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	var action: Dictionary = result["beats"][0]["action"]
	var key: String = "enemy_%d:-%d" % [before["enemies"][0]["id"], action["damage"]]
	if slide_frame < 0:
		failures.append(id + ": no in-transit slide frame was submitted")
	if not board.seen_numbers.has(key):
		failures.append(id + ": the direct damage number was not submitted")
	if id == Fixture.COLLISION and (impact_frame < 0 or impact_frame <= slide_frame):
		failures.append(id + ": both Collision numbers and the impact must appear together after the slide")
	var targets: Array[Dictionary]
	for index: int in range(before["enemies"].size()):
		var start: Dictionary = before["enemies"][index]
		var end: Dictionary = after["enemies"][index]
		targets.append({"from": [start["pos"].x, start["pos"].y], "to": [end["pos"].x, end["pos"].y], "health_before": start["hp"], "health_after": end["hp"]})
	var hero_tile: Vector2i = before["player"]["pos"]
	return {
		"card": fixture["card"],
		"hero_tile": [hero_tile.x, hero_tile.y],
		"targets": targets,
		"slide_frame": slide_frame,
		"impact_frame": impact_frame,
		"collisions": Fixture.collision_events(before, after).size()
	}
