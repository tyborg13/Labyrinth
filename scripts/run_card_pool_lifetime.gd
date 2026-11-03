extends RefCounted

# Cache capacity follows simultaneous display, never the set of card identities
# encountered during a run. Live views keep their ordinary complete contents.
const Combat = preload("res://scripts/combat_engine.gd")
const FULL_PILE_LAYOUT_CARD_COUNT: int = 6

static func discard(scene: Node, entry: Dictionary, field: String) -> void:
	# A configured pile owns button instances, not just the same card IDs.
	if field == "button": scene._pile_dialog_content_source.clear()
	var node: Variant = entry.get(field)
	if not scene._node_is_alive(node): return
	scene._prepare_node_for_immediate_free(node)
	if node.get_parent() != null: node.get_parent().remove_child(node)
	node.queue_free()

static func trim_hand(scene: Node) -> void:
	while scene._hand_card_pool.size() > Combat.MAX_HAND_SIZE:
		discard(scene, scene._hand_card_pool.pop_front(), "slot")

static func prepare_hand(scene: Node, cards: Array) -> void:
	var remaining: Dictionary = {}
	for id: String in cards: remaining[id] = int(remaining.get(id, 0)) + 1
	for index: int in range(scene._hand_card_pool.size() - 1, -1, -1):
		var entry: Dictionary = scene._hand_card_pool[index]
		var id: String = str(entry["card_id"])
		if int(remaining.get(id, 0)) > 0:
			remaining[id] -= 1
			continue
		scene._hand_card_pool.remove_at(index)
		discard(scene, entry, "slot")
	trim_hand(scene)

static func acquire_hand(scene: Node, card_id: String, card_size: Vector2) -> Dictionary:
	scene._ensure_hand_card_pool_host()
	var chosen: int = -1
	for index: int in range(scene._hand_card_pool.size()):
		if str(scene._hand_card_pool[index]["card_id"]) == card_id:
			chosen = index
			break
	if chosen < 0 and not scene._hand_card_pool.is_empty(): chosen = scene._hand_card_pool.size() - 1
	if chosen < 0: return scene._new_hand_card_pool_entry(card_id, card_size)
	var entry: Dictionary = scene._hand_card_pool[chosen]
	scene._hand_card_pool.remove_at(chosen)
	if str(entry["card_id"]) != card_id:
		entry["card_id"] = card_id
		entry["definition_signature"] = -1
	var slot: Control = entry["slot"]
	if slot.get_parent() != null: slot.get_parent().remove_child(slot)
	slot.visible = true
	return entry

static func pile_limit(scene: Node) -> int:
	# Query the existing full-view layout without changing it. Card readability,
	# chrome, UI scale and viewport clamping all contribute to the cache bound.
	var available: Vector2 = scene._pile_dialog_size_for_count(FULL_PILE_LAYOUT_CARD_COUNT)
	available -= scene._pile_dialog.get_theme_stylebox("panel").get_minimum_size()
	for child: Node in scene._pile_dialog.get_children():
		if child is MarginContainer and child.is_ancestor_of(scene._pile_dialog_scroll):
			available -= Vector2(child.get_theme_constant("margin_left") + child.get_theme_constant("margin_right"), child.get_theme_constant("margin_top") + child.get_theme_constant("margin_bottom"))
	var column: VBoxContainer = scene._pile_dialog_scroll.get_parent() as VBoxContainer
	var fixed_children: int = 0
	for child: Node in column.get_children():
		if child == scene._pile_dialog_scroll or child == scene._pile_dialog_empty or not child is Control or not child.visible: continue
		available.y -= child.get_combined_minimum_size().y
		fixed_children += 1
	available.y -= column.get_theme_constant("separation") * fixed_children
	available -= scene._pile_dialog_scroll.get_theme_stylebox("panel").get_minimum_size()
	available.x -= scene._pile_dialog_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var horizontal_gap: float = scene._pile_dialog_cards.get_theme_constant("h_separation")
	var vertical_gap: float = scene._pile_dialog_cards.get_theme_constant("v_separation")
	var card_size: Vector2 = scene.PILE_DIALOG_CARD_SIZE
	var columns: int = maxi(1, floori((available.x + horizontal_gap) / (card_size.x + horizontal_gap)))
	# Scrolling can expose partial rows at both edges around the full rows.
	var rows: int = maxi(1, ceili((available.y - vertical_gap) / (card_size.y + vertical_gap)) + 1)
	return columns * rows

static func prepare_pile(scene: Node, cards: Array) -> void:
	if scene._pile_scrim != null and scene._pile_scrim.visible: return
	var remaining: Dictionary = {}
	for index: int in range(mini(cards.size(), pile_limit(scene))):
		var id: String = str(cards[index])
		remaining[id] = int(remaining.get(id, 0)) + 1
	for index: int in range(scene._pile_dialog_card_pool.size() - 1, -1, -1):
		var entry: Dictionary = scene._pile_dialog_card_pool[index]
		var id: String = str(entry["card_id"])
		if int(remaining.get(id, 0)) > 0:
			remaining[id] -= 1
			continue
		scene._pile_dialog_card_pool.remove_at(index)
		discard(scene, entry, "button")

static func close_pile(scene: Node) -> void:
	if not is_instance_valid(scene) or scene.is_queued_for_deletion() or not is_instance_valid(scene._pile_scrim) or scene._pile_scrim.visible: return
	while scene._pile_dialog_card_pool.size() > pile_limit(scene):
		discard(scene, scene._pile_dialog_card_pool.pop_back(), "button")

static func pile_entries(scene: Node, cards: Array) -> Array[Dictionary]:
	var available: Array[Dictionary]
	available.append_array(scene._pile_dialog_card_pool)
	var result: Array[Dictionary]
	for value: Variant in cards:
		var id: String = str(value)
		var chosen: int = -1
		for index: int in range(available.size()):
			if str(available[index]["card_id"]) == id:
				chosen = index
				break
		if chosen < 0 and not available.is_empty(): chosen = available.size() - 1
		var entry: Dictionary
		if chosen < 0:
			entry = scene._append_pile_dialog_card_pool_entry(id)
		else:
			entry = available[chosen]
			available.remove_at(chosen)
			if str(entry["card_id"]) != id:
				scene._pile_dialog_content_source.clear()
				entry["card_id"] = id
				entry["definition_signature"] = {}
		result.append(entry)
	# Unused entries are historical view contents, not part of this open view.
	for entry: Dictionary in available:
		scene._pile_dialog_card_pool.erase(entry)
		discard(scene, entry, "button")
	return result

static func close_pre_battle(scene: Node) -> void:
	# No caller retains the previous fight's kit/roster after this view ends.
	scene._prepared_pre_battle_view_revision += 1
	scene._prepared_pre_battle_view_ready = false
	scene._prepared_pre_battle_view_key.clear()
	scene._live_pre_battle_view_key.clear()
	if scene._node_is_alive(scene._pre_battle_panel):
		scene._clear_children_now(scene._pre_battle_panel)
