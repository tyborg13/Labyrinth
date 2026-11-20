extends SceneTree
## Measure synchronous runtime loads of the imported textures on the main thread.

const SAMPLES: int = 11
const PATHS := [
	"res://assets/art/icons/map/boss_iskaldra.png",
	"res://assets/art/icons/map/boss_noctyrax.png",
	"res://assets/art/icons/map/boss_tharokh.png",
	"res://assets/art/icons/map/boss_vaeloryx.png",
	"res://assets/art/icons/map/boss_vyraketh.png",
	"res://assets/art/icons/map/boss_zekarion.png",
	"res://assets/art/icons/map/campfire.png",
	"res://assets/art/icons/map/event.png",
	"res://assets/art/icons/map/fight.png",
	"res://assets/art/icons/map/graftwright.png",
	"res://assets/art/icons/map/lantern.png",
	"res://assets/art/icons/map/last_light.png",
	"res://assets/art/icons/map/relic.png",
	"res://assets/art/icons/map/scavenger.png",
	"res://assets/art/icons/map/scout.png",
	"res://assets/art/icons/map/umbral_snare.png",
	"res://assets/art/icons/map/warband.png",
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
		print("PERF155 %s %dx%d median_us=%d rgba8_bytes=%d samples_us=%s" % [
			path.get_file(), int(size.x), int(size.y), samples[SAMPLES >> 1],
			int(size.x * size.y) * 4, str(samples),
		])
	quit()
