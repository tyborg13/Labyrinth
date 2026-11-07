extends RefCounted

## Empty retained canvases still need one submission to erase old commands.
## Thereafter unrelated write paths can leave them alone. These are sufficient
## empty conditions from the existing draw routines, never output hashes. A
## nonempty/unknown layer keeps its original invalidation and animation cadence.
## When a layer's draw routine gains new content, add it to that layer's rule here.
static func retain_empty(board: Control, layer: Control) -> bool:
	if not layer.is_inside_tree():
		layer.set("_retained_commands_empty", false)
		return false
	var empty: bool = _empty(board, layer)
	var was_empty: bool = bool(layer.get("_retained_commands_empty"))
	layer.set("_retained_commands_empty", empty)
	return empty and was_empty

static func _empty(board: Control, layer: Control) -> bool:
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
			return str(shown.get("umbra_stage", "clear")) == "clear"
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
