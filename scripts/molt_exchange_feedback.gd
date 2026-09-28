extends RefCounted
## Acknowledges a durable purchase. Never owns currency or waits for analytics.
const Typography = preload("res://scripts/ui_typography.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Sfx = preload("res://scripts/run_sfx_library.gd")
const DURATION: float = .95
var active: bool = false
var generation: int = 0
var _receipt: Control

class EmberGlow extends Control:
	const Spell = preload("res://scripts/elemental_spell_fx.gd")
	var phase: float = 0.0
	var reduced: bool = false
	func _draw() -> void:
		Spell.prepare()
		Spell._glow(self,size*.5,Vector2(280,65),Color(1.0,.43,.10,.24))
		if reduced: return
		for i: int in range(9):
			var t: float = fmod(float(i)*.137+phase*.7,1.0)
			var point := Vector2(size.x*.5+sin(float(i)*2.4)*110.0,size.y*.74-t*57.0)
			Spell._glow(self,point,Vector2(5,9),Color(1.0,.68,.24,sin(t*PI)*.8))

func reset() -> void:
	generation += 1
	active = false
	if is_instance_valid(_receipt): _receipt.queue_free()
	_receipt = null

func reserve() -> void:
	active = true

func play(host: Node, overlay: Control, dialog: Control, amount: int, reduced: bool, sound: Callable) -> bool:
	var token: int = generation
	var glow := EmberGlow.new()
	glow.name = "MoltShardExchangeFeedback"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.focus_mode = Control.FOCUS_NONE
	glow.size = Vector2(360,84)
	glow.reduced = reduced
	glow.set_meta("amount",amount)
	glow.set_meta("reduced_motion",reduced)
	_receipt = glow
	overlay.add_child(glow)
	# The receipt sits above the existing service card, never over its choices.
	glow.position = Vector2((overlay.size.x-glow.size.x)*.5,maxf(12.0,dialog.global_position.y-overlay.global_position.y-glow.size.y-8.0))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size = glow.size
	glow.add_child(center)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",10)
	center.add_child(row)
	var icon := TextureRect.new()
	icon.texture = Icons.icon_texture("ember")
	icon.custom_minimum_size = Vector2(32,32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name = "EmberReceipt"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "+%d Embers" % amount
	Typography.set_label_size(label,Typography.SIZE_SECTION)
	label.add_theme_color_override("font_color",Color("ffd38b"))
	label.add_theme_color_override("font_outline_color",Color("2c1f16"))
	label.add_theme_constant_override("outline_size",2)
	row.add_child(label)
	sound.call(Sfx.entry(Sfx.HEARTH_STRENGTH_ID))
	var started: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec()-started)/1000.0 < DURATION:
		if token != generation or not is_instance_valid(glow): return false
		var p: float = float(Time.get_ticks_msec()-started)/1000.0/DURATION
		glow.phase = p
		glow.modulate.a = minf(1.0,p/.10)*(1.0-smoothstep(.76,1.0,p))
		glow.queue_redraw()
		await host.get_tree().process_frame
	if token != generation: return false
	reset()
	return true
