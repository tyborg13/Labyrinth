extends RefCounted
## Decode the existing title art during the splash's authored hold. There is no
## readiness gate: interruption or an unfinished request uses the ordinary menu
## loader. AssetLoader publishes the same texture under the same cache key.

const Assets = preload("res://scripts/asset_loader.gd")
const BACKGROUND_ART_PATH: String = "res://assets/art/ui/main_menu_umbra_dragon.png"

static func prepare_during_hold(owner: Control) -> void:
	var tree: SceneTree = owner.get_tree()
	Assets.prepare_textures_for(tree.root, {BACKGROUND_ART_PATH: false}, _present_frame.bind(tree), _still_active.bind(owner))

static func _still_active(owner: Variant) -> bool:
	return is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion()

static func _present_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
	else:
		await RenderingServer.frame_post_draw
