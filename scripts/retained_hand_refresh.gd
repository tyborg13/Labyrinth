extends RefCounted

## Keep plain live slots through a deal. Matching cards retain their authored
## motion; a changed face gets the same reset/geometry as pooled re-entry, but
## avoids exiting/re-entering every descendant and propagating the theme again.
static func entries(scene: Node, next_hand: Array) -> Dictionary:
	var result: Dictionary = {}
	var available: Array = []
	for child: Node in scene.hand_box.get_children():
		var widget: Control = scene._card_widget_descendant(child)
		if widget == null or widget.get_parent() == null or widget.get_parent().get_parent() != child: continue
		available.append({"card_id": widget.card_id, "widget": widget, "slot": child,
			"definition_signature": int(widget.get_meta("hand_card_definition_signature", -1))})
	for index: int in range(next_hand.size()):
		for entry: Dictionary in available:
			if str(entry["card_id"]) != str(next_hand[index]): continue
			result[index] = entry
			available.erase(entry)
			break
	for index: int in range(next_hand.size()):
		if result.has(index) or available.is_empty(): continue
		# The pool's fallback uses the last available slot too. Changed identities
		# must not inherit pointer/focus ownership from the card that occupied it.
		var entry: Dictionary = available.pop_back()
		var widget: Control = entry["widget"]
		widget.prepare_for_pool()
		# Match the old tree-exit reset without propagating an exit/re-entry
		# through the card subtree. A new face must snap rather than inherit
		# the previous card's neighbour spread or closing-gap motion.
		scene.hand_box._on_child_exiting_tree(entry["slot"])
		var focused: Control = widget.get_viewport().gui_get_focus_owner()
		if focused != null and (focused == widget or widget.is_ancestor_of(focused)):
			focused.release_focus()
		entry["card_id"] = str(next_hand[index])
		entry["definition_signature"] = -1
		entry["rebound"] = true
		result[index] = entry
	return result
