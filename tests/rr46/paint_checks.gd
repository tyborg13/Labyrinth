extends RefCounted

const LOGICAL_SIZE := Vector2i(1920,1080)
const COLOR_TOLERANCE: int = 1
const CATEGORIES := ["floor_front","floor_behind","wall_front","wall_behind","prop_front","prop_behind"]

static func capture_rect(local: Rect2, canvas: Transform2D, logical: Vector2, pixels: Vector2i) -> Rect2i:
	# CanvasItem local -> viewport logical -> actual capture backing pixels.
	# SubViewport normally makes the last scale 1; retain it for Retina tests.
	var scale := Vector2(pixels)/logical
	var corners := PackedVector2Array([local.position,Vector2(local.end.x,local.position.y),local.end,Vector2(local.position.x,local.end.y)])
	var bounds := Rect2((canvas*corners[0])*scale,Vector2.ZERO)
	for corner: Vector2 in corners: bounds = bounds.expand((canvas*corner)*scale)
	return Rect2i(Vector2i(floori(bounds.position.x),floori(bounds.position.y)),Vector2i(ceili(bounds.end.x),ceili(bounds.end.y))-Vector2i(floori(bounds.position.x),floori(bounds.position.y)))

static func fully_dissolved(timing: Dictionary, phase: float) -> bool:
	# Source-time end, independent of playback scale and rendered pixels.
	if timing.is_empty(): return false
	var end: float = float(timing["clip_seconds"])+float(timing["dissolve_seconds"])
	return end>0.0 and phase*end>=end

static func inspect(actual: Image, expected: Image, actor: Image, masks: Dictionary, rect: Rect2i, death_timing: Dictionary = {}, phase: float = 0.0, tolerance: int = COLOR_TOLERANCE) -> Dictionary:
	var terminal: bool = fully_dissolved(death_timing,phase)
	var result: Dictionary = {"errors":[],"actor_pixels":0,"painted_errors":0,"occluders":{}}
	if actual.get_size()!=expected.get_size() or actual.get_size()!=actor.get_size():
		result["errors"].append("capture/reference/mask dimensions differ")
		return result
	rect = rect.intersection(Rect2i(Vector2i.ZERO,actual.get_size()))
	if not rect.has_area():
		result["errors"].append("empty transformed actor bounds")
		return result
	var own: Image = actor.get_region(rect)
	var bits := BitMap.new()
	bits.create_from_image_alpha(own,0.0)
	result["actor_pixels"] = bits.get_true_bit_count()
	if result["actor_pixels"]==0 and not terminal: result["errors"].append("empty actor crop before authored dissolve completion")
	if terminal and result["actor_pixels"]>0: result["errors"].append("actor paint remains after authored dissolve completion")
	var a: Image = actual.get_region(rect)
	var e: Image = expected.get_region(rect)
	a.convert(Image.FORMAT_RGBA8)
	e.convert(Image.FORMAT_RGBA8)
	own.convert(Image.FORMAT_RGBA8)
	var actual_bytes: PackedByteArray = a.get_data()
	var expected_bytes: PackedByteArray = e.get_data()
	var own_bytes: PackedByteArray = own.get_data()
	var occluder_bytes: Dictionary = {}
	for category: String in CATEGORIES:
		if not masks.has(category): continue
		var mask: Image = masks[category].get_region(rect)
		mask.convert(Image.FORMAT_RGBA8)
		occluder_bytes[category] = mask.get_data()
		var intersection := Image.create(rect.size.x,rect.size.y,false,Image.FORMAT_RGBA8)
		intersection.blit_rect_mask(mask,own,Rect2i(Vector2i.ZERO,rect.size),Vector2i.ZERO)
		bits.create_from_image_alpha(intersection,0.0)
		result["occluders"][category] = {"overlap_pixels":bits.get_true_bit_count(),"errors":0}
	if actual_bytes!=expected_bytes:
		for pixel: int in range(rect.size.x*rect.size.y):
			var at: int = pixel*4
			if own_bytes[at+3]==0 and not terminal: continue
			var mismatch: bool = false
			for channel: int in range(4):
				if absi(int(actual_bytes[at+channel])-int(expected_bytes[at+channel]))>tolerance: mismatch = true
			if not mismatch: continue
			result["painted_errors"] += 1
			for category: String in occluder_bytes:
				if occluder_bytes[category][at+3]>0: result["occluders"][category]["errors"] += 1
	if result["painted_errors"]>0: result["errors"].append("painted actor/occluder order differs from independent board-depth reference")
	return result
