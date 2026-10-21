class_name CharacterInput
extends RefCounted
## A snapshot of what a character "wants" to do during one physics tick.
##
## The character never reads the keyboard or mouse itself. Instead, an
## InputSource (local player, AI bot, or later a network peer) fills one of
## these every tick. This keeps game logic separate from input, which is
## what makes bots and online multiplayer possible later.

## Desired movement on the ground plane. x = right, y = forward. Length <= 1.
var move := Vector2.ZERO
## Where the character is looking, in radians.
var yaw := 0.0
var pitch := 0.0
## Held actions.
var sprint := false
## One-shot actions (true only on the tick they were pressed).
var jump := false
var interact := false
var toggle_flashlight := false
var use_item := false
var reload := false
var drop_item := false
## Inventory slot to hold (0-based), or -1 for no change. Choosing the slot
## already held puts the item away.
var select_slot := -1
## Inventory slot to drop on the floor, or -1 for none.
var drop_slot := -1
