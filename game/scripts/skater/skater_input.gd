class_name SkaterInput
extends RefCounted
## One frame of intent. The player fills it from Controls; tests and NPCs fill it by hand.

var move: Vector2 = Vector2.ZERO        # raw stick (x right, y down). Spin in the air, steer in tank mode
var world_dir: Vector3 = Vector3.ZERO   # stick resolved through the camera (screen mode)
var ollie_pressed: bool = false
var ollie_held: bool = false
var flip_pressed: bool = false
var grab_held: bool = false
var grind_pressed: bool = false
var brake: bool = false
var manual: bool = false


func clear_edges() -> void:
	ollie_pressed = false
	flip_pressed = false
	grind_pressed = false
