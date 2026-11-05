extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Materials = preload("res://scripts/scavenger_materials.gd")
const Card = preload("res://scripts/card_widget.gd")
const Action = preload("res://scripts/scavenger_action.gd")
const Price = preload("res://scripts/scavenger_price_tag.gd")
const Ember = preload("res://scripts/scavenger_ember_chip.gd")
var _input: Dictionary = {}
var _controls: Array[WeakRef]
var hits: int = 0

# Shop rendering/merchant rules never read analytics, elapsed score time or
# Grimoire receipts. All remaining run fields and mutable definition catalogs
# compare exactly. The view still receives the newest complete logical state.
func inputs(shop: Control) -> Dictionary:
	var state: Dictionary = shop._run_state.duplicate(false)
	state.erase("analytics")
	for field: String in ["grimoire_unlocked", "grimoire_unread", "grimoire_notice"]: state.erase(field)
	var progression: Dictionary = (state.get("progression", {}) as Dictionary).duplicate(false)
	for field: String in ["grimoire_unlocked", "grimoire_unread"]: progression.erase(field)
	state["progression"] = progression
	var stats: Dictionary = (state.get("run_stats", {}) as Dictionary).duplicate(false)
	stats.erase("run_seconds")
	state["run_stats"] = stats
	return {"state":state, "engine":shop._run_engine, "reduced":shop._reduced_motion,
		"selection":[shop._selected_item_id,shop._selected_is_sell,shop._detail_card_index],
		"pack":[shop._pack_mode,shop._pack_filter,shop._sell_page,shop._intro_open],
		"viewport":shop.get_viewport_rect().size,
		"definitions":[Data.cards(),Data.equipment(),Data.relics(),Data.upgrades(),Skills.definitions()]}

func matches(shop: Control) -> bool:
	if shop._inventory_released or _input.is_empty() or inputs(shop) != _input: return false
	var nodes: Array[Node] = shop._canvas.find_children("*", "", true, false)
	if nodes.size() != _controls.size(): return false
	for index: int in range(nodes.size()):
		var node: Node = nodes[index]
		if node.is_queued_for_deletion() or _controls[index].get_ref() != node: return false
	for node: Label in _shaded_labels(shop):
		if node.material is ShaderMaterial and node.material.shader == Materials.ShadedType:
			# Repeated typography can round differently at other supported scales.
			# Retain only if another application has exactly the same size/height.
			var font_size: int = node.get_theme_font_size("font_size")
			if Typography.scaled_size(node, font_size) != font_size: return false
			var height: float = maxf(maxf(node.size.y,node.custom_minimum_size.y),font_size)
			if node.material.get_shader_parameter("line_height") != height: return false
	hits += 1
	return true

func remember(shop: Control) -> void:
	_input = inputs(shop).duplicate(true)
	_controls.clear()
	for node: Node in shop._canvas.find_children("*", "", true, false): _controls.append(weakref(node))

func finish_hidden_layout(shop: Control) -> void:
	if shop.visible: return
	# Glyph preparation settles the hidden native containers after configure.
	# Finish the same material-height projection arrival would apply. A scale
	# whose next typography application changes size keeps the normal fallback.
	for node: Label in _shaded_labels(shop):
		if not node.material is ShaderMaterial or node.material.shader != Materials.ShadedType: continue
		var font_size: int = node.get_theme_font_size("font_size")
		if Typography.scaled_size(node,font_size) != font_size: return
	for node: Label in _shaded_labels(shop):
		if node.material is ShaderMaterial and node.material.shader == Materials.ShadedType:
			node.material.set_shader_parameter("line_height",maxf(maxf(node.size.y,node.custom_minimum_size.y),node.get_theme_font_size("font_size")))
	remember(shop)

func _shaded_labels(shop: Control) -> Array[Label]:
	var result: Array[Label]
	for group: Node in [shop._magic_group,shop._gear_group,shop._item_group,shop._sell_panel]: _collect_labels(group,result)
	return result

func _collect_labels(node: Node,result: Array[Label]) -> void:
	# Same recursion boundary as ScavengerShopView._shade_ui_labels.
	if node is Card or node is Action or node is Price or node is Ember: return
	if node is Label and not node.has_meta("scene_label"): result.append(node)
	for child: Node in node.get_children(): _collect_labels(child,result)
