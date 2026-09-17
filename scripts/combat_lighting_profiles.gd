extends RefCounted
## Authoritative named combat lighting looks. Warm applies to every combat.
## Other profiles are retained for development and future encounter art direction.
## See spec/combat_art_treatment.md for tuning, extension and reconstruction.

const DEFAULT_ID: String = "warm"
# Authored density anchors: preserve original Warm at two columns and original
# Gentle at four. Other stored profiles keep their original art direction.
const SPARSE_SOURCES: float = 2.0
const DENSE_SOURCES: float = 4.0
const TORCH_STRENGTH: float = 0.80
const DENSE_TARGETS := {"warm": "gentle"}
const SCALAR_FIELDS = ["ambient", "gain", "reach", "contrast", "saturation", "rim"]
# Declaration order is the comparison order; add new looks here only.
const PRESETS := {
	"gentle": {"ambient": 0.90, "gain": 0.38, "reach": 1.05, "contrast": 1.02, "saturation": 0.94, "rim": 0.80, "tint": Vector3(0.985, 0.985, 1.01)},
	"warm": {"ambient": 0.77, "gain": 0.68, "reach": 1.0, "contrast": 1.05, "saturation": 0.92, "rim": 1.0, "tint": Vector3(1.015, 0.985, 0.95)},
	"balanced": {"ambient": 0.62, "gain": 0.95, "reach": 1.0, "contrast": 1.07, "saturation": 0.90, "rim": 1.20, "tint": Vector3(0.94, 0.98, 1.045)},
	"moody": {"ambient": 0.46, "gain": 1.25, "reach": 0.93, "contrast": 1.10, "saturation": 0.88, "rim": 1.45, "tint": Vector3(0.91, 0.965, 1.075)},
	"dramatic": {"ambient": 0.32, "gain": 1.55, "reach": 0.88, "contrast": 1.13, "saturation": 0.86, "rim": 1.65, "tint": Vector3(0.89, 0.95, 1.10)},
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

static func density_blend(source_equivalents: float) -> float:
	return smoothstep(SPARSE_SOURCES, DENSE_SOURCES, maxf(source_equivalents, 0.0))

static func local_light_scale(source_equivalents: float) -> float:
	# Above the dense reference, retain four torch-equivalents of total energy.
	# This also scales the retained floor glows, not the flames themselves.
	return minf(1.0, DENSE_SOURCES / maxf(source_equivalents, DENSE_SOURCES))

static func resolved_definition(id: String, source_equivalents: float) -> Dictionary:
	var sparse: Dictionary = definition(id)
	if sparse.is_empty() or not DENSE_TARGETS.has(id):
		return sparse
	var blend: float = density_blend(source_equivalents)
	if blend <= 0.0:
		return sparse
	var dense: Dictionary = definition(str(DENSE_TARGETS[id]))
	if blend >= 1.0:
		return dense
	for key: String in SCALAR_FIELDS:
		sparse[key] = lerpf(float(sparse[key]), float(dense[key]), blend)
	var sparse_tint: Vector3 = sparse["tint"]
	var dense_tint: Vector3 = dense["tint"]
	sparse["tint"] = sparse_tint.lerp(dense_tint, blend)
	return sparse
