extends SceneTree

## Headless encoding measurement on existing native Seer production pixels.
## No synthetic art, renderer substitutions or new dependencies. Decode every
## candidate byte-for-byte, including RGB under transparent alpha.
const Storage = preload("capture_storage.gd")
const SIZE_LIMIT_BYTES: int = 1000000000
const PROOF_ENCODERS := ["png", "webp", "rgba"]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--validate-only"):
		print("CAPTURE ENCODER BENCHMARK LOAD: PASS")
		quit()
		return
	if not args.has("--capture") or not args.has("--output"):
		push_error("Use -- --capture SEER_PRODUCTION --output REPORT.json [--crop x,y,w,h]")
		quit(1)
		return
	var directory: String = args[args.find("--capture") + 1]
	var output: String = args[args.find("--output") + 1]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("frames.json")))
	if not manifest.get("native_pixels", false) or manifest.get("type", "") != "hoarfrost_seer" or manifest.get("frames", []).is_empty():
		push_error("Benchmark requires the Seer's actual native production capture")
		quit(1)
		return
	var crop: Array = manifest.get("crop", [])
	if args.has("--crop-plan"):
		var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--crop-plan") + 1]))
		crop = plan.get("crop", [])
	if args.has("--crop"):
		crop = []
		for value: String in args[args.find("--crop") + 1].split(","): crop.append(int(value))
	if crop.size() != 4:
		push_error("Supply the planned crop, or a cropped production manifest")
		quit(1)
		return
	var index: Dictionary = {}
	if FileAccess.file_exists(directory.path_join(Storage.INDEX_NAME)):
		index = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(Storage.INDEX_NAME)))["files"]
	var rows: Array[Dictionary]
	var selected: String = ""
	var fastest: float = INF
	var temporary: String = output.get_base_dir().path_join("encoding_candidate")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	for codec: String in PROOF_ENCODERS:
		var microseconds: int = 0
		var bytes: int = 0
		var lossless: bool = true
		for row: Dictionary in manifest["frames"]:
			var record: Dictionary = index.get(row["file"], {})
			var image: Image = Storage.load_image(directory.path_join(record.get("stored_file", row["file"])), record.get("encoding", "png"))
			image.convert(Image.FORMAT_RGBA8)
			if record.is_empty(): image = image.get_region(Rect2i(crop[0], crop[1], crop[2], crop[3]))
			var path: String = temporary + "." + codec
			var start: int = Time.get_ticks_usec()
			var error: Error = Storage.write_image(image, path, codec)
			microseconds += Time.get_ticks_usec() - start
			if error != OK:
				push_error("Benchmark write failed: " + error_string(error))
				quit(1)
				return
			bytes += FileAccess.get_file_as_bytes(path).size()
			var decoded: Image = Storage.load_image(path, codec)
			decoded.convert(Image.FORMAT_RGBA8)
			lossless = lossless and decoded.get_size() == image.get_size() and decoded.get_data() == image.get_data()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			await process_frame
		var seconds: float = float(microseconds) / 1000000.0
		rows.append({"encoder": codec, "seconds": seconds, "GB": float(bytes) / 1000000000.0,
			"frames_per_second": float(manifest["frames"].size()) / maxf(seconds, 0.000001), "lossless": lossless, "bytes": bytes})
		if lossless and bytes < SIZE_LIMIT_BYTES and seconds < fastest:
			selected = codec
			fastest = seconds
		print("CAPTURE ENCODER %s: %.6f seconds; %.6f GB; %.3f frames/s; lossless=%s" % [codec, seconds, float(bytes) / 1000000000.0, float(manifest["frames"].size()) / maxf(seconds, 0.000001), lossless])
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"ok": not selected.is_empty(), "capture": directory,
		"frames": manifest["frames"].size(), "crop": crop, "encoders": rows, "selected_codec": selected,
		"timing_scope": "Godot save call, including file close; excludes image load, crop, decode verification and unlink"}))
	print("CAPTURE ENCODER BENCHMARK: " + ("PASS" if not selected.is_empty() else "FAIL") + "; selected=" + selected)
	quit(0 if not selected.is_empty() else 1)
