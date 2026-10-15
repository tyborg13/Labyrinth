extends RefCounted
class_name SfxCueRouter

const Dragon = preload("res://scripts/dragon_presentation.gd")
const GameData = preload("res://scripts/game_data.gd")
const Attacks = preload("res://scripts/attack_sfx_library.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const CursorFeedback = preload("res://scripts/cursor_feedback.gd")
const ENEMY_ATTACK_FAMILIES: Dictionary = {
	"crawler": "claw", "acolyte": "blunt", "harrier": "pierce", "warden": "blunt",
	"cinder_ooze": "blunt", "cinder_droplet": "blunt", "bile_bloomer": "blunt",
	"chainbound_gaoler": "blunt", "grave_surgeon": "blade", "frostglass_lancer": "pierce",
	"veilbound_acolyte": "blunt", "lightning_wisp": "blunt", "ashen_reaver": "blade",
	"rimejaw": "claw", "storm_cantor": "blunt", "gallows_roc": "claw", "craghide": "claw",
	"last_lamplighter": "blunt", "ash_hound": "claw", "rime_whelp": "claw",
	"rime_spitter": "claw", "bell_tender": "blunt", "roc_fledgling": "claw",
	"stoneback_mite": "claw", "wick_shade": "claw",
	"burrow_grub": "claw", "ember_tick": "claw", "hoarfrost_seer": "blunt",
	"gale_herald": "blunt", "arc_thrall": "blunt", "gloam_stalker": "blade",
	"briar_weaver": "claw", "slag_mortar": "blunt", "glacial_mirror": "blunt",
	"gust_shrike": "claw", "storm_capacitor": "blunt", "hollow_mimic": "blade",
	"tharokh": "claw", "vyraketh": "claw", "vaeloryx": "claw", "iskaldra": "claw",
	"noctyrax": "claw", "zekarion": "claw"
}
const DEATH_FAMILIES: Dictionary = {
	"crawler": "beast", "acolyte": "humanoid", "harrier": "bone", "warden": "stone",
	"cinder_ooze": "ooze", "cinder_droplet": "ooze", "bile_bloomer": "stone",
	"chainbound_gaoler": "humanoid", "grave_surgeon": "humanoid", "frostglass_lancer": "humanoid",
	"veilbound_acolyte": "spirit", "lightning_wisp": "spirit", "ashen_reaver": "humanoid",
	"rimejaw": "beast", "storm_cantor": "humanoid", "gallows_roc": "avian", "craghide": "stone",
	"last_lamplighter": "humanoid", "ash_hound": "beast", "rime_whelp": "beast",
	"rime_spitter": "beast", "bell_tender": "humanoid", "roc_fledgling": "avian",
	"stoneback_mite": "beast", "wick_shade": "spirit",
	"burrow_grub": "beast", "ember_tick": "beast", "hoarfrost_seer": "humanoid",
	"gale_herald": "humanoid", "arc_thrall": "humanoid", "gloam_stalker": "spirit",
	"briar_weaver": "stone", "slag_mortar": "humanoid", "glacial_mirror": "stone",
	"gust_shrike": "avian", "storm_capacitor": "stone", "hollow_mimic": "spirit",
	"tharokh": "dragon", "vyraketh": "dragon", "vaeloryx": "dragon", "iskaldra": "dragon",
	"noctyrax": "dragon", "zekarion": "dragon"
}
const WEAPON_FAMILIES: Dictionary = {
	"sword": "blade", "dagger": "blade", "knife": "blade", "knives": "blade", "rapier": "blade", "axe": "blade",
	"hatchet": "blade", "halberd": "blade", "scythe": "blade", "glass spear edge": "blade",
	"mace": "blunt", "maul": "blunt", "hammer": "blunt", "club": "blunt", "flail": "blunt",
	"shield": "blunt", "staff": "blunt", "spear": "pierce", "lance": "pierce",
	"bow": "pierce", "crossbow": "pierce", "repeater": "pierce", "sling": "pierce"
}
const HEAVY_TYPES: Array[String] = ["warden", "craghide", "ashen_reaver", "rimejaw", "storm_cantor", "gallows_roc", "last_lamplighter", "tharokh", "vyraketh", "vaeloryx", "iskaldra", "noctyrax", "zekarion"]
const EQUIPMENT_FAMILIES: Dictionary = {"phoenix_brand": "blade", "worldbreaker": "blunt", "dawnlight_censer": "blunt", "galewhip": "blade"}
const AREA_GAIN_DB: float = -6.0
const CHAIN_GAIN_DB: float = -5.0
const BEAST_VOCAL_CHANCE: float = 0.30

var bank: Node
var _action: Dictionary = {}
var _actor: Dictionary = {}
var _weapon: String = ""
var _units: Dictionary = {}
var _terrain: Dictionary = {}
var _illusions: Dictionary = {}
var _deaths: Dictionary = {}
var _dragons: Dictionary = {}
var _roar_pending: bool = false
var _animation_frames: int = 1
var _animation_frame_ms: float = 0.0
var _resolved: bool = false
var _released: bool = false
var _blink_signature: String = ""
var _blink_progress: float = -1.0
var _impact_count: int = 0
var _impact_frame: int = -1
var _impact_cues: Dictionary = {}
var _animation_scale: float = 1.0
var _animation_wall_frame_ms: float = 0.0
var _action_serial: int = 0
var _fight_key: String = ""
var _deck: Dictionary = {}
var _omen_ids: Dictionary = {}
var _relic_logs: Array = []
var _relic_names: Array[String] = []
var _collisions: Dictionary = {}
var _merged_hits: Dictionary = {}
var _run_hp: int = -1
var _trap_impact_pending: bool = false
var _radiance_played: bool = false
var _run_baselined: bool = false
var _vocal_rng := RandomNumberGenerator.new()
var _warned_families: Dictionary = {}

func _init(cue_bank: Node = null) -> void:
	bank = cue_bank

func request(cue_id: String, opts: Dictionary = {}) -> void:
	if bank != null: bank.play(cue_id, opts)

func weapon_family(weapon: String) -> String:
	if EQUIPMENT_FAMILIES.has(weapon): return EQUIPMENT_FAMILIES[weapon]
	var name: String = weapon.to_lower().replace("_", " ")
	for token: String in WEAPON_FAMILIES:
		if name.contains(token): return WEAPON_FAMILIES[token]
	return _unknown_family("weapon", weapon, "blunt") if not weapon.is_empty() else ""

func _unknown_family(kind: String, id: String, fallback: String) -> String:
	var key: String = kind + ":" + id
	if OS.is_debug_build() and not _warned_families.has(key):
		_warned_families[key] = true
		push_warning("Unknown SFX %s family for '%s'; using %s." % [kind, id, fallback])
	return fallback

func enemy_family(type: String, death_family: bool = false) -> String:
	var families: Dictionary = DEATH_FAMILIES if death_family else ENEMY_ATTACK_FAMILIES
	if families.has(type): return families[type]
	return _unknown_family("death" if death_family else "enemy attack", type, "humanoid" if death_family else "blunt")

func weapon_for_card(card_id: String, state: Dictionary) -> String:
	for slot: String in ["weapon", "offhand"]:
		var id: String = str(state.get("equipped_equipment", {}).get(slot, ""))
		if not id.is_empty() and GameData.equipment_cards(id, state).has(card_id): return id
	return ""

func bind_map_hover(host: Node) -> void:
	if not host.child_entered_tree.is_connected(bind_map_hover): host.child_entered_tree.connect(bind_map_hover)
	var script: Script = host.get_script() as Script
	if script != null and script.resource_path == "res://scripts/section_map_node.gd":
		host.set_meta(CursorFeedback.CUE_CLICK_META, true)
		host.set_meta(CursorFeedback.CUE_FOCUS_META, true)
		var callback: Callable = _map_node_entered.bind(host)
		if not host.mouse_entered.is_connected(callback): host.mouse_entered.connect(callback)
		if not host.focus_entered.is_connected(callback): host.focus_entered.connect(callback)
	elif script != null and script.resource_path in ["res://scripts/event_view_choice.gd", "res://scripts/labyrinth_map_view.gd"]:
		host.set_meta(CursorFeedback.CUE_CLICK_META, true)
	for child: Node in host.get_children(): bind_map_hover(child)

func _map_node_entered(button: Node) -> void:
	if bool(button.get("actionable")): map_hover()

func attack_family(action: Dictionary, actor: Dictionary = {}, weapon: String = "") -> String:
	var kind: String = str(action.get("type", action.get("kind", "")))
	if kind in ["push", "pull", "charge", "force_area"]: return "blunt"
	if not actor.is_empty() and str(actor.get("type", "player")) != "player":
		if kind == "ranged" and str(actor.get("type", "")) in ["acolyte", "veilbound_acolyte"]: return "arcane"
		return enemy_family(str(actor.get("type", "")))
	var family: String = weapon_family(weapon)
	if not family.is_empty(): return family
	return "blade" if kind == "melee" or (kind == "aoe" and str(action.get("aim", "")) == "facing") else "pierce" if str(action.get("physical", "")) == "true" or bool(action.get("physical", false)) else "arcane"

func impact_cue(action: Dictionary, actor: Dictionary = {}, weapon: String = "", target_before: Dictionary = {}, hp_loss: int = 1, absorbed: int = 0, collision: bool = false) -> String:
	if hp_loss <= 0 and absorbed > 0: return "hit.blocked"
	if collision or bool(action.get("collision", false)): return "push.collision"
	if int(target_before.get("freeze", 0)) > 0 and hp_loss > 0: return "status.shatter"
	var element: String = str(action.get("element", action.get("_card_element", "none")))
	if str(action.get("type", "")) == "detonate": element = "earth" if str(action.get("_detonate_surface", "fire")) == "rubble" else "fire"
	if element in ["umbra", "shadow"]: return "spell.shadow"
	if element in ["fire", "ice", "lightning", "earth", "air"]: return "spell." + element
	var family: String = attack_family(action, actor, weapon)
	if family in ["blade", "blunt"]:
		return "hit.%s.%s" % [family, "heavy" if int(action.get("damage", action.get("amount", hp_loss + absorbed))) >= 6 else "light"]
	return "hit." + family

func begin_player_action(before: Dictionary, action: Dictionary, weapon: String = "") -> void:
	begin_action(before, action, {"type": "player"}, weapon)

func begin_enemy_action(before: Dictionary, action: Dictionary, actor: Dictionary) -> void:
	begin_action(before, action, actor)

func begin_action(before: Dictionary, action: Dictionary, actor: Dictionary, weapon: String = "") -> void:
	_roar_pending = false
	_action = action
	_actor = actor
	_weapon = weapon
	_action_serial += 1
	_impact_count = 0
	_impact_frame = -1
	_impact_cues.clear()
	_collisions.clear()
	_merged_hits.clear()
	_resolved = false
	_released = false
	_trap_impact_pending = false
	_radiance_played = false
	baseline(before)
	_blink_signature = ""
	_blink_progress = -1.0
	var family: String = DEATH_FAMILIES.get(str(actor.get("type", "")), "")
	var actor_key: String = str(action.get("actor_key", actor.get("id", "player")))
	var kind: String = str(action.get("type", action.get("kind", "")))
	# A big-area roar accompanies its wind-up, including empty-ground attacks.
	# Waiting for a damage/impact snapshot put this layer after the cast visual.
	if family == "dragon" and (not _dragons.has(actor_key) or kind in ["aoe", "lightning_strikes"]):
		_dragons[actor_key] = true
		_roar_pending = _has_profiled_presentation(action)
		if not _roar_pending: request("dragon.roar")
	if kind == "umbra_eclipse": request("spell.shadow")
	if kind not in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes", "detonate", "all_enemies", "burst_terrain", "destroy_illusion"]: return
	if family in ["beast", "avian"]:
		# Presentation randomness is reproducible per action and never consumes combat RNG.
		_vocal_rng.seed = int(before.get("seed", before.get("rng_state", 0))) + _action_serial + actor_key.hash()
		if _vocal_rng.randf() < BEAST_VOCAL_CHANCE: request("vocal.beast")
	wind_up(action, actor, weapon)
	if int(action.get("push", 0)) > 0 or int(action.get("pull", 0)) > 0: push()

# These paths return through dedicated views without submitting a profiled
# effect. Their first-action roar remains attached to the action start.
func _has_profiled_presentation(action: Dictionary) -> bool:
	if Dragon.profile(action).is_empty() or bool(action.get("hidden_by_umbra", false)): return false
	for key: String in ["en05_after", "en04_mechanic", "en02_mechanic", "guardian_board_after"]:
		if action.has(key): return false
	if bool(action.get("en03_veil", false)) or bool(action.get("en06_mirror", false)): return false
	if str(action.get("action_type", "")) in ["chain_discharge", "tether_beam"]: return false
	return str(action.get("kind", action.get("type", ""))) in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes", "umbra_eclipse", "summon", "block", "heal", "stoneskin", "status"]

func wind_up(action: Dictionary, actor: Dictionary = {}, weapon: String = "") -> void:
	var kind: String = str(action.get("type", action.get("kind", "")))
	var element: String = str(action.get("element", action.get("_card_element", "none")))
	if element not in ["", "none"] or kind in ["detonate", "destroy_illusion", "burst_terrain"]: return
	if kind == "melee" or (kind == "aoe" and str(action.get("aim", "")) == "facing"):
		request("swing.heavy" if attack_family(action, actor, weapon) == "blunt" or int(action.get("damage", action.get("amount", 0))) >= 6 else "swing.light")

func release(action: Dictionary, actor: Dictionary = {}, weapon: String = "", climax_ms: float = -1.0) -> void:
	var cue: String = release_cue(action, actor, weapon)
	if not cue.is_empty(): request(cue, {"peak_climax_ms": climax_ms} if cue == "cast.arcane" and climax_ms >= 0.0 else {})

func release_cue(action: Dictionary, actor: Dictionary = {}, weapon: String = "") -> String:
	var kind: String = str(action.get("type", action.get("kind", "")))
	var element: String = str(action.get("element", action.get("_card_element", "none")))
	if element not in ["", "none"]: return ""
	if kind in ["ranged", "aoe", "all_enemies"]:
		var name: String = weapon.to_lower()
		if name.contains("crossbow") or name.contains("repeater") or bool(action.get("thrown", false)): return "shot.crossbow"
		if name.contains("bow") or name.contains("sling"): return "shot.bow"
		if attack_family(action, actor, weapon) == "arcane" or str(actor.get("type", "")) in ["acolyte", "veilbound_acolyte"]: return "cast.arcane"
		if attack_family(action, actor, weapon) == "pierce": return "shot.crossbow"
	return ""

func hit(action: Dictionary, actor: Dictionary, weapon: String, target_before: Dictionary, target_after: Dictionary, gain_db: float = 0.0) -> void:
	var hp_loss: int = maxi(0, int(target_before.get("hp", 0)) - int(target_after.get("hp", 0)))
	var absorbed: int = maxi(0, int(target_before.get("block", 0)) - int(target_after.get("block", 0))) + maxi(0, int(target_before.get("stoneskin", 0)) - int(target_after.get("stoneskin", 0)))
	var key: String = _unit_key(target_before)
	var now: int = bank.now_ms() if bank != null else Time.get_ticks_msec()
	var merge_ms: int = int(bank.data.get("rules", {}).get("merge_window_ms", 60)) if bank != null else 60
	if _merged_hits.has(key) and now - int(_merged_hits[key]) < merge_ms: return
	_merged_hits[key] = now
	var cue: String = impact_cue(action, actor, weapon, target_before, hp_loss, absorbed, _collisions.has(key))
	var frame: int = bank.frame_id() if bank != null else Engine.get_process_frames()
	# Collapse identical cues on one frame; a blocked and a damaging contact
	# remain audible together. Additional distinct contacts retain -6 dB layering.
	if frame != _impact_frame:
		_impact_cues.clear()
		_impact_frame = frame
	if not _impact_cues.has(cue):
		_impact_cues[cue] = true
		if _impact_count == 0:
			request(cue, {"gain_db": gain_db})
		elif _impact_count <= 2 and bank != null:
			request(cue, {"gain_db": gain_db + AREA_GAIN_DB, "area_instance": true})
		_impact_count += 1
	if hp_loss > 0 and int(target_before.get("block", 0)) > 0 and int(target_after.get("block", 0)) == 0: request("block.break")
	if hp_loss >= 5 and str(target_before.get("type", "player")) == "player": request("hurt.hero")

func death(unit: Dictionary) -> void:
	var key: String = _unit_key(unit)
	if _deaths.has(key): return
	_deaths[key] = true
	request("death." + ("hero" if key == "player" else enemy_family(str(unit.get("type", "")), true)))

func walk_tile(unit: Dictionary) -> void:
	if str(unit.get("type", "player")) == "player": request("step.hero")
	else:
		var footprint: Variant = unit.get("footprint", [1, 1])
		var large: bool = HEAVY_TYPES.has(str(unit.get("type", ""))) or (footprint is Vector2i and footprint.x * footprint.y > 1) or (footprint is Array and int(footprint[0]) * int(footprint[1]) > 1)
		request("step.enemy.heavy" if large else "step.enemy.light")

func walk_start(unit: Dictionary) -> void:
	if DEATH_FAMILIES.get(str(unit.get("type", "")), "") == "dragon": request("dragon.wings")

func blink(climax_ms: float = -1.0) -> void:
	request("move.blink", {"peak_climax_ms": climax_ms} if climax_ms >= 0.0 else {})
func push() -> void: request("push.slide")
func trap(traps: Array) -> void:
	_trap_impact_pending = not traps.is_empty()
	for _entry: Dictionary in traps:
		request("trap.trigger")
func surface(surface_id: String) -> void:
	request("surface." + ("electric" if surface_id == "electrified" else surface_id))
func status(status_id: String) -> void:
	if status_id in ["bleed", "freeze", "shock", "stagger"]: request("status." + status_id)
func light() -> void: request("radiance.light")
func heal() -> void: request("heal")
func illusion_spawn() -> void: request("illusion.spawn")
func illusion_break() -> void: request("illusion.break")
func crate(broken: bool) -> void: request("crate.break" if broken else "crate.hit")
func pickup(kind: String) -> void: request("pickup.item" if kind == "item" else "pickup.gear")
func defiance() -> void: request("defiance")
func fatigue() -> void: request("fatigue")
func relic_trigger() -> void: request("relic.trigger")
func card_hover() -> void: request("card.hover")
func card_select() -> void: request("card.select")
func card_invalid() -> void: request("card.invalid")
func card_exhaust() -> void: request("card.exhaust")
func deck_shuffle() -> void: request("deck.shuffle")
func map_hover() -> void: request("map.hover")
func map_select() -> void: request("map.select")
func event_choose() -> void: request("event.choose")
func omen(kind: String) -> void: request("omen." + kind)
func shop_buy() -> void: request("shop.buy")
func shop_sell() -> void: request("shop.sell")
func ambience(biome: String = "stone") -> void: request("ambience." + biome)

func baseline(state: Dictionary) -> void:
	_units = _unit_snapshot(state)
	_terrain = _indexed(state.get("terrain", []), "id")
	_illusions = _indexed(state.get("illusions", []), "id")
	_deck = (state.get("deck", {}) as Dictionary).duplicate(true)
	_relic_logs = (state.get("log", []) as Array).duplicate()
	_relic_names.clear()
	for id: String in state.get("relics", []):
		var name: String = str(GameData.relic_def(id).get("name", ""))
		if not name.is_empty(): _relic_names.append(name)

func begin_animation(frame_count: int, frame_seconds: float, effective_scale: float = 1.0, wall_frame_ms: float = 0.0) -> void:
	_animation_wall_frame_ms = wall_frame_ms
	_animation_scale = maxf(effective_scale, 0.001)
	_animation_frames = frame_count
	_animation_frame_ms = round(frame_seconds * 1000000.0) / 1000.0

func _wall_climax_ms(visual_ms: float) -> float:
	var wall_ms: float = visual_ms / _animation_scale
	# Timed animations submit on process frames. Include that same final tick
	# when converting the authored deadline; a raw division is early by up to
	# one frame at 1.5x/2x. The observed frame interval supplies the prediction.
	if _animation_wall_frame_ms > 0.0:
		wall_ms = ceil(wall_ms / _animation_wall_frame_ms - 0.00001) * _animation_wall_frame_ms
	return wall_ms

func presentation(state: Dictionary, shown: Dictionary) -> void:
	var effect: Dictionary = shown.get("effect", {})
	if _roar_pending and not Dragon.profile(effect).is_empty():
		_roar_pending = false
		var release: float = Dragon.RELEASE if str(Dragon.profile(effect).get("geometry", "")) == "breath" else Dragon.CONTACT
		var current_frame: int = roundi(float(shown.get("effect_progress", 0.0)) * _animation_frames)
		var climax_ms: float = _wall_climax_ms(maxi(0, ceili(release * _animation_frames) - current_frame) * _animation_frame_ms)
		request("dragon.roar", {"peak_climax_ms": climax_ms})
	if str(effect.get("kind", "")) == "blink" and str(effect.get("actor_key", "player")) == "player" and not bool(effect.get("preview", false)):
		var signature: String = str(effect)
		var progress: float = float(shown.get("effect_progress", 0.0))
		if signature != _blink_signature or progress < _blink_progress:
			# The destination appears after the final authored frame interval.
			blink(_wall_climax_ms((_animation_frames + 1 - roundi(progress * _animation_frames)) * _animation_frame_ms))
		_blink_signature = signature
		_blink_progress = progress
	else:
		_blink_signature = ""
		_blink_progress = -1.0
	if not effect.is_empty() and not _released and str(effect.get("kind", "")) in ["ranged", "aoe"]:
		var style: String = Fx.style_for_effect(effect)
		var release_progress: float = 0.18 if style == Fx.STYLE_DEFAULT else Fx.anticipation_end_progress(style)
		var current_frame: int = roundi(float(shown.get("effect_progress", 0.0)) * _animation_frames)
		if release_cue(_action, _actor, _weapon) == "cast.arcane":
			var climax_ms: float = _wall_climax_ms(maxi(0, ceili(release_progress * _animation_frames) - current_frame) * _animation_frame_ms)
			release(_action, _actor, _weapon, climax_ms)
			_released = true
		elif float(shown.get("effect_progress", 0.0)) >= release_progress:
			release(_action, _actor, _weapon)
			_released = true
	var chain_hop: bool = int(effect.get("chain_index", 0)) > 0
	if chain_hop: _impact_count = 0
	var hit_action: Dictionary = effect if chain_hop else _action
	var next_units: Dictionary = _unit_snapshot(state)
	for key: String in next_units:
		var after: Dictionary = next_units[key]
		var before: Dictionary = _units.get(key, after)
		var loss: int = int(before.get("hp", 0)) - int(after.get("hp", 0))
		var absorbed: int = int(before.get("block", 0)) + int(before.get("stoneskin", 0)) - int(after.get("block", 0)) - int(after.get("stoneskin", 0))
		if loss > 0 or absorbed > 0:
			if str(_action.get("kind", "")) == "status_damage":
				if str(_action.get("label", "")) == "Bleed": status("bleed")
				elif str(_action.get("label", "")) == "Fire": request("spell.fire")
			elif str(_action.get("kind", "")) != "fatigue" and not _trap_impact_pending: hit(hit_action, _actor, _weapon, before, after, CHAIN_GAIN_DB if chain_hop else 0.0)
			if _trap_impact_pending and loss >= 5 and key == "player": request("hurt.hero")
			if not _resolved:
				_resolved = true
		if loss < 0: heal()
		for field: String in ["block", "stoneskin"]:
			if int(after.get(field, 0)) > int(before.get(field, 0)): request(field + ".gain")
		for field: String in ["bleed", "freeze", "shock", "stagger"]:
			if int(after.get(field, 0)) > int(before.get(field, 0)): status(field)
	if not _radiance_played and int(_action.get("illuminate_radius", 0)) > 0 and next_units != _units:
		light()
		_radiance_played = true
	if not _resolved and shown.has("impact_actor_keys"):
		var element: String = str(_action.get("element", _action.get("_card_element", "none")))
		if element not in ["", "none"] and _impact_count == 0 and not _trap_impact_pending: request(impact_cue(_action, _actor, _weapon))
		_resolved = true
	if next_units != _units: _trap_impact_pending = false
	_units = next_units
	for unit: Dictionary in shown.get("death_animation_units", []): death(unit)
	var next_terrain: Dictionary = _indexed(state.get("terrain", []), "id")
	for key: Variant in _terrain:
		var before: Dictionary = _terrain[key]
		var after: Dictionary = next_terrain.get(key, {})
		if int(before.get("hp", 0)) > int(after.get("hp", 0)) and str(before.get("kind", before.get("type", ""))) in ["box", "crate"]: crate(int(after.get("hp", 0)) <= 0)
	_terrain = next_terrain
	var next_illusions: Dictionary = _indexed(state.get("illusions", []), "id")
	for key: Variant in next_illusions:
		if not _illusions.has(key): illusion_spawn()
	for key: Variant in _illusions:
		if not next_illusions.has(key) or (int(_illusions[key].get("hp", 1)) > 0 and int(next_illusions[key].get("hp", 1)) <= 0): illusion_break()
	_illusions = next_illusions
	deck_transition(state.get("deck", {}))
	relic_outcomes(state.get("log", []))

func deck_transition(deck: Dictionary) -> void:
	if int(deck.get("cycles", 0)) > int(_deck.get("cycles", 0)): deck_shuffle()
	if (deck.get("burned", []) as Array).size() > (_deck.get("burned", []) as Array).size(): card_exhaust()
	_deck = deck.duplicate(true)

func outcomes(events: Array) -> void:
	var seen: Dictionary = {}
	for event: Dictionary in events:
		var kind: String = str(event.get("kind", ""))
		var surface_id: String = str(event.get("surface", ""))
		var source: Dictionary = event.get("source", {})
		var relic_id: String = str(event.get("relic_id", source.get("relic_id", "")))
		if not relic_id.is_empty() and not relic_id.begins_with("rite:") and not seen.has("relic:" + relic_id):
			relic_trigger()
			seen["relic:" + relic_id] = true
		if kind in ["surface_created", "surface_replaced"] and surface_id in ["fire", "ice", "electrified", "rubble"] and not seen.has(surface_id):
			surface(surface_id)
			seen[surface_id] = true
		if kind == "force_collision":
			var actor_key: String = "player" if str(event.get("actor_kind", "")) == "player" else "enemy:%s" % event.get("id", -1)
			_collisions[actor_key] = true
			for blocker: Dictionary in event.get("blockers", []):
				if str(blocker.get("kind", "")) == "enemy": _collisions["enemy:%s" % blocker.get("id", -1)] = true

func run_context(state: Dictionary) -> void:
	var key: String = "%s:%s" % [state.get("seed", 0), state.get("current_room", "")]
	if key != _fight_key:
		_fight_key = key
		_dragons.clear()
		_deaths.clear()
		baseline(state.get("combat_state", {}))
	var hp: int = int(state.get("player_hp", -1))
	if _run_hp >= 0 and hp > _run_hp and str(state.get("mode", "")) != "combat": heal()
	_run_hp = hp
	var next_ids: Dictionary = {}
	for entry: Dictionary in Omens.active(state):
		var id: String = str(entry.get("id", ""))
		next_ids[id] = true
		if _run_baselined and not _omen_ids.has(id): omen(str(entry.get("kind", "blessing")))
	_omen_ids = next_ids
	_run_baselined = true

func ambience_for_run(state: Dictionary) -> String:
	if not Graph.enabled(state): return "stone"
	return str(Graph.section(state, Graph.active_section(state)).get("boss_id", "stone"))

func _unit_key(unit: Dictionary) -> String:
	return "enemy:%s" % unit["id"] if unit.has("id") else "player"

func _unit_snapshot(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if state.has("player"):
		result["player"] = _audible_unit(state["player"])
	for unit: Dictionary in state.get("enemies", []): result[_unit_key(unit)] = _audible_unit(unit)
	return result

func _audible_unit(unit: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ["id", "type", "hp", "block", "stoneskin", "bleed", "freeze", "shock", "stagger"]:
		if unit.has(field): result[field] = unit[field]
	return result

func _indexed(entries: Array, field: String) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in entries: result[entry.get(field, "")] = entry.duplicate(true)
	return result

# Legacy resolvers expose actual reward records in their bounded log. Do not
# infer a fired effect from counters: counters also advance before thresholds.
# Relics without a reward record need a semantic engine presentation event.
func relic_outcomes(log_lines: Array) -> void:
	if log_lines == _relic_logs: return
	var overlap: int = mini(_relic_logs.size(), log_lines.size())
	while overlap > 0 and _relic_logs.slice(_relic_logs.size() - overlap) != log_lines.slice(0, overlap): overlap -= 1
	for index: int in range(overlap, log_lines.size()):
		var line: String = str(log_lines[index])
		for name: String in _relic_names:
			if line == name + " triggers." or line == name + " prevents death." or line.begins_with(name + " carries ") or line.begins_with(name + " hardens "):
				relic_trigger()
				break
	_relic_logs = log_lines.duplicate()
