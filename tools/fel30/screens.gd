extends RefCounted
## Read presentation and input surfaces without calling a game handler.

var tree: SceneTree
var inputs


func _init(host: SceneTree, driver: RefCounted) -> void:
	tree = host
	inputs = driver


func run_scene() -> Node:
	var scene := tree.current_scene
	return scene if is_instance_valid(scene) and scene.has_method("has_installed_run") else null


func visible(control: Variant) -> bool:
	return is_instance_valid(control) and control is Control and control.is_visible_in_tree()


func screen() -> String:
	var scene := tree.current_scene
	if not is_instance_valid(scene): return "between_scenes"
	if not scene.has_method("has_installed_run"):
		if scene.name == "MenuRunTransition" or scene.get("_loading_run"): return "loading"
		if scene.get("_boot_preparing"): return "title_boot"
		return "title"
	if visible(scene._run_end_recap): return "recap"
	if visible(scene._menu_scrim): return "pause"
	if visible(scene._upgrade_scrim): return {"equipment": "gear", "magic": "magic", "skills": "skills"}.get(scene._progression_overlay_mode, "gear")
	if visible(scene._grimoire_scrim): return "grimoire"
	if visible(scene._event_view): return "event_" + str(scene._event_view.page)
	if visible(scene._scavenger_shop_view): return "shop"
	if visible(scene._pre_battle_scrim): return "prebattle"
	if visible(scene._large_map_scrim): return "map"
	if scene._dialogue_active: return "dialogue"
	return str(scene._run_state.get("mode", "boot"))


func witness() -> Array:
	var scene := run_scene()
	var state: Array = [screen()]
	if scene == null: return state
	var run: Dictionary = scene._run_state
	var combat: Dictionary = scene._combat_state
	state.append_array([str(run.get("seed", "")), str(run.get("current_room", "")),
		str(combat.get("turn", "")), str(combat.get("current_actor", "")),
		str(combat.get("player", {}).get("pos", "")), str(combat.get("player", {}).get("hp", "")),
		str(combat.get("deck", {}).get("hand", [])), str(scene._selected_card_index),
		scene._player_movement_selected, scene._pending_action_index,
		scene._dialogue_line_index if scene._dialogue_active else -1,
		str(scene._run_engine.held_embers(run))])
	return state


