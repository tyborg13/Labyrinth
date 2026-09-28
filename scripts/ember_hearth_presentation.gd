extends RefCounted
## Presentation only. RunScene commits outcomes before playing their feedback.
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")

var generation: int = 0
var _room_key: String = ""
var _reveal_revision: int = 0
var _last_focus_msec: int = -1000
var _reveals: Array[Tween]

func reset() -> void:
	generation += 1
	_room_key = ""
	_cancel_reveal()

func _cancel_reveal() -> void:
	_reveal_revision += 1
	for tween: Tween in _reveals:
		if tween != null and tween.is_valid():
			tween.kill()
	_reveals.clear()

func present(host: Node, bar: HBoxContainer, room_key: String, reduced: bool, sound: Callable) -> void:
	_cancel_reveal()
	var first_arrival: bool = room_key != _room_key
	_room_key = room_key
	var revision: int = _reveal_revision
	var choices: Array[Control]
	for child: Node in bar.get_children():
		var panel: Control = child as Control
		if panel == null: continue
		panel.set_meta("choice_revealed", not first_arrival)
		panel.modulate.a = 0.0 if first_arrival else 1.0
		if bool(panel.get_meta("choice_enabled", false)):
			choices.append(panel)
	for index: int in range(choices.size()):
		var panel: Control = choices[index]
		panel.focus_neighbor_left = panel.get_path_to(choices[posmod(index - 1, choices.size())])
		panel.focus_neighbor_right = panel.get_path_to(choices[(index + 1) % choices.size()])
		panel.focus_previous = panel.focus_neighbor_left
		panel.focus_next = panel.focus_neighbor_right
	if not first_arrival: return
	# Containers finish layout before transforms are authored. Hover never moves a hit target.
	await host.get_tree().process_frame
	if revision != _reveal_revision or not is_instance_valid(bar): return
	sound.call(RunSfx.entry(RunSfx.HEARTH_ARRIVAL_ID))
	for index: int in range(bar.get_child_count()):
		var panel: Control = bar.get_child(index) as Control
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2.ONE if reduced else Vector2(0.96, 0.96)
		var delay: float = 0.0 if reduced else 0.08 + index * 0.10
		var duration: float = 0.12 if reduced else 0.30
		var tween: Tween = panel.create_tween().set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, duration).set_delay(delay)
		if not reduced:
			tween.tween_property(panel, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(func() -> void: panel.set_meta("choice_revealed", true))
		_reveals.append(tween)

func emphasize(_host: Node, panel: Control, emphasized: bool, sound: Callable) -> void:
	var was_emphasized: bool = bool(panel.get_meta("hearth_emphasized", false))
	panel.set_meta("hearth_emphasized", emphasized)
	if emphasized and not was_emphasized and bool(panel.get_meta("choice_revealed", false)):
		var now: int = Time.get_ticks_msec()
		if now - _last_focus_msec >= 80:
			_last_focus_msec = now
			sound.call(RunSfx.entry(RunSfx.HEARTH_FOCUS_ID))
	var art: Control = panel.find_child("CampfireChoiceBackground", true, false) as Control
	if art != null:
		var previous: Tween = art.get_meta("hearth_tween") as Tween if art.has_meta("hearth_tween") else null
		if previous != null and previous.is_valid(): previous.kill()
		var tween: Tween = art.create_tween()
		art.set_meta("hearth_tween", tween)
		tween.tween_property(art, "modulate:a", 0.86 if emphasized else 0.68, 0.12)

func select(host: Node, bar: HBoxContainer, selected: Control, reduced: bool, sound: Callable) -> void:
	_cancel_reveal()
	sound.call(RunSfx.entry(RunSfx.HEARTH_SELECT_ID))
	for child: Node in bar.get_children():
		var panel: Control = child as Control
		if panel == null: continue
		panel.set_meta("choice_selected", panel == selected)
		var tween: Tween = panel.create_tween().set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0 if panel == selected else 0.28, 0.10 if reduced else 0.20)
		if not reduced and panel == selected:
			tween.tween_property(panel, "scale", Vector2(1.025, 1.025), 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.chain().tween_property(panel, "scale", Vector2.ONE, 0.14)
	await host.get_tree().create_timer(0.12 if reduced else 0.26).timeout

func result(host: Node, display: Dictionary, chrome: Dictionary, text: String, heal: bool, reduced: bool, render: Callable) -> void:
	var token: int = generation
	var tile: Vector2i = (display.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var color := Color("9ee27e") if heal else Color("ffd38b")
	var base: Dictionary = chrome.duplicate(true)
	base["focus_actor_keys"] = ["player"]
	base["focus_actor_color"] = color
	if heal: base["effect"] = {"kind": "heal", "tile": tile}
	var texts: Array = [{"tile": tile, "text": text, "color": color, "offset": -8.0}]
	var duration: float = 0.65 if reduced else 0.90
	var started: int = Time.get_ticks_usec()
	while token == generation:
		var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
		var progress: float = clampf(elapsed / duration, 0.0, 1.0)
		var frame: Dictionary = base.duplicate(true)
		# Hold a legible static heal pose under reduced motion, not the invisible last frame.
		frame["effect_progress"] = 0.48 if reduced else progress
		frame["floating_texts"] = FloatingText.animate_entries(texts, progress * FloatingText.ANIMATION_DURATION_SECONDS, reduced)
		render.call(display, frame)
		if elapsed >= duration: break
		await host.get_tree().process_frame

func dismiss(host: Node, bar: HBoxContainer, reduced: bool) -> void:
	if not is_instance_valid(bar): return
	for child: Node in bar.get_children():
		var panel: Control = child as Control
		if panel == null: continue
		var tween: Tween = panel.create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.10 if reduced else 0.18)
	await host.get_tree().create_timer(0.10 if reduced else 0.18).timeout
