extends SceneTree

## Only this unit's owned outputs; no editor scan or provided-input writes.
const PNG_ROOTS = [
	"res://experiments/cutouts/slag_mortar/rr30",
	"res://experiments/cutouts/slag_mortar/rr31",
	"res://assets/units/slag_mortar_cutout",
	"res://spec/art_identity/jobs/slag_mortar/mq11_front",
	"res://spec/art_identity/jobs/slag_mortar/mq11_rear",
	"res://spec/assets/board_pixel_density/sources/assets/units/slag_mortar_cutout",
]
const SCRIPTS = [
	"res://experiments/cutouts/slag_mortar/rr30/motion.gd",
	"res://tests/rr30/runtime_checks.gd",
	"res://tests/rr30/production_capture.gd",
	"res://tests/rr30/density_rebake.gd",
	"res://tests/rr31/joint_samples.gd",
	"res://experiments/cutouts/slag_mortar/rr30_sidecars.gd",
]
const KEEP_IMPORT = "[remap]\n\nimporter=\"keep\"\n"
const TRANSIENT_PROOF_FOLDERS = ["logs", "native", "native_rest", "production_native",
	"seam_cpu", "contact_sheets", "idle_native", "gait_move_native"]
var imports_created: int = 0
var uids_created: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for path: String in PNG_ROOTS: _png_sidecars(path)
	for path: String in SCRIPTS:
		if FileAccess.file_exists(path + ".uid"): continue
		var uid: int = ResourceUID.create_id()
		var file := FileAccess.open(path + ".uid", FileAccess.WRITE)
		assert(file != null, "Cannot write owned UID: " + path)
		file.store_line(ResourceUID.id_to_text(uid))
		uids_created += 1
	print("RR30 SIDECARS: PASS (%d missing imports; %d missing UIDs created; existing sidecars retained)" % [imports_created, uids_created])
	quit(0)

func _png_sidecars(folder: String) -> void:
	if "/proof/" in folder:
		var relative: String = folder.split("/proof/", true, 1)[1]
		if relative.get_slice("/", 0) in TRANSIENT_PROOF_FOLDERS: return
	for directory: String in DirAccess.get_directories_at(folder):
		_png_sidecars(folder.path_join(directory))
	for name: String in DirAccess.get_files_at(folder):
		if not name.ends_with(".png"): continue
		var path: String = folder.path_join(name) + ".import"
		if FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert(file != null, "Cannot write owned import: " + path)
		file.store_string(KEEP_IMPORT)
		imports_created += 1
