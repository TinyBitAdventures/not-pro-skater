extends Node
## Registers every input action in code so bindings live in one readable place.

const KEYS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
	"ollie": [KEY_SPACE], "flip": [KEY_J], "grab": [KEY_K], "grind": [KEY_L],
	"brake": [KEY_SHIFT], "manual": [KEY_M],
	"respawn": [KEY_R], "pause": [KEY_ESCAPE],
}
const PAD_BUTTONS: Dictionary = {
	"ollie": [JOY_BUTTON_A], "flip": [JOY_BUTTON_X], "grab": [JOY_BUTTON_B], "grind": [JOY_BUTTON_Y],
	"respawn": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START], "manual": [JOY_BUTTON_RIGHT_SHOULDER + 100],
}
const PAD_AXES: Dictionary = {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"brake": [JOY_AXIS_TRIGGER_LEFT, 1.0], "manual": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


signal device_changed(pad: bool)

var using_pad: bool = false       # the last input came from a gamepad: hints show pad buttons
var _axis_zone: Dictionary = {}   # "device:axis" -> -1 / 0 / 1: where each stick axis was, for menu navigation
var _nav_event: int = 0
var _nav_fresh: bool = false


## A menu press: keys and buttons as usual (no echo), but a stick only when it crosses into a direction. Every
## stick motion past the dead zone reports "pressed", so one push used to move a menu five or six rows.
func nav_pressed(event: InputEvent, action: StringName) -> bool:
	var m: InputEventJoypadMotion = event as InputEventJoypadMotion
	if m == null:
		return event.is_action_pressed(action)
	_track_axis(m)
	return _nav_fresh and event.is_action_pressed(action)


func _track_axis(m: InputEventJoypadMotion) -> void:
	if m.get_instance_id() == _nav_event:
		return
	_nav_event = m.get_instance_id()
	var key: String = "%d:%d" % [m.device, m.axis]
	var zone: int = 0 if absf(m.axis_value) < 0.5 else (1 if m.axis_value > 0.0 else -1)
	_nav_fresh = zone != 0 and zone != int(_axis_zone.get(key, 0))
	_axis_zone[key] = zone


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_track_axis(event as InputEventJoypadMotion)
	var pad: bool = using_pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(pad)


func _ready() -> void:
	for action in KEYS:
		_ensure(action)
		for k in KEYS[action]:
			var e: InputEventKey = InputEventKey.new()
			e.physical_keycode = k as Key
			InputMap.action_add_event(action, e)
	for action in PAD_BUTTONS:
		_ensure(action)
		for b in PAD_BUTTONS[action]:
			if b > 50:
				continue
			var e: InputEventJoypadButton = InputEventJoypadButton.new()
			e.button_index = b as JoyButton
			InputMap.action_add_event(action, e)
	for action in PAD_AXES:
		_ensure(action)
		var ax: Array = PAD_AXES[action]
		var e: InputEventJoypadMotion = InputEventJoypadMotion.new()
		e.axis = ax[0] as JoyAxis
		e.axis_value = ax[1]
		InputMap.action_add_event(action, e)
	# menus: A accepts and B goes back, as the hints say (Godot's ui_accept / ui_cancel are keys only)
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var jb: InputEventJoypadButton = InputEventJoypadButton.new()
		jb.button_index = pair[1] as JoyButton
		InputMap.action_add_event(pair[0], jb)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
