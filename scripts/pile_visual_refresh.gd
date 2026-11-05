extends RefCounted

# Combat revisions also change for walking, hovering and analytics. None of
# those changes the pile artwork. Validate its actual inputs and live children
# instead; keep the public signature so diagnostic cold-refresh hooks still work.
var _inputs: Array = []
var _children: Array = []

func unchanged(scene: Control, piles: Dictionary, card_size: Vector2) -> bool:
	var inputs: Array = [piles, card_size]
	var signature: String = str(hash(inputs))
	var children: Array = []
	for kind: String in ["draw", "discard"]:
		var host: Control = scene._pile_visual_hosts.get(kind)
		children.append(host.get_children() if host != null else [])
	if scene._pile_visual_signature == signature and inputs == _inputs and children == _children:
		return true
	_inputs = inputs.duplicate(true)
	scene._pile_visual_signature = signature
	return false

func remember_children(scene: Control) -> void:
	_children.clear()
	for kind: String in ["draw", "discard"]:
		var host: Control = scene._pile_visual_hosts.get(kind)
		_children.append(host.get_children() if host != null else [])

static func populate_icon(scene: Control, host: Control, icon_path: String, empty: bool, icon_name: String) -> void:
	var icon: TextureRect = host.get_node_or_null(NodePath(icon_name)) as TextureRect
	if icon == null or host.get_child_count() != 1:
		scene._clear_children_now(host)
		icon = TextureRect.new()
		icon.name = icon_name
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2.ZERO
		icon.size = scene.PILE_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		host.add_child(icon)
	icon.texture = scene.AssetLoader.load_texture(icon_path)
	icon.modulate = Color(1.0, 1.0, 1.0, 0.42) if empty else Color.WHITE
