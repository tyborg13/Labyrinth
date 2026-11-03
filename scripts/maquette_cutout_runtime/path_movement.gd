extends RefCounted

## One distance clock for the entire path. Quadratic position ramps cover the
## first/last quarter tile; their derivatives meet the constant cruise speed.
## Distance is in board pixels, so corners (including unequal projected steps)
## cannot restart easing or change speed. The caller retains its authored tile
## phase/facing/sound clock; only root forward travel is replaced.
const RAMP_TILES: float = 0.25
var points: Array[Vector2]
var distances: Array[float]
var total_distance: float = 0.0
var ramp_in: float = 0.0
var ramp_out: float = 0.0
var speed: float = 0.0 # Pixels per normalized whole-path time.

func configure(path_points: Array[Vector2]) -> void:
	points.assign(path_points)
	distances.clear()
	total_distance = 0.0
	for index: int in range(points.size()):
		if index > 0: total_distance += points[index - 1].distance_to(points[index])
		distances.append(total_distance)
	ramp_in = points[0].distance_to(points[1]) * RAMP_TILES
	ramp_out = points[-2].distance_to(points[-1]) * RAMP_TILES
	speed = total_distance + ramp_in + ramp_out

func distance_at(progress: float) -> float:
	var time: float = clampf(progress, 0.0, 1.0)
	var rise: float = 2.0 * ramp_in / speed
	var fall: float = 2.0 * ramp_out / speed
	if time < rise: return speed * time * time / (2.0 * rise)
	if time > 1.0 - fall: return total_distance - speed * (1.0 - time) * (1.0 - time) / (2.0 * fall)
	return ramp_in + speed * (time - rise)

func sample(progress: float) -> Dictionary:
	var travel: float = distance_at(progress)
	var index: int = 0
	while index + 2 < points.size() and travel >= distances[index + 1]: index += 1
	var forward: float = travel - distances[index]
	return {"index": index,
		"progress": forward / (distances[index + 1] - distances[index]),
		"position": points[index] + (points[index + 1] - points[index]).normalized() * forward}

func override_from(origin: Vector2, sample: Dictionary, tiles: Array[Vector2i]) -> Dictionary:
	# Texture/pose origins keep the authored tile clock. At a corner the root
	# can be on the adjacent segment; its actual path axis must stay independent
	# of the unchanged facing. This also carries the ground segment to depth.
	var offset: Vector2 = (sample["position"] as Vector2) - origin
	var index: int = int(sample["index"])
	return {"forward_px": offset.length(), "axis": offset.normalized(),
		"path_from": tiles[index], "path_to": tiles[index + 1]}
