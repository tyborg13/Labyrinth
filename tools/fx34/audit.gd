extends RefCounted

# Hooks in the staged proof projects record the production submit sites.
static var active: bool
static var headless: bool
static var manual: bool
static var primitives: Dictionary
static var painters: Dictionary
static var items: Dictionary
static var beats: Array[Dictionary]

static func reset() -> void:
	primitives.clear()
	painters.clear()
	items.clear()
	beats.clear()
	active = true

static func painter(site: String) -> void:
	if active and (not headless or manual): painters[site] = int(painters.get(site, 0)) + 1

static func primitive(site: String) -> void:
	if active and (not headless or manual): primitives[site] = int(primitives.get(site, 0)) + 1

static func beat(index: int, frames: int, seconds: float, contact: float) -> void:
	if active:
		beats.append({"index": index, "frames": frames, "frame_usec": roundi(seconds * 1000000.0), "contact": contact})

static func item(tile: Vector2i, progress: float, tint: Color, rise: float, height: float) -> void:
	if not active or (headless and not manual): return
	var key: String = "%s/%d" % [str(tile), roundi(progress * 100)]
	items[key] = {"tile": "%d:%d" % [tile.x, tile.y], "progress": progress,
		"alpha": tint.a, "tint": [tint.r, tint.g, tint.b], "rise_in_tiles": snappedf(rise / height, 0.000001)}
