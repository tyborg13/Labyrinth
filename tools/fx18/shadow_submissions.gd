extends RefCounted
## Record the calls the procedural dragon renderer sends to the shadow painter.
static var calls: Array[Array]

static func stream(_canvas: CanvasItem, source: Vector2, target: Vector2, size: float, travel: float, alpha: float) -> void:
	calls.append(["stream", source, target, size, travel, alpha])

static func impact(_canvas: CanvasItem, target: Vector2, size: float, phase: float, alpha: float, front: bool, seed: int) -> void:
	calls.append(["impact", target, size, phase, alpha, front, seed])

static func release(_canvas: CanvasItem, source: Vector2, size: float, amount: float) -> void:
	calls.append(["release", source, size, amount])
