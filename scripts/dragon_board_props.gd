extends RefCounted

const Stone = preload("res://scripts/stone_outcrop_art.gd")

static func draw_spire(c: CanvasItem, center: Vector2, width: float, seed: int, rise: float, opacity: float) -> void:
	# The same mineral grain, fracture planes and lighting as Crag Outcrops,
	# with one dominant narrow spine and two broken roots instead of a cluster.
	Stone._prepare_texture()
	c.draw_set_transform(center)
	Stone._draw_stone(c,Vector2(-.16,.04)*width,width*.16,width*.37,seed+31,rise,opacity)
	Stone._draw_stone(c,Vector2(.04,-.025)*width,width*.22,width*.86,seed+7,rise,opacity)
	Stone._draw_stone(c,Vector2(.19,.07)*width,width*.105,width*.24,seed+19,rise,opacity)
	for i: int in range(6):
		var angle: float = float(i)*2.39996
		var point := Vector2(cos(angle)*.29,sin(angle)*.12+.05)*width
		Stone._draw_stone(c,point,width*.035,width*.045,seed+i*67,1.0,opacity)
	c.draw_set_transform(Vector2.ZERO)
