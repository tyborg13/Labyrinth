extends Node2D

## Persistent Fire uses the live attack's procedural clouds and broad hot folds.
## Retain immutable bed commands and particle topology; hand-shaped tongue geometry
## advances on the same supplied clock. No raster illustrations or idle TIME.
const Art = preload("res://scripts/board_surface_presentation.gd")
const Fx = preload("res://scripts/elemental_spell_fx.gd")
const Particle = preload("res://scripts/board_surface_particle.gd")

class Bed extends Node2D:
	var width: float
	var seed: int
	func _draw() -> void:
		Art._draw_fire_bed(self, Vector2.ZERO, width, seed)

class Tongue extends Node2D:
	var width: float
	var index: int
	var origin: Vector2
	var height_base: float
	var phase: float = INF
	var _drawn_phase: float = INF
	func configure(next_phase: float) -> void:
		if next_phase == phase: return
		phase = next_phase
		queue_redraw()
	func _draw() -> void:
		# Keep the same tile-local arithmetic as the immediate renderer. A
		# second node translation changes MSAA coverage at tiny folded tips.
		Art._draw_fire_tongue(self, origin, width, height_base, index, phase)
		_drawn_phase = phase

var _width: float = -1.0
var _seed: int = -1
var _phase: float = INF
var _reduced: bool = false
var _base: Particle
var _pockets: Array[Dictionary]

func configure(center: Vector2, width: float, seed: int, phase: float, reduced: bool) -> void:
	position = center
	if width != _width or seed != _seed:
		_width = width
		_seed = seed
		_build()
		_phase = INF
	if phase == _phase and reduced == _reduced: return
	_phase = phase
	_reduced = reduced
	_base.set_tint(Color(1.0, 0.25, 0.025, 0.30 + sin(phase * 2.7) * 0.045))
	for pocket: Dictionary in _pockets:
		var i: int = int(pocket["index"])
		var at: Vector2 = pocket["at"]
		var pose: Dictionary = Art.fire_pose(width, phase, i, reduced)
		var lift: float = float(pose["lift"])
		var size: Vector2 = pose["size"]
		_pose(pocket["puff"], at - Vector2(0, lift), size, sin(phase * 0.9 + i) * 0.22, pose["outer"])
		_pose(pocket["core"], at - Vector2(width * 0.009, lift * 0.72), size * Vector2(0.59, 0.69), -sin(phase * 1.2 + i) * 0.18, pose["inner"])
		(pocket["tongue"] as Tongue).configure(phase)
		if pocket.has("ember"):
			var age: float = 0.5 if reduced else fposmod(phase * 0.42 + i * 0.23, 1.0)
			var ember: Vector2 = at + Vector2(sin(phase + i) * width * 0.037, -width * (0.14 + age * 0.16))
			_pose(pocket["ember"], ember, Vector2(width * 0.025, width * 0.018), 0.0, Color(1.0, 0.73, 0.22, sin(age * PI) * 0.78))

func _sprite(texture: Texture2D) -> Particle:
	var particle := Particle.new()
	particle.texture = texture
	add_child(particle)
	return particle

func _pose(particle: Particle, at: Vector2, size: Vector2, angle: float, tint: Color) -> void:
	particle.configure(at, size, angle, tint)

func _build() -> void:
	for item: Node in get_children():
		remove_child(item)
		item.queue_free()
	_pockets.clear()
	Fx.prepare()
	var bed := Bed.new()
	bed.width = _width
	bed.seed = _seed
	add_child(bed)
	_base = _sprite(Fx._light)
	_pose(_base, Vector2.ZERO, Vector2(_width * 0.95, _width * 0.39), 0.0, Color.WHITE)
	for source: Dictionary in Art.fire_pockets(_width, _seed):
		var pocket: Dictionary = source.duplicate()
		var i: int = int(pocket["index"])
		pocket["puff"] = _sprite(Fx._clouds[posmod(_seed + i, Fx._clouds.size())])
		pocket["core"] = _sprite(Fx._clouds[posmod(_seed + i + 1, Fx._clouds.size())])
		var tongue := Tongue.new()
		tongue.origin = pocket["at"]
		tongue.width = _width
		tongue.index = i
		tongue.height_base = float(pocket["height"])
		add_child(tongue)
		pocket["tongue"] = tongue
		if i % 2 == 0: pocket["ember"] = _sprite(Fx._light)
		_pockets.append(pocket)
