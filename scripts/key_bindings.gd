extends RefCounted

## Binding values are Godot physical keycodes. Keep the original letter defaults
## on the active layout, then match an explicitly saved key by position only.
const SETTING := "key_bindings"
const PASS := "pass"
const HURRY := "hurry"
const EMPOWER := "empower"
const UNDO_WALK := "undo_walk"
const ENEMY_INTENTS := "enemy_intents"
const MAP := "map"

const DEFAULT_KEYS := {
	PASS: KEY_P,
	HURRY: KEY_SPACE,
	EMPOWER: KEY_E,
	UNDO_WALK: KEY_Z,
	ENEMY_INTENTS: KEY_I,
	MAP: KEY_M,
}
const RESERVED_KEYS := [
	KEY_ESCAPE, KEY_BACKSPACE, KEY_DELETE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB,
	KEY_BACKTAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK,
]

static var _defaults: Dictionary = {}
static var _active: Dictionary = {}

static func defaults() -> Dictionary:
	if _defaults.is_empty():
		_defaults = _layout_defaults(DisplayServer)
	return _defaults.duplicate()

static func _layout_defaults(display: Object) -> Dictionary:
	var result := DEFAULT_KEYS.duplicate()
	if display.get_name() == "headless": return result
	var positions: Dictionary = {}
	for code: int in range(KEY_SPACE, KEY_ASCIITILDE + 1):
		if not can_bind(code): continue
		var logical: Key = display.keyboard_get_keycode_from_physical(code as Key)
		if not positions.has(logical): positions[logical] = code
	for action: String in DEFAULT_KEYS:
		var logical: Key = DEFAULT_KEYS[action]
		result[action] = positions.get(logical, logical)
	return result

static func can_bind(code: int) -> bool:
	if code in RESERVED_KEYS or (code >= KEY_1 and code <= KEY_9) or (code >= KEY_KP_1 and code <= KEY_KP_9):
		return false
	# Exclude modifier masks, non-keys and Unicode values outside Godot's
	# physical key enum before asking OS to format the code.
	if not ((code >= KEY_SPACE and code <= KEY_ASCIITILDE) or code in [KEY_YEN, KEY_SECTION]
		or (code >= KEY_ESCAPE and code <= KEY_JIS_KANA) or (code >= KEY_KP_MULTIPLY and code <= KEY_KP_9)):
		return false
	return OS.find_keycode_from_string(OS.get_keycode_string(code as Key)) == code

static func normalize(value: Variant) -> Dictionary:
	var baseline: Dictionary = defaults()
	var bindings: Dictionary = baseline.duplicate()
	if not value is Dictionary: return bindings
	for action: String in bindings:
		var raw: Variant = value.get(action)
		if not (raw is int or raw is float): continue
		var number: float = float(raw)
		if not is_finite(number) or number < 0.0 or number >= KEY_UNKNOWN or number != floorf(number): continue
		var code: int = int(number)
		if code == KEY_NONE or can_bind(code): bindings[action] = code
	# Hand-edited files can contain duplicates. Keep the defaults for any
	# conflicting entries, including conflicts revealed by a fallback.
	var changed: bool = true
	while changed:
		changed = false
		for action: String in bindings:
			var code: int = bindings[action]
			if code != KEY_NONE and code != baseline[action] and bindings.values().count(code) > 1:
				bindings[action] = baseline[action]
				changed = true
	return bindings

static func apply(bindings: Dictionary) -> void:
	_active = bindings

static func physical_key(action: String) -> Key:
	if _defaults.is_empty(): defaults()
	return int(_active.get(action, _defaults.get(action, KEY_NONE))) as Key

static func event_physical_key(event: InputEventKey) -> Key:
	# Native key events supply both codes. Keycode-only synthetic events use
	# the matching position on a layout when the display server exposes it.
	if event.physical_keycode != KEY_NONE: return event.physical_keycode
	if DisplayServer.get_name() != "headless" and event.keycode != KEY_NONE:
		for code: int in range(KEY_SPACE, KEY_ASCIITILDE + 1):
			if DisplayServer.keyboard_get_keycode_from_physical(code as Key) == event.keycode: return code as Key
	return event.keycode

static func matches(action: String, event: InputEvent, allow_modifiers: bool = false) -> bool:
	var key := event as InputEventKey
	var code: Key = physical_key(action)
	return (
		key != null and not key.echo and code != KEY_NONE and event_physical_key(key) == code
		and (allow_modifiers or not (key.alt_pressed or key.ctrl_pressed or key.meta_pressed or key.shift_pressed))
	)

static func pressed(action: String, event: InputEvent) -> bool:
	return event.is_pressed() and matches(action, event)

static func label(action: String, display: Object = DisplayServer) -> String:
	var code: Key = physical_key(action)
	if code == KEY_NONE: return ""
	var localized: Key = code if display.get_name() == "headless" else display.keyboard_get_label_from_physical(code)
	return OS.get_keycode_string(code if localized == KEY_NONE or localized == KEY_UNKNOWN else localized)

static func with_mark(body: String, action: String) -> String:
	var key: String = label(action)
	return body if key.is_empty() else "%s [%s]" % [body, key]

static func sentence(action: String, template: String, unbound: String) -> String:
	var key: String = label(action)
	return unbound if key.is_empty() else template % key

static func swap_binding(bindings: Dictionary, action: String, physical: Key) -> String:
	var previous: int = bindings[action]
	if physical == previous: return ""
	var conflict: String = ""
	if physical != KEY_NONE:
		for other: String in bindings:
			if other != action and bindings[other] == physical:
				conflict = other
				bindings[other] = previous
				break
	bindings[action] = physical
	return conflict
