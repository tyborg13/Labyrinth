extends RefCounted

## Playback only. Protected compiled tracks stay byte-identical. Linear-root
## humanoids use their authored tile clock; eased creatures use the director's.
# Existing Board constants moved here so packaged cutout playback does not
# depend on loading the complete board/UI resource graph just to read a clock.
const ENEMY_SHADOW_DISSOLVE_FRAME_COUNT: int = 28
const ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS: float = 0.037
const MOVE_TILE_SECONDS: Dictionary = {
	"ember_tick": 0.20, "ember_hoarder": 0.20, "lightning_wisp": 0.22,
	"arc_thrall": 0.24, "burrow_grub": 0.26, "hoarfrost_seer": 0.26,
	"shale_bloomer": 0.28,
}
## walk-01's reviewed humanoid roster. Other v2 creatures (the Mimic) keep
## their existing clock until their own cadence is revised.
const AUTHORED_HUMANOID_TILE_TYPES := [
	"arc_thrall", "ashen_reaver", "briar_weaver", "chainbound_gaoler",
	"frostglass_lancer", "gale_herald", "glacial_mirror", "gloam_stalker",
	"slag_mortar", "hoarfrost_seer", "last_lamplighter", "storm_cantor",
]

## Inspect the effective tracks, not the rig generation: the Seer's v2 root
## still eases/holds, while the current Thrall v2 root is already linear.
static func uses_continuous_root(data: Dictionary) -> bool:
	if not MOVE_TILE_SECONDS.has(str(data.get("creature", ""))): return false
	for clips: Dictionary in data.get("view_tracks", {}).values():
		for track: Dictionary in clips.get("move", []):
			if track["bone"] != "root" or track["channel"] != "forward_px": continue
			for key: Dictionary in track["keys"]:
				if str(key["interpolation"]) != "linear" or not is_equal_approx(float(key["at"]), float(key["value"])): return true
	return false

static func uses_parity(data: Dictionary) -> bool:
	return str(data.get("rig", "")) == "humanoid_v2" and data.get("clips", {}).has("move")

static func movement_frame_seconds(data: Dictionary, pacing: Node, key: String, counts: Array[int], authored: float, reduced: bool = false) -> float:
	# Reduced motion keeps its existing travel clock as well as its still art.
	if not reduced and uses_parity(data) and str(data.get("creature", "")) in AUTHORED_HUMANOID_TILE_TYPES and pacing.enemies_active and key != "player" and not counts.is_empty():
		return float(data["clips"]["move"]["seconds"]) / float(counts.max())
	if not reduced and uses_continuous_root(data) and pacing.enemies_active and key != "player" and not counts.is_empty():
		return float(MOVE_TILE_SECONDS[str(data["creature"])]) / float(counts.max())
	return pacing.walk_frame_seconds(key, counts, authored) if uses_parity(data) else authored

static func death_duration_scale(data: Dictionary, authored_total: float, reduced: bool = false) -> float:
	# Normal humanoid deaths own their full clip + dissolve duration. Only the
	# existing reduced-motion presentation retains the legacy total.
	if not reduced or not uses_parity(data): return 1.0
	var legacy_seconds: float = ENEMY_SHADOW_DISSOLVE_FRAME_COUNT * ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS
	return legacy_seconds / authored_total
