extends RefCounted

## Expected painter order. This file never calls a production tile-order or
## retained-layer helper. Each input contains exactly one isolated primitive.
const KIND_PRIORITY := {"floor":0,"wall":1,"prop":2,"actor":3}

static func before(a: Dictionary, b: Dictionary) -> bool:
	if a.get("plane",1)!=b.get("plane",1): return a.get("plane",1)<b.get("plane",1)
	if a["ground_y"]!=b["ground_y"]: return a["ground_y"]<b["ground_y"]
	if a["ground_x"]!=b["ground_x"]: return a["ground_x"]<b["ground_x"]
	var ar: int = a.get("tie_rank",KIND_PRIORITY[a["kind"]])
	var br: int = b.get("tie_rank",KIND_PRIORITY[b["kind"]])
	if ar!=br: return ar<br
	return str(a["id"])<str(b["id"])

static func ordered(layers: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	result.assign(layers)
	result.sort_custom(before)
	return result

static func front(occluder: Dictionary, actor: Dictionary) -> bool:
	return actor["ground_y"]<occluder["ground_y"] or (actor["ground_y"]==occluder["ground_y"] and before(actor,occluder))

static func channel_to_linear(value: float) -> float:
	return value/12.92 if value<=0.04045 else pow((value+0.055)/1.055,2.4)

static func channel_to_encoded(value: float) -> float:
	return 12.92*value if value<=0.0031308 else 1.055*pow(value,1.0/2.4)-0.055

static func over(src: Color, dst: Color, mode: String) -> Color:
	var linear: bool = mode.begins_with("linear")
	var premultiplied: bool = mode.ends_with("premultiplied")
	var result := Color(0,0,0,src.a+dst.a*(1-src.a))
	for channel: int in range(3):
		var s: float = channel_to_linear(src[channel]) if linear else src[channel]
		var d: float = channel_to_linear(dst[channel]) if linear else dst[channel]
		var value: float = s*(1.0 if premultiplied else src.a)+d*(1-src.a)
		result[channel] = channel_to_encoded(value) if linear else value
	return result

static func compose(size: Vector2i, background: Color, layers: Array[Dictionary], mode: String = "encoded_premultiplied", roi: Rect2i = Rect2i()) -> Image:
	return blend_in_order(size,background,ordered(layers),mode,roi)

static func blend_in_order(size: Vector2i, background: Color, layers: Array[Dictionary], mode: String, roi: Rect2i = Rect2i()) -> Image:
	var result := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	# Godot Color.TRANSPARENT is transparent WHITE. Native ID readback and
	# isolated primitive encoding use zero RGBA for unowned pixels, including
	# the death tail. Canonicalize at construction, preserving strict equality.
	result.fill(Color(0,0,0,0) if background.a==0.0 else background)
	var region: Rect2i = Rect2i(Vector2i.ZERO,size) if not roi.has_area() else roi.intersection(Rect2i(Vector2i.ZERO,size))
	for layer: Dictionary in layers:
		var image: Image = layer["image"]
		var offset: Vector2i = layer.get("offset",Vector2i.ZERO)
		var bounds: Rect2i = Rect2i(offset,image.get_size()).intersection(region)
		if not bounds.has_area(): continue
		if mode.begins_with("encoded"):
			var source: Image = image.get_region(Rect2i(bounds.position-offset,bounds.size))
			source.convert(Image.FORMAT_RGBA8)
			if mode=="encoded_premultiplied":
				var data: PackedByteArray = source.get_data()
				for at: int in range(0,data.size(),4):
					var alpha: int = data[at+3]
					if alpha==0 or alpha==255: continue
					for channel: int in range(3): data[at+channel] = clampi(roundi(float(data[at+channel])*255.0/alpha),0,255)
				source.set_data(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8,data)
			result.blend_rect(source,Rect2i(Vector2i.ZERO,bounds.size),bounds.position)
			continue
		for y: int in range(bounds.position.y,bounds.end.y):
			for x: int in range(bounds.position.x,bounds.end.x):
				var src: Color = image.get_pixel(x-offset.x,y-offset.y)
				if src.a<=0: continue
				result.set_pixel(x,y,over(src,result.get_pixel(x,y),mode))
	return result
