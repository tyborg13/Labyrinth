extends RefCounted

# A passive focus submission may add an enemy route and its destination echo.
# New presentation fields take the full submission path by default.
const FOCUS_FIELDS: Array = [  # untyped: only read with has() (Windows typed-array rule)
	"hover_owner_tile", "isolated_enemy_actor_keys", "expanded_enemy_actor_keys",
	"enemy_threat_previews", "path_tiles", "path_color", "projected_destination",
	"projected_attack_tiles", "preview_units",
]
# These bindings have a single retained paint consumer. The board continues
# to own the live copies used by navigation, tooltips and the layout solver.
const FOCUS_LOCAL_BINDINGS: Dictionary = {
	&"move_tiles": "overlays",
	&"_move_tiles_lookup_cache": "overlays",
	&"_attack_tiles_lookup_cache": "overlays",
	&"_focus_tiles_lookup_cache": "overlays",
	&"_confirmation_target_tiles_lookup_cache": "overlays",
	&"_objective_exit_tiles_lookup_cache": "overlays",
	&"_projected_attack_tiles_lookup_cache": "overlays",
	&"_summon_tiles_lookup_cache": "overlays",
	&"_projected_destination_tiles_lookup_cache": "overlays",
	&"_hud_layout_entries_cache": "hud",
	&"_foreground_obstruction_geometry_inputs": "foreground",
}

static func only_focus_fields(changes: Dictionary, previous: Dictionary, shown: Dictionary) -> bool:
	if not previous.has("isolated_enemy_actor_keys") or not shown.has("isolated_enemy_actor_keys"): return false
	for key: String in changes:
		if not FOCUS_FIELDS.has(key): return false
	for source: Dictionary in [previous, shown]:
		if bool(source.get("board_targeting", false)): return false
		for unit: Dictionary in source.get("preview_units", []):
			if str(unit.get("role", "")) != "enemy_move_preview": return false
	return true

# _build_visible_units places explicit previews after friendly bodies and
# before independently generated wind/rule ghosts and committed enemies.
static func replace_destination_echoes(roster: Array[Dictionary], previous: Array, echoes: Array[Dictionary]) -> Array[Dictionary]:
	var previous_keys: Dictionary = {}
	for unit: Dictionary in previous:
		previous_keys[str(unit.get("key", "illusion_preview"))] = true
	var result: Array[Dictionary]
	var inserted: bool = false
	for unit: Dictionary in roster:
		if not inserted and str(unit.get("role", "")) not in ["player", "illusion"]:
			result.append_array(echoes)
			inserted = true
		if not previous_keys.has(str(unit.get("key", ""))): result.append(unit)
	if not inserted: result.append_array(echoes)
	return result

static func can_retain_focus_effects(board: Control) -> bool:
	var shown: Dictionary = board.presentation
	return (
		is_instance_valid(board._effects_render_layer)
		and board._effects_render_layer._layer_slices._initialized
		and not protagonist_effects_active(shown)
		and not has_lethal_preview(board)
		and (shown.get("floating_texts", []) as Array).is_empty()
		and (shown.get("trap_effects", []) as Array).is_empty()
	)

static func has_chain_preview(shown: Dictionary) -> bool:
	for threat: Dictionary in shown.get("enemy_threat_previews", []):
		if str(threat.get("projected_attack_action", {}).get("type", "")) == "chain_discharge" and not (threat.get("chain_hits", []) as Array).is_empty():
			return true
	return false

## Empty retained canvases still need one submission to erase old commands.
## Thereafter unrelated write paths can leave them alone. These are sufficient
## empty conditions from the existing draw routines, never output hashes. A
## nonempty/unknown layer keeps its original invalidation and animation cadence.
## When a layer's draw routine gains new content, add it to that layer's rule here.
static func retain_empty(board: Control, layer: Control) -> bool:
	if not layer.is_inside_tree():
		layer.set("_retained_commands_empty", false)
		return false
	var empty: bool = is_empty(board, layer)
	var was_empty: bool = bool(layer.get("_retained_commands_empty"))
	layer.set("_retained_commands_empty", empty)
	return empty and was_empty

static func world_has_paint(shown: Dictionary) -> bool:
	return str(shown.get("umbra_stage", "clear")) != "clear" or not (shown.get("umbra_light_sources", []) as Array).is_empty()

static func is_empty(board: Control, layer: Control) -> bool:
	var shown: Dictionary = board.presentation
	match str(layer.get("_render_layer_kind")):
		"scene_tile":
			# Rear/front effect canvases have no ordinary tile art. After one
			# clearing draw, unrelated state/room submissions can retain them.
			# Trap and elemental/dragon passes keep their original cadence and
			# clear any old strike-trail/pixel children when they become empty.
			return int(layer.get("_render_layer_scene_effect_pass")) != 0 and (shown.get("trap_effects", []) as Array).is_empty() and not board._effect_uses_elemental_scene_depth(shown.get("effect", {}))
		"path":
			# The authored path is drawn inside each scene tile's depth pass.
			return true
		"world":
			return not world_has_paint(shown)
		"impact_floor":
			return (shown.get("impact_decals", []) as Array).is_empty()
		"ground":
			return (board.combat_state.get("loot", []) as Array).is_empty() and (board.combat_state.get("traps", []) as Array).is_empty() and (shown.get("death_site_embers", {}) as Dictionary).is_empty()
		"ambient":
			return board._campfire_scene_props().is_empty() and board._ambient_active_element_ids().is_empty()
		"foreground":
			if not board._campfire_scene_props().is_empty() or board._pillar_torch_ember_motes_active(): return false
			for source_var: Variant in shown.get("umbra_light_sources", []):
				if not source_var is Dictionary: continue
				var source: Dictionary = source_var
				if not str(source.get("id", "")).begins_with("brazier:") and (source.get("pos", Vector2i(-1, -1)) as Vector2i).x >= 0: return false
			return true
		"effect_telegraphs":
			for threat: Dictionary in shown.get("enemy_threat_previews", []):
				if str(threat.get("projected_attack_action", {}).get("type", "")) == "chain_discharge" and not (threat.get("chain_hits", []) as Array).is_empty(): return false
			return true
		"action_floor":
			if not (shown.get("trap_effects", []) as Array).is_empty() or not (shown.get("trap_trigger_previews", []) as Array).is_empty(): return false
			var effect: Dictionary = shown.get("effect", {})
			return effect.is_empty() or bool(effect.get("preview", false)) or effect.has("en02_mechanic") or effect.has("en04_mechanic") or board.AttackFxLibrary.style_for_effect(effect) == board.AttackFxLibrary.STYLE_DEFAULT
	return false

# Only the AOE resolution wash and the Wind push front read progress on the
# overlay canvas. Ranged force diamonds are static; other effects paint later.
static func overlay_effect_inputs(shown: Dictionary) -> Array:
	var effect: Dictionary = shown.get("effect", {})
	if str(effect.get("en02_mechanic", "")) == "wind_push":
		return [effect, shown.get("effect_progress", 0.0)]
	if str(effect.get("kind", "")) == "aoe" and not bool(effect.get("preview", false)):
		return [effect, shown.get("effect_progress", 1.0)]
	if str(effect.get("kind", "")) == "ranged" and (effect.get("from", Vector2i(-1, -1)) as Vector2i).x >= 0 and (effect.get("to", Vector2i(-1, -1)) as Vector2i).x >= 0:
		return [effect.get("force_tiles", [])]
	return []

static func has_lethal_preview(board: Control) -> bool:
	for preview: Dictionary in board._damage_preview_map().values():
		if bool(preview.get("lethal", false)): return true
	return false

static func protagonist_effects_active(shown: Dictionary) -> bool:
	return not (shown.get("effect", {}) as Dictionary).is_empty() or (not bool(shown.get("reduced_motion", false)) and float(shown.get("protagonist_motion", {}).get("charge", 0.0)) > 0.0)

static func strike_changes_need_effects_redraw(board: Control) -> bool:
	# Trail-only windup submits to an independent child. Preserve the parent's
	# existing cadence whenever hit/preview FX, charge FX or lethal markers are
	# present, including bespoke effects with progress-dependent actor sockets.
	return protagonist_effects_active(board.presentation) or has_lethal_preview(board)

static func bind_retained_strike_frame(board: Control, layer: Control) -> void:
	# Match the redraw path's late bindings even when its canvas is retained.
	# Run after submission flush so trail preparation keeps its original order.
	layer.set("_idle_elapsed", board.get("_idle_elapsed"))
	layer.set("_hover_tile", board.get("_hover_tile"))
	layer.set("_controller_focus_tile", board.get("_controller_focus_tile"))

# Ordinary melee's changing light is already submitted by _sync_strike_trail
# to its independent child. The parent has no progress-dependent primitives.
# Unknown/bespoke descriptors stay conservative as new effects are introduced.
static func effects_read_progress(board: Control) -> bool:
	var shown: Dictionary = board.presentation
	if not (shown.get("trap_effects", []) as Array).is_empty() or has_lethal_preview(board): return true
	var effect: Dictionary = shown.get("effect", {})
	if str(effect.get("kind", "")) != "melee": return true
	for key: String in effect:
		if key not in ["kind", "actor_key", "enemy_type", "from", "to", "element", "seed", "action_type", "protagonist_melee", "illusion_echo", "protagonist_weapon_motion"]: return true
	return false

# An otherwise unrelated effect submission also samples any wall-clock art on
# this canvas. Preserve that exact sampling cadence, including the higher rate
# while an attack resolves; falling back to the idle 30 Hz pulse changes pixels.
static func overlay_reads_clock(board: Control) -> bool:
	var shown: Dictionary = board.presentation
	return (
		board.ThreatTiles.needs_pulse(shown, board._rest_threat_tile_alphas)
		or (board.WindView.has_forecast(board) and not bool(shown.get("reduced_motion", false)))
		or (bool(shown.get("pulse_attack_tiles", false)) and not board.attack_tiles.is_empty())
		or (bool(shown.get("pulse_exit_tiles", false)) and not board.exit_tiles.is_empty())
		or not board._confirmation_target_tiles_lookup_cache.is_empty()
		or not board._objective_exit_tiles_lookup_cache.is_empty()
		or board.exit_tiles.has(board._controller_focus_tile)
	)

# Effect progress incidentally samples wall-clock overlay art. Only those slices
# need resubmission when the effect's actual floor inputs remain unchanged.
static func overlay_clock_only(changed: Dictionary, previous: Dictionary, shown: Dictionary) -> bool:
	for key: String in changed:
		if key != "effect_progress": return false
	return overlay_effect_inputs(previous) == overlay_effect_inputs(shown)

# A targeting transition used to refresh every scene tile. Keep the tiles
# with independent paint clocks and any owned operations whose isolation fade
# can change. Ordinary empty floor and boundary stone have no clock.
static func release_targeting_scene_tiles(board: Control, previous: Dictionary) -> Dictionary:
	var shown: Dictionary = board.presentation
	var tiles: Dictionary = preload("res://scripts/board_preview_redraws.gd").tiles(board, previous, shown)
	for sources: Dictionary in [
		board._units_by_draw_tile_cache, board._scene_props_by_tile,
		board._terrain_by_tile, board._loot_by_tile, board._rule_threat_tiles,
	]:
		tiles.merge(sources)
	for tile: Vector2i in board.BoardSurfaceRules.tiles(board.combat_state):
		tiles[tile] = true
	var grid: Array = board.combat_state.get("grid", [])
	var live_surface_paint: bool = false
	for key: String in ["surface_preview_events", "surface_preview_arcs", "surface_feedback_events", "throw_surface_frames", "combat_feel_surface_frames"]:
		if not shown.get(key, []).is_empty():
			live_surface_paint = true
			break
	for tile: Vector2i in board._rendered_tiles_in_draw_order():
		if live_surface_paint or board._tile_renders_as_pillar(grid, tile):
			tiles[tile] = true
	return tiles

static func blink_preview_active(shown: Dictionary) -> bool:
	var effect: Dictionary = shown.get("effect", {})
	return str(effect.get("kind", "")) == "blink" and bool(effect.get("preview", false))

# The ordinary presentation diff owns surfaces, paths, previews and threats.
# The targeting edge additionally samples the artists' existing paint clocks.
static func targeting_clock_tiles(board: Control) -> Dictionary:
	var tiles: Dictionary = {}
	var still: bool = bool(board.presentation.get("reduced_motion", false))
	if not still:
		for tile: Vector2i in board._animated_surface_tiles:
			if board._board_tile_is_visible_to_player(tile): tiles[tile] = true
		for loot: Dictionary in board.combat_state.get("loot", []):
			if not bool(loot.get("claimed", false)) and board._is_floating_loot(loot):
				tiles[loot["pos"]] = true
	for prop: Dictionary in board.presentation.get("scene_props", []):
		if (board._scene_prop_idle_animation_active(prop) or str(prop.get("kind", "")) == "campfire_bonfire"):
			tiles[prop.get("tile", Vector2i(-1, -1))] = true
	if board._pillar_torch_idle_animation_active() or (not still and board._pillar_torch_light_texture != null):
		var grid: Array = board.combat_state.get("grid", [])
		for tile: Vector2i in board._rendered_tiles_in_draw_order():
			if board._tile_renders_as_pillar(grid, tile): tiles[tile] = true
	return tiles

static func targeting_samples_unit_clock(board: Control, unit: Dictionary) -> bool:
	if board._unit_impact_shake_strength(unit) > 0.0: return true
	if not bool(board.presentation.get("reduced_motion", false)):
		if bool(unit.get("burrowed", false)) or str(unit.get("role", "")) in ["illusion_preview", "enemy_move_preview"]:
			return true
	if board._unit_idle_frames(unit).is_empty() or bool(unit.get("death_animation", false)): return false
	var silhouettes: Node = board._occlusion_silhouettes
	if not is_instance_valid(silhouettes) or not silhouettes.tool_enabled: return true
	var canvas: Control = silhouettes.team.bodies.get(str(unit.get("key", "")))
	return not is_instance_valid(canvas) or board._idle_frame_index(unit) != canvas._idle_frame_index(unit)

static func rule_outline_tiles(board: Control, previous: Dictionary, previous_shown: Dictionary) -> Dictionary:
	var current: Dictionary = board._floor_threat_coverage
	var old_rules: Dictionary = previous.get("rules", {})
	var new_rules: Dictionary = current.get("rules", {})
	var candidates: Dictionary = old_rules.merged(new_rules)
	if board._targeting_redraw_baseline(): return candidates
	var dirty: Dictionary = {}
	for tile: Vector2i in candidates:
		var visible: bool = board._board_tile_is_visible_to_player(tile)
		if _rule_outline_inputs(tile, previous, previous_shown, visible) != _rule_outline_inputs(tile, current, board.presentation, visible):
			dirty[tile] = true
	return dirty

static func _rule_outline_inputs(tile: Vector2i, coverage: Dictionary, shown: Dictionary, visible: bool) -> Array:
	if not coverage.get("rules", {}).has(tile) or not (visible or coverage.get("announced", {}).has(tile)): return []
	var alpha: float = float(coverage.get("alphas", {}).get(tile, -1.0))
	if alpha < 0.0: return []
	if not shown.has("isolated_enemy_actor_keys"): return [alpha]
	var isolation = preload("res://scripts/board_threat_isolation.gd")
	var owners: Array = coverage.get("owners", {}).get(tile, [])
	return [alpha, owners, isolation.alpha_for(owners, shown["isolated_enemy_actor_keys"])]
