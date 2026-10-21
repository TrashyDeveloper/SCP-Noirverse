class_name IdleInput
extends InputSource
## An InputSource that stands still and looks in one direction. Used for
## test NPCs until real AI bots arrive (Step 4).

var yaw := 0.0


func sample() -> CharacterInput:
	var input := CharacterInput.new()
	input.yaw = yaw
	return input


func get_view_angles() -> Vector2:
	return Vector2(yaw, 0.0)
