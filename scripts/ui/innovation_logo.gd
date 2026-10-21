class_name InnovationLogo
extends Control
## The Innovation Inc. mark, drawn in code: a hexagon with a ring-shaped
## reactor (two tilted orbits) around a glowing core. The orbits turn slowly.

@export var accent := Color(0.35, 0.9, 1.0)
@export var line := Color(0.92, 0.94, 0.97)

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	# Hexagon frame (double line).
	for k: float in [1.0, 0.86]:
		var pts := PackedVector2Array()
		for i in 7:
			var a := TAU * i / 6.0 + PI / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r * k)
		draw_polyline(pts, line if k == 1.0 else Color(line, 0.35), 2.0 if k == 1.0 else 1.0, true)
	# Two tilted orbits.
	for j in 2:
		var tilt := _time * 0.35 + j * PI / 2.0
		var pts := PackedVector2Array()
		for i in 65:
			var a := TAU * i / 64.0
			var p := Vector2(cos(a) * r * 0.62, sin(a) * r * 0.22).rotated(tilt)
			pts.append(c + p)
		draw_polyline(pts, accent, 2.0, true)
	# Core with a soft glow.
	var pulse := 0.8 + 0.2 * sin(_time * 2.4)
	for i in 5:
		draw_circle(c, r * (0.2 - i * 0.03) * pulse, Color(accent, 0.12 + i * 0.12))
	draw_circle(c, r * 0.06, Color.WHITE)
