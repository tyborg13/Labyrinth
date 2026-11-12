extends RefCounted
## Proof-only geometry and settling, independent of rejected body targeting.
const PROOF_SIZE := Vector2i(1920, 1080)
const ENEMY_TILE := Vector2i(4, 4)
const SETTLE_FRAMES: int = 8

static func settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES):
		await tree.process_frame

static func pointer_point(board: Control, tile: Vector2i) -> Vector2:
	# Floor centers are the production click targets on this base.
	return board.call("_tile_center", tile)
