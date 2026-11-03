extends "res://scripts/combat_board_view.gd"

## Proof extraction only. No reference frame delegates to this painter.
## Occluder mode draws one identified primitive, with no retained tile ordering.
var proof_mode: String = "production"
var proof_occluder: Dictionary = {}
var proof_ids: Dictionary = {}
var proof_calibration: bool = false
var proof_owner: Control

func _id_owner() -> Control:
	return proof_owner if is_instance_valid(proof_owner) else self

func _ensure_art_treatment() -> void:
	super._ensure_art_treatment()
	if proof_mode=="production_id":
		var unlit := CanvasItemMaterial.new()
		unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unlit
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _paint_id(id: String) -> void:
	var owner: Control = _id_owner()
	if owner.proof_calibration and id!="actor": return
	if not owner.proof_ids.has(id): return
	var sprite: Dictionary = owner.proof_ids[id]
	draw_texture_rect(sprite["texture"],Rect2(sprite["offset"],sprite["image"].get_size()),false)

func _draw_static_board_contents() -> void:
	if proof_mode!="production_id":
		super._draw_static_board_contents()
		return
	if combat_state.is_empty(): return
	for tile: Vector2i in _rendered_tiles_in_draw_order(): _draw_floor_tile(combat_state["grid"],tile)

func _draw_floor_tile(grid: Array, tile: Vector2i) -> void:
	if proof_mode=="production_id": _paint_id("floor_%d_%d"%[tile.x,tile.y])
	else: super._draw_floor_tile(grid,tile)

func _draw_scene_props_for_tile(tile: Vector2i, obstruction_entries: Array = []) -> void:
	if proof_mode!="production_id":
		super._draw_scene_props_for_tile(tile,obstruction_entries)
		return
	for index: int in range(presentation.get("scene_props",[]).size()):
		if presentation["scene_props"][index]["tile"]==tile: _paint_id("scene_%d"%index)

func _draw_tile_props(grid: Array, tile: Vector2i, obstruction_entries: Array = []) -> void:
	if proof_mode!="production_id":
		super._draw_tile_props(grid,tile,obstruction_entries)
		return
	_paint_id("grid_%d_%d"%[tile.x,tile.y])
	for index: int in range(combat_state.get("terrain",[]).size()):
		if combat_state["terrain"][index]["pos"]==tile: _paint_id("terrain_%d"%index)

func _draw_board_surface(tile: Vector2i) -> void:
	if proof_mode!="production_id": super._draw_board_surface(tile)


func _uses_protagonist_cutout() -> bool: return false
func _umbra_visual_time_seconds() -> float: return 0.0

func _create_retained_render_layer(layer_name: String, layer_kind: String) -> Control:
	var layer: Control = super._create_retained_render_layer(layer_name,layer_kind)
	layer.proof_mode = proof_mode
	layer.proof_owner = self
	layer._ensure_art_treatment()
	return layer

func _create_static_render_cache() -> void:
	if proof_mode=="production": super._create_static_render_cache()
	else: _ensure_art_treatment()

func _create_dynamic_render_layer() -> void:
	if proof_mode in ["production","production_id","actor","actor_mask"]: super._create_dynamic_render_layer()

func _sync_enemy_shadow_dissolve_effects() -> void:
	if proof_mode in ["production","actor","actor_mask"]: super._sync_enemy_shadow_dissolve_effects()
	if proof_mode in ["actor","actor_mask"] and not _is_dynamic_render_layer:
		for effect: Control in _enemy_shadow_dissolve_effects_by_key.values():
			if effect.get_parent()!=self: effect.reparent(self,false)

func _draw_enemy_intent_compass(unit: Dictionary) -> void:
	if proof_mode!="actor_mask": super._draw_enemy_intent_compass(unit)

func _draw_unit_body(unit: Dictionary) -> void:
	if unit.get("key","")!="enemy_1": return
	if proof_mode=="production_id": _paint_id("actor")
	else: super._draw_unit_body(unit)

func _draw_unit_shadow(unit: Dictionary) -> void:
	if proof_mode!="actor_mask": super._draw_unit_shadow(unit)

func _draw_rect_ground_shadow(tile: Vector2i, rect: Rect2, width_scale: float, height_scale: float, opacity: float) -> void:
	if proof_mode!="occluder_mask": super._draw_rect_ground_shadow(tile,rect,width_scale,height_scale,opacity)

func _draw_wall_segment_shadow(tile: Vector2i, orientation: String, rect: Rect2) -> void:
	if proof_mode!="occluder_mask": super._draw_wall_segment_shadow(tile,orientation,rect)

func _draw_terrain_health_bar(terrain: Dictionary, rect: Rect2) -> void:
	if proof_mode!="occluder_mask": super._draw_terrain_health_bar(terrain,rect)

# Light/shadow/HUD sprites do not own solid geometry in the ID proof.
func _draw_pillar_torch_flame_light(tile: Vector2i, rect: Rect2, side: float, alpha: float) -> void:
	if proof_mode!="occluder_mask": super._draw_pillar_torch_flame_light(tile,rect,side,alpha)

func _draw_pillar_torch_floor_light(grid: Array, tile: Vector2i, polygon: PackedVector2Array) -> void:
	if proof_mode!="occluder_mask": super._draw_pillar_torch_floor_light(grid,tile,polygon)

func _draw_floor_contact_shading(grid: Array, tile: Vector2i, polygon: PackedVector2Array) -> void:
	if proof_mode!="occluder_mask": super._draw_floor_contact_shading(grid,tile,polygon)

func _draw_powder_keg_fuse_glow(rect: Rect2, opacity: float) -> void:
	if proof_mode!="occluder_mask": super._draw_powder_keg_fuse_glow(rect,opacity)

func _draw_campfire_prop_glow(tile: Vector2i, rect: Rect2) -> void:
	if proof_mode!="occluder_mask": super._draw_campfire_prop_glow(tile,rect)

func _draw_board_commands() -> void:
	if proof_mode in ["production","production_id"]:
		# Isolate world paint: no HUD/ambient particles can contaminate comparisons.
		if _is_dynamic_render_layer and (_render_layer_kind!=RENDER_LAYER_SCENE_TILE or _render_layer_scene_effect_pass!=0): return
		super._draw_board_commands()
		return
	_submitted_shadow_meshes.clear()
	if combat_state.is_empty(): return
	if proof_mode in ["actor","actor_mask"]:
		# Retained tile children are needed by the production death dissolve.
		# Only one actor is drawn, so their relative order is irrelevant here.
		if not _is_dynamic_render_layer:
			for unit: Dictionary in _visible_units(): _draw_unit_body(unit)
		return
	if proof_mode not in ["occluder","occluder_mask"] or proof_occluder.is_empty(): return
	var tile: Vector2i = proof_occluder["tile"]
	var grid: Array = combat_state["grid"]
	match str(proof_occluder["renderer"]):
		"floor":
			_draw_floor_tile(grid,tile)
			_draw_board_surface(tile)
		"grid_prop":
			# Structural grid sprite only; terrain and scene props get their own pass.
			var old_terrain: Dictionary = _terrain_by_tile
			_terrain_by_tile = {}
			_draw_tile_props(grid,tile,_foreground_obstruction_entries_cache)
			_terrain_by_tile = old_terrain
		"terrain": _draw_terrain_object(proof_occluder["data"],_foreground_obstruction_entries_cache)
		"scene_prop":
			var old_props: Dictionary = _scene_props_by_tile
			_scene_props_by_tile = {tile:[proof_occluder["data"]]}
			_draw_scene_props_for_tile(tile,_foreground_obstruction_entries_cache)
			_scene_props_by_tile = old_props
