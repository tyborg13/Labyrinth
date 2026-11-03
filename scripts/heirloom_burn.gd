extends Control

## Seekable, deterministic particles and a CanvasGroup dissolve. The only RNG
## is a local integer hash: proof clocks never consume the run's randomness.
const BurnShader = preload("res://scripts/heirloom_burn.gdshader")
const Palette = preload("res://scripts/ui_palette.gd")
const BURN_SECONDS: float = 0.50
const BAND_PIXELS: float = 5.0
const NOISE_PERIOD: float = 24.0
const NOISE_AMPLITUDE: float = 8.0
const GRID: float = 2.0
const EMBER_COUNT: int = 14
const EMBER_SECONDS: float = 0.60
const EMBER_RISE := Vector2(60.0, 110.0)
const EMBER_DRIFT: float = 14.0
const CHAR_HEX: int = 0x3a1a0cff
const EMBER_BRIGHT_HEX: int = 0xffb35aff
# A small minority of the fourteen sparks uses the specified 2px size.
static var SMALL_EMBER_INDICES := PackedInt32Array([0, 5, 10])
var elapsed: float = 0.0
var group: CanvasGroup
var burn_material: ShaderMaterial
var sparks: Array[Dictionary]
var _embers: Control
var _card: Control
var _top: float

func configure(card: Control) -> void:
	_card = card
	name = "HeirloomBurn_" + str(card.item_id)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = card.size
	position = card.position
	_top = minf(0.0, card.get_node("BoonColumnTag").position.y)
	group = CanvasGroup.new()
	group.name = "BurningCard"
	add_child(group)
	card.reparent(group, false)
	card.position = Vector2.ZERO
	burn_material = ShaderMaterial.new()
	burn_material.shader = BurnShader
	burn_material.set_shader_parameter("card_size", card.size)
	burn_material.set_shader_parameter("burn_top", _top)
	burn_material.set_shader_parameter("noise_period", NOISE_PERIOD)
	burn_material.set_shader_parameter("noise_amplitude", NOISE_AMPLITUDE)
	burn_material.set_shader_parameter("pixel_grid", GRID)
	burn_material.set_shader_parameter("band_pixels", BAND_PIXELS)
	burn_material.set_shader_parameter("gold_bright", Palette.GOLD_BRIGHT)
	burn_material.set_shader_parameter("ember", Palette.EMBER)
	burn_material.set_shader_parameter("char_color", Color.hex(CHAR_HEX))
	group.material = burn_material
	_embers = Control.new()
	_embers.name = "BurnEmbers"
	_embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_embers.z_index = 1
	add_child(_embers)
	_embers.draw.connect(_draw_embers)
	var seed_value: int = int(card.item_id.hash())
	for index: int in range(EMBER_COUNT):
		var birth: float = BURN_SECONDS * (index + 0.5) / EMBER_COUNT
		var x: float = (index + _lattice(index, seed_value)) * size.x / EMBER_COUNT
		sparks.append({"birth": birth, "origin": Vector2(x, line_y(x, birth)),
			"rise": lerpf(EMBER_RISE.x, EMBER_RISE.y, _lattice(index + EMBER_COUNT, seed_value)),
			"drift": lerpf(-EMBER_DRIFT, EMBER_DRIFT, _lattice(index + EMBER_COUNT * 2, seed_value)),
			"pixels": 2 if SMALL_EMBER_INDICES.has(index) else 3,
			"color": Palette.EMBER.lerp(Color.hex(EMBER_BRIGHT_HEX), _lattice(index + EMBER_COUNT * 3, seed_value))})
	seek(0.0)

func seek(seconds: float) -> void:
	elapsed = maxf(0.0, seconds)
	burn_material.set_shader_parameter("card_origin", _card.get_global_rect().position)
	burn_material.set_shader_parameter("progress", progress_at(elapsed))
	group.visible = elapsed < BURN_SECONDS
	_embers.queue_redraw()

static func progress_at(seconds: float) -> float:
	var t: float = clampf(seconds / BURN_SECONDS, 0.0, 1.0)
	return t * t

func line_y(x: float, seconds: float) -> float:
	var base: float = floorf(lerpf(size.y, _top, progress_at(seconds)) / GRID + 0.5) * GRID
	var sample_point := Vector2(floorf(x / GRID) * GRID, base) / NOISE_PERIOD
	return base + floorf((_noise(sample_point) * 2.0 - 1.0) * NOISE_AMPLITUDE / GRID + 0.5) * GRID

static func _lattice(x: int, y: int) -> float:
	var h: int = (x * 374761393 + y * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 65535) / 65535.0

static func _noise(point: Vector2) -> float:
	var cell := Vector2i(floori(point.x), floori(point.y))
	var f: Vector2 = point - Vector2(cell)
	f = f * f * (Vector2.ONE * 3.0 - f * 2.0)
	return lerpf(lerpf(_lattice(cell.x, cell.y), _lattice(cell.x + 1, cell.y), f.x), lerpf(_lattice(cell.x, cell.y + 1), _lattice(cell.x + 1, cell.y + 1), f.x), f.y)

func ember_sample(index: int, seconds: float) -> Dictionary:
	var spark: Dictionary = sparks[index]
	var age: float = seconds - float(spark["birth"])
	if age < 0.0 or age >= EMBER_SECONDS: return {}
	var t: float = age / EMBER_SECONDS
	var point: Vector2 = spark["origin"] + Vector2(float(spark["drift"]), -float(spark["rise"])) * t
	var pixels: float = float(spark["pixels"])
	return {"rect": Rect2((point - Vector2.ONE * pixels * 0.5).floor(), Vector2.ONE * pixels), "color": Color(spark["color"], 1.0 - t)}

func _draw_embers() -> void:
	for index: int in range(sparks.size()):
		var sample: Dictionary = ember_sample(index, elapsed)
		if not sample.is_empty(): _embers.draw_rect(sample["rect"], sample["color"])
