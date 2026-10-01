extends RefCounted
class_name ActionIconLibrary

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")

const ICON_ROOT: String = "res://assets/art/icons"
const SKILL_ICON_ROOT: String = "res://assets/art/skills"

const KEYWORDS: Dictionary = {
	"raise_cover": {"label":"Raise Cover","description":"Spend 1 independent Move and all Stoneskin. Place cover within 2 with that much HP.","path":"res://assets/art/icons/guardians/raise_cover.png"},
	"reclaim_cover": {"label":"Reclaim Cover","description":"Spend 1 independent Move to remove adjacent owned cover and recover its surviving HP as Stoneskin.","path":"res://assets/art/icons/guardians/reclaim_cover.png"},
	"surface": {"label": "Shape Ground", "description": "Creates a surface in the shown area.", "path": "%s/surface.png" % ICON_ROOT},
	"surface_fire": {"label": "Fire", "description": "Deals 3 damage on turn start and 2 damage when entered.", "path": "%s/surface_fire.png" % ICON_ROOT},
	"surface_ice": {"label": "Ice", "description": "Entering or starting a turn on Ice applies Chilled.", "path": "%s/surface_ice.png" % ICON_ROOT},
	"surface_electrified": {"label": "Electrified", "description": "Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.", "path": "%s/surface_electrified.png" % ICON_ROOT},
	"surface_rubble": {"label": "Rubble", "description": "Costs 2 movement to leave.", "path": "%s/surface_rubble.png" % ICON_ROOT},
	"chilled": {"label": "Chilled", "description": "Takes +2 attack damage. An Ice hit Freezes this character and consumes the Ice beneath them.", "path": "%s/chilled.png" % ICON_ROOT},
	"detonate": {"label": "Detonate", "description": "Consumes Fire tiles to damage targets on them and their four neighboring tiles.", "path": "%s/detonate.png" % ICON_ROOT},
	"surface_consume": {"label": "Consume Ground", "description": "Consumes the shown surface to gain its reward.", "path": "%s/surface_consume.png" % ICON_ROOT},
	"surface_relocate": {"label": "Relocate Ground", "description": "Moves a surface to another tile.", "path": "%s/surface_relocate.png" % ICON_ROOT},
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
		"description": "Absorbs damage until your next turn.",
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
		"description": "Repeats this card once per remaining card play, spending them all. Pays Time once.",
		"path": "%s/flurry.png" % ICON_ROOT
	},
	"follow_up": {"label": "Follow-up", "description": "Gains the listed bonus if you already played a card this turn.", "path": "%s/follow_up.png" % ICON_ROOT},
	"empower": {"label": "Empower", "description": "Optional: pay the listed extra cost while playing this card to gain the listed bonus.", "path": "%s/empower.png" % ICON_ROOT},
	"stagger": {"label": "Stagger", "description": "Delays the target's next turn by this much Time. Dragons take half. At most 6 per enemy each turn.", "path": "%s/stagger.png" % ICON_ROOT},
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
	"bleed": {
		"label": "Bleed",
		"description": "Deals damage before moving or attacking. Lasts through the next turn.",
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
	"retaliate": {"label": "Retaliate", "description": "Until your next turn, an enemy that hits you in melee takes this much damage (Block and Stoneskin absorb it) and any listed riders. Several Retaliates add up.", "path": "%s/retaliate.png" % ICON_ROOT},
	"quicken": {"label": "Quicken", "description": "Your next card this turn costs this much less Time (minimum 1). Several Quickens add up; unused Quicken ends with your turn.", "path": "%s/quicken.png" % ICON_ROOT},
	"rite": {"label": "Rite", "description": "Rite: Exhaust. Lasts for the rest of this combat.", "path": "%s/rite.png" % ICON_ROOT},
	"next_attack": {
		"label": "Next Attack",
		"description": "Your next attack on a later card this turn gains the shown bonus, then the bonus is spent. Unused bonuses end with your turn.",
		"path": "%s/next_attack.png" % ICON_ROOT
	},
	# Wave-4 maneuver family (spec/card_mechanics_maneuver.md).
	"swap": {"label": "Swap", "description": "Swap places with a visible one-tile enemy or one of your illusions. Both of you arrive normally; nothing collides, and Anchored does not stop it.", "path": "%s/swap.png" % ICON_ROOT},
	"petrify": {"label": "Petrify", "description": "The enemy skips its next turn (the skipped turn still costs its Time) and gains Block that lasts through your next turn. Not Freeze: no extra damage. Dragons are immune.", "path": "%s/petrify.png" % ICON_ROOT},
	"cleanse": {"label": "Cleanse", "description": "Removes the listed statuses from you: Bleed, Immobilize, Chilled or Shock.", "path": "%s/cleanse.png" % ICON_ROOT},
	"skate": {"label": "Skate", "description": "This turn, moving onto Ice costs no movement and Ice doesn't Chill you.", "path": "%s/skate.png" % ICON_ROOT},
	"anchored": {"label": "Anchored", "description": "Until your next turn, you can't be pushed or pulled: Push and Pull move you 0 tiles and never collide.", "path": "%s/anchored.png" % ICON_ROOT},
	"fireproof": {"label": "Fireproof", "description": "Fire doesn't damage you this turn.", "path": "%s/fireproof.png" % ICON_ROOT},
	# Wave-4 surface family (spec/card_mechanics_surfaces.md).
	"surface_convert": {"label": "Convert Ground", "description": "Turns the chosen surface tile, and every tile of it connected to it when shown, into another surface. Each enemy on a converted tile takes the damage.", "path": "%s/surface_convert.png" % ICON_ROOT},
	"discharge": {"label": "Discharge", "description": "Removes a connected Electrified network. Each enemy on it or next to it takes the damage once.", "path": "%s/discharge.png" % ICON_ROOT},
	"all_enemies": {"label": "Sweeping Strike", "description": "Hits every enemy you can see that meets the shown condition. There is no target to choose, and enemies hidden by the Umbra are never hit.", "path": "%s/all_enemies.png" % ICON_ROOT},
	# Wave-4 illusion family (spec/card_mechanics_illusions_terrain.md).
	"illusion_swap": {"label": "Swap Illusion", "description": "You and one of your illusions trade tiles. Both of you trigger the ground and traps where you land. Immobilize prevents it.", "path": "%s/illusion_swap.png" % ICON_ROOT},
	"shatter_illusion": {"label": "Shatter Illusion", "description": "Destroys one of your illusions to blast each enemy next to it.", "path": "%s/shatter_illusion.png" % ICON_ROOT},
	"freeze": {
		"label": "Freeze",
		"description": "Skips the next turn and takes triple attack damage.",
		"path": "%s/freeze.png" % ICON_ROOT
	},
	"shock": {
		"label": "Shock",
		"description": "Cancels the next non-movement action.",
		"path": "%s/shock.png" % ICON_ROOT
	},
	"immobilize": {
		"label": "Immobilize",
		"description": "Prevents movement and Blink next turn.",
		"path": "%s/immobilize.png" % ICON_ROOT
	},
	"chain": {
		"label": "Chain",
		"description": "Jumps between targets within the shown range. Electrified tiles extend its reach.",
		"path": "%s/chain.png" % ICON_ROOT
	},
	"push": {
		"label": "Push",
		"description": "Forces the target away in one straight line. If it's stopped early, it collides.",
		"path": "%s/push.png" % ICON_ROOT
	},
	"pull": {
		"label": "Pull",
		"description": "Forces the target closer in one straight line. If it's stopped early, it collides.",
		"path": "%s/pull.png" % ICON_ROOT
	},
	"collision": {
		"label": "Collision",
		"description": "A stopped Push or Pull deals 2 damage per tile not moved to the target and to whatever stopped it. Walls take nothing. Block and Stoneskin absorb it.",
		"path": "%s/collision.png" % ICON_ROOT
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
		"label": "Kindle Ground",
		"description": "Creates Fire on the marked tiles.",
		"path": "%s/cinder_marks.png" % ICON_ROOT
	},
	"detonate_cinders": {
		"label": "Crownfire",
		"description": "Consumes Fire to damage targets on it and its four neighboring tiles.",
		"path": "%s/detonate_cinders.png" % ICON_ROOT
	},
	"gale_force": {
		"label": "Hollow Gale",
		"description": "Sweeps the target through the arena.",
		"path": "%s/gale_force.png" % ICON_ROOT
	},
	"frost_armor": {
		"label": "Crystal Mantle",
		"description": "Each layer prevents one direct damaging hit, then breaks.",
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
		"label": "Radiance",
		"description": "Carries protective light into the Umbra.",
		"path": "%s/radiance.png" % ICON_ROOT
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
		"path": "%s/map_rooms.png" % ICON_ROOT,
		"toolbar_path": "%s/ui/map_toolbar.svg" % ICON_ROOT
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
		"description": "Shapes dangerous ground and consumes it in powerful blasts.",
		"path": "%s/element_fire.png" % ICON_ROOT
	},
	"element_ice": {
		"label": "Ice",
		"description": "Prepares Ice, Chills exposed units and Freezes with a later Ice hit.",
		"path": "%s/element_ice.png" % ICON_ROOT
	},
	"element_lightning": {
		"label": "Lightning",
		"description": "Conducts through Electrified ground and rewards connected targets.",
		"path": "%s/element_lightning.png" % ICON_ROOT
	},
	"element_air": {
		"label": "Air",
		"description": "Controls positioning with movement, Push and Pull.",
		"path": "%s/element_air.png" % ICON_ROOT
	},
	"element_earth": {
		"label": "Earth",
		"description": "Creates Rubble and persistent Stoneskin defense.",
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
	# Wave-4 surface family (spec/card_mechanics_surfaces.md). Wards are the
	# Shape Ground action placed under each adjacent enemy.
	"all_enemies": "all_enemies",
	"surface": "surface",
	"surface_adjacent_enemies": "surface",
	"convert_surface": "surface_convert",
	"detonate": "detonate",
	"consume_surface": "surface_consume",
	"discharge": "discharge",
	"surface_relocate": "surface_relocate",
	"blink": "blink",
	"block": "block",
	# Card pool wave 4 (spec/card_mechanics_illusions_terrain.md): Rockburst and
	# Worldbreak burst terrain exactly like the Worldspine pulse.
	"burst_terrain": "terrain_burst",
	"card_play": "card_play",
	"cinder_marks": "cinder_marks",
	# The Meteorfall card marks tiles exactly like the dragon's Meteorfall.
	"meteor_marks": "cinder_marks",
	"consume": "consume",
	"detonate_cinders": "detonate_cinders",
	"destroy_illusion": "shatter_illusion",
	"dispel_umbra": "dispel_umbra",
	"draw": "draw",
	"exhaust": "exhaust",
	"frost_armor": "frost_armor",
	"gale_force": "gale_force",
	"guard_ally": "guard_ally",
	"heal": "heal",
	"heal_ally": "heal_ally",
	"heal_self": "heal",
	"health_cost": "health_cost",
	"illuminate": "illuminate",
	"illusion": "illusion",
	"illusion_swap": "illusion_swap",
	"lightning_strikes": "lightning_strikes",
	"melee": "melee",
	"move": "move",
	"move_away": "retreat",
	"move_toward": "move",
	"outcrop": "raise_terrain",
	"next_attack": "next_attack",
	"pull": "pull",
	"push": "push",
	"quicken": "quicken",
	"raise_terrain": "raise_terrain",
	"ranged": "ranged",
	"retaliate": "retaliate",
	"rite": "rite",
	"stoneskin": "stoneskin",
	"summon_minions": "summon_minions",
	"terrain_burst": "terrain_burst",
	"truesight": "truesight",
	"umbra_eclipse": "umbra_eclipse",
	"vision": "vision",
	# Wave-4 family B (spec/card_mechanics_maneuver.md). Exact concepts:
	# force_area is Push (or Pull, see action_icon_key) on an area; mantle is
	# Crystal Mantle; convert_block_to_stoneskin is a Stoneskin gain.
	"force_area": "push",
	"mantle": "frost_armor",
	"convert_block_to_stoneskin": "stoneskin",
	"swap": "swap",
	"cleanse": "cleanse",
	"petrify": "petrify",
}

## `self_flag` has no single identity: each flag resolves here, for card rows,
## action steps and the player's status badges alike. `no_move` (Rooted: you
## can't Move or Blink) is the exact Immobilize concept. Keep this dictionary
## parseable by tests/test_icon_identity_policy.py.
const SELF_FLAG_ICON_KEYS: Dictionary = {
	"ice_skate": "skate",
	"no_move": "immobilize",
	"anchored": "anchored",
	"fire_immune_turn": "fireproof",
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
	if action_type == "force_area" and int(action.get("pull", 0)) > 0 and int(action.get("push", 0)) <= 0:
		return "pull"
	if action_type == "self_flag":
		return str(SELF_FLAG_ICON_KEYS.get(str(action.get("flag", "")), ""))
	return str(ACTION_ICON_ALIASES.get(action_type, ""))

## Outcrop kinds that are thrown at enemies rather than raised as cover.
const OFFENSIVE_OUTCROP_KINDS: Array = ["powder_keg", "worldspine"]
## Self flags that defend in place; the others (Skate, Fireproof) are movement stances.
const DEFENSIVE_SELF_FLAGS: Array = ["no_move", "anchored"]

## One watermark per card. Primary roles win in the order ranged attack, melee
## attack, block, illusion, mobility. Setup riders (Next Attack, Cleanse, wards,
## Quicken, Detonate by the attack range rule, a Stoneskin/Block-paying ground
## consume) choose a role only when the card has no primary role, so Capacitor
## stays a shield, Smelling Salts stays a boot and Cinder Second stays a shield
## while Magma Vent and Immolation read as attacks.
static func card_role_emblem_key(card: Dictionary) -> String:
	var authored_role: String = str(card.get("role_emblem", ""))
	if CARD_ROLE_EMBLEM_PATHS.has(authored_role):
		return authored_role
	var has_melee_attack: bool = false
	var has_ranged_attack: bool = false
	var has_block: bool = false
	var has_illusion: bool = false
	var has_mobility: bool = false
	var setup_attack: bool = false
	var setup_ranged_attack: bool = false
	var setup_block: bool = false
	var setup_mobility: bool = false
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		var action_type: String = str(action.get("type", ""))
		if action_type == "outcrop" and str(action.get("kind", "")) in OFFENSIVE_OUTCROP_KINDS:
			action_type = "offensive_outcrop"
		match action_type:
			"ranged", "all_enemies":
				has_ranged_attack = true
			"melee", "terrain_burst":
				has_melee_attack = true
			"aoe", "push", "pull", "lightning_strikes", "cinder_marks", "gale_force", "umbra_eclipse", "burst_terrain", "destroy_illusion", "meteor_marks", "discharge", "convert_surface", "force_area", "petrify", "offensive_outcrop":
				if int(action.get("range", 0)) > 1:
					has_ranged_attack = true
				else:
					has_melee_attack = true
			"block", "guard_ally", "stoneskin", "frost_armor", "raise_terrain", "outcrop", "mantle", "retaliate", "convert_block_to_stoneskin":
				has_block = true
			"illusion", "illusion_swap":
				has_illusion = true
			"move", "move_toward", "move_away", "blink", "swap":
				has_mobility = true
			"self_flag":
				if str(action.get("flag", "")) in DEFENSIVE_SELF_FLAGS:
					has_block = true
				else:
					has_mobility = true
			"next_attack":
				setup_attack = true
			"detonate":
				if int(action.get("range", 0)) > 1:
					setup_ranged_attack = true
				else:
					setup_attack = true
			"consume_surface":
				for reward_var: Variant in action.get("rewards", []):
					if typeof(reward_var) == TYPE_DICTIONARY and str((reward_var as Dictionary).get("type", "")) in ["block", "stoneskin"]:
						setup_block = true
			"cleanse", "surface_adjacent_enemies":
				setup_block = true
			"quicken":
				setup_mobility = true
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
	if setup_ranged_attack:
		return "attack_ranged"
	if setup_attack:
		return "attack_melee"
	if setup_block:
		return "block"
	if setup_mobility:
		return "mobility"
	return ""

static func card_role_emblem_path(card: Dictionary) -> String:
	return str(CARD_ROLE_EMBLEM_PATHS.get(card_role_emblem_key(card), ""))

static func icon_path(icon_key: String) -> String:
	return str(_icon_definition(icon_key).get("path", ""))

static func icon_texture(icon_key: String, presentation: String = "default") -> Texture2D:
	# Toolbar variants belong to the same audited identity as their detailed art.
	var path: String = icon_path(icon_key)
	if presentation == "toolbar":
		path = str(_icon_definition(icon_key).get("toolbar_path", path))
	return AssetLoader.load_texture(path)

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
			if str(token.get("kind", "")) == "surface_condition":
				var surface_key: String = str(token.get("icon", "surface"))
				var keyword_condition: bool = token.has("state_condition") or token.has("scale_bonus")
				_append_tooltip_entry(entries, seen, surface_key, token_tooltip(token) if keyword_condition else tooltip(surface_key))
				continue
			if str(token.get("kind", "")) in ["text", "rules_text"]:
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
		var guardian_row: Array = tokens_for_guardian_rule(action)
		if not guardian_row.is_empty(): rows.append(guardian_row)
		var bonus_row: Array = tokens_for_surface_bonus(action)
		if not bonus_row.is_empty():
			rows.append(bonus_row)
		rows.append_array(keyword_rider_rows(action))
	return rows

static func append_action_row(rows: Array, action: Dictionary, row: Array, previous_action_row_index: int = -1) -> int:
	if row.is_empty():
		return previous_action_row_index
	if (bool(action.get("reuse_previous_target", false)) or str(action.get("target", "")) == "previous_target") and previous_action_row_index >= 0 and previous_action_row_index < rows.size():
		var shared_row: Array = (rows[previous_action_row_index] as Array).duplicate(true)
		for token_var: Variant in row:
			if typeof(token_var) == TYPE_DICTIONARY and _duplicates_shared_target_token(shared_row, token_var as Dictionary):
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

static func _duplicates_shared_target_token(row: Array, candidate: Dictionary) -> bool:
	for existing_var: Variant in row:
		if typeof(existing_var) != TYPE_DICTIONARY:
			continue
		var existing: Dictionary = existing_var
		if str(candidate.get("icon", "")) == "range" and str(existing.get("icon", "")) == "range" and existing.get("value", null) == candidate.get("value", null):
			return true
		if str(candidate.get("kind", "")) == "aoe_pattern" and str(existing.get("kind", "")) == "aoe_pattern" and _same_pattern(candidate.get("pattern", []), existing.get("pattern", [])):
			return true
	return false

static func _same_pattern(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for offset: Variant in left:
		if not right.has(offset):
			return false
	return true

static func rows_for_card(card: Dictionary, options_by_index: Array = []) -> Array:
	var rows: Array = cost_rows_for_card(card)
	rows.append_array(rows_for_actions(card.get("actions", []), options_by_index))
	rows.append_array(keyword_rows_for_card(card))
	rows.append_array(rules_text_rows_for_card(card))
	return rows

# Card-level Follow-up / Empower segments: keyword icon, Empower cost, then the
# bonus. `state` marks a segment active when its bonus is already in the rows.
static func keyword_rows_for_card(card: Dictionary, state: Dictionary = {}) -> Array:
	var rows: Array = []
	var printed: Array = card.get("actions", []) as Array
	var follow_up: Variant = card.get("follow_up", null)
	if typeof(follow_up) == TYPE_DICTIONARY and not (follow_up as Dictionary).is_empty():
		var active: bool = bool(state.get("follow_up", false))
		var row: Array = [token_for("follow_up", "✓" if active else null, "bonus" if active else "neutral", "Follow-up%s\nGains this bonus if you already played a card this turn." % (" · active" if active else ""))]
		row[0]["keyword_segment"] = "follow_up"
		row[0]["active"] = active
		row.append_array(tokens_for_keyword_bonus(printed, follow_up as Dictionary, "bonus" if active else "condition"))
		rows.append(row)
	var empower: Variant = card.get("empower", null)
	if typeof(empower) == TYPE_DICTIONARY and not (empower as Dictionary).is_empty():
		var active: bool = bool(state.get("empowered", false))
		var row: Array = [token_for("empower", "✓" if active else null, "bonus" if active else "neutral", "Empower%s\nOptional: pay the extra cost while playing this card for the bonus." % (" · active" if active else ""))]
		row[0]["keyword_segment"] = "empower"
		row[0]["active"] = active
		var cost: Dictionary = (empower as Dictionary).get("cost", {}) as Dictionary
		if bool(cost.get("exhaust", false)):
			row.append(token_for("exhaust", null, "neutral", "Empower cost: Exhaust this card."))
		if int(cost.get("health", 0)) > 0:
			row.append(token_for("health_cost", "-%d" % int(cost.get("health", 0)), "neutral", "Empower cost: pay %d health after the card resolves." % int(cost.get("health", 0))))
		if int(cost.get("time", 0)) > 0:
			row.append(token_for("time", "+%d" % int(cost.get("time", 0)), "neutral", "Empower cost: %d more Time." % int(cost.get("time", 0))))
		row.append_array(tokens_for_keyword_bonus(printed, empower as Dictionary, "bonus" if active else "condition"))
		rows.append(row)
	return rows

static func tokens_for_keyword_bonus(printed_actions: Array, spec: Dictionary, tone: String = "condition") -> Array:
	var tokens: Array = []
	for mod_var: Variant in spec.get("mods", []):
		if typeof(mod_var) != TYPE_DICTIONARY:
			continue
		var mod: Dictionary = mod_var
		var index: int = int(mod.get("action", -1))
		var action: Dictionary = printed_actions[index] as Dictionary if index >= 0 and index < printed_actions.size() and typeof(printed_actions[index]) == TYPE_DICTIONARY else {}
		var added: Dictionary = mod.get("add", {}) as Dictionary
		for field_var: Variant in added.keys():
			var field: String = str(field_var)
			tokens.append(token_for(_keyword_field_icon(action, field), "%+d" % int(added[field_var]), tone))
		var assigned: Dictionary = mod.get("set", {}) as Dictionary
		for field_var: Variant in assigned.keys():
			var field: String = str(field_var)
			var value: Variant = assigned[field_var]
			match field:
				"pattern":
					var pattern_token: Dictionary = _aoe_pattern_token({"pattern": value, "range": int(action.get("range", 0))})
					pattern_token["tone"] = tone
					tokens.append(pattern_token)
				"surface":
					tokens.append(surface_token(str(value)))
				_:
					if typeof(value) == TYPE_BOOL:
						if bool(value):
							tokens.append(token_for(_keyword_field_icon(action, field), null, tone))
					elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
						# JSON numbers load as floats; card chips print whole numbers.
						tokens.append(token_for(_keyword_field_icon(action, field), str(int(value)), tone))
					else:
						tokens.append(token_for(_keyword_field_icon(action, field), str(value), tone))
	for appended_var: Variant in spec.get("append", []):
		if typeof(appended_var) != TYPE_DICTIONARY:
			continue
		for token_var: Variant in tokens_for_action(appended_var as Dictionary):
			var token: Dictionary = (token_var as Dictionary).duplicate(true)
			if str(token.get("tone", "neutral")) == "neutral":
				token["tone"] = tone
			tokens.append(token)
	return tokens

static func _keyword_field_icon(action: Dictionary, field: String) -> String:
	match field:
		"damage":
			return _damage_icon_for_action(action, _damage_bonus_fallback_icon(action))
		"amount":
			var action_key: String = action_icon_key(action)
			return action_key if not action_key.is_empty() else "range"
		"health":
			return "illusion" if str(action.get("type", "")) == "illusion" else "health"
	return field if KEYWORDS.has(field) else action_icon_key(action)

# Per-hit rider rows: state bonuses (target in Light / Frozen / at half health)
# and scale bonuses (per Stoneskin or tile moved this turn).
static func keyword_rider_rows(action: Dictionary) -> Array:
	var rows: Array = []
	var bonuses: Variant = action.get("state_bonus", [])
	if typeof(bonuses) == TYPE_ARRAY:
		for bonus_var: Variant in bonuses:
			if typeof(bonus_var) != TYPE_DICTIONARY:
				continue
			var bonus: Dictionary = bonus_var
			var row: Array = [state_condition_token(str(bonus.get("state", "")))]
			if int(bonus.get("damage", 0)) != 0:
				row.append(token_for(_damage_icon_for_action(action, _damage_bonus_fallback_icon(action)), "%+d" % int(bonus.get("damage", 0)), "condition"))
			if int(bonus.get("stagger", 0)) != 0:
				row.append(token_for("stagger", "%+d" % int(bonus.get("stagger", 0)), "condition"))
			rows.append(row)
	var scale: Variant = action.get("scale_bonus", {})
	if typeof(scale) == TYPE_DICTIONARY and not (scale as Dictionary).is_empty():
		rows.append([scale_bonus_token(action)])
	rows.append_array(surface_family_rider_rows(action))
	return rows

## Wave-4 surface-family riders (spec/card_mechanics_surfaces.md): consume,
## on_result and frozen_splash.
static func surface_family_rider_rows(action: Dictionary) -> Array:
	var rows: Array = []
	var consume: Variant = action.get("consume", null)
	if typeof(consume) == TYPE_DICTIONARY and not str((consume as Dictionary).get("surface", "")).is_empty():
		var spec: Dictionary = consume
		var kind: String = str(spec.get("surface", ""))
		var required: bool = bool(spec.get("required", false))
		var per_hit: bool = bool(spec.get("per_hit", false))
		var condition: Dictionary = surface_condition_token({"surface": kind, "subject": "target", "present": true})
		if required:
			condition["prefix"] = "Only Target on"
			condition["value"] = "Only Target on %s:" % label(surface_icon_key(kind))
			condition["tooltip"] = "Only Target on %s\nThis attack can only target an enemy standing on %s." % [label(surface_icon_key(kind)), label(surface_icon_key(kind))]
		elif per_hit:
			condition["prefix"] = "Each hit on"
			condition["value"] = "Each hit on %s:" % label(surface_icon_key(kind))
		var row: Array = [condition]
		var bonus: int = int(spec.get("bonus_damage", 0))
		if bonus != 0:
			row.append(token_for(_damage_icon_for_action(action, _damage_bonus_fallback_icon(action)), "%+d" % bonus, "condition"))
		var where: String = "on each pattern tile" if str(action.get("type", "")) == "aoe" else "beneath each enemy hit" if per_hit else "beneath the target"
		row.append(token_for("surface_consume", null, "neutral", "Consume Surface\nRemoves the %s %s after the hit." % [label(surface_icon_key(kind)), where]))
		rows.append(row)
	var result: Variant = action.get("on_result", null)
	if typeof(result) == TYPE_DICTIONARY and not (result as Dictionary).is_empty():
		var when: String = str((result as Dictionary).get("when", ""))
		var result_text: String = "if it Freezes:" if when == "froze" else "if it kills:" if when == "killed" else "if %s:" % when
		var result_tooltip: String = "If this hit Freezes the target (it was not Frozen before), also:" if when == "froze" else "If this hit defeats the target, also (on top of the usual card play for a kill):"
		var result_row: Array = [text_token(result_text, "neutral", result_tooltip)]
		for reward_var: Variant in (result as Dictionary).get("rewards", []):
			if typeof(reward_var) != TYPE_DICTIONARY:
				continue
			for token_var: Variant in tokens_for_action(reward_var as Dictionary):
				var token: Dictionary = (token_var as Dictionary).duplicate(true)
				token["tone"] = "condition"
				result_row.append(token)
		rows.append(result_row)
	var splash: int = int(action.get("frozen_splash", 0))
	if splash > 0:
		rows.append([state_condition_token("frozen"), token_for("aoe", splash, "condition", "Shatter\nIf the target was Frozen before the hit, deal %d to each other enemy next to it (not tripled)." % splash), text_token("adjacent", "neutral", "Each other enemy next to the target.")])
	return rows

# `prefix` is the compact card-face label beside the condition icon, short
# enough to keep the condition and its bonus on one hand-card row; `text` keeps
# the full condition for plain-text summaries, and `tooltip` the exact rule.
const STATE_CONDITION_COPY: Dictionary = {
	"light": {"icon": "illuminate", "prefix": "in", "text": "if Target in Light:", "tooltip": "If Target in Light\nApplies if the target stands in Light."},
	"frozen": {"icon": "freeze", "prefix": "vs", "text": "if Target Frozen:", "tooltip": "If Target Frozen\nApplies if the target is Frozen before the hit."},
	"half_hp": {"icon": "health", "prefix": "≤½", "text": "if Target at half health:", "tooltip": "If Target at Half Health\nApplies if the target is at or below half health before the hit."},
}

static func state_condition_token(condition: String) -> Dictionary:
	var copy: Dictionary = STATE_CONDITION_COPY.get(condition, {"icon": "targeting", "prefix": "vs", "tooltip": condition}) as Dictionary
	var token: Dictionary = text_token(str(copy.get("text", "if %s:" % condition)), "neutral", str(copy.get("tooltip", "")))
	token["kind"] = "surface_condition"
	token["icon"] = str(copy.get("icon", "targeting"))
	token["prefix"] = str(copy.get("prefix", "if"))
	token["suffix"] = ":"
	token["state_condition"] = condition
	return token

static func scale_bonus_token(action: Dictionary) -> Dictionary:
	var scale: Dictionary = action.get("scale_bonus", {}) as Dictionary
	var per: String = str(scale.get("per", ""))
	var icon: String = "stoneskin" if per == "stoneskin" else "move"
	var suffix: String = "%+d each (max %d)" % [int(scale.get("damage", 1)), int(scale.get("max", 0))]
	var detail: String = "Stoneskin you have" if per == "stoneskin" else "tile you moved this turn"
	var token: Dictionary = text_token("%s %s" % [label(icon), suffix], "neutral", "Deals %d more damage for each %s (maximum %d more)." % [int(scale.get("damage", 1)), detail, int(scale.get("max", 0))])
	token["kind"] = "surface_condition"
	token["icon"] = icon
	token["prefix"] = ""
	token["suffix"] = suffix
	token["scale_bonus"] = scale.duplicate(true)
	return token
static func card_is_rite(card: Dictionary) -> bool:
	return typeof(card.get("rite", null)) == TYPE_DICTIONARY and not (card["rite"] as Dictionary).is_empty()

## Complete rules text for a card ("Rite:" already means Exhaust); a Rite's
## health cost is appended. Tooltips and plain-text surfaces use this.
static func card_rules_text(card: Dictionary) -> String:
	var text: String = str(card.get("description", ""))
	var health_cost: int = int(card.get("health_cost", 0))
	if card_is_rite(card) and health_cost > 0 and not text.to_lower().contains("health"):
		text = "%s Health cost %d." % [text.strip_edges(), health_cost]
	return text

## A Rite's card face: the cost row (labelled `rite` keyword and health cost)
## carries "Rite:" and the cost, so the rules text below starts at the effect.
static func rite_face_rules_text(card: Dictionary) -> String:
	var text: String = str(card.get("description", "")).strip_edges()
	if text.to_lower().begins_with("rite:"):
		text = text.substr(5).strip_edges()
	if not text.is_empty():
		text = text.substr(0, 1).to_upper() + text.substr(1)
	return text

static func rite_label_token() -> Dictionary:
	# Condition-style keyword label: the unfamiliar Rite icon is named beside it.
	var token: Dictionary = text_token(label("rite"), "neutral", tooltip("rite"))
	token["kind"] = "surface_condition"
	token["icon"] = "rite"
	token["prefix"] = ""
	token["suffix"] = label("rite")
	token["keyword_label"] = "rite"
	return token

static func rules_text_token(text: String) -> Dictionary:
	var token: Dictionary = text_token(text)
	token["kind"] = "rules_text"
	return token

## Rows after the cost row for a card whose effect is rules text (a Rite).
static func rules_text_rows_for_card(card: Dictionary) -> Array:
	if not card_is_rite(card):
		return []
	var text: String = rite_face_rules_text(card)
	return [[rules_text_token(text)]] if not text.is_empty() else []

static func cost_rows_for_card(card: Dictionary) -> Array:
	var row: Array = []
	if card_is_rite(card):
		row.append(rite_label_token())
	elif bool(card.get("burn", false)):
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
		"move_away":
			tokens.append(_token_for_action_field(action, "retreat", "range", int(action.get("range", 0))))
		"blink":
			tokens.append(_token_for_action_field(action, "blink", "range", int(action.get("range", 0))))
		"melee":
			_append_damage_token(tokens, _damage_icon_for_action(action, "melee"), action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
		"ranged":
			# A zero-damage throw (Throwing Net) only carries statuses, like a
			# zero-damage area: no 0 damage chip unless something adds damage.
			if int(action.get("damage", 0)) > 0 or int(options.get("final_damage", 0)) > 0:
				_append_damage_token(tokens, _damage_icon_for_action(action, "ranged"), action, options)
			if bool(action.get("ignore_los", false)):
				var unlimited: bool = int(action.get("range", 0)) >= 99
				tokens.append(_token_for_action_field(action, "range", "range", "∞" if unlimited else int(action.get("range", 0)), "neutral", "Range\n%s" % ("Any enemy you can see, ignoring range and line of sight." if unlimited else "Ignores line of sight: any enemy you can see within this range.")))
			else:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			if bool(action.get("also_hits_near_illusions", false)):
				tokens.append(token_for("illusion", "+", "neutral", "Also hits each other enemy next to one of your illusions, once each."))
			_append_keyword_tokens(tokens, action)
			if bool(action.get("shock_all_hits", false)):
				for token_index: int in range(tokens.size()):
					if str((tokens[token_index] as Dictionary).get("icon", "")) == "shock":
						(tokens[token_index] as Dictionary)["tooltip"] = "Shock\nEvery enemy this hits is Shocked, including Chain and conducted hits."
		"aoe":
			# A facing-aimed area starts on an adjacent tile, like a melee strike:
			# the pattern token carries its reach, so no range chip is shown.
			var aims_facing: bool = str(action.get("aim", "")) == "facing"
			# A zero-damage area (Caltrops) is a status/ground placement, like a
			# zero-damage push: it shows no damage chip unless something adds damage.
			if int(action.get("damage", 0)) > 0 or int(options.get("final_damage", 0)) > 0:
				_append_damage_token(tokens, _damage_icon_for_action(action, "ranged" if int(action.get("range", 0)) > 0 and not aims_facing else "melee"), action, options)
			if int(action.get("range", 0)) > 0 and not aims_facing:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			if str(action.get("committed_shape", action.get("guardian_shape", ""))).is_empty(): tokens.append(_aoe_pattern_token(action))
			_append_keyword_tokens(tokens, action)
		"push":
			_append_optional_hit_token(tokens, action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
			# Authored sideways force (Crosswind) may push in any open direction.
			var push_tooltip: String = "Push %d in any open direction." % int(action.get("amount", 0)) if bool(action.get("_allow_sideways_force", false)) else ""
			tokens.append(_token_for_action_field(action, "push", "amount", int(action.get("amount", 0)), "neutral", push_tooltip))
		"pull":
			_append_optional_hit_token(tokens, action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
			tokens.append(_token_for_action_field(action, "pull", "amount", int(action.get("amount", 0))))
		"surface":
			tokens.append(surface_token(str(action.get("surface", ""))))
			if int(action.get("range", 0)) > 0:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			if (action.get("pattern", []) as Array).size() > 1:
				tokens.append(_aoe_pattern_token(action))
		"detonate":
			_append_damage_token(tokens, "detonate", action, options)
			if action.has("detonate_surface") and str(action.get("detonate_surface", "fire")) != "fire":
				tokens.append(surface_token(str(action.get("detonate_surface", "")), "Detonates this surface instead of Fire."))
			if int(action.get("range", 0)) > 0:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			if (action.get("pattern", []) as Array).size() > 1:
				tokens.append(_aoe_pattern_token(action))
			_append_keyword_tokens(tokens, action)
			if not str(action.get("leave_surface", "")).is_empty():
				tokens.append(surface_token(str(action.get("leave_surface", "")), "Leaves this surface on each detonated tile and its four neighbors."))
			if bool(action.get("spare_player", false)):
				tokens.append(text_token("spares you", "neutral", "You take no damage from this Detonate."))
		"consume_surface":
			tokens.append(token_for("surface_consume"))
			tokens.append(surface_token(str(action.get("surface", ""))))
			for reward_var: Variant in action.get("rewards", []):
				if typeof(reward_var) == TYPE_DICTIONARY:
					tokens.append_array(tokens_for_action(reward_var as Dictionary))
					if bool((reward_var as Dictionary).get("per_tile", false)):
						var cap: int = int((reward_var as Dictionary).get("max", 0))
						tokens.append(text_token("per tile" + (", max %d" % cap if cap > 0 else ""), "neutral", "Gains this for each tile removed%s." % (" (maximum %d)" % cap if cap > 0 else "")))
		"surface_adjacent_enemies":
			var self_too: bool = bool(action.get("include_self", false))
			var adjacent_detail: String = "Leaves this surface under each adjacent enemy%s." % (" and on your tile" if self_too else "")
			tokens.append(surface_token(str(action.get("surface", "")), adjacent_detail))
			tokens.append(text_token("adjacent + you" if self_too else "adjacent", "neutral", adjacent_detail))
		"convert_surface":
			var from_kind: String = str(action.get("surface", "ice"))
			var to_kind: String = str(action.get("to", "electrified"))
			var convert_detail: String = "Turns a %s tile%s into %s." % [label(surface_icon_key(from_kind)), (" and every %s tile connected to it" % label(surface_icon_key(from_kind))) if bool(action.get("connected", false)) else "", label(surface_icon_key(to_kind))]
			tokens.append(surface_token(from_kind, convert_detail))
			tokens.append(text_token("→", "neutral", convert_detail))
			tokens.append(surface_token(to_kind, convert_detail))
			if int(action.get("damage", 0)) > 0 or int(options.get("final_damage", 0)) > 0:
				_append_damage_token(tokens, "aoe", action, options)
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Range\nChoose a %s tile within this range and line of sight." % label(surface_icon_key(from_kind))))
			_append_keyword_tokens(tokens, action)
		"discharge":
			tokens.append(token_for("discharge"))
			tokens.append(surface_token("electrified"))
			_append_damage_token(tokens, "aoe", action, options)
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Range\nChoose an Electrified tile within this range and line of sight."))
			_append_keyword_tokens(tokens, action)
		"all_enemies":
			tokens.append(selector_token(str(action.get("selector", ""))))
			if int(action.get("damage", 0)) > 0 or int(options.get("final_damage", 0)) > 0:
				_append_damage_token(tokens, "all_enemies", action, options)
			if int(action.get("range", 0)) > 0:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Range\nOnly enemies within this distance of you."))
			_append_keyword_tokens(tokens, action)
		"meteor_marks":
			var meteor_surface: String = str(action.get("surface", ""))
			tokens.append(token_for("cinder_marks", null, "neutral", "Meteorfall\nMarks the shown tiles. At the start of your next turn, before you draw, each marked tile takes the damage (anyone there, including you)%s." % (" and becomes %s" % label(surface_icon_key(meteor_surface)) if not meteor_surface.is_empty() else "")))
			_append_damage_token(tokens, "aoe", action, options)
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Range\nMark tiles within this range and line of sight."))
			if (action.get("pattern", []) as Array).size() > 1:
				tokens.append(_aoe_pattern_token(action))
			if not meteor_surface.is_empty():
				tokens.append(surface_token(meteor_surface, "Each marked tile becomes this surface when the meteor lands."))
		"surface_relocate":
			tokens.append(token_for("surface_relocate"))
			if int(action.get("range", 0)) > 0:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
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
		"illusion":
			tokens.append(_token_for_action_field(action, "illusion", "health", int(action.get("health", action.get("amount", 0)))))
			_append_illusion_placement_tokens(tokens, action)
			_append_illusion_trait_tokens(tokens, action)
		"illusion_swap":
			tokens.append(token_for("illusion_swap", null, "neutral", "Swap Illusion\nSwap places with one of your illusions%s. Both of you trigger the ground and traps where you land." % ("" if int(action.get("range", 0)) >= 20 else " within range %d" % int(action.get("range", 0)))))
			if int(action.get("range", 0)) < 20:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Swap range."))
			else:
				tokens.append(text_token("any illusion", "neutral", "Any of your illusions on the board."))
			if bool(action.get("transfer_block", false)):
				tokens.append(token_for("block", "→", "neutral", "The illusion gains all your Block as extra health. You lose that Block."))
		"destroy_illusion":
			tokens.append(token_for("shatter_illusion", null, "neutral", "Shatter Illusion\nDestroy one of your illusions within range. It counts as destroyed for illusion effects."))
			_append_damage_token(tokens, "aoe", action, options)
			tokens.append(text_token("next to it", "neutral", "Hits each enemy on the four tiles next to the destroyed illusion."))
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Range to the illusion you destroy."))
			_append_illuminate_rider_tokens(tokens, action)
		"burst_terrain":
			var owned_only: bool = bool(action.get("owned_outcrop_only", false))
			var line_length: int = int(action.get("line_length", 0))
			tokens.append(token_for("terrain_burst", null, "neutral", "Destroy an adjacent outcrop you raised." if owned_only else "Destroy an outcrop, crate or other terrain within range and sight."))
			var burst_action: Dictionary = action.duplicate(false)
			burst_action["damage"] = int(action.get("line_damage", action.get("damage", 0))) if owned_only else int(action.get("damage", 0))
			_append_damage_token(tokens, "aoe", burst_action, options)
			if owned_only and line_length > 0:
				tokens.append(text_token("%d-tile line beyond" % line_length, "neutral", "Hits each enemy in the %d tiles beyond the outcrop, away from you." % line_length))
			else:
				tokens.append(text_token("next to it", "neutral", "Hits each enemy on the four tiles next to the destroyed terrain."))
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Range to the terrain you destroy."))
			_append_keyword_tokens(tokens, action)
		"illuminate":
			var light_range: int = int(action.get("range", 0))
			tokens.append(_token_for_action_field(action, "illuminate", "radius", int(action.get("radius", action.get("amount", 1))), "neutral", "Light radius in tiles." if light_range > 0 else "Light radius in tiles, centered on you."))
			# Range-0 Light is created on the hero's own tile; no placement chip.
			if light_range > 0:
				tokens.append(_token_for_action_field(action, "range", "range", light_range, "neutral", "Light placement range."))
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
			tokens.append(_token_for_action_field(action, "shock", "count", int(action.get("count", 0)), "neutral", "Strikes the marked tiles. The marks stay fixed." if action.has("declared_tiles") else "Random lightning strikes."))
			_append_keyword_tokens(tokens, action)
		"summon_minions":
			var minion_name: String = str(preload("res://scripts/game_data.gd").enemy_def(str(action.get("minion_type", "lightning_wisp"))).get("name", "Backup"))
			var count: int = int(action.get("count", 1))
			var summon_text: String = "Calls %s." % minion_name
			if action.has("guardian_cap") or action.has("summon_cap"): summon_text += " Up to %d living." % int(action.get("summon_cap", action.get("guardian_cap", 0)))
			tokens.append(token_for("summon_minions", null, "neutral", summon_text))
			tokens.append(text_token(("%d × " % count if count > 1 else "") + minion_name))
		"outcrop":
			var outcrop_kind: String = str(action.get("kind", ""))
			var raise_tooltip: String = "Raises an outcrop with this much health on empty floor. It blocks movement and sight and leaves Rubble when destroyed."
			if outcrop_kind == "powder_keg":
				raise_tooltip = "Places a powder keg with this much health on empty floor. It blocks movement, not sight."
			elif outcrop_kind == "worldspine":
				raise_tooltip = "Raises a Worldspine with this much health on each empty tile around the target. Spires block movement, not sight, and leave Rubble when destroyed."
			tokens.append(_token_for_action_field(action, "raise_terrain", "health", int(action.get("health", 0)), "neutral", raise_tooltip))
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Outcrop placement range."))
			if (action.get("pattern", []) as Array).size() > 1:
				tokens.append(_aoe_pattern_token(action))
			if outcrop_kind == "powder_keg":
				tokens.append(token_for("detonate", int(action.get("burst_damage", 0)), "warning", "When the keg is destroyed by anything, it deals %d to its tile and each tile next to it: you, illusions, enemies and terrain. Kegs set each other off." % int(action.get("burst_damage", 0))))
			elif outcrop_kind == "worldspine":
				tokens.append(token_for("terrain_burst", int(action.get("pulse_damage", 0)), "neutral", "At the start of each of your turns, each enemy next to at least one of your Worldspines takes %d." % int(action.get("pulse_damage", 0))))
		"raise_terrain":
			tokens.append(_token_for_action_field(action, "raise_terrain", "count", int(action.get("count", 0)), "neutral", "Raises attackable terrain around the arena."))
			tokens.append(_token_for_action_field(action, "health", "health", int(action.get("health", 0)), "neutral", "Health of each terrain piece."))
		"terrain_burst":
			_append_damage_token(tokens, "melee", action, options)
			if str(action.get("guardian_kind", "")) == "crag_outcrop":
				tokens.append(text_token("All outcrops · within %d" % int(action.get("range",1)), "warning", "Surviving outcrops rupture every floor tile within the shown distance."))
			else:
				var consuming: bool = bool(action.get("consume_terrain",true))
				tokens.append(text_token("Spire burst" if consuming else "Spire pulse", "warning", "Hits within %d of surviving Worldspines. %s" % [int(action.get("radius",1)), "Breaks the spires." if consuming else "Spires remain."]))
		"cinder_marks":
			tokens.append(_token_for_action_field(action, "cinder_marks", "count", int(action.get("count", 0)), "neutral", "Creates Fire on the marked tiles."))
			if int(action.get("damage", 0)) > 0: _append_damage_token(tokens, "ranged", action, options)
			_append_keyword_tokens(tokens, action)
		"detonate_cinders":
			tokens.append(_token_for_action_field(action, "detonate_cinders", "damage", int(action.get("damage", 0)), "warning", "Consumes Fire. Each affected actor, including the dragon, takes damage once on the Fire or its four neighboring tiles."))
		"gale_force":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(_token_for_action_field(action, "push", "amount", int(action.get("amount", 0)), "neutral", "Pushes the player away from the dragon through arena hazards."))
		"frost_armor":
			tokens.append(_token_for_action_field(action,"frost_armor","amount",int(action.get("amount",0)),"neutral","Forms Crystal Mantle. Each direct damaging hit breaks one layer and prevents its damage; ground and damage over time bypass it."))
		"umbra_eclipse":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(_token_for_action_field(action, "eclipse", "duration", int(action.get("duration", 0)), "neutral", "Forces Eclipse for this many player turns. Radiance and light protect affected tiles."))
		"retaliate":
			_append_retaliate_tokens(tokens, action)
		"quicken":
			tokens.append(_token_for_action_field(action, "quicken", "amount", int(action.get("amount", 0)), "neutral", "Quicken %d\nYour next card this turn costs %d less Time (minimum 1)." % [int(action.get("amount", 0)), int(action.get("amount", 0))]))
		"next_attack":
			_append_next_attack_tokens(tokens, action)
		"force_area", "swap", "self_flag", "cleanse", "convert_block_to_stoneskin", "mantle", "petrify":
			_append_maneuver_tokens(tokens, action)
	if action_type in ["move", "blink", "push", "pull", "aoe"]:
		_append_maneuver_rider_tokens(tokens, action)
	if int(action.get("outcrop_health", 0)) > 0:
		tokens.append(token_for("raise_terrain", int(action["outcrop_health"]), "neutral", "Raises an outcrop with this much HP at an empty ground target."))
	if action_type not in ["surface", "consume_surface", "surface_adjacent_enemies", "convert_surface", "meteor_marks"] and not str(action.get("surface", "")).is_empty():
		tokens.append(surface_token(str(action.get("surface", "")), "Leaves this surface along your path." if bool(action.get("surface_path", false)) else "Leaves this surface in the affected area."))
		if bool(action.get("surface_path", false)): tokens.append(text_token("trail"))
		elif action.has("surface_tiles_limit"): tokens.append(text_token("%d nearest tile%s" % [int(action["surface_tiles_limit"]), "" if int(action["surface_tiles_limit"]) == 1 else "s"], "neutral", "Places ground on the nearest affected tiles, beginning at the dragon."))
		if action.has("surface_pattern") and not _same_pattern(action.get("surface_pattern", []), action.get("pattern", [])):
			# surface_follows_facing patterns are authored from the struck tile
			# facing away from you, like a facing-aimed area.
			tokens.append(_aoe_pattern_token({"pattern": action.get("surface_pattern", []), "range": int(action.get("range", 0)), "aim": "facing" if bool(action.get("surface_follows_facing", false)) else str(action.get("aim", ""))}))
	if action_type in ["move", "move_toward", "move_away", "blink", "melee", "ranged", "aoe", "push", "pull"]:
		_append_illuminate_rider_tokens(tokens, action)
	if not str(action.get("clear_surface", "")).is_empty():
		tokens.append(token_for("surface_consume", null, "neutral", "Remove %s beneath you." % str(action.get("clear_surface", ""))))
	var requirement: Dictionary = action.get("requires_surface", {}) as Dictionary
	if not requirement.is_empty():
		tokens.push_front(surface_condition_token(requirement))
	return tokens

const SELECTOR_COPY: Dictionary = {
	"on_fire": {"icon": "surface_fire", "prefix": "Each on", "tooltip": "Each Enemy on Fire\nHits every enemy you can see that stands on Fire. There is no target to choose."},
	"chilled": {"icon": "chilled", "prefix": "Each", "tooltip": "Each Chilled Enemy\nHits every Chilled enemy you can see. There is no target to choose."},
	"in_light": {"icon": "illuminate", "prefix": "Each in", "tooltip": "Each Enemy in Light\nHits every enemy you can see that stands in Light. There is no target to choose."},
	"on_electrified": {"icon": "surface_electrified", "prefix": "Each on", "tooltip": "Each Enemy on Electrified\nHits every enemy you can see that stands on Electrified ground. There is no target to choose."},
}

## all_enemies selector: "Each on [Fire]:" etc. Rendered like a surface condition.
static func selector_token(selector: String) -> Dictionary:
	var copy: Dictionary = SELECTOR_COPY.get(selector, {"icon": "aoe", "prefix": "Each", "tooltip": "Each matching enemy you can see."}) as Dictionary
	var text: String = "%s %s:" % [str(copy.get("prefix", "Each")), label(str(copy.get("icon", "aoe")))]
	var token: Dictionary = text_token(text, "neutral", str(copy.get("tooltip", "")))
	token["kind"] = "surface_condition"
	token["icon"] = str(copy.get("icon", "aoe"))
	token["prefix"] = str(copy.get("prefix", "Each"))
	token["suffix"] = ":"
	token["state_condition"] = selector
	return token


const SELF_FLAG_TEXT: Dictionary = {
	"ice_skate": ["Skate", "Skate\nThis turn, moving onto Ice costs no movement and Ice doesn't Chill you."],
	"no_move": ["Rooted", "Rooted\nYou can't Move or Blink for the rest of this turn."],
	"anchored": ["Anchored", "Anchored\nUntil your next turn, you can't be pushed or pulled."],
	"fire_immune_turn": ["Fireproof", "Fireproof\nFire doesn't damage you this turn."],
}
const CLEANSE_STATUS_LABELS: Dictionary = {"bleed": "Bleed", "immobilize": "Immobilize", "chilled": "Chilled", "shock": "Shock"}

## Wave-4 family B action rows (spec/card_mechanics_maneuver.md).
static func _append_maneuver_tokens(tokens: Array, action: Dictionary) -> void:
	match str(action.get("type", "")):
		"force_area":
			var pulling: bool = int(action.get("pull", 0)) > 0 and int(action.get("push", 0)) <= 0
			var amount: int = int(action.get("pull" if pulling else "push", 0))
			var on_target: bool = str(action.get("center", "self")) == "target"
			var radius: int = int(action.get("radius", 1))
			var where: String = "the chosen tile" if on_target else "you"
			var verb: String = "Pull each enemy within %d of %s %d toward it." % [radius, where, amount] if pulling else "Push each enemy within %d of %s %d away from it." % [radius, where, amount]
			if not str(action.get("consume_center", "")).is_empty():
				tokens.append(token_for("surface_consume", null, "neutral", "Consumes this surface on the chosen tile first."))
				tokens.append(surface_token(str(action.get("consume_center", ""))))
			if on_target:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Choose a tile within this range."))
			tokens.append(_token_for_action_field(action, "pull" if pulling else "push", "pull" if pulling else "push", amount, "neutral", verb + " Each moves along its own straight line; stopped lines collide."))
			tokens.append(text_token("within %d" % radius, "neutral", verb))
			if int(action.get("expose", 0)) > 0:
				tokens.append(_token_for_action_field(action, "expose", "expose", int(action.get("expose", 0))))
		"swap":
			tokens.append(token_for("swap", null, "neutral", "Swap\nSwap places with a one-tile enemy or one of your illusions. Both arrive normally; nothing collides."))
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
		"self_flag":
			var flag: String = str(action.get("flag", ""))
			var text: Array = SELF_FLAG_TEXT.get(flag, [flag.capitalize(), flag.capitalize()]) as Array
			var flag_icon: String = action_icon_key(action)
			tokens.append(token_for(flag_icon, null, "neutral", str(text[1])) if not flag_icon.is_empty() else text_token(str(text[0]), "neutral", str(text[1])))
		"cleanse":
			var names: PackedStringArray = PackedStringArray()
			for status_var: Variant in action.get("statuses", []):
				names.append(str(CLEANSE_STATUS_LABELS.get(str(status_var), str(status_var).capitalize())))
			var detail: String = "Cleanse\nRemove %s from yourself." % ", ".join(names)
			tokens.append(token_for("cleanse", null, "neutral", detail))
			for status_var: Variant in action.get("statuses", []):
				var key: String = str(status_var)
				if KEYWORDS.has(key):
					tokens.append(token_for(key, null, "neutral", detail))
		"convert_block_to_stoneskin":
			tokens.append(token_for("block", null, "neutral", "Turn all your Block into Stoneskin."))
			tokens.append(text_token("→", "neutral", "Turn all your Block into Stoneskin."))
			tokens.append(token_for("stoneskin", null, "neutral", "Turn all your Block into Stoneskin."))
		"mantle":
			tokens.append(_token_for_action_field(action, "frost_armor", "amount", int(action.get("amount", 0)), "neutral", "Crystal Mantle\nEach direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and health costs bypass it."))
		"petrify":
			var petrify_tip: String = "Petrify\nThe enemy skips its next turn (it still costs its Time) and gains Block, which lasts through your next turn. Dragons are immune."
			tokens.append(token_for("petrify", null, "neutral", petrify_tip))
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			tokens.append(text_token("skips turn", "neutral", petrify_tip))
			# The Block goes to the petrified enemy, not the hero: a "foe gains"
			# marker travels with the shield so it never reads as your Block.
			var foe_block: int = int(action.get("block", 0))
			if foe_block > 0:
				var foe_block_tip: String = "Block for the foe\nThe petrified enemy gains this much Block, not you. It lasts through your next turn."
				var foe_marker: Dictionary = text_token("foe gains", "neutral", foe_block_tip)
				foe_marker["row_group"] = "foe_block"
				tokens.append(foe_marker)
				var foe_block_token: Dictionary = _token_for_action_field(action, "block", "block", foe_block, "neutral", foe_block_tip)
				foe_block_token["row_group"] = "foe_block"
				foe_block_token["recipient"] = "enemy"
				tokens.append(foe_block_token)

static func _append_maneuver_rider_tokens(tokens: Array, action: Dictionary) -> void:
	if str(action.get("force_mode", "")) == "from_center":
		tokens.append(text_token("from center", "neutral", "Each enemy is pushed away from the pattern's center; the enemy on the center is pushed away from you."))
	if bool(action.get("straight_line", false)):
		tokens.append(text_token("straight line", "neutral", "Move along one clear straight line."))
	if not str(action.get("trail_surface", "")).is_empty():
		var moving_self: bool = str(action.get("type", "")) == "move"
		tokens.append(surface_token(str(action.get("trail_surface", "")), "Leaves this surface on each tile you leave." if moving_self else "Leaves this surface on each tile the target passes through."))
		tokens.append(text_token("trail"))
	if not str(action.get("origin_surface", "")).is_empty():
		tokens.append(surface_token(str(action.get("origin_surface", "")), "Leaves this surface on the tile you started on."))
		tokens.append(text_token("start tile"))
	if int(action.get("block_per_tile", 0)) > 0:
		tokens.append(token_for("block", int(action.get("block_per_tile", 0)), "neutral", "Gain this much Block for each tile you move."))
		tokens.append(text_token("per tile"))
	var trail_light: Variant = action.get("trail_light", null)
	if typeof(trail_light) == TYPE_DICTIONARY:
		tokens.append(token_for("illuminate", int((trail_light as Dictionary).get("radius", 1)), "neutral", "Creates Light on each tile you enter. Radius in tiles."))
		tokens.append(token_for("time", int((trail_light as Dictionary).get("duration", 2)), "neutral", "Turns this Light lasts."))
	if bool(action.get("destination_requires_light", false)):
		tokens.append(text_token("into Light", "neutral", "The destination must be in Light."))
	var adjacent_to: Array = action.get("destination_adjacent_to", []) as Array
	if not adjacent_to.is_empty():
		tokens.append(text_token("beside foe/terrain" if adjacent_to.has("terrain") else "beside a foe", "neutral", "The destination must be next to an enemy, outcrop or crate." if adjacent_to.has("terrain") else "The destination must be next to an enemy."))
	if int(action.get("illusion_at_origin", 0)) > 0:
		tokens.append(token_for("illusion", int(action.get("illusion_at_origin", 0)), "neutral", "Leaves an illusion with this much health where you stood."))
	var started: Variant = action.get("if_started_on_surface", null)
	if typeof(started) == TYPE_DICTIONARY:
		var surface_kind: String = str((started as Dictionary).get("surface", ""))
		var condition: Dictionary = text_token("if started on %s:" % label(surface_icon_key(surface_kind)), "neutral", "Applies if you started this turn on %s." % label(surface_icon_key(surface_kind)))
		tokens.append(condition)
		for reward_var: Variant in (started as Dictionary).get("rewards", []):
			if typeof(reward_var) == TYPE_DICTIONARY:
				tokens.append_array(tokens_for_action(reward_var as Dictionary))
	var lonely: Variant = action.get("if_no_adjacent_enemies", null)
	if typeof(lonely) == TYPE_ARRAY and not (lonely as Array).is_empty():
		tokens.append(text_token("if no foe adjacent:", "neutral", "Applies if no enemy is next to you after the Blink."))
		for reward_var: Variant in lonely as Array:
			if typeof(reward_var) == TYPE_DICTIONARY:
				tokens.append_array(tokens_for_action(reward_var as Dictionary))

static func _append_illusion_placement_tokens(tokens: Array, action: Dictionary) -> void:
	match str(action.get("place", "")):
		"ring_around_self":
			tokens.append(text_token("each tile next to you", "neutral", "Creates one illusion on each empty tile next to you (up to four)."))
		"adjacent_to_enemy":
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Choose an enemy within this range."))
			tokens.append(text_token("next to enemy", "neutral", "The illusion appears on the free tile next to the chosen enemy that is nearest you."))
			if int(action.get("expose_adjacent", 0)) > 0:
				tokens.append(token_for("expose", int(action.get("expose_adjacent", 0)), "neutral", "The chosen enemy is Exposed %d." % int(action.get("expose_adjacent", 0))))
		_:
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Illusion placement range."))
	var ring_surface: String = str(action.get("surface_ring", ""))
	if not ring_surface.is_empty():
		tokens.append(surface_token(ring_surface, "Leaves this surface on each empty tile next to the illusion."))
		tokens.append(text_token("around it", "neutral", "Each empty tile next to the illusion."))

static func _append_illusion_trait_tokens(tokens: Array, action: Dictionary) -> void:
	var on_damaged: Dictionary = action.get("on_damaged", {}) as Dictionary if typeof(action.get("on_damaged", null)) == TYPE_DICTIONARY else {}
	if not on_damaged.is_empty():
		var element: String = str(on_damaged.get("element", "none"))
		var element_text: String = " %s" % element.capitalize() if element not in ["", "none"] else ""
		var shock_text: String = " and are Shocked" if int(on_damaged.get("shock", 0)) > 0 else ""
		tokens.append(token_for("retaliate", int(on_damaged.get("damage", 0)), "neutral", "Enemies that damage this illusion take %d%s damage%s. Once per enemy attack." % [int(on_damaged.get("damage", 0)), element_text, shock_text]))
		if int(on_damaged.get("shock", 0)) > 0:
			tokens.append(token_for("shock", null, "neutral", "Enemies that damage this illusion are Shocked."))
	if bool(action.get("reflect", false)):
		tokens.append(token_for("retaliate", "=", "neutral", "Enemies that damage this illusion take that much damage too. Once per enemy attack."))
	if bool(action.get("ranged_origin", false)):
		tokens.append(token_for("ranged", null, "neutral", "While this illusion lives, your ranged attacks may fire from its tile."))

static func _append_retaliate_tokens(tokens: Array, action: Dictionary) -> void:
	var amount: int = int(action.get("amount", 0))
	var riders: PackedStringArray = []
	if int(action.get("bleed", 0)) > 0:
		riders.append("Bleed %d" % int(action.get("bleed", 0)))
	if int(action.get("shock", 0)) > 0:
		riders.append("Shock")
	if int(action.get("push", 0)) > 0:
		riders.append("Push %d" % int(action.get("push", 0)))
	var detail: String = "Until your next turn, enemies that hit you in melee"
	var shown_amount: Variant = null
	if amount > 0:
		detail += " take %d" % amount
		shown_amount = amount
	if not riders.is_empty():
		detail += (" and suffer %s" if amount > 0 else " suffer %s") % ", ".join(riders)
	tokens.append(_token_for_action_field(action, "retaliate", "amount", shown_amount, "neutral", "Retaliate\n%s." % detail))
	if int(action.get("bleed", 0)) > 0:
		tokens.append(_token_for_action_field(action, "bleed", "bleed", int(action.get("bleed", 0))))
	if int(action.get("shock", 0)) > 0:
		tokens.append(_token_for_action_field(action, "shock", "shock", int(action.get("shock", 0))))
	if int(action.get("push", 0)) > 0:
		tokens.append(_token_for_action_field(action, "push", "push", int(action.get("push", 0))))

static func _append_next_attack_tokens(tokens: Array, action: Dictionary) -> void:
	var element_id: String = str(action.get("element", ""))
	var subject: String = "Your next %s attack this turn" % element_id.capitalize() if not element_id.is_empty() and element_id != "none" else "Your next attack this turn"
	var parts: PackedStringArray = []
	var damage: int = int(action.get("damage", 0))
	if damage > 0:
		parts.append("deals %d more" % damage)
	var per_tile: Dictionary = action.get("per_tile_moved", {}) as Dictionary if typeof(action.get("per_tile_moved", null)) == TYPE_DICTIONARY else {}
	if not per_tile.is_empty():
		parts.append("deals %d more for each tile you moved this turn (maximum %d)" % [int(per_tile.get("damage", 1)), int(per_tile.get("max", 0))])
	if bool(action.get("pierce", false)):
		parts.append("Pierces")
	if int(action.get("chain", 0)) > 0:
		parts.append("gains Chain %d" % int(action.get("chain", 0)))
	var tooltip_text: String = "Next Attack\n%s %s." % [subject, " and ".join(parts)]
	var value: Variant = null
	if damage > 0:
		value = "+%d" % damage
	elif not per_tile.is_empty():
		value = "+%d" % int(per_tile.get("max", 0))
	tokens.append(token_for("next_attack", value, "neutral", tooltip_text))
	if ElementData.is_elemental(element_id):
		tokens.append(token_for(element_icon_key(element_id), null, "neutral", "Only a %s attack uses this bonus." % element_id.capitalize()))
	if bool(action.get("pierce", false)):
		tokens.append(token_for("pierce", null, "neutral", tooltip_text))
	if int(action.get("chain", 0)) > 0:
		tokens.append(token_for("chain", int(action.get("chain", 0)), "neutral", tooltip_text))

static func _bonus_token(icon_key: String, amount: int, tooltip_text: String) -> Dictionary:
	return token_for(icon_key, "+%d" % amount, "neutral", tooltip_text)

static func _damage_bonus_fallback_icon(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"ranged":
			return "ranged"
		"all_enemies":
			return "all_enemies"
		"convert_surface", "discharge", "meteor_marks":
			return "aoe"
		"aoe":
			return "ranged" if int(action.get("range", 0)) > 0 and str(action.get("aim", "")) != "facing" else "melee"
		"detonate":
			return "detonate"
		_:
			return "melee"

static func plain_text_for_tokens(tokens: Array) -> String:
	var parts: PackedStringArray = []
	for token_var: Variant in tokens:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "aoe_pattern":
			parts.append("Area")
			continue
		if str(token.get("kind", "")) in ["text", "surface_condition", "rules_text"]:
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
	if str(action.get("aim", "")) == "facing":
		# Facing patterns are authored from the chosen adjacent tile at (0, 0),
		# facing +x. Draw them from the hero so the card shows the real reach.
		var from_hero: Array = []
		for offset_var: Variant in action.get("pattern", []):
			if typeof(offset_var) == TYPE_ARRAY and (offset_var as Array).size() >= 2:
				from_hero.append([int((offset_var as Array)[0]) + 1, int((offset_var as Array)[1])])
		return {
			"kind": "aoe_pattern",
			"icon": "aoe_pattern",
			"pattern": from_hero,
			"show_origin": true,
			"tooltip": "Area pattern\nRed tiles are hit relative to you, facing the adjacent tile you choose."
		}
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
	if int(action.get("freeze", 0)) > 0:
		tokens.append(_token_for_action_field(action, "freeze", "freeze", int(action.get("freeze", 0))))
	if int(action.get("shock", 0)) > 0:
		tokens.append(_token_for_action_field(action, "shock", "shock", int(action.get("shock", 0))))
	if bool(action.get("immobilize", false)):
		tokens.append(_token_for_action_field(action, "immobilize", "immobilize"))
	if int(action.get("chain", 0)) > 0:
		tokens.append(_token_for_action_field(action, "chain", "chain", int(action.get("chain", 0))))
	if int(action.get("stagger", 0)) > 0:
		tokens.append(_token_for_action_field(action, "stagger", "stagger", int(action.get("stagger", 0))))
	if int(action.get("push", 0)) > 0:
		tokens.append(_token_for_action_field(action, "push", "push", int(action.get("push", 0))))
	if int(action.get("pull", 0)) > 0:
		tokens.append(_token_for_action_field(action, "pull", "pull", int(action.get("pull", 0))))

static func _append_illuminate_rider_tokens(tokens: Array, action: Dictionary) -> void:
	var radius: int = int(action.get("illuminate_radius", 0))
	if radius <= 0:
		return
	var action_type: String = str(action.get("type", ""))
	var radius_tooltip: String = "Creates Light at the target. Radius in tiles."
	var duration_tooltip: String = "Turns this Light lasts."
	if action_type in ["move", "move_toward", "move_away", "blink"]:
		radius_tooltip = "Creates Light where you land. Radius in tiles."
		duration_tooltip = "Turns this Light lasts."
	tokens.append(_token_for_action_field(
		action,
		"illuminate",
		"illuminate_radius",
		radius,
		"neutral",
		radius_tooltip
	))
	(tokens[tokens.size() - 1] as Dictionary)["row_group"] = "light"
	var duration: int = int(action.get("illuminate_duration", 1))
	tokens.append(_token_for_action_field(
		action,
		"time",
		"illuminate_duration",
		"∞" if duration < 0 else duration,
		"neutral",
		duration_tooltip
	))

	(tokens[tokens.size() - 1] as Dictionary)["row_group"] = "light"

static func _action_element(action: Dictionary) -> String:
	var element_id: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
	return element_id if ElementData.is_elemental(element_id) else ElementData.NONE

static func _damage_tone(final_damage: int, base_damage: int) -> String:
	return _value_tone(final_damage, base_damage)

static func _value_tone(final_value: int, base_value: int) -> String:
	if final_value > base_value:
		return "bonus"
	if final_value < base_value:
		return "penalty"
	return "neutral"

static func surface_icon_key(kind: String) -> String:
	return "surface_%s" % kind if kind in ["fire", "ice", "electrified", "rubble"] else "surface"

static func surface_token(kind: String, detail: String = "") -> Dictionary:
	var key: String = surface_icon_key(kind)
	var token: Dictionary = token_for(key, null, "neutral", tooltip(key) + ("\n" + detail if not detail.is_empty() else ""))
	token["surface"] = kind
	return token

static func surface_condition_token(condition: Dictionary) -> Dictionary:
	var kind: String = str(condition.get("surface", ""))
	var subject: String = str(condition.get("subject", "target"))
	if subject == "conducted" and kind.is_empty():
		return text_token("Conducted hits:", "neutral", "Applies only to hits carried by a conductive connection.")
	var placement: String = "on" if bool(condition.get("present", true)) else "off"
	var prefix: String = "if" if subject in ["consumed", "conducted"] else "%s %s" % ["if" if subject == "player" else "Target", placement]
	var suffix: String = "consumed:" if subject == "consumed" else "used:" if subject == "conducted" else ":"
	var condition_text: String = ("%s %s %s" % [prefix, label(surface_icon_key(kind)), suffix]).replace(" :", ":")
	var token: Dictionary = text_token(condition_text, "neutral", condition_text)
	token["kind"] = "surface_condition"
	token["icon"] = surface_icon_key(kind)
	# Ground conditions read "on [Fire]:" on the face so the condition and its
	# bonus share one hand-card row; the subject ("Target on Fire:", "if on
	# Electrified:") stays in the plain text and the hover tooltip.
	token["prefix"] = placement if subject in ["target", "player"] else prefix
	token["suffix"] = suffix
	token["surface_condition"] = condition.duplicate(true)
	return token

static func tokens_for_surface_bonus(action: Dictionary) -> Array:
	var bonus: Dictionary = action.get("surface_bonus", {}) as Dictionary
	if bonus.is_empty(): return []
	var tokens: Array = [surface_condition_token(bonus)]
	for key: String in ["damage", "amount", "shock", "push", "pull", "chain"]:
		var amount: int = int(bonus.get(key, 0))
		if amount == 0: continue
		# The bonus chip repeats the attack's own damage icon (melee, ranged, Pierce).
		var icon: String = _damage_icon_for_action(action, _damage_bonus_fallback_icon(action)) if key == "damage" else action_icon_key(action) if key == "amount" else key
		tokens.append(token_for(icon, "%+d" % amount, "condition"))
	return tokens

static func tokens_for_guardian_rule(action: Dictionary) -> Array:
	var row: Array = []
	var shape: String = str(action.get("committed_shape", action.get("guardian_shape", "")))
	if shape == "ring":
		var low: int = int(action.get("minimum_range",1))
		var high: int = int(action.get("range",1))
		row.append(text_token("Ring %d–%d" % [low,high] if low != high else "Ring %d" % high,"warning","Distance is measured from the nearest occupied dragon tile."))
		if action.has("range_status"): row.append(text_token("· Mantle fuels range","warning","Each remaining layer adds 1 range, up to %d. Break layers to shrink the warning; Shatterstorm spends the rest." % int(action.get("maximum_range",3))))
		_append_brazier_rule(row,action)
		return row
	if shape == "swept_path":
		row.append(text_token("Along approach +%d" % int(action.get("range",1)),"warning","Hits the shown approach path and every tile within this distance of the dragon's swept body, including where it started. The approach direction stays fixed."))
		_append_brazier_rule(row,action)
		return row
	if shape == "surface_snapshot":
		row.append(surface_token(str(action.get("snapshot_surface","electrified"))))
		var radius: int = int(action.get("snapshot_radius",0))
		var label: String = "Marked + adjacent" if radius > 0 else "Marked tiles"
		if action.has("consume_surface"): label += " · consumed"
		row.append(text_token(label,"warning","Hits surviving marked ground%s. Replacing a marked surface removes its area; later ground is not added." % (" and its orthogonal neighbors" if radius > 0 else "")))
		_append_brazier_rule(row,action)
		return row
	if shape == "trail_snapshot":
		row.append(text_token("Dive wake", "warning", "Hits the marked wake left by the actual Dive. It stays fixed when the dragon moves."))
		return row
	if shape == "refuge":
		row.append(text_token("Shadow sweep", "warning", "Hits the marked ground. Light blocks darkness, but this sweep can still hit."))
		return row
	if shape == "cross":
		row.append(text_token("Cross %d" % int(action.get("range",3)), "warning", "Two-wide lanes extend from all four edges of the dragon. Leaves Ice on the marked ground."))
		return row
	if action.has("pattern_footprint") and not shape.is_empty():
		var pattern: Array = []
		var reach: int = int(action.get("range", 1))
		for distance: int in range(1, reach + 1):
			var flank: int = maxi(distance - 1, int(action.get("pattern_min_flank",0))) if shape == "fan" else 1 if shape == "crescent" else int(action.get("pattern_flank", 0))
			for lane: int in range(-flank, 2 + flank): pattern.append([lane, -distance])
		if shape == "crescent":
			for row_index: int in [0, 1]:
				pattern.append([-1, row_index])
				pattern.append([2, row_index])
		row.append(_aoe_pattern_token({"pattern": pattern, "range": 0}))
		row.append(text_token("Fixed direction", "warning", "The shown approach and direction stay fixed. Displacing the dragon shifts the pattern with it."))
		_append_brazier_rule(row,action)
		return row
	match shape:
		"line", "broken_line", "sweep":
			var pattern: Array = []
			var width: int = int(action.get("guardian_width",3 if shape=="sweep" else 1))
			for side: int in range(-width/2,width/2+1):
				for distance: int in range(1,int(action.get("guardian_length",action.get("range",1)))+1):
					if shape!="broken_line" or distance!=2: pattern.append([side,-distance])
			row.append(_aoe_pattern_token({"pattern":pattern,"range":0}))
			row.append(text_token("Fixed direction", "warning", "Pattern follows the caster; direction stays fixed."))
		"connector":
			row.append(text_token("%d linked tiles" % int(action.get("guardian_count",1)),"warning","Extends existing Electrified toward its target."))
		"conductor":
			row.append(surface_token("electrified"))
			row.append(text_token("Connected network", "warning", "Origin: the marked conductor."))
	if int(action.get("self_expose",0))>0:
		row.append(text_token("Self:"))
		row.append(token_for("expose",action["self_expose"]))
	for field: String in ["trail_surface","terminal_surface"]:
		if action.has(field):
			row.append(surface_token(str(action[field])))
			row.append(text_token("Trail" if field=="trail_surface" else "At lane end"))
	_append_brazier_rule(row,action)
	return row

static func _append_brazier_rule(row: Array, action: Dictionary) -> void:
	if bool(action.get("snuff_brazier",false)):
		var label: String = "Snuff before hit" if str(action.get("type",""))=="umbra_eclipse" else "Snuff refuge"
		row.append(text_token(label if row.is_empty() else "· "+label,"warning",brazier_rule_tooltip(action)))

static func brazier_rule_tooltip(action: Dictionary) -> String:
	# Saved first-revision Eclipse still snuffs immediately before its damage.
	# Dispatch on the verb so it cannot inherit the Guardian's recovery rule.
	if str(action.get("type",""))=="umbra_eclipse":
		return "The marked brazier goes dark before this Eclipse hits. Use another Light source for protection."
	if action.has("committed_shape"):
		return "Night Coil extinguishes the marked brazier. Step onto its tile afterward to relight it before Eclipse."
	return "Lasts until Last Procession, including a skipped turn."
