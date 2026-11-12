extends SceneTree

# Stable resource metadata only. Never rewrite a source or an existing UID.
const SOURCES: Array = [
	"res://scripts/board_threat_isolation.gd",
	"res://scripts/board_threat_isolation_paint.gd",
	"res://tools/rd04/threat_isolation_proof.gd",
	"res://tools/rd04/reproduce.gd",
	"res://tools/rd04/focused_checks.gd",
	"res://tools/rd04/hover_checks.gd",
	"res://tools/rd04/ensure_sidecars.gd",
	"res://tools/rd04/fixture_generator.gd",
	"res://tools/rd04/real_fixture.gd",
	"res://tools/rd04/proof_case.gd",
	"res://tools/rd04/movie_capture.gd",
]
func _initialize() -> void:
	for source: String in SOURCES:
		if FileAccess.file_exists(source + ".uid"): continue
		var file := FileAccess.open(source + ".uid", FileAccess.WRITE)
		assert(file != null, "Write new source UID")
		file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
	print("RD04 SIDECARS: PASS")
	quit()
