extends SceneTree
## Measure synchronous runtime loads of the imported textures on the main thread.

const SAMPLES: int = 11
const PATHS := [
	"res://assets/art/ui/campfire_choice_embrace_v2.png",
	"res://assets/art/ui/campfire_choice_linger_v2.png",
	"res://assets/art/ui/campfire_choice_purge_v2.png",
	"res://assets/art/ui/campfire_choice_strength_v2.png",
	"res://assets/art/ui/graftwright/ritual_clasp.png",
	"res://assets/art/icons/map/ember_hoarder.png",
]

func _initialize() -> void:
	# Prime the filesystem and decoder, then bypass Godot's resource cache.
	for path: String in PATHS:
		if ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) == null:
			push_error("Missing imported texture: " + path)
			quit(1)
			return
	var measurements: Dictionary = {}
	var sizes: Dictionary = {}
	for path: String in PATHS:
		var samples: Array[int]
		measurements[path] = samples
	for sample: int in range(SAMPLES):
		for path: String in PATHS:
			var started: int = Time.get_ticks_usec()
			var texture: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
			var elapsed: int = Time.get_ticks_usec() - started
			if texture == null:
				quit(1)
				return
			measurements[path].append(elapsed)
			sizes[path] = texture.get_size()
	for path: String in PATHS:
		var samples: Array[int] = measurements[path]
		samples.sort()
		var size: Vector2 = sizes[path]
		# Lossless textures with no mipmaps, estimated at four bytes per pixel.
		print("PERF153 %s %dx%d median_us=%d rgba8_bytes=%d samples_us=%s" % [
			path.get_file(), int(size.x), int(size.y), samples[SAMPLES >> 1],
			int(size.x * size.y) * 4, str(samples),
		])
	quit()
