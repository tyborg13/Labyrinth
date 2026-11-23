extends RefCounted
## Skybreak's per-tile strike profile, shared by board rule strikes.
## Delivery/contact clocks stay owned by the original playback steps.
const Dragon = preload("res://scripts/dragon_presentation.gd")
const ZEKARION_REVEAL: float = 0.38
const REDUCED_IMPACT_PROGRESS: float = 0.38

static func profile() -> Dictionary:
	return {"geometry": "meteor", "element": "lightning"}

static func revealed(effect: Dictionary, progress: float, reduced: bool) -> bool:
	return reduced or not bool(effect.get("zekarion_cutout", false)) or progress >= ZEKARION_REVEAL

static func impact_progress(effect: Dictionary, progress: float, reduced: bool) -> float:
	if not revealed(effect, progress, reduced): return -1.0
	if reduced: return REDUCED_IMPACT_PROGRESS
	if progress < Dragon.CONTACT: return -1.0
	return clampf((progress - Dragon.CONTACT) / (1.0 - Dragon.CONTACT), 0.0, 1.0)
