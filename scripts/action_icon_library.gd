extends RefCounted
class_name ActionIconLibrary

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")

const ICON_ROOT: String = "res://assets/art/icons"
const SKILL_ICON_ROOT: String = "res://assets/art/skills"

const KEYWORDS: Dictionary = {
	"melee": {
		"label": "Melee",
		"description": "Deals damage up close.",
		"path": "%s/melee.png" % ICON_ROOT
	},
	"ranged": {
		"label": "Ranged",
		"description": "Deals damage from a distance.",
		"path": "%s/ranged.png" % ICON_ROOT
	},
	"pierce": {
		"label": "Pierce",
		"description": "Deals damage straight through block and stoneskin.",
		"path": "%s/pierce.png" % ICON_ROOT
	},
	"move": {
		"label": "Move",
		"description": "Moves across board tiles.",
		"path": "%s/move.png" % ICON_ROOT
	},
	"free_move": {
		"label": "Free Move",
		"description": "Once each activation, move up to 2 tiles without spending a card play or Time.",
		"path": "%s/free_move.png" % ICON_ROOT
	},
	"retreat": {
		"label": "Retreat",
		"description": "Moves away from the target.",
		"path": "%s/retreat.png" % ICON_ROOT
	},
	"blink": {
		"label": "Blink",
		"description": "Teleports to another tile.",
		"path": "%s/blink.png" % ICON_ROOT
	},
	"range": {
		"label": "Range",
		"description": "Maximum target distance in tiles.",
		"path": "%s/range.png" % ICON_ROOT
	},
	"block": {
		"label": "Block",
		"description": "Absorbs incoming damage before health.",
		"path": "%s/block.png" % ICON_ROOT
	},
	"stoneskin": {
		"label": "Stoneskin",
		"description": "Persistent armor that absorbs damage across turns.",
		"path": "%s/stoneskin.png" % ICON_ROOT
	},
	"heal": {
		"label": "Heal",
		"description": "Restores health.",
		"path": "%s/heal.png" % ICON_ROOT
	},
	"draw": {
		"label": "Draw",
		"description": "Adds cards to your hand.",
		"path": "%s/draw.png" % ICON_ROOT
	},
	"card_play": {
		"label": "Card Play",
		"description": "Adds card plays for this turn.",
		"path": "%s/card_play.png" % ICON_ROOT
	},
	"flurry": {
		"label": "Flurry",
		"description": "Spends all current card plays. Repeats printed actions and health cost once per play spent; pays Time once.",
		"path": "%s/flurry.png" % ICON_ROOT
	},
	"time": {
		"label": "Time",
		"description": "Adds to the initiative delay before your next turn.",
		"path": "%s/time.png" % ICON_ROOT
	},
	"illusion": {
		"label": "Illusion",
		"description": "Creates a stationary copy that enemies can target.",
		"path": "%s/illusion.png" % ICON_ROOT
	},
	"illuminate": {
		"label": "Illuminate",
		"description": "Creates a light that reveals nearby Umbra tiles.",
		"path": "%s/illuminate.png" % ICON_ROOT
	},
	"vision": {
		"label": "Vision",
		"description": "Expands the light centered on you.",
		"path": "%s/vision.png" % ICON_ROOT
	},
	"truesight": {
		"label": "Truesight",
		"description": "Reveals and permits targeting enemies through the Umbra.",
		"path": "%s/truesight.png" % ICON_ROOT
	},
	"dispel_umbra": {
		"label": "Dispel Umbra",
		"description": "Reduces this combat's Umbra stage.",
		"path": "%s/dispel_umbra.png" % ICON_ROOT
	},
	"eclipse": {
		"label": "Eclipse",
		"description": "Forces the arena into absolute Umbra. Radiance and light offer protection.",
		"path": "%s/eclipse.svg" % ICON_ROOT
	},
	"burn": {
		"label": "Burn",
		"description": "Fire damage over time. Ticks at the start of turn, then decays.",
		"path": "%s/burn.png" % ICON_ROOT
	},
	"bleed": {
		"label": "Bleed",
		"description": "Physical wound damage. Triggers before actual move or attack actions, then clears after the next turn.",
		"path": "%s/bleed.png" % ICON_ROOT
	},
	"expose": {
		"label": "Expose",
		"description": "The next hit against this target deals extra damage.",
		"path": "%s/expose.png" % ICON_ROOT
	},
	"sunder": {
		"label": "Sunder",
		"description": "Breaks block and stoneskin before damage lands.",
		"path": "%s/sunder.png" % ICON_ROOT
	},
	"exhaust": {
		"label": "Exhaust",
		"description": "Removes this card from the deck for the rest of combat.",
		"path": "%s/exhaust.png" % ICON_ROOT
	},
	"consume": {
		"label": "Consume",
		"description": "Uses this item card once, then removes it from the run.",
		"path": "%s/consume.png" % ICON_ROOT
	},
	"freeze": {
		"label": "Freeze",
		"description": "Stops the affected unit from acting on its next turn.",
		"path": "%s/freeze.png" % ICON_ROOT
	},
	"shock": {
		"label": "Shock",
		"description": "Disrupts the affected unit's next action.",
		"path": "%s/shock.png" % ICON_ROOT
	},
	"immobilize": {
		"label": "Immobilize",
		"description": "Stops movement for the rest of the turn.",
		"path": "%s/immobilize.png" % ICON_ROOT
	},
	"poison": {
		"label": "Poison",
		"description": "Delayed damage that lands after its countdown.",
		"path": "%s/poison.png" % ICON_ROOT
	},
	"chain": {
		"label": "Chain",
		"description": "Jumps to additional nearby enemies.",
		"path": "%s/chain.png" % ICON_ROOT
	},
	"push": {
		"label": "Push",
		"description": "Forces the target away.",
		"path": "%s/push.png" % ICON_ROOT
	},
	"pull": {
		"label": "Pull",
		"description": "Forces the target closer.",
		"path": "%s/pull.png" % ICON_ROOT
	},
	"health": {
		"label": "Health",
		"description": "Health paid or restored.",
		"path": "%s/health.png" % ICON_ROOT
	},
	"health_cost": {
		"label": "Health Cost",
		"description": "Health paid to play this card.",
		"path": "%s/health_cost.png" % ICON_ROOT
	},
	"aoe": {
		"label": "Area Attack",
		"description": "Affects a pattern of board tiles.",
		"path": "%s/aoe.png" % ICON_ROOT
	},
	"lightning_strikes": {
		"label": "Lightning Strikes",
		"description": "Calls down lightning across several marked tiles.",
		"path": "%s/lightning_strikes.png" % ICON_ROOT
	},
	"summon_minions": {
		"label": "Summon Minions",
		"description": "Adds new enemy units to the battle.",
		"path": "%s/summon_minions.png" % ICON_ROOT
	},
	"raise_terrain": {
		"label": "Raise Terrain",
		"description": "Creates attackable terrain on the board.",
		"path": "%s/raise_terrain.png" % ICON_ROOT
	},
	"terrain_burst": {
		"label": "Terrain Burst",
		"description": "Ruptures the arena around surviving terrain.",
		"path": "%s/terrain_burst.png" % ICON_ROOT
	},
	"cinder_marks": {
		"label": "Cinder Marks",
		"description": "Places marks that threaten a later detonation.",
		"path": "%s/cinder_marks.png" % ICON_ROOT
	},
	"detonate_cinders": {
		"label": "Detonate Cinders",
		"description": "Detonates every surviving cinder mark.",
		"path": "%s/detonate_cinders.png" % ICON_ROOT
	},
	"gale_force": {
		"label": "Hollow Gale",
		"description": "Sweeps the target through the arena.",
		"path": "%s/gale_force.png" % ICON_ROOT
	},
	"frost_armor": {
		"label": "Crystal Armor",
		"description": "Forms armor whose layers break one hit at a time.",
		"path": "%s/frost_armor.png" % ICON_ROOT
	},
	"guard_ally": {
		"label": "Guard Ally",
		"description": "Grants block to another enemy.",
		"path": "%s/guard_ally.png" % ICON_ROOT
	},
	"heal_ally": {
		"label": "Heal Ally",
		"description": "Restores another enemy's health.",
		"path": "%s/heal_ally.png" % ICON_ROOT
	},
	"umbra_eclipse": {
		"label": "The Last Eclipse",
		"description": "Forces the arena into absolute Umbra.",
		"path": "%s/umbra_eclipse.png" % ICON_ROOT
	},
	"radiance": {
		"label": "Radiance Field",
		"description": "Damages enemies on entry and activation start, clears Corruption, and reveals Umbra.",
		"path": "%s/radiance.png" % ICON_ROOT
	},
	"corruption": {
		"label": "Corruption Field",
		"description": "Damages the player on entry and activation start, and heals enemies at activation start.",
		"path": "%s/corruption.png" % ICON_ROOT
	},
	"surface_bramble": {
		"label": "Bramble Surface",
		"description": "Entering this tile ends movement.",
		"path": "%s/surface_bramble.png" % ICON_ROOT
	},
	"surface_poison": {
		"label": "Poison Surface",
		"description": "After entering Poison, each further tile moved deals 1 damage.",
		"path": "%s/surface_poison.png" % ICON_ROOT
	},
	"surface_ice": {
		"label": "Ice Surface",
		"description": "Entering locks movement direction and slides until collision or open ground.",
		"path": "%s/surface_ice.png" % ICON_ROOT
	},
	"surface_snowdrift": {
		"label": "Snowdrift Surface",
		"description": "Attacks against a character on this tile deal +2 damage.",
		"path": "%s/surface_snowdrift.png" % ICON_ROOT
	},
	"surface_electrified": {
		"label": "Electrified Surface",
		"description": "Suppresses attack segments for the activation, then is consumed.",
		"path": "%s/surface_electrified.png" % ICON_ROOT
	},
	"combust": {
		"label": "Combust",
		"description": "Consumes Surfaces in the attack pattern for bonus damage.",
		"path": "%s/combust.png" % ICON_ROOT
	},
	"ember": {
		"label": "Embers",
		"description": "Run currency used to gain permanent levels.",
		"path": "%s/ember.png" % ICON_ROOT
	},
	"run": {
		"label": "The Run",
		"description": "The full journey from entry to victory or defeat.",
		"path": "%s/run.png" % ICON_ROOT
	},
	"map_rooms": {
		"label": "Map and Rooms",
		"description": "Routes and room types across the labyrinth.",
		"path": "%s/map_rooms.png" % ICON_ROOT
	},
	"loadout": {
		"label": "Character and Loadout",
		"description": "Equipment, attuned magic, items, relics, and skills.",
		"path": "%s/loadout.png" % ICON_ROOT
	},
	"rewards": {
		"label": "Rewards",
		"description": "Cards, healing, and other prizes claimed during a run.",
		"path": "%s/rewards.png" % ICON_ROOT
	},
	"relics": {
		"label": "Relics",
		"description": "Passive run modifiers collected during exploration.",
		"path": "%s/relics.png" % ICON_ROOT
	},
	"combat_board": {
		"label": "Combat Board",
		"description": "The tactical tile grid where actions resolve.",
		"path": "%s/combat_board.png" % ICON_ROOT
	},
	"turn_clock": {
		"label": "Turn Clock",
		"description": "Orders the next actor by current initiative delay.",
		"path": "%s/turn_clock.png" % ICON_ROOT
	},
	"health_defense": {
		"label": "Health and Defenses",
		"description": "Health protected by block and stoneskin.",
		"path": "%s/health_defense.png" % ICON_ROOT
	},
	"defiance": {
		"label": "Defiance",
		"description": "A per-run rescue that restores health after lethal loss.",
		"path": "%s/defiance.png" % ICON_ROOT
	},
	"targeting": {
		"label": "Targeting",
		"description": "Range, line of sight, patterns, and legal targets.",
		"path": "%s/targeting.png" % ICON_ROOT
	},
	"fatigue": {
		"label": "Fatigue",
		"description": "Direct health loss caused by reshuffling an empty deck.",
		"path": "%s/fatigue.png" % ICON_ROOT
	},
	"traps": {
		"label": "Traps",
		"description": "Board hazards triggered by movement or attacks.",
		"path": "%s/traps.png" % ICON_ROOT
	},
	"umbra": {
		"label": "The Umbra",
		"description": "Darkness that conceals tiles, enemies, and threats.",
		"path": "%s/umbra.png" % ICON_ROOT
	},
	"worldspines": {
		"label": "Worldspines",
		"description": "Tharokh's attackable stone spires.",
		"path": "%s/worldspines.png" % ICON_ROOT
	},
	"element_fire": {
		"label": "Fire",
		"description": "Broad damage and Combust payoffs for a manipulated board.",
		"path": "%s/element_fire.png" % ICON_ROOT
	},
	"element_ice": {
		"label": "Ice",
		"description": "Creates Ice and Snowdrift Surfaces.",
		"path": "%s/element_ice.png" % ICON_ROOT
	},
	"element_lightning": {
		"label": "Lightning",
		"description": "Creates Electrified Surfaces and chains through grouped enemies.",
		"path": "%s/element_lightning.png" % ICON_ROOT
	},
	"element_air": {
		"label": "Air",
		"description": "Moves actors with deterministic push, pull, Move, and Blink patterns.",
		"path": "%s/element_air.png" % ICON_ROOT
	},
	"element_earth": {
		"label": "Earth",
		"description": "Creates Bramble and Poison Surfaces.",
		"path": "%s/element_earth.png" % ICON_ROOT
	}
}

const SKILL_ICONS: Dictionary = {
	"skill_quick_wits": {"label": "Quick Wits", "path": "%s/quick_wits.png" % SKILL_ICON_ROOT},
	"skill_measured_breath": {"label": "Measured Breath", "path": "%s/measured_breath.png" % SKILL_ICON_ROOT},
	"skill_ghost_stride": {"label": "Ghost Stride", "path": "%s/ghost_stride.png" % SKILL_ICON_ROOT},
	"skill_discerning_eye": {"label": "Discerning Eye", "path": "%s/discerning_eye.png" % SKILL_ICON_ROOT},
	"skill_long_dawn": {"label": "Long Dawn", "path": "%s/long_dawn.png" % SKILL_ICON_ROOT},
	"skill_sunpath": {"label": "Sunpath", "path": "%s/sunpath.png" % SKILL_ICON_ROOT},
	"skill_witchlight": {"label": "Witchlight", "path": "%s/witchlight.png" % SKILL_ICON_ROOT},
	"skill_dawnbrand": {"label": "Dawnbrand", "path": "%s/dawnbrand.png" % SKILL_ICON_ROOT},
	"skill_afterglow": {"label": "Afterglow", "path": "%s/afterglow.png" % SKILL_ICON_ROOT},
	"skill_open_sky": {"label": "Open Sky", "path": "%s/open_sky.png" % SKILL_ICON_ROOT},
	"skill_rehearsed_escape": {"label": "Rehearsed Escape", "path": "%s/rehearsed_escape.png" % SKILL_ICON_ROOT},
	"skill_makeshift_tool": {"label": "Makeshift Tool", "path": "%s/makeshift_tool.png" % SKILL_ICON_ROOT},
	"skill_carry_the_guard": {"label": "Carry the Guard", "path": "%s/carry_the_guard.png" % SKILL_ICON_ROOT},
	"skill_pain_remembers": {"label": "Pain Remembers", "path": "%s/pain_remembers.png" % SKILL_ICON_ROOT},
	"skill_sure_footed": {"label": "Sure-Footed", "path": "%s/sure_footed.png" % SKILL_ICON_ROOT},
	"skill_afterimage": {"label": "Afterimage", "path": "%s/afterimage.png" % SKILL_ICON_ROOT},
	"skill_deferred_choice": {"label": "Deferred Choice", "path": "%s/deferred_choice.png" % SKILL_ICON_ROOT},
	"skill_salvager": {"label": "Salvager", "path": "%s/salvager.png" % SKILL_ICON_ROOT},
	"skill_borrowed_time": {"label": "Borrowed Time", "path": "%s/borrowed_time.png" % SKILL_ICON_ROOT},
	"skill_last_reserve": {"label": "Last Reserve", "path": "%s/last_reserve.png" % SKILL_ICON_ROOT},
	"skill_plunderers_step": {"label": "Plunderer's Step", "path": "%s/plunderers_step.png" % SKILL_ICON_ROOT},
	"skill_prismatic_instinct": {"label": "Prismatic Instinct", "path": "%s/prismatic_instinct.png" % SKILL_ICON_ROOT},
	"skill_curators_patience": {"label": "Curator's Patience", "path": "%s/curators_patience.png" % SKILL_ICON_ROOT},
	"skill_living_shadow": {"label": "Living Shadow", "path": "%s/living_shadow.png" % SKILL_ICON_ROOT},
	"skill_true_bearing": {"label": "True Bearing", "path": "%s/true_bearing.png" % SKILL_ICON_ROOT},
	"skill_layaway": {"label": "Layaway", "path": "%s/layaway.png" % SKILL_ICON_ROOT},
	"skill_encore": {"label": "Encore", "path": "%s/encore.png" % SKILL_ICON_ROOT},
	"skill_open_arsenal": {"label": "Open Arsenal", "path": "%s/open_arsenal.png" % SKILL_ICON_ROOT},
	"skill_confluence": {"label": "Confluence", "path": "%s/confluence.png" % SKILL_ICON_ROOT},
	"skill_last_door": {"label": "Last Door", "path": "%s/last_door.png" % SKILL_ICON_ROOT},
}

## Action names may share an icon only when players experience them as the exact
## same concept. Keep this dictionary parseable by tests/test_icon_identity_policy.py.
const ACTION_ICON_ALIASES: Dictionary = {
	"aoe": "aoe",
	"blink": "blink",
	"block": "block",
	"card_play": "card_play",
	"cinder_marks": "cinder_marks",
	"consume": "consume",
	"detonate_cinders": "detonate_cinders",
	"dispel_umbra": "dispel_umbra",
	"draw": "draw",
	"exhaust": "exhaust",
	"field": "radiance",
	"frost_armor": "frost_armor",
	"gale_force": "gale_force",
	"guard_ally": "guard_ally",
	"heal": "heal",
	"heal_ally": "heal_ally",
	"heal_self": "heal",
	"health_cost": "health_cost",
	"illuminate": "illuminate",
	"illusion": "illusion",
	"lightning_strikes": "lightning_strikes",
	"melee": "melee",
	"move": "move",
	"move_away": "retreat",
	"move_toward": "move",
	"pull": "pull",
	"push": "push",
	"raise_terrain": "raise_terrain",
	"ranged": "ranged",
	"stoneskin": "stoneskin",
	"surface": "surface_bramble",
	"summon_minions": "summon_minions",
	"terrain_burst": "terrain_burst",
	"truesight": "truesight",
	"umbra_eclipse": "umbra_eclipse",
	"vision": "vision",
}

const CARD_ROLE_EMBLEM_PATHS: Dictionary = {
	"attack_melee": "res://assets/art/ui/card_role_emblems/role_attack_melee.png",
	"attack_ranged": "res://assets/art/ui/card_role_emblems/role_attack_ranged.png",
	"block": "res://assets/art/ui/card_role_emblems/role_block.png",
	"illusion": "res://assets/art/ui/card_role_emblems/role_illusion.png",
	"mobility": "res://assets/art/ui/card_role_emblems/role_mobility.png",
}

static func all_icon_keys() -> Array:
	var result: Array = KEYWORDS.keys()
	result.append_array(SKILL_ICONS.keys())
	return result

static func action_icon_key(action: Dictionary) -> String:
	var action_type: String = str(action.get("type", ""))
	if action_type == "field":
		return str(action.get("kind", "corruption"))
	if action_type == "surface":
		return "surface_%s" % str(action.get("kind", "bramble"))
	return str(ACTION_ICON_ALIASES.get(action_type, ""))

static func card_role_emblem_key(card: Dictionary) -> String:
	var authored_role: String = str(card.get("role_emblem", ""))
	if CARD_ROLE_EMBLEM_PATHS.has(authored_role):
		return authored_role
	var has_melee_attack: bool = false
	var has_ranged_attack: bool = false
	var has_block: bool = false
	var has_illusion: bool = false
	var has_mobility: bool = false
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		var action_type: String = str(action.get("type", ""))
		match action_type:
			"ranged":
				has_ranged_attack = true
			"melee", "terrain_burst":
				has_melee_attack = true
			"aoe", "push", "pull", "lightning_strikes", "cinder_marks", "gale_force", "umbra_eclipse":
				if int(action.get("range", 0)) > 1:
					has_ranged_attack = true
				else:
					has_melee_attack = true
			"block", "guard_ally", "stoneskin", "frost_armor", "raise_terrain":
				has_block = true
			"illusion":
				has_illusion = true
			"move", "move_toward", "move_away", "blink":
				has_mobility = true
	if has_ranged_attack:
		return "attack_ranged"
	if has_melee_attack:
		return "attack_melee"
	if has_block:
		return "block"
	if has_illusion:
		return "illusion"
	if has_mobility:
		return "mobility"
	return ""

static func card_role_emblem_path(card: Dictionary) -> String:
	return str(CARD_ROLE_EMBLEM_PATHS.get(card_role_emblem_key(card), ""))

static func icon_path(icon_key: String) -> String:
	return str(_icon_definition(icon_key).get("path", ""))

static func icon_texture(icon_key: String) -> Texture2D:
	return AssetLoader.load_texture(icon_path(icon_key))

static func label(icon_key: String) -> String:
	return str(_icon_definition(icon_key).get("label", icon_key.capitalize()))

static func description(icon_key: String) -> String:
	return str(_icon_definition(icon_key).get("description", ""))

static func _icon_definition(icon_key: String) -> Dictionary:
	if KEYWORDS.has(icon_key):
		return KEYWORDS.get(icon_key, {}) as Dictionary
	return SKILL_ICONS.get(icon_key, {}) as Dictionary

static func tooltip(icon_key: String) -> String:
	var text: String = label(icon_key)
	var detail: String = description(icon_key)
	if detail.is_empty():
		return text
	return "%s\n%s" % [text, detail]

static func tooltip_entries_for_rows(
	rows: Array,
	leading_icon_keys: Array = []
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for icon_key_var: Variant in leading_icon_keys:
		var leading_icon_key: String = str(icon_key_var)
		_append_tooltip_entry(entries, seen, leading_icon_key, tooltip(leading_icon_key))
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		for token_var: Variant in row_var as Array:
			if typeof(token_var) != TYPE_DICTIONARY:
				continue
			var token: Dictionary = token_var as Dictionary
			if str(token.get("kind", "")) == "text":
				continue
			var icon_key: String = str(token.get("icon", ""))
			if str(token.get("kind", "")) == "aoe_pattern":
				icon_key = "aoe"
			_append_tooltip_entry(entries, seen, icon_key, token_tooltip(token))
	return entries

static func _append_tooltip_entry(
	entries: Array[Dictionary],
	seen: Dictionary,
	icon_key: String,
	tooltip_text: String
) -> void:
	var normalized_tooltip: String = tooltip_text.strip_edges()
	if normalized_tooltip.is_empty():
		normalized_tooltip = tooltip(icon_key)
	var semantic_key: String = "%s\u001f%s" % [icon_key, normalized_tooltip]
	if icon_key.is_empty() or seen.has(semantic_key):
		return
	var texture: Texture2D = icon_texture(icon_key)
	if texture == null:
		return
	seen[semantic_key] = true
	var copy: Dictionary = _tooltip_entry_copy(icon_key, normalized_tooltip)
	entries.append({
		"icon": icon_key,
		"texture": texture,
		"title": str(copy.get("title", label(icon_key))),
		"description": str(copy.get("description", "")),
		"tooltip": normalized_tooltip,
		"semantic_key": semantic_key,
	})

static func _tooltip_entry_copy(icon_key: String, tooltip_text: String) -> Dictionary:
	var default_title: String = label(icon_key)
	var lines: PackedStringArray = tooltip_text.split("\n", false)
	var body_start: int = 0
	var title_text: String = default_title
	if not lines.is_empty():
		var first_line: String = lines[0].strip_edges()
		var first_lower: String = first_line.to_lower()
		var default_lower: String = default_title.to_lower()
		if first_lower == default_lower or first_lower.begins_with("%s " % default_lower):
			title_text = first_line
			body_start = 1
	var body_lines := PackedStringArray()
	for index: int in range(body_start, lines.size()):
		var body_line: String = lines[index].strip_edges()
		if not body_line.is_empty():
			body_lines.append(body_line)
	return {
		"title": title_text,
		"description": "\n".join(body_lines),
	}

static func token_tooltip(token: Dictionary) -> String:
	var text: String = str(token.get("tooltip", tooltip(str(token.get("icon", "")))))
	var modifier_lines: PackedStringArray = _modifier_tooltip_lines(token)
	if modifier_lines.is_empty():
		return text
	return "%s\nModified by:\n%s" % [text, "\n".join(modifier_lines)]

static func token_value_text(token: Dictionary) -> String:
	if not token.has("value"):
		return ""
	var value: Variant = token.get("value", "")
	if value == null:
		return ""
	return str(value)

static func token_for(icon_key: String, value: Variant = null, tone: String = "neutral", tooltip_override: String = "", modifiers: Array = [], base_value: Variant = null) -> Dictionary:
	var token: Dictionary = {
		"icon": icon_key,
		"tone": tone
	}
	if value != null:
		token["value"] = value
	if not tooltip_override.is_empty():
		token["tooltip"] = tooltip_override
	if not modifiers.is_empty():
		token["modifiers"] = modifiers.duplicate(true)
		token["modified"] = true
		if base_value != null:
			token["base_value"] = base_value
	return token

static func text_token(text: String, tone: String = "neutral", tooltip_override: String = "") -> Dictionary:
	var token: Dictionary = {
		"kind": "text",
		"value": text,
		"tone": tone
	}
	if not tooltip_override.is_empty():
		token["tooltip"] = tooltip_override
	return token

static func element_icon_key(element_id: String) -> String:
	return "element_%s" % str(element_id)

static func token_is_modified(token: Dictionary) -> bool:
	return bool(token.get("modified", false)) or not (token.get("modifiers", []) as Array).is_empty()

static func _token_for_action_field(action: Dictionary, icon_key: String, field: String, value: Variant = null, tone: String = "neutral", tooltip_override: String = "", base_value: Variant = null, extra_modifiers: Array = []) -> Dictionary:
	var modifiers: Array = _action_modifiers_for_field(action, field)
	for modifier_var: Variant in extra_modifiers:
		if typeof(modifier_var) == TYPE_DICTIONARY:
			modifiers.append((modifier_var as Dictionary).duplicate(true))
	var resolved_base_value: Variant = base_value
	if resolved_base_value == null and value != null and not modifiers.is_empty() and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		resolved_base_value = int(value) - _modifier_amount_total(modifiers)
	var resolved_tone: String = tone
	if resolved_tone == "neutral" and resolved_base_value != null and value != null and typeof(value) in [TYPE_INT, TYPE_FLOAT] and typeof(resolved_base_value) in [TYPE_INT, TYPE_FLOAT]:
		resolved_tone = _value_tone(int(value), int(resolved_base_value))
	var token: Dictionary = token_for(icon_key, value, resolved_tone, tooltip_override, modifiers, resolved_base_value)
	if not field.is_empty():
		token["field"] = field
	return token

static func _action_modifiers_for_field(action: Dictionary, field: String) -> Array:
	var modifiers: Array = []
	if typeof(action.get("_modifiers", {})) != TYPE_DICTIONARY:
		return modifiers
	var modifiers_by_field: Dictionary = action.get("_modifiers", {}) as Dictionary
	var modifier_keys: Array = ["_action"]
	if field != "_action":
		modifier_keys.append(field)
	for key: String in modifier_keys:
		if key.is_empty():
			continue
		if typeof(modifiers_by_field.get(key, [])) != TYPE_ARRAY:
			continue
		for modifier_var: Variant in modifiers_by_field.get(key, []):
			if typeof(modifier_var) == TYPE_DICTIONARY:
				modifiers.append((modifier_var as Dictionary).duplicate(true))
	return modifiers

static func _option_modifiers_for_field(options: Dictionary, field: String) -> Array:
	var modifiers: Array = []
	var field_key: String = "%s_modifiers" % field
	if typeof(options.get(field_key, [])) == TYPE_ARRAY:
		for modifier_var: Variant in options.get(field_key, []):
			if typeof(modifier_var) == TYPE_DICTIONARY:
				modifiers.append((modifier_var as Dictionary).duplicate(true))
	if typeof(options.get("modifiers_by_field", {})) == TYPE_DICTIONARY:
		var by_field: Dictionary = options.get("modifiers_by_field", {}) as Dictionary
		if typeof(by_field.get(field, [])) == TYPE_ARRAY:
			for modifier_var: Variant in by_field.get(field, []):
				if typeof(modifier_var) == TYPE_DICTIONARY:
					modifiers.append((modifier_var as Dictionary).duplicate(true))
	return modifiers

static func _modifier_amount_total(modifiers: Array) -> int:
	var total: int = 0
	for modifier_var: Variant in modifiers:
		if typeof(modifier_var) != TYPE_DICTIONARY:
			continue
		total += int((modifier_var as Dictionary).get("amount", 0))
	return total

static func _modifier_tooltip_lines(token: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for modifier_var: Variant in token.get("modifiers", []):
		if typeof(modifier_var) != TYPE_DICTIONARY:
			continue
		var modifier: Dictionary = modifier_var
		var source: String = str(modifier.get("source", "Modifier"))
		var label_text: String = str(modifier.get("label", ""))
		if label_text.is_empty() and int(modifier.get("amount", 0)) != 0:
			label_text = "%+d" % int(modifier.get("amount", 0))
		var detail: String = str(modifier.get("detail", ""))
		var line: String = source
		if not label_text.is_empty():
			line = "%s %s" % [line, label_text]
		if not detail.is_empty():
			line = "%s  %s" % [line, detail]
		lines.append(line)
	return lines

static func rows_for_actions(actions: Array, options_by_index: Array = []) -> Array:
	var rows: Array = []
	var previous_action_row_index: int = -1
	for index: int in range(actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[index] as Dictionary
		var options: Dictionary = {}
		if index < options_by_index.size() and typeof(options_by_index[index]) == TYPE_DICTIONARY:
			options = options_by_index[index]
		var row: Array = tokens_for_action(action, options)
		previous_action_row_index = append_action_row(rows, action, row, previous_action_row_index)
	return rows

static func append_action_row(rows: Array, action: Dictionary, row: Array, previous_action_row_index: int = -1) -> int:
	if row.is_empty():
		return previous_action_row_index
	if bool(action.get("reuse_previous_target", false)) and previous_action_row_index >= 0 and previous_action_row_index < rows.size():
		var shared_row: Array = (rows[previous_action_row_index] as Array).duplicate(true)
		for token_var: Variant in row:
			if typeof(token_var) == TYPE_DICTIONARY and _duplicates_shared_range(shared_row, token_var as Dictionary):
				continue
			shared_row.append(token_var)
		for token_index: int in range(shared_row.size()):
			if typeof(shared_row[token_index]) != TYPE_DICTIONARY:
				continue
			var token: Dictionary = (shared_row[token_index] as Dictionary).duplicate(true)
			token["keep_row_together"] = true
			shared_row[token_index] = token
		rows[previous_action_row_index] = shared_row
		return previous_action_row_index
	rows.append(row)
	return rows.size() - 1

static func _duplicates_shared_range(row: Array, candidate: Dictionary) -> bool:
	if str(candidate.get("icon", "")) != "range":
		return false
	for existing_var: Variant in row:
		if typeof(existing_var) != TYPE_DICTIONARY:
			continue
		var existing: Dictionary = existing_var
		if str(existing.get("icon", "")) == "range" and existing.get("value", null) == candidate.get("value", null):
			return true
	return false

static func rows_for_card(card: Dictionary, options_by_index: Array = []) -> Array:
	var rows: Array = cost_rows_for_card(card)
	rows.append_array(rows_for_actions(card.get("actions", []), options_by_index))
	return rows

static func cost_rows_for_card(card: Dictionary) -> Array:
	var row: Array = []
	if bool(card.get("burn", false)):
		row.append(token_for("exhaust"))
	if bool(card.get("consume_on_play", false)):
		row.append(token_for("consume"))
	if bool(card.get("flurry", false)):
		row.append(token_for("flurry"))
	var health_cost: int = int(card.get("health_cost", 0))
	if health_cost > 0:
		row.append(token_for("health_cost", "-%d" % health_cost))
	return [row] if not row.is_empty() else []

static func tokens_for_action(action: Dictionary, options: Dictionary = {}) -> Array:
	var action_type: String = str(action.get("type", ""))
	var tokens: Array = []
	match action_type:
		"cost":
			if bool(action.get("exhaust", false)):
				tokens.append(token_for("exhaust"))
			var health_cost: int = int(action.get("health", action.get("health_cost", 0)))
			if health_cost > 0:
				tokens.append(token_for("health_cost", "-%d" % health_cost))
		"exhaust":
			tokens.append(token_for("exhaust"))
		"consume":
			tokens.append(token_for("consume"))
		"health_cost":
			var health_cost: int = int(action.get("amount", action.get("health", 0)))
			if health_cost > 0:
				tokens.append(token_for("health_cost", "-%d" % health_cost))
		"move", "move_toward":
			tokens.append(_token_for_action_field(action, "move", "range", int(action.get("range", 0))))
			_append_illuminate_rider_tokens(tokens, action)
		"move_away":
			tokens.append(_token_for_action_field(action, "retreat", "range", int(action.get("range", 0))))
			_append_illuminate_rider_tokens(tokens, action)
		"blink":
			tokens.append(_token_for_action_field(action, "blink", "range", int(action.get("range", 0))))
			_append_illuminate_rider_tokens(tokens, action)
		"melee":
			_append_damage_token(tokens, _damage_icon_for_action(action, "melee"), action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
			_append_illuminate_rider_tokens(tokens, action)
		"ranged":
			_append_damage_token(tokens, _damage_icon_for_action(action, "ranged"), action, options)
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
			_append_illuminate_rider_tokens(tokens, action)
		"aoe":
			_append_damage_token(tokens, _damage_icon_for_action(action, "ranged" if int(action.get("range", 0)) > 0 else "melee"), action, options)
			if int(action.get("range", 0)) > 0:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			tokens.append(_aoe_pattern_token(action))
			_append_keyword_tokens(tokens, action)
			_append_illuminate_rider_tokens(tokens, action)
		"push":
			_append_optional_hit_token(tokens, action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
			tokens.append(_token_for_action_field(action, "push", "amount", int(action.get("amount", 0))))
			_append_illuminate_rider_tokens(tokens, action)
		"pull":
			_append_optional_hit_token(tokens, action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
			tokens.append(_token_for_action_field(action, "pull", "amount", int(action.get("amount", 0))))
			_append_illuminate_rider_tokens(tokens, action)
		"block", "guard_ally":
			tokens.append(_token_for_action_field(action, "block", "amount", int(action.get("amount", 0))))
		"stoneskin":
			tokens.append(_token_for_action_field(action, "stoneskin", "amount", int(action.get("amount", 0))))
		"heal", "heal_self", "heal_ally":
			tokens.append(_token_for_action_field(action, "heal", "amount", int(action.get("amount", 0))))
		"draw":
			tokens.append(_token_for_action_field(action, "draw", "amount", int(action.get("amount", 0))))
		"card_play":
			tokens.append(_token_for_action_field(action, "card_play", "amount", int(action.get("amount", 0))))
		"field":
			_append_direct_tile_effect_tokens(tokens, action, "field")
		"surface":
			_append_direct_tile_effect_tokens(tokens, action, "surface")
		"illusion":
			tokens.append(_token_for_action_field(action, "illusion", "health", int(action.get("health", action.get("amount", 0)))))
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Illusion placement range."))
		"illuminate":
			tokens.append(_token_for_action_field(action, "illuminate", "radius", int(action.get("radius", action.get("amount", 1))), "neutral", "Light radius in tiles."))
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Light placement range."))
			var light_duration: int = int(action.get("duration", 1))
			tokens.append(token_for("time", "∞" if light_duration < 0 else light_duration, "neutral", "Player turns this light remains."))
		"vision":
			tokens.append(_token_for_action_field(action, "vision", "amount", int(action.get("amount", 0))))
			var vision_duration: int = int(action.get("duration", 1))
			tokens.append(token_for("time", "∞" if vision_duration < 0 else vision_duration, "neutral", "Player turns this vision remains."))
		"truesight":
			var truesight_duration: int = int(action.get("duration", action.get("amount", 1)))
			tokens.append(token_for("truesight", "∞" if truesight_duration < 0 else truesight_duration))
		"dispel_umbra":
			tokens.append(_token_for_action_field(action, "dispel_umbra", "amount", int(action.get("amount", 1))))
		"lightning_strikes":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(_token_for_action_field(action, "shock", "count", int(action.get("count", 0)), "neutral", "Random lightning strikes."))
			_append_keyword_tokens(tokens, action)
		"summon_minions":
			tokens.append(_token_for_action_field(action, "shock", "count", int(action.get("count", 0)), "neutral", "Summons lightning wisps."))
		"raise_terrain":
			tokens.append(_token_for_action_field(action, "stoneskin", "count", int(action.get("count", 0)), "neutral", "Raises attackable Worldspines around the arena."))
			tokens.append(_token_for_action_field(action, "health", "health", int(action.get("health", 0)), "neutral", "Health of each Worldspine."))
		"terrain_burst":
			_append_damage_token(tokens, "melee", action, options)
			tokens.append(text_token("Spire burst", "warning", "Every surviving Worldspine ruptures nearby tiles, then breaks."))
		"cinder_marks":
			tokens.append(_token_for_action_field(action, "burn", "count", int(action.get("count", 0)), "neutral", "Places attackable cinder marks; surviving marks detonate on the dragon's next turn."))
			_append_damage_token(tokens, "ranged", action, options)
			_append_keyword_tokens(tokens, action)
		"detonate_cinders":
			tokens.append(token_for("burn", null, "warning", "Detonates every surviving cinder mark in a blast around it."))
		"gale_force":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(_token_for_action_field(action, "push", "amount", int(action.get("amount", 0)), "neutral", "Pushes the player away from the dragon through arena hazards."))
		"frost_armor":
			tokens.append(_token_for_action_field(action, "freeze", "amount", int(action.get("amount", 0)), "neutral", "Forms crystal armor. Each damaging hit breaks one layer instead of dealing damage."))
		"umbra_eclipse":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(_token_for_action_field(action, "eclipse", "duration", int(action.get("duration", 0)), "neutral", "Forces Eclipse for this many player turns. Radiance and light protect affected tiles."))
	if action_type not in ["field", "surface"]:
		_append_authored_tile_effect_rider_tokens(tokens, action)
	return tokens

static func _append_direct_tile_effect_tokens(tokens: Array, action: Dictionary, layer: String) -> void:
	var kind: String = str(action.get("kind", ""))
	if kind.is_empty():
		return
	var icon_key: String = kind if layer == "field" else "surface_%s" % kind
	var duration: int = maxi(1, int(action.get("duration", 18)))
	tokens.append(token_for(icon_key, duration, "neutral", "%s remains for %d Time." % [label(icon_key), duration]))
	if int(action.get("range", 0)) > 0:
		tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "%s placement range." % layer.capitalize()))

static func _append_authored_tile_effect_rider_tokens(tokens: Array, action: Dictionary) -> void:
	for layer: String in ["field", "surface"]:
		var kind: String = str(action.get("%s_kind" % layer, ""))
		if kind.is_empty():
			continue
		var icon_key: String = kind if layer == "field" else "surface_%s" % kind
		var duration: int = maxi(1, int(action.get("%s_duration" % layer, 18)))
		tokens.append(token_for(icon_key, duration, "neutral", "%s is placed by this action for %d Time." % [label(icon_key), duration]))
	if bool(action.get("combust", false)):
		tokens.append(token_for("combust", null, "bonus"))

static func plain_text_for_tokens(tokens: Array) -> String:
	var parts: PackedStringArray = []
	for token_var: Variant in tokens:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "aoe_pattern":
			parts.append("Area")
			continue
		if str(token.get("kind", "")) == "text":
			parts.append(token_value_text(token))
			continue
		var value_text: String = token_value_text(token)
		if value_text.is_empty():
			parts.append(label(str(token.get("icon", ""))))
		else:
			parts.append("%s %s" % [label(str(token.get("icon", ""))), value_text])
	return "  ".join(parts)

static func plain_text_for_rows(rows: Array) -> String:
	var lines: PackedStringArray = []
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		lines.append(plain_text_for_tokens(row_var as Array))
	return "\n".join(lines)

static func _append_damage_token(tokens: Array, icon_key: String, action: Dictionary, options: Dictionary) -> void:
	var base_damage: int = int(action.get("damage", 0))
	var final_damage: int = int(options.get("final_damage", base_damage))
	var tone_base_damage: int = int(options.get("tone_base_damage", base_damage))
	tokens.append(_token_for_action_field(
		action,
		icon_key,
		"damage",
		final_damage,
		_damage_tone(final_damage, tone_base_damage),
		"",
		tone_base_damage,
		_option_modifiers_for_field(options, "damage")
	))

static func _damage_icon_for_action(action: Dictionary, fallback_icon: String) -> String:
	return "pierce" if bool(action.get("pierce", false)) else fallback_icon

static func _append_optional_hit_token(tokens: Array, action: Dictionary, options: Dictionary) -> void:
	if int(action.get("damage", 0)) <= 0:
		return
	var base_damage: int = int(action.get("damage", 0))
	var final_damage: int = int(options.get("final_damage", base_damage))
	var tone_base_damage: int = int(options.get("tone_base_damage", base_damage))
	tokens.append(_token_for_action_field(
		action,
		_damage_icon_for_action(action, "melee"),
		"damage",
		final_damage,
		_damage_tone(final_damage, tone_base_damage),
		"",
		tone_base_damage,
		_option_modifiers_for_field(options, "damage")
	))

static func _aoe_pattern_token(action: Dictionary) -> Dictionary:
	return {
		"kind": "aoe_pattern",
		"icon": "aoe_pattern",
		"pattern": action.get("pattern", []),
		"show_origin": int(action.get("range", 0)) <= 0,
		"tooltip": "Area pattern\nRed tiles are hit%s." % (" relative to you" if int(action.get("range", 0)) <= 0 else "")
	}

static func _append_keyword_tokens(tokens: Array, action: Dictionary) -> void:
	if int(action.get("bleed", 0)) > 0:
		tokens.append(_token_for_action_field(action, "bleed", "bleed", int(action.get("bleed", 0))))
	if int(action.get("expose", 0)) > 0:
		tokens.append(_token_for_action_field(action, "expose", "expose", int(action.get("expose", 0))))
	if int(action.get("sunder", 0)) > 0:
		tokens.append(_token_for_action_field(action, "sunder", "sunder", int(action.get("sunder", 0))))
	if bool(action.get("immobilize", false)):
		tokens.append(_token_for_action_field(action, "immobilize", "immobilize"))
	if int(action.get("chain", 0)) > 0:
		tokens.append(_token_for_action_field(action, "chain", "chain", int(action.get("chain", 0))))
	if int(action.get("push", 0)) > 0:
		tokens.append(_token_for_action_field(action, "push", "push", int(action.get("push", 0))))
	if int(action.get("pull", 0)) > 0:
		tokens.append(_token_for_action_field(action, "pull", "pull", int(action.get("pull", 0))))

static func _append_illuminate_rider_tokens(tokens: Array, action: Dictionary) -> void:
	var radius: int = int(action.get("illuminate_radius", 0))
	if radius <= 0:
		return
	var action_type: String = str(action.get("type", ""))
	var radius_tooltip: String = "After this attack resolves, create Light at its impact within this radius."
	var duration_tooltip: String = "Player turns this light remains at the impact."
	if action_type in ["move", "move_toward", "move_away", "blink"]:
		radius_tooltip = "After this movement resolves, create Light where you arrive within this radius."
		duration_tooltip = "Player turns this light remains at your destination."
	tokens.append(_token_for_action_field(
		action,
		"illuminate",
		"illuminate_radius",
		radius,
		"neutral",
		radius_tooltip
	))
	var duration: int = int(action.get("illuminate_duration", 1))
	tokens.append(_token_for_action_field(
		action,
		"time",
		"illuminate_duration",
		"∞" if duration < 0 else duration,
		"neutral",
		duration_tooltip
	))

static func _damage_tone(final_damage: int, base_damage: int) -> String:
	return _value_tone(final_damage, base_damage)

static func _value_tone(final_value: int, base_value: int) -> String:
	if final_value > base_value:
		return "bonus"
	if final_value < base_value:
		return "penalty"
	return "neutral"
