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


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
