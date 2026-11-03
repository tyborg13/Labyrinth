extends RefCounted
## Shared attack resolution: player, enemy and team-neutral board attacks.
const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")
const BurrowRules = preload("res://scripts/enemy_mechanics/burrow.gd")
const CardKeywordRules = preload("res://scripts/card_keyword_rules.gd")
const CombatTerrainRules = preload("res://scripts/combat_terrain_rules.gd")
const CommonRelicRules = preload("res://scripts/common_relic_rules.gd")
const GuardianRelicRules = preload("res://scripts/guardian_relic_rules.gd")
const IllusionCardRules = preload("res://scripts/illusion_card_rules.gd")
const IllusionRelicRules = preload("res://scripts/illusion_relic_rules.gd")
const ManeuverRules = preload("res://scripts/maneuver_rules.gd")
const ReflectRules = preload("res://scripts/enemy_mechanics/reflect.gd")
const RetaliateRules = preload("res://scripts/retaliate_rules.gd")
const SurfaceCardRules = preload("res://scripts/surface_card_rules.gd")
const SurfaceRelicRules = preload("res://scripts/surface_relic_rules.gd")

static func resolve(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i, actor_kind: String = "player", actor_id: int = -1, trace: Dictionary = {}, supplied_impact: Array[Vector2i] = []) -> Dictionary:
	action = action.duplicate(true)
	var player_bonuses: bool = actor_kind == "player"
	if actor_kind == "player" and GuardianRelicRules.amount(state,"force_enemy_line") > 0:
		action["_group_force_context"] = {"moved_ids":{}}
	if actor_kind == "player" and IllusionRelicRules.puppet_action(engine, state, action) and not IllusionCardRules.illusion_at(engine, state, target).is_empty():
		state = engine._trigger_player_bleed_for_action(state, action)
		if engine.combat_outcome(state) == "defeat": return state
		state = IllusionRelicRules.resolve_puppet(engine, state, action, target)
		if int(action.get("damage", 0)) > 0: engine._mark_first_attack_used(state)
		return state
	var raise_outcrop: bool = actor_kind == "player" and int(action.get("outcrop_health", 0)) > 0 and CombatTerrainRules.is_empty_floor(engine, state, target)
	var performance_started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var capture_states: bool = trace.has("chain_hits") and bool(trace.get("capture_states", true))
	var origin: Vector2i = action.get("_origin_tile", (engine._surface_actor(state, actor_kind, actor_id)).get("pos", engine.INVALID_TILE))
	var resolved: Dictionary = action.duplicate(true)
	if str(action.get("type", "")) in ["push", "pull"]:
		resolved[str(action["type"])] = int(action.get("amount", 0))
	var impact: Array[Vector2i] = supplied_impact.duplicate()
	if impact.is_empty():
		if str(action.get("type", "")) == "aoe":
			impact = engine._best_aoe_tiles_for_target(state, action, engine._board_aoe_center(action, target, origin), actor_kind != "player")
		else:
			impact.append(target)
	var route_action: Dictionary = resolved.duplicate(true)
	if actor_kind == "player":
		for index: int in engine._enemy_indices_in_tiles(state, impact):
			if not engine.is_enemy_visible_to_player(state, (state.get("enemies", []) as Array)[index]) or not BurrowRules.targetable((state.get("enemies", []) as Array)[index], action):
				continue
			var target_action: Dictionary = engine._action_with_target_state_relic_modifiers(state, resolved, index)
			route_action["chain"] = maxi(int(route_action.get("chain", 0)), int(target_action.get("chain", 0)))
	# Illusion echoes repeat damage only: no Bleed payment and no Flint fuel.
	var echo: bool = bool(action.get("_illusion_echo", false))
	if actor_kind == "player" and not echo:
		state = engine._trigger_player_bleed_for_action(state, resolved)
		if engine.combat_outcome(state) == "defeat":
			return state
	if actor_kind == "enemy" and ReflectRules.reflects(engine, state, resolved, origin, engine._enemy_index_at_tile(state, target)):
		return ReflectRules.bounce(engine, state, engine._enemy_index_at_tile(state, target), int(resolved.get("damage", 0)), actor_kind, actor_id)
	var melee_fuel: Dictionary = CommonRelicRules.consume_melee_target(engine, state, resolved, target, actor_kind == "player" and not echo)
	var plan: Dictionary = engine._board_attack_plan(state, route_action, impact, actor_kind)
	if actor_kind == "player" and bool(action.get("also_hits_near_illusions", false)):
		IllusionCardRules.append_refraction_hits(engine, state, plan)
	var family_context: Dictionary = {} if echo else SurfaceCardRules.begin_attack(engine, state, resolved, impact, actor_kind)
	performance_started = engine._record_runtime_performance_phase("board_attack_plan_total", performance_started)
	engine._resolver_journal("begin", state, {"kind": "action"})
	preload("res://scripts/reaction_presentation_trace.gd").action_started(trace, state)
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var consumed: Dictionary = plan["consumed"] as Dictionary
	var used_conductors: Dictionary = plan["used_conductors"] as Dictionary
	var capture_route: bool = int(route_action.get("chain", 0)) > 0 or not used_conductors.is_empty() or action.has("_ranged_relay") or bool(plan.get("refraction", false))
	capture_states = capture_states and capture_route
	# Ordinary Electrified is reusable. Stormcoal Fire pays for conduction.
	for tile: Vector2i in engine._sorted_tiles_from_lookup(used_conductors):
		var event: Dictionary = {"kind": "surface_conducted", "surface": BoardSurfaceRules.element_at(state, tile), "tile": tile, "reason": str(used_conductors[tile]), "source": engine._surface_source(state, action)}
		if IllusionRelicRules.copper_active(engine, state, action, actor_kind) and IllusionRelicRules.virtual_conductor(engine, state, tile):
			event["surface"] = "electrified"
			event["virtual"] = true
		BoardSurfaceRules.record_event(state, event)
	var removal_source: Dictionary = SurfaceRelicRules.removal_source(state, "conductive_fire") if actor_kind == "player" and SurfaceRelicRules.has_effect(state, "conductive_fire") else {}
	for tile: Vector2i in engine._sorted_tiles_from_lookup(consumed):
		BoardSurfaceRules.remove(state, tile, "elemental", str(consumed[tile]), removal_source)
	var affected: Array[int]
	var player_struck: bool = false
	var struck_player_tile: Vector2i = engine.INVALID_TILE
	var attack_health_loss: int = 0
	var attack_block_loss: int = 0
	var struck_illusions: Dictionary = {}
	var retaliators: Dictionary = {}
	var native_trace: Array = []
	var rebound_route: Array = []
	var relay: Dictionary = action.get("_ranged_relay",{}) as Dictionary
	if not relay.is_empty():
		var relay_hit: Dictionary = {"kind":"relay","from":relay["from"],"to":relay["relay"],"range_relay":true}
		if capture_states: relay_hit["state"] = state.duplicate(true)
		native_trace.append(relay_hit)
	performance_started = engine._record_runtime_performance_phase("board_attack_conduction", performance_started)
	# Squall: every enemy in the pattern is pushed away from its center (the one
	# on the center away from the attacker), farthest first.
	var from_center: bool = actor_kind == "player" and ManeuverRules.uses_from_center(action)
	var aoe_center: Vector2i = engine._board_aoe_center(action, target, origin)
	var ordered_hits: Array = plan["hits"] as Array
	if from_center:
		ordered_hits = ManeuverRules.order_from_center_hits(engine, ordered_hits, aoe_center)
	elif actor_kind == "player" and engine._forced_movement_amount(resolved) > 0:
		# Wind Shear and friends: farthest first for pushes, nearest first for
		# pulls, so no target collides with one about to move out of the way.
		ordered_hits = ManeuverRules.order_force_hits(engine, ordered_hits, origin, engine._forced_movement_pushes(resolved))
	for hit: Dictionary in ordered_hits:
		var trace_hit: Dictionary = {"kind": str(hit["kind_trace"]), "conduction": str(hit["kind_trace"]) == "conduction", "from": hit["from"], "to": hit["to"]}
		if not relay.is_empty() and hit["from"] == hit["to"]:
			trace_hit["from"] = relay["relay"]
			trace_hit["relay_delivery"] = true
		if hit.has("path"):
			trace_hit["path"] = hit["path"]
		if hit.has("id"):
			trace_hit["actor_kind"] = hit["kind"]
			trace_hit["id"] = hit["id"]
			if str(hit["kind"]) == "enemy":
				trace_hit["enemy_id"] = hit["id"]
		if str(hit["kind_trace"]) == "relay":
			if capture_states:
				trace_hit["state"] = state.duplicate(true)
			native_trace.append(trace_hit)
			rebound_route.append(trace_hit)
			continue
		var hit_action: Dictionary = resolved.duplicate(true)
		if actor_kind == "player" and hit.has("enemy_hop"):
			trace_hit["base_damage"] = int(hit_action.get("damage",0))
			hit_action["damage"] = GuardianRelicRules.boosted(int(hit_action.get("damage",0)),int(hit["enemy_hop"]),GuardianRelicRules.amount(state,"chain_hop_damage"))
			trace_hit["enemy_hop"] = int(hit["enemy_hop"])
			trace_hit["chain_bonus_damage"] = int(hit_action["damage"])-int(trace_hit["base_damage"])
		var bonus: Dictionary = hit_action.get("surface_bonus", {}) as Dictionary
		var target_bonus: bool = str(bonus.get("subject", "")) == "target" and engine._surface_condition_met(state, bonus, hit["to"])
		var assisted_bonus: bool = str(bonus.get("subject", "")) == "conducted" and bool(hit.get("electrically_assisted", false))
		if target_bonus or assisted_bonus:
			for field: String in engine.SURFACE_BONUS_FIELDS:
				if bonus.has(field):
					hit_action[field] = int(hit_action.get(field, 0)) + int(bonus[field])
		if str(hit["kind"]) == "enemy":
			var index: int = engine._enemy_index_for_id(state, int(hit["id"]))
			if index < 0 or int(engine._surface_actor(state, "enemy", int(hit["id"])).get("hp", 0)) <= 0:
				continue
			if player_bonuses:
				hit_action = engine._action_with_target_state_relic_modifiers(state, hit_action, index)
				if not echo: hit_action = engine._action_with_light_target_skill_modifier(state, hit_action, index)
				hit_action = CardKeywordRules.action_with_state_bonus(engine, state, hit_action, index)
				hit_action = CommonRelicRules.before_melee_hit(state, hit_action, hit, melee_fuel)
			hit_action = SurfaceCardRules.before_enemy_hit(engine, state, hit_action, hit, index, family_context)
			if str(hit.get("kind_trace", "")) == "actor" and index == engine._enemy_index_at_tile(state, target) and ReflectRules.reflects(engine, state, hit_action, origin, index):
				var reflected_damage: int = engine._damage_for_enemy_target(state, hit_action, index) if actor_kind == "player" else int(hit_action.get("damage", 0))
				state = ReflectRules.bounce(engine, state, index, reflected_damage, actor_kind, actor_id)
				continue
			if not echo: state = engine._sunder_enemy_defense(state, index, int(hit_action.get("sunder", 0)))
			var damage: int = engine._damage_for_enemy_target(state, hit_action, index, player_bonuses)
			if actor_kind == "player" and not echo and damage > 0:
				RetaliateRules.collect_player_hit(engine, state, retaliators, int(hit["id"]), hit_action, origin, damage)
			trace_hit["damage"] = IllusionRelicRules.direct_amount(engine, state, engine._surface_actor(state, "enemy", int(hit["id"])), damage) if player_bonuses else damage
			if echo:
				damage = IllusionRelicRules.half(int(trace_hit["damage"]))
				trace_hit["damage"] = damage
				state = engine._damage_enemy(state, index, damage, true, engine._action_pierces_defense(hit_action), false, false)
			else:
				state = engine._damage_enemy(state, index, damage, true, engine._action_pierces_defense(hit_action), player_bonuses)
			if not melee_fuel.is_empty(): BoardSurfaceRules.sync_chilled(state)
			if damage > 0:
				state = engine._consume_enemy_expose(state, index)
			if action.has("_group_force_context"): hit_action["_group_force_context"] = action["_group_force_context"]
			# The aimed line belongs to the primary target; Chain hops push from
			# their hop origin along their own default line.
			if hit["from"] != hit["to"]: hit_action.erase("force_direction")
			var force_source: Vector2i = origin if hit["from"] == hit["to"] else hit["from"]
			if from_center:
				force_source = ManeuverRules.from_center_source(engine, state, int(hit["id"]), aoe_center, origin)
			state = engine._apply_action_keywords_to_enemy(state, index, IllusionRelicRules.echo_forces(hit_action) if echo else hit_action, force_source, player_bonuses)
			if not echo: engine._apply_stagger_to_enemy(state, int(hit["id"]), int(hit_action.get("stagger", 0)))
			state = SurfaceCardRules.after_enemy_hit(engine, state, hit_action, family_context)
			if player_bonuses and not echo: engine._mark_light_target_skill_trigger(state, hit_action)
			affected.append(index)
		else:
			var hit_origin: Vector2i = origin
			if actor_kind == "enemy" and bool(hit_action.get("radial_force",false)):
				# Ring force radiates from the nearest footprint tile, like every
				# enemy Push/Pull; the ordinary straight-line resolver picks the line.
				hit_origin = engine._closest_enemy_tile_to(engine._surface_actor(state,"enemy",actor_id),hit["to"])
			if actor_kind == "enemy" and str(hit["kind"]) == "illusion":
				IllusionCardRules.note_enemy_hit(engine, state, struck_illusions, hit, hit_action)
			var block_before_hit: int = int((state.get("player", {}) as Dictionary).get("block", 0))
			var health_lost_before_hit: int = int((state.get("run_stats", {}) as Dictionary).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0))
			state = engine._damage_actor_target(state, hit, int(hit_action.get("damage", 0)), engine._action_pierces_defense(hit_action), hit_action)
			if actor_kind == "enemy" and str(hit["kind"]) == "player":
				# Count health actually lost before Defiance/prevent-lethal recovery.
				attack_health_loss += maxi(0, int((state.get("run_stats", {}) as Dictionary).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0)) - health_lost_before_hit)
				attack_block_loss += maxi(0, block_before_hit - int(state["player"].get("block", 0)))
			if not player_struck and actor_kind == "enemy" and str(hit["kind"]) == "player" and int(hit_action.get("damage", 0)) > 0:
				# Retaliate judges melee range where the strike landed, before knockback.
				player_struck = true
				struck_player_tile = (state.get("player", {}) as Dictionary).get("pos", engine.INVALID_TILE)
			state = engine._apply_action_keywords_to_target(state, hit, hit_action, hit_origin)
		trace_hit["hidden_direct"] = bool(hit.get("hidden_direct", false))
		rebound_route.append(trace_hit.duplicate(true))
		if bool(hit.get("hidden_direct", false)):
			continue
		if capture_states:
			trace_hit["state"] = state.duplicate(true)
		native_trace.append(trace_hit)
	performance_started = engine._record_runtime_performance_phase("board_attack_hits_total", performance_started)
	if actor_kind == "player":
		state = IllusionRelicRules.rebound(engine, state, route_action, rebound_route, native_trace, capture_states)
	state = SurfaceCardRules.after_attack_hits(engine, state, family_context)
	# Card blasts derived from non-attack actions (IllusionCardRules.blast_action)
	# hit enemies only: no terrain damage and no trap triggers on their tiles.
	var enemies_only: bool = bool(resolved.get("_enemies_only", false))
	if actor_kind == "player":
		var terrain_damage: int = engine.final_damage_for_player_action(state, resolved)
		if not enemies_only:
			var terrain_targets: Array[int] = engine._terrain_indices_in_tiles(state, impact)
			if IllusionRelicRules.copper_active(engine, state, action, actor_kind):
				terrain_targets.assign(terrain_targets.filter(func(index: int) -> bool: return not IllusionRelicRules.owned_outcrop(state["terrain"][index])))
			state = engine._damage_terrain_indices(state, terrain_targets, terrain_damage)
		if int(resolved.get("damage", 0)) > 0:
			engine._mark_first_attack_used(state)
		if not echo:
			state = engine._trigger_resolved_action_light(state, resolved, target, affected)
			engine._mark_light_target_skill_trigger(state, resolved)
	else:
		var terrain_targets: Array[int] = engine._terrain_indices_in_tiles(state, impact)
		if bool(resolved.get("preserve_owned_terrain",false)):
			terrain_targets.assign(terrain_targets.filter(func(index: int) -> bool: return int(state["terrain"][index].get("owner_id",-1)) != actor_id))
		state = engine._damage_terrain_indices(state, terrain_targets, int(resolved.get("damage", 0)))
	if not enemies_only:
		state = engine._trigger_traps_on_tiles(state, engine._trap_tiles_in_tiles(state, impact))
	state = engine._place_action_surface(state, resolved, engine._board_aoe_center(action, target, origin) if str(action.get("type", "")) == "aoe" else target, impact)
	if actor_kind == "player" and not echo and not affected.is_empty():
		state = engine._trigger_direct_attack_surface(state, resolved, target)
	if raise_outcrop:
		CombatTerrainRules.raise_outcrop(engine, state, target, int(action["outcrop_health"]), engine._surface_source(state, action))
	if player_struck:
		# Once per enemy attack, inside the batch so Retaliate deaths flush here.
		state = CommonRelicRules.blocked_attack(engine, state, actor_id, attack_health_loss, attack_block_loss)
	engine._resolver_journal("end", state)
	preload("res://scripts/reaction_presentation_trace.gd").action_finished(engine, trace, state)
	state = RetaliateRules.after_player_hits(engine, state, retaliators, resolved, trace)
	if player_struck:
		state = RetaliateRules.after_enemy_hit(engine, state, actor_id, resolved, struck_player_tile, trace)
	if not struck_illusions.is_empty():
		state = IllusionCardRules.after_enemy_hit(engine, state, actor_id, struck_illusions, trace)
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch:
		state = engine._flush_surface_deaths(state, trace)
	state = SurfaceCardRules.finish_attack(engine, state, family_context)
	if not relay.is_empty() and native_trace.size() == 1:
		var ground_hit: Dictionary = {"kind":"actor","from":relay["relay"],"to":relay["to"],"relay_delivery":true}
		if capture_states: ground_hit["state"] = state.duplicate(true)
		native_trace.append(ground_hit)
	trace["chain_hits"] = native_trace if capture_route else []
	engine._record_runtime_performance_phase("board_attack_finish_total", performance_started)
	return state

