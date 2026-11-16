extends "res://scripts/combat_board_view.gd"
## Recorder-only presentation mask. Production rendering and animation are inherited.
func set_combat_state(state: Dictionary, _moves: Array = [], _attacks: Array = [], _selected: Vector2i = Vector2i(-1, -1), _label: String = "", _detail: String = "", _exits: Dictionary = {}, _icons: Dictionary = {}, shown: Dictionary = {}, stable: bool = false) -> void:
	var clean: Dictionary = shown.duplicate()
	for key: String in ["threats_at_rest", "enemy_threat_previews", "focus_actor_keys", "focus_tiles", "path_tiles", "attack_reach_tiles", "intent_callouts", "expanded_enemy_actor_keys", "show_all_enemy_intents", "hover_owner_tile"]: clean.erase(key)
	_hover_tile = Vector2i(-1, -1)
	_controller_focus_tile = Vector2i(-1, -1)
	super.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, clean, stable)

func _draw_health_bar_entry(_entry: Dictionary) -> void: pass
func _draw_unit_hud_details(_units: Array[Dictionary]) -> void: pass
func _draw_slice_hud_chips() -> void: pass
func _draw_slice_intent_chip(_badge: Dictionary) -> void: pass
func _draw_slice_intent_halo(_badge: Dictionary) -> void: pass
func _draw_slice_callouts() -> void: pass
func _draw_unit_focus(_unit: Dictionary, _center: Vector2) -> void: pass
func _draw_scene_props_for_tile(_tile: Vector2i, _obstructions: Array = []) -> void: pass
func _draw_tile_props(_grid: Array, _tile: Vector2i, _obstructions: Array = []) -> void: pass
