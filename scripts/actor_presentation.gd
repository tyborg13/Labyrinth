extends RefCounted

const MaquettePresentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")

## Fixed source-space support registration. See spec/actor_presentation.md.
## These are ground contacts, not the center of a weapon-inclusive silhouette.
## HUD heights use each painted rest view; raised weapons never lift a nameplate.
const SOURCE_SIZE: float = 255.0
## Director-authored body contact, in the same rest canvas as PROFILES.
const GROUND_CONTACT: Dictionary = {
	"burrow_grub": {
		"front": {"from": Vector2(53.86120086, 237.49779122), "to": Vector2(213.86362062, 181.41817269), "half_width": 38.13637938, "alpha": 0.62},
		"rear": {"from": Vector2(59.92722330, 244.91288333), "to": Vector2(206.39567464, 178.28768974), "half_width": 33.60432536, "alpha": 0.62},
	},
}
const PROFILES: Dictionary = {
	# Live rig's two-sole midpoint (bottom three opaque rows per foot), plus the
	# owner's nudge (+5, 0).
	# Keep the painted-rest HUD landmarks at source y=16 front / y=8 rear.
	"glacial_mirror": {"front": Vector2(122.57, 224.82), "rear": Vector2(125.81, 226.23), "height": Vector2(208.82, 218.23)},
	"ember_tick": {"front": Vector2(117.0, 226.46), "rear": Vector2(135.75, 225.21), "height": Vector2(127.46000000000001, 132.21)},
	"ember_hoarder": {"front": Vector2(117.0, 226.46), "rear": Vector2(135.75, 225.21), "height": Vector2(127.46000000000001, 132.21)},
	"burrow_grub": {"front": Vector2(138.39211465, 207.87035554), "rear": Vector2(140.07841208, 208.45391609), "height": Vector2(101.87035554, 109.45391609)},
	"hoarfrost_seer": {"front": Vector2(135.0, 232.46), "rear": Vector2(122.0, 219.21), "height": Vector2(192.46, 182.21)},
	"arc_thrall": {"front": Vector2(132.0, 230.46), "rear": Vector2(124.75, 239.96), "height": Vector2(189.46, 190.96)},
	"ash_hound": {"front": Vector2(120.2500, 217.0000), "rear": Vector2(130.2500, 217.7500), "height": Vector2(171.0000, 171.7500)},
	"ashen_reaver": {"front": Vector2(152.75000000, 224.50000000), "rear": Vector2(92.00000000, 227.50000000), "height": Vector2(218.50000000, 219.50000000)},
	"bell_tender": {"front": Vector2(144.0000, 241.0000), "rear": Vector2(106.0000, 240.5000), "height": Vector2(231.0000, 230.5000)},
	"craghide": {"front": Vector2(135.0000, 215.7500), "rear": Vector2(127.2500, 209.2500), "height": Vector2(172.7500, 166.2500)},
	"gallows_roc": {"front": Vector2(125.5000, 212.5000), "rear": Vector2(134.5000, 211.5000), "height": Vector2(203.5000, 201.5000)},
	"last_lamplighter": {"front": Vector2(120.00000000, 231.00000000), "rear": Vector2(120.25000000, 230.50000000), "height": Vector2(212.00000000, 224.50000000)},
	"rime_spitter": {"front": Vector2(128.0000, 221.3333), "rear": Vector2(136.6667, 219.0000), "height": Vector2(134.3333, 131.0000)},
	"rime_whelp": {"front": Vector2(115.2500, 215.7500), "rear": Vector2(134.5000, 212.2500), "height": Vector2(166.7500, 163.2500)},
	"rimejaw": {"front": Vector2(123.3333, 215.6667), "rear": Vector2(143.0000, 211.0000), "height": Vector2(167.6667, 162.0000)},
	"roc_fledgling": {"front": Vector2(125.5000, 230.5000), "rear": Vector2(139.0000, 224.0000), "height": Vector2(165.5000, 159.0000)},
	"stoneback_mite": {"front": Vector2(147.0000, 230.5000), "rear": Vector2(126.2000, 232.4000), "height": Vector2(143.5000, 145.4000)},
	"storm_cantor": {"front": Vector2(120.75000000, 232.50000000), "rear": Vector2(118.75000000, 231.00000000), "height": Vector2(210.50000000, 225.00000000)},
	"wick_shade": {"front": Vector2(140.5000, 242.0000), "rear": Vector2(114.5000, 241.5000), "height": Vector2(233.0000, 232.5000)},
	"crawler": {"front": Vector2(120.0, 187.5), "rear": Vector2(134.75, 179.25), "height": Vector2(155.5000, 147.2500)},
	"acolyte": {"front": Vector2(142.5, 233.0), "rear": Vector2(141.5, 234.0), "height": Vector2(214.0000, 214.0000)},
	"harrier": {"front": Vector2(143.5, 209.5), "rear": Vector2(108.5, 217.0), "height": Vector2(179.5000, 187.0000)},
	"warden": {"front": Vector2(131.5, 222.0), "rear": Vector2(119.0, 224.5), "height": Vector2(211.0000, 212.5000)},
	"cinder_ooze": {"front": Vector2(130.3333, 204.8333), "rear": Vector2(132.6667, 202.6667), "height": Vector2(192.8333, 183.6667)},
	"cinder_droplet": {"front": Vector2(125.4, 203.2), "rear": Vector2(120.4, 201.8), "height": Vector2(123.2000, 121.8000)},
	"bile_bloomer": {"front": Vector2(128.00000000, 195.40221374), "rear": Vector2(114.53153153, 207.00554874), "height": Vector2(175.40221374, 163.00554874)},
	"chainbound_gaoler": {"front": Vector2(140.00000000, 236.50000000), "rear": Vector2(105.25000000, 238.50000000), "height": Vector2(206.50000000, 207.50000000)},
	"grave_surgeon": {"front": Vector2(163.5, 207.0), "rear": Vector2(166.5, 200.0), "height": Vector2(180.0000, 173.0000)},
	"frostglass_lancer": {"front": Vector2(117.50000000, 239.00000000), "rear": Vector2(122.50000000, 237.50000000), "height": Vector2(218.00000000, 217.50000000)},
	"tharokh": {"front": Vector2(111.25, 200.0), "rear": Vector2(138.75, 188.75), "height": Vector2(193.0000, 178.7500)},
	"vyraketh": {"front": Vector2(124.75, 177.75), "rear": Vector2(102.0, 168.0), "height": Vector2(166.7500, 137.0000)},
	"vaeloryx": {"front": Vector2(127.5, 227.0), "rear": Vector2(127.5, 227.0), "height": Vector2(207.0000, 206.0000)},
	"iskaldra": {"front": Vector2(137.5, 191.0), "rear": Vector2(149.5, 189.5), "height": Vector2(183.0000, 180.5000)},
	"noctyrax": {"front": Vector2(111.25, 188.5), "rear": Vector2(160.0, 190.0), "height": Vector2(182.5000, 187.0000)},
	"zekarion": {"front": Vector2(116.0, 185.5), "rear": Vector2(152.75, 178.0), "height": Vector2(176.5000, 170.0000)},
	"veilbound_acolyte": {"front": Vector2(140.0, 229.0), "rear": Vector2(134.5, 230.0), "height": Vector2(210.0000, 211.0000)},
	"lightning_wisp": {"front": Vector2(131.00000000, 270.71935182), "rear": Vector2(124.00000000, 279.71935182), "height": Vector2(192.71935182, 197.71935182)},
}

static func has_profile(unit_type: String) -> bool:
	return PROFILES.has(unit_type)

static func floor_anchor(unit_type: String, facing: String = "front", mirrored: bool = false) -> Vector2:
	var anchor: Vector2 = PROFILES.get(unit_type, {}).get(facing, Vector2(127.5, 202.7))
	if mirrored:
		anchor.x = SOURCE_SIZE - anchor.x
	return anchor

static func height_above_floor(unit_type: String, facing: String = "") -> float:
	var heights: Vector2 = PROFILES.get(unit_type, {}).get("height", Vector2.ZERO)
	return heights.y if facing == "rear" else heights.x if facing == "front" else maxf(heights.x, heights.y)

const ACTION_BOUNDS: Dictionary = {
	"ember_tick": Rect2(-128.0, -150.0, 256.0, 178.0),
	"ember_hoarder": Rect2(-128.0, -150.0, 256.0, 178.0),
	"burrow_grub": Rect2(-152.0, -131.0, 304.0, 228.0),
	"arc_thrall": Rect2(-172.0, -196.0, 344.0, 232.0),
	"hoarfrost_seer": Rect2(-163.0, -223.0, 326.0, 263.0),
	"crawler": Rect2(-158.2500, -159.5000, 316.5000, 209.2500),
	"acolyte": Rect2(-103.5000, -216.0000, 207.0000, 236.0000),
	"harrier": Rect2(-192.5000, -246.0000, 385.0000, 276.5000),
	"warden": Rect2(-183.0000, -256.0000, 366.0000, 282.5000),
	"cinder_ooze": Rect2(-150.6667, -198.8333, 301.3334, 243.1666),
	"cinder_droplet": Rect2(-137.6000, -127.2000, 275.2000, 165.4000),
	"bile_bloomer": Rect2(-151.6667, -246.6667, 303.3334, 277.0000),
	"chainbound_gaoler": Rect2(-233.0000, -244.5000, 466.0000, 275.5000),
	"grave_surgeon": Rect2(-135.5000, -182.0000, 271.0000, 210.0000),
	"frostglass_lancer": Rect2(-267.0, -255.0, 534.0, 279.0),
	"tharokh": Rect2(-140.7500, -197.0000, 281.5000, 254.2500),
	"vyraketh": Rect2(-143.0000, -169.7500, 286.0000, 246.7500),
	"vaeloryx": Rect2(-128.5000, -217.0000, 257.0000, 234.0000),
	"iskaldra": Rect2(-130.5000, -187.0000, 261.0000, 243.0000),
	"noctyrax": Rect2(-155.0000, -192.0000, 310.0000, 262.5000),
	"zekarion": Rect2(-141.7500, -183.5000, 283.5000, 249.0000),
	"veilbound_acolyte": Rect2(-101.5000, -213.0000, 203.0000, 235.0000),
	"lightning_wisp": Rect2(-76.0000, -210.0000, 152.0000, 210.0000),
}

static func body_envelope(unit_type: String) -> Rect2:
	if ACTION_BOUNDS.has(unit_type):
		return (ACTION_BOUNDS[unit_type] as Rect2).grow(8.0)
	# Reserve both painted directions/reflections before anyone moves. A small
	# action margin also covers breathing and the walk's lifted/reaching limbs.
	# The native presentation probe verifies the complete sampled action bounds.
	var left: float = INF
	var top: float = INF
	var right: float = -INF
	var bottom: float = -INF
	for facing: String in ["front", "rear"]:
		var anchor: Vector2 = floor_anchor(unit_type, facing)
		left = minf(left, minf(-anchor.x, anchor.x - SOURCE_SIZE))
		right = maxf(right, maxf(SOURCE_SIZE - anchor.x, anchor.x))
		top = minf(top, -anchor.y)
		bottom = maxf(bottom, SOURCE_SIZE - anchor.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top)).grow(16.0)

static func travel_renderer(unit_type: String) -> Script:
	if MaquettePresentation.handles(unit_type):
		return MaquettePresentation.renderer_script(unit_type)
	if preload("res://scripts/guardian_cutout/renderer.gd").handles(unit_type):
		return preload("res://scripts/guardian_cutout/renderer.gd")
	if unit_type != "player" and not PROFILES.has(unit_type):
		return null
	var directory: String = "protagonist" if unit_type == "player" else "stone_warden" if unit_type == "warden" else unit_type
	return load("res://scripts/%s_cutout/renderer.gd" % directory) as Script
