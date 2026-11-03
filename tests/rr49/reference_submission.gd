extends RefCounted

## Immutable optimized submission at the director-approved c78b9f7f6. Paint and
## skin are exact Git sources. The idle-only point helper is extracted from the
## same Git motion.gd, so even unmeasured reference imports stay independent.
const REVISION: String = "c78b9f7f68cc52880a6e74d805983a698999c1b6"
const FIXTURE: String = "res://tests/rr49/fixtures/optimized_c78b9f7f6/"
const PAINT_SHA256: String = "06abd3523e15c73ea1d957cbfced52217ebde111792c82a1815f0f569bd8196d"
const SKIN_SHA256: String = "81c2970dd401601a7a70c7fe0b3838e359eb152aa91e3ce8c0a3e6c102748b1a"
const POINT_SHA256: String = "68d5169068b52e37488e1ba4e13f9d533440d91c5bde753bc51e973f64b76d35"
const StableSkin = preload("res://tests/rr49/fixtures/optimized_c78b9f7f6/stable_skin.gd")
const Paint = preload("res://tests/rr49/fixtures/optimized_c78b9f7f6/stable_paint.gd")

static func paint_script() -> GDScript:
	assert(FileAccess.get_sha256(FIXTURE + "stable_paint.gd") == PAINT_SHA256)
	assert(FileAccess.get_sha256(FIXTURE + "stable_skin.gd") == SKIN_SHA256)
	assert(FileAccess.get_sha256(FIXTURE + "motion.gd") == POINT_SHA256)
	return Paint
