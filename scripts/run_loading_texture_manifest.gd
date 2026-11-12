extends RefCounted

# qa-82: traced cold room inputs. The existing loading job publishes these
# through AssetLoader; only its normal texture cache retains the resources.
const CAMPFIRE_VIEW_TEXTURES: PackedStringArray = [
	"res://assets/art/cards/bloody_lunge.png",
	"res://assets/art/cards/brace.png",
	"res://assets/art/cards/clockwork_mark.png",
	"res://assets/art/cards/dull_bolt.png",
	"res://assets/art/cards/fault_strike.png",
	"res://assets/art/cards/flowing_step.png",
	"res://assets/art/cards/frozen_bite.png",
	"res://assets/art/cards/galvanize.png",
	"res://assets/art/cards/guarded_step.png",
	"res://assets/art/cards/hamstring_shot.png",
	"res://assets/art/cards/kestrel_dive.png",
	"res://assets/art/cards/lantern_shot.png",
	"res://assets/art/cards/lodestone_reversal.png",
	"res://assets/art/cards/pale_spark.png",
	"res://assets/art/cards/palm_strike.png",
	"res://assets/art/cards/patch_up.png",
	"res://assets/art/cards/polar_guard.png",
	"res://assets/art/cards/quick_stab.png",
	"res://assets/art/cards/raise_the_anvil.png",
	"res://assets/art/cards/razor_gale.png",
	"res://assets/art/cards/rime_hack.png",
	"res://assets/art/cards/rockburst.png",
	"res://assets/art/cards/shadow_step.png",
	"res://assets/art/cards/shatter_swing.png",
	"res://assets/art/cards/shield_charge.png",
	"res://assets/art/cards/shield_wall.png",
	"res://assets/art/cards/sidestep_slash.png",
	"res://assets/art/cards/static_mantle.png",
	"res://assets/art/cards/whirlwind_slash.png",
	"res://assets/art/cards/worldbreak.png",
	"res://assets/art/equipment/cracked_lantern.png",
	"res://assets/art/equipment/patched_cloak.png",
	"res://assets/art/equipment/skirmisher_boots.png",
	"res://assets/art/equipment/splintered_shield.png",
	"res://assets/art/equipment/training_sword.png",
	"res://assets/art/ui/campfire_choice_embrace_v2.png",
	"res://assets/art/ui/campfire_choice_linger_v2.png",
	"res://assets/art/ui/campfire_choice_purge_v2.png",
	"res://assets/art/ui/campfire_choice_strength_v2.png",
]

const GRAFT_PANEL_TEXTURES: PackedStringArray = [
	"res://assets/art/ui/graftwright/atelier.png",
	"res://assets/art/ui/graftwright/workmat.png",
	"res://assets/art/ui/graftwright/item_cradle.png",
	"res://assets/art/ui/graftwright/ritual_clasp.png",
]

const MAP_PREPARATION_TEXTURES: PackedStringArray = [
	"res://assets/art/events/ember_shaft.png",
	"res://assets/art/cards/caltrops.png",
	"res://assets/art/cards/cinder_bloom.png",
	"res://assets/art/cards/gale_ward.png",
	"res://assets/art/cards/glacier_salts.png",
	"res://assets/art/cards/headsmans_toll.png",
	"res://assets/art/cards/hook_and_hold.png",
	"res://assets/art/cards/hookspine_reap.png",
	"res://assets/art/cards/pitch_firebomb.png",
	"res://assets/art/cards/static_rush.png",
	"res://assets/art/cards/sweeping_haft.png",
	"res://assets/art/cards/sworn_oath.png",
	"res://assets/art/equipment/headsmans_coin.png",
	"res://assets/art/equipment/hookspine_halberd.png",
	"res://assets/art/equipment/oathstone.png",
	"res://assets/art/items/caltrops.png",
	"res://assets/art/items/glacier_salts.png",
	"res://assets/art/items/pitch_firebomb.png",
	"res://assets/art/ui/card_frame_rarity_common.png",
	"res://assets/art/ui/card_role_emblems/role_attack_ranged.png",
	"res://assets/art/ui/card_role_emblems/role_block.png",
	"res://assets/art/ui/card_role_emblems/role_mobility.png",
	"res://assets/art/ui/card_time_watch.png",
	"res://assets/art/ui/visual_pass_4/price_tag.png",
]

# perf-126: only the two idle sheets observed in the first minute of the demo.
# Keep the ordinary import/source policy; the shared source worker can decode
# these before BiomeLibrary first asks for them while constructing the room.
const DEMO_FIRST_ROOM_TEXTURES: PackedStringArray = [
	"res://assets/art/biomes/tharokh/light_left_idle.png",
	"res://assets/art/biomes/tharokh/light_right_idle.png",
]

static func add_to(manifest: Dictionary) -> void:
	for paths: PackedStringArray in [CAMPFIRE_VIEW_TEXTURES, GRAFT_PANEL_TEXTURES, MAP_PREPARATION_TEXTURES, DEMO_FIRST_ROOM_TEXTURES]:
		for path: String in paths: manifest[path] = false
