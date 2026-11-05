extends Control
## Reserve the authored one-line slot so a wrapped name cannot lower its price.

var _label: Label
var _art: Control
var _art_baseline_y: float = 0.0
var _layout_queued: bool = false

func configure(label: Label, art: Control) -> void:
	name = "WareNameSlot"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = label
	_art = art
	custom_minimum_size = label.custom_minimum_size
	add_child(label)
	label.minimum_size_changed.connect(_queue_layout)
	resized.connect(_queue_layout)

func _ready() -> void:
	(get_parent() as Container).sort_children.connect(_stack_sorted)
	_queue_layout()

func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree(): return
	_layout_queued = true
	_layout.call_deferred()

func _stack_sorted() -> void:
	_art_baseline_y = _art.position.y
	_layout()

func _layout() -> void:
	_layout_queued = false
	_label.size.x = size.x
	_label.size.y = maxf(size.y, _label.get_combined_minimum_size().y)
	var extra_height: float = maxf(0.0, _label.size.y - size.y)
	_label.position = Vector2(0.0, -extra_height)
	_art.position.y = _art_baseline_y - extra_height
