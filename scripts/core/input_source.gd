class_name InputSource
extends Node
## Base class for anything that can drive a character.
##
## Subclasses: LocalPlayerInput (keyboard + mouse). Later: BotInput (AI) and
## NetworkInput (a remote player's commands).

## Whether this source should currently be listened to (e.g. false while the
## pause menu is open).
var enabled := true


## Called by the character once per physics tick. Must return a fresh
## CharacterInput. One-shot actions should be cleared after being returned.
func sample() -> CharacterInput:
	return CharacterInput.new()


## The current view direction (x = yaw, y = pitch) in radians. The character
## reads this every rendered frame so the camera stays smooth even on
## monitors faster than the physics tick rate.
func get_view_angles() -> Vector2:
	return Vector2.ZERO


## Weapon recoil kicks the view up (radians). Sources that have no view of
## their own (bots) can ignore it.
func add_recoil(_pitch: float, _yaw: float) -> void:
	pass
