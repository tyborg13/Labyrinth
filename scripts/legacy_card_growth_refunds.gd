extends RefCounted
class_name LegacyCardGrowthRefunds

# Fixed-upgrade prices evaluated with the final fixed-upgrade code and card
# data at 7ee5f38d^, before the flexible modifier migration. Kept here only for
# refunding serialized ownership; no retired mechanic is playable through this.
# Flexible modifiers instead refund their individually serialized cost_paid.
const PRICES: Dictionary = {
	"basalt_guard_reinforced": 30,
	"bloody_lunge_cinder": 30,
	"bone_dart_barbed": 25,
	"brace_stone": 15,
	"chain_bolt_arcing": 20,
	"cinderburst_kindled": 30,
	"ember_jab_spark": 30,
	"ember_rain_cinders": 30,
	"frostbolt_deep": 20,
	"guarded_step_bulwark": 15,
	"iron_wheel_spiked": 20,
	"lantern_shot_flare": 30,
	"patch_up_binding": 20,
	"quick_stab_honed": 20,
	"rallying_breath_deep": 20,
	"ricochet_knife_keening": 20,
	"shadow_step_thread": 20,
	"sidestep_slash_kindled": 20,
	"stone_plate_mantle": 20,
	"threaded_path_quickening": 20,
	"trapdoor_shell": 30,
	"venom_claw_virulent": 20,
	"warded_advance_bastion": 20,
	"whirlwind_slash_weighted": 15
}

static func cost(upgrade_id: String) -> int:
	return int(PRICES.get(upgrade_id, 0))
