extends RefCounted
## Seed 7 regression witness from the qa-116 census. The guided exit uses the
## same tile earlier, so match the source and destination rooms too.
const SOURCE_ROOM := Vector2i(-1, 1)
const DESTINATION_ROOM := Vector2i(2, -1)
const TARGET_TILE := Vector2i(8, 4)
const CAPTURE_NAME: String = "gfix-19-tile-8-4.png"

static func matches(state: Dictionary, destination: Vector2i, tile: Vector2i) -> bool:
	return state["current_room"] == SOURCE_ROOM and destination == DESTINATION_ROOM and tile == TARGET_TILE

static func capture(session: Node, scene: Node) -> bool:
	var native: bool = DisplayServer.get_name() != "headless"
	if native: await RenderingServer.frame_post_draw
	var candidate: Dictionary = scene.get("_controller_focus_candidate")
	var board_view: Node = scene.get("board_view")
	if candidate.get("tile") != TARGET_TILE or candidate.get("kind") != "door" or board_view.get("_controller_focus_tile") != TARGET_TILE:
		session.fail("Board proof did not reach the expected door and rendered focus tile")
		return false
	var path: String = ""
	if native:
		path = session.output.path_join(CAPTURE_NAME)
		var image: Image = session.root.get_texture().get_image()
		if image == null or image.is_empty() or image.save_png(path) != OK:
			session.fail("Board proof image readback failed")
			return false
		print(path)
	session.log_event("board_proof_focus", {"tile": str(TARGET_TILE), "point": str(candidate["point"]), "native": native, "path": path})
	return true
