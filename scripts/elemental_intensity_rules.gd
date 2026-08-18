extends RefCounted
class_name ElementalIntensityRules

const ElementData = preload("res://scripts/element_data.gd")

const TRAP_SCALE_CAP: int = 6
const AMBIENT_SCALE_CAP: int = 6

static func normalized_cost(raw: Variant, fallback_element: String = ElementData.NONE) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = raw as Dictionary
	var element_id: String = str(source.get("element", fallback_element))
	var amount: int = maxi(0, int(source.get("amount", source.get("cost", 0))))
	if not ElementData.is_elemental(element_id) or amount <= 0:
		return {}
	return {"element": element_id, "amount": amount}

static func card_cost(card: Dictionary) -> Dictionary:
	return normalized_cost(card.get("intensity_cost", {}), str(card.get("element", ElementData.NONE)))

static func action_spend(action: Dictionary) -> Dictionary:
	return normalized_cost(action.get("spend_intensity", {}), str(action.get("element", action.get("_card_element", ElementData.NONE))))

static func trap_scale_percent(intensity: int) -> int:
	var level: int = clampi(intensity, 0, TRAP_SCALE_CAP)
	# Baseline elemental rooms begin at one intensity (94% of the old trap
	# damage). The quadratic term makes deliberately overcharging a room a
	# meaningful environmental risk without allowing unbounded save values to
	# create unbounded damage.
	return 72 + 18 * level + 4 * level * level

static func scaled_trap_damage(base_damage: int, intensity: int) -> int:
	if base_damage <= 0:
		return 0
	return maxi(1, int(roundf(float(base_damage) * float(trap_scale_percent(intensity)) / 100.0)))

static func trap_multiplier(intensity: int) -> float:
	return float(trap_scale_percent(intensity)) / 100.0

static func ambient_density_scale(intensity: int) -> float:
	return ambient_density_scale_continuous(float(intensity))

static func ambient_density_scale_continuous(intensity: float) -> float:
	var level: float = clampf(intensity, 0.0, float(AMBIENT_SCALE_CAP))
	return 0.55 + 0.25 * level

static func ambient_opacity_scale(intensity: int) -> float:
	return ambient_opacity_scale_continuous(float(intensity))

static func ambient_opacity_scale_continuous(intensity: float) -> float:
	var level: float = clampf(intensity, 0.0, float(AMBIENT_SCALE_CAP))
	return 0.72 + 0.08 * level

static func ambient_speed_scale(intensity: int) -> float:
	return ambient_speed_scale_continuous(float(intensity))

static func ambient_speed_scale_continuous(intensity: float) -> float:
	var level: float = clampf(intensity, 0.0, float(AMBIENT_SCALE_CAP))
	return 0.84 + 0.055 * level

static func threat_band_id(intensity: int) -> String:
	if intensity <= 0:
		return "quiet"
	if intensity == 1:
		return "stirring"
	if intensity == 2:
		return "charged"
	if intensity <= 4:
		return "volatile"
	return "cataclysmic"

static func threat_band_name(intensity: int) -> String:
	match threat_band_id(intensity):
		"quiet":
			return "Quiet"
		"stirring":
			return "Stirring"
		"charged":
			return "Charged"
		"volatile":
			return "Volatile"
		_:
			return "Cataclysmic"
