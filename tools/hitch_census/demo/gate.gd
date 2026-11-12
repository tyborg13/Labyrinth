extends RefCounted
const READY_TIMEOUT_S: float = 180.0
static func witness(scene: Node) -> Dictionary:
	if scene == null: return {}
	var result: Dictionary = {"scene": scene.get_instance_id()}
	if scene.get("_run_state") != null:
		var state: Dictionary = scene.get("_run_state")
		var combat: Dictionary = scene.get("_combat_state")
		result["turn"] = combat.get("turn")
		result["actor"] = combat.get("current_actor", {}).get("actor_key")
		result["selected"] = scene.get("_selected_card_index")
		result["action_index"] = scene.get("_pending_action_index")
		result.merge({"room": state.get("current_room"), "mode": state.get("mode"), "phase": scene.get("_guided_tutorial_phase_id"), "dialogue": scene.get("_dialogue_active"), "line": scene.get("_dialogue_line_index")})
		var scope: Control = scene.call("_controller_focus_scope")
		result["scope"] = scope.get_instance_id() if scope != null else 0
	return result
static func ready(scene: Node) -> bool:
	if scene == null or not scene.is_inside_tree(): return false
	if scene.get_viewport().gui_disable_input: return false
	if scene.get("_run_state") == null:
		return scene.scene_file_path.ends_with("main_menu.tscn") and not bool(scene.get("_loading_run"))
	for property: String in ["_animation_lock", "_turn_order_animating", "_equipment_swap_animation_active", "_merchant_trade_animation_active", "_pending_umbra_commit_locked", "_pre_battle_start_pending", "_campfire_choice_action_pending", "_loadout_acquisition_in_progress", "_reward_reveal_pending"]:
		if bool(scene.get(property)): return false
	if is_instance_valid(scene.get("_section_transition")): return false
	if bool(scene.call("_treasure_presentation_busy")): return false
	var purge = scene.get("_magic_purge_overlay")
	if is_instance_valid(purge) and bool(purge.get("_committing")): return false
	var map = scene.get("_large_map_view")
	if is_instance_valid(map) and map.get("activation_coord") != null and map.get("activation_coord") != Vector2i(-999, -999): return false
	return true
