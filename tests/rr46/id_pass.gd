extends RefCounted

## Proof-only ownership encoding. Zero is background; every nonzero alpha
## sample belongs to exactly one sprite, independent of paint/room lighting.
const ACTOR_CODE: int = 1
const COLOR_MULTIPLIER: int = 7919
const RETAIN_EVERY: int = 10
const MAX_SECONDS: float = 300.0
const MAX_BYTES: int = 250000000

static func color(code: int) -> Color:
	code *= COLOR_MULTIPLIER
	return Color8(code & 255,(code >> 8) & 255,(code >> 16) & 255,255)

static func encode(source: Image, code: int) -> Image:
	code *= COLOR_MULTIPLIER
	var image: Image = source.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = image.get_data()
	for at: int in range(0,data.size(),4):
		if data[at+3]==0:
			data[at]=0; data[at+1]=0; data[at+2]=0
			continue
		data[at]=code & 255; data[at+1]=(code >> 8) & 255; data[at+2]=(code >> 16) & 255; data[at+3]=255
	image.set_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,data)
	return image

static func indices(count: int, death: bool) -> Array[int]:
	var result: Array[int]
	for frame: int in range(count):
		if death or frame%2==0 or absf(float(frame+1)-float(count)*0.5)<=1.0 or frame==count-1: result.append(frame)
	return result
