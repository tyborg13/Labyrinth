extends RefCounted
## Authoritative named combat lighting looks. Warm applies to every combat.
## Other profiles are retained for development and future encounter art direction.
## See spec/combat_art_treatment.md for tuning, extension and reconstruction.

const DEFAULT_ID: String = "warm"
# Ambient carries the scene; local_budget softly bounds overlapping firelight.
# Original revision values remain in spec/proofs/combat-art-treatment/reference/lighting-capture.json.
# Declaration order is the comparison order; add new looks here only.
const PRESETS := {
	"gentle": {"ambient": 0.94, "gain": 0.23, "local_budget": 0.70, "reach": 1.05, "contrast": 1.02, "saturation": 0.94, "rim": 0.80, "tint": Vector3(0.985, 0.985, 1.01)},
	"warm": {"ambient": 0.88, "gain": 0.38, "local_budget": 0.70, "reach": 1.0, "contrast": 1.05, "saturation": 0.92, "rim": 1.0, "tint": Vector3(1.015, 0.985, 0.95)},
	"balanced": {"ambient": 0.80, "gain": 0.46, "local_budget": 0.70, "reach": 1.0, "contrast": 1.07, "saturation": 0.90, "rim": 1.20, "tint": Vector3(0.94, 0.98, 1.045)},
	"moody": {"ambient": 0.65, "gain": 0.62, "local_budget": 0.70, "reach": 0.93, "contrast": 1.10, "saturation": 0.88, "rim": 1.45, "tint": Vector3(0.91, 0.965, 1.075)},
	"dramatic": {"ambient": 0.52, "gain": 0.80, "local_budget": 0.70, "reach": 0.88, "contrast": 1.13, "saturation": 0.86, "rim": 1.65, "tint": Vector3(0.89, 0.95, 1.10)},
}

static func ids() -> Array[String]:
	var result: Array[String]
	for id: String in PRESETS:
		result.append(id)
	return result

static func has_profile(id: String) -> bool:
	return PRESETS.has(id)

static func definition(id: String) -> Dictionary:
	# Callers may annotate a copy for tools; never mutate the shared definitions.
	return (PRESETS[id] as Dictionary).duplicate(true) if PRESETS.has(id) else {}
