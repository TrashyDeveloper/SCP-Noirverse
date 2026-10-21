class_name RoundEndScreen
extends CanvasLayer
## Shown when a round is over: who won, why, some statistics and a countdown
## to the next round. Like other menus it only asks; Game decides.

signal next_round_requested
signal main_menu_requested

const WINNER_TITLES := {
	CharacterClass.Side.FOUNDATION: "THE FOUNDATION WINS",
	CharacterClass.Side.INSURGENCY: "CLASS-D & CHAOS INSURGENCY WIN",
	CharacterClass.Side.SCP: "THE SCPs WIN",
}

var _countdown := -1.0


func _ready() -> void:
	visible = false
	%NextRound.pressed.connect(next_round_requested.emit)
	%MainMenu.pressed.connect(main_menu_requested.emit)


func _process(delta: float) -> void:
	if not visible or _countdown < 0.0:
		return
	_countdown -= delta
	%Countdown.text = "Next round in %d…" % ceili(maxf(_countdown, 0.0))
	if _countdown <= 0.0:
		_countdown = -1.0
		next_round_requested.emit()


## `player_side` is the local player's side at the end (-1 if unknown).
func show_result(result: Dictionary, player_side: int, restart_delay: float) -> void:
	var winner: int = result.winner
	%Title.text = WINNER_TITLES.get(winner, "STALEMATE")
	if winner == RoundManager.NO_WINNER or player_side == -1:
		%Verdict.text = ""
	else:
		%Verdict.text = "VICTORY" if winner == player_side else "DEFEAT"
	%Reason.text = result.reason
	var stats: Dictionary = result.stats
	var kills: Dictionary = stats.kills
	var duration: float = result.duration
	%Stats.text = "\n".join(PackedStringArray([
		"Round time  %d:%02d" % [int(duration) / 60, int(duration) % 60],
		"Class-D escaped  %d   (while disarmed: %d)" % [stats.class_d_escaped, stats.class_d_escaped_disarmed],
		"Scientists escaped  %d   (while disarmed: %d)" % [stats.scientists_escaped, stats.scientists_escaped_disarmed],
		"Kills by the Foundation  %d" % kills.get(CharacterClass.Side.FOUNDATION, 0),
		"Kills by Class-D & Chaos  %d" % kills.get(CharacterClass.Side.INSURGENCY, 0),
		"Deaths  %d" % stats.deaths,
	]))
	_countdown = restart_delay
	visible = true
	var panel: Control = $Panel
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.8)
	%NextRound.grab_focus()
