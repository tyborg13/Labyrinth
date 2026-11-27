extends "res://tools/fel01/policy.gd"
## Store the actual dispatched input, with typed coordinates and scene-relative controls.


static func encode(scene: Node, action: Dictionary) -> Dictionary:
	var saved: Dictionary = action.duplicate()
	if action.has("control"):
		saved["control_path"] = str(scene.get_path_to(action["control"]))
		saved.erase("control")
	if action.get("kind") == "dialogue":
		saved.erase("args") # Rebuild the inherited left-button press on replay.
	return saved


func replay(scene: Node, saved: Dictionary) -> bool:
	var action: Dictionary = saved.duplicate()
	if saved.has("control_path"):
		var control: Node = scene.get_node_or_null(NodePath(saved["control_path"]))
		if not control is Control or not control.is_visible_in_tree():
			# Dynamically generated @Button names change on Continue. Resolve
			# the real offer by its signal and text. Continue can also finish
			# the guided introduction before constructing its Skip button.
			var matches: Array[Control]
			for offer: Dictionary in offers(scene):
				if offer.get("signal") == saved.get("signal") and offer.get("text", "") == saved.get("text", ""):
					matches.append(offer["control"])
			if matches.size() == 1:
				control = matches[0]
			elif saved.get("text") == "Skip Tutorial" and str(saved["control_path"]).contains("ContextualCombatPromptHost"):
				scene._guided_tutorial_dismiss()
				return not scene._guided_tutorial_is_active()
			else:
				return false
		if control is BaseButton and control.disabled: return false
		action["control"] = control
	if saved.get("kind") == "dialogue": action["args"] = [_click()]
	if saved.get("kind") == "card":
		var hand: Array = scene._combat_state.get("deck", {}).get("hand", [])
		var index: int = saved["args"][0]
		if index >= hand.size() or hand[index] != saved["card_id"]: return false
	dispatch(scene, action)
	return true
