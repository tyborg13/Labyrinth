extends RefCounted
## Controller bindings live in the prompt bar; keyboard shortcuts stay in tips.

const KeyBindings = preload("res://scripts/key_bindings.gd")

static func text(owner: Node, body: String, action: String) -> String:
	var router: Node = owner.get_node_or_null("/root/InputRouter")
	if router != null and bool(router.call("using_controller")):
		return body
	return KeyBindings.with_mark(body, action)

static func refresh_maps(scene: Node) -> void:
	for control: Control in [scene.mini_map_overlay, scene._section_map_hud_button]:
		if is_instance_valid(control):
			control.tooltip_text = text(scene, "Map", KeyBindings.MAP)
