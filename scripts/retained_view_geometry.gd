extends RefCounted

# Hidden native containers may not have sorted yet. Resolve their future scroll
# height from the existing dialog and its chrome without constructing/showing a
# second screen or changing any layout value.
static func scroll_height(scroll: ScrollContainer, dialog: Control) -> float:
	if scroll.is_visible_in_tree() and scroll.size.y > 0.0: return scroll.size.y
	var height: float = maxf(dialog.size.y, dialog.custom_minimum_size.y)
	var branch: Node = scroll
	while branch != dialog:
		var parent: Node = branch.get_parent()
		if parent == null: return 0.0
		if parent is MarginContainer:
			height -= parent.get_theme_constant("margin_top") + parent.get_theme_constant("margin_bottom")
		elif parent is PanelContainer:
			height -= parent.get_theme_stylebox("panel").get_minimum_size().y
		elif parent is VBoxContainer:
			var count: int = 0
			for child: Node in parent.get_children():
				if not child is Control or not child.visible or child.top_level: continue
				count += 1
				if child != branch: height -= child.get_combined_minimum_size().y
			height -= parent.get_theme_constant("separation") * maxi(0, count - 1)
		branch = parent
	return maxf(0.0, height)

# A hidden flow may still report its pre-wrap minimum. Use the single-column
# upper bound until it has live geometry; speculative rows cannot accumulate
# merely because their container has not sorted yet.
static func minimum_height(control: Control) -> float:
	var height: float = control.get_combined_minimum_size().y
	if control.is_visible_in_tree(): return height
	var children: Array[Control]
	for child: Node in control.get_children():
		if child is Control and child.visible and not child.top_level: children.append(child)
	if control is VBoxContainer or control is HFlowContainer:
		var total: float = 0.0
		for child: Control in children: total += minimum_height(child)
		var gap: int = control.get_theme_constant("v_separation" if control is HFlowContainer else "separation")
		height = maxf(height, total + gap * maxi(0, children.size() - 1))
	elif control is MarginContainer or control is PanelContainer:
		var largest: float = 0.0
		for child: Control in children: largest = maxf(largest, minimum_height(child))
		if control is MarginContainer:
			largest += control.get_theme_constant("margin_top") + control.get_theme_constant("margin_bottom")
		else:
			largest += control.get_theme_stylebox("panel").get_minimum_size().y
		height = maxf(height, largest)
	return height
