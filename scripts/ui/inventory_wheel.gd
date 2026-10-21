class_name InventoryWheel
extends Control
## A round inventory: 8 segments in a ring around an empty centre, drawn in
## code (no image files). Slot 0 is at the top, then clockwise.
##
## It only draws and reports clicks; InventoryMenu decides what they mean.

signal slot_clicked(slot: int, button: MouseButton)
signal hovered_changed(slot: int)

@export var outer_radius := 250.0
@export var inner_radius := 112.0
## Gap between segments, in pixels.
@export var gap := 9.0
@export var rim_width := 9.0

@export_group("Colors")
@export var segment_color := Color(0.055, 0.058, 0.065, 0.96)
@export var segment_hover_color := Color(0.13, 0.135, 0.145, 0.98)
@export var segment_held_color := Color(0.18, 0.185, 0.19, 1.0)
@export var metal_light := Color(0.72, 0.73, 0.75)
@export var metal_dark := Color(0.28, 0.29, 0.31)
@export var text_color := Color(0.85, 0.85, 0.82)
@export var empty_text_color := Color(0.4, 0.4, 0.4)

const SLOT_COUNT := 8

## One entry per slot: {"title": String, "subtitle": String} or {} if empty.
var slot_info: Array[Dictionary] = []
var held_slot := -1
var hovered_slot := -1
## Lines of text shown in the empty centre (first line is larger).
var center_lines: PackedStringArray = []:
	set(value):
		center_lines = value
		queue_redraw()


func _ready() -> void:
	slot_info.resize(SLOT_COUNT)
	custom_minimum_size = Vector2.ONE * (outer_radius + rim_width + 4.0) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_slots(info: Array[Dictionary], held: int) -> void:
	slot_info = info
	held_slot = held
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var slot := slot_at(event.position)
		if slot != hovered_slot:
			hovered_slot = slot
			hovered_changed.emit(slot)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var slot := slot_at(event.position)
		if slot != -1 and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			slot_clicked.emit(slot, event.button_index)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hovered_slot != -1:
		hovered_slot = -1
		hovered_changed.emit(-1)
		queue_redraw()


## Which slot is under `point` (local coordinates), or -1.
func slot_at(point: Vector2) -> int:
	var offset := point - size / 2.0
	var distance := offset.length()
	if distance < inner_radius or distance > outer_radius:
		return -1
	# Angle measured clockwise from straight up.
	var angle := fposmod(atan2(offset.x, -offset.y) + PI / SLOT_COUNT, TAU)
	return int(angle / (TAU / SLOT_COUNT)) % SLOT_COUNT


func _draw() -> void:
	var center := size / 2.0
	# Outer metal rim and the dark disc behind the segments.
	draw_circle(center, outer_radius + rim_width, Color(0.02, 0.02, 0.025, 0.9))
	draw_arc(center, outer_radius + rim_width * 0.5, 0.0, TAU, 96, metal_dark, rim_width, true)
	draw_arc(center, outer_radius + rim_width * 0.5, 0.0, TAU, 96, metal_light, rim_width * 0.45, true)
	draw_arc(center, inner_radius - rim_width * 0.5, 0.0, TAU, 64, metal_dark, rim_width, true)
	draw_arc(center, inner_radius - rim_width * 0.5, 0.0, TAU, 64, metal_light, rim_width * 0.45, true)
	draw_circle(center, inner_radius - rim_width, Color(0.0, 0.0, 0.0, 0.95))

	for slot in SLOT_COUNT:
		_draw_segment(center, slot)

	var font := get_theme_default_font()
	var y := -10.0 * (center_lines.size() - 1)
	for i in center_lines.size():
		var font_size := 17 if i == 0 else 12
		var color := text_color if i == 0 else text_color.darkened(0.3)
		_draw_centered(font, center_lines[i], center + Vector2(0, y), font_size, color, inner_radius * 1.6)
		y += 22.0 if i == 0 else 18.0


func _draw_segment(center: Vector2, slot: int) -> void:
	var step := TAU / SLOT_COUNT
	# Slot 0 centred at the top (-90 degrees), going clockwise.
	var mid := -PI / 2.0 + slot * step
	var a0 := mid - step / 2.0
	var a1 := mid + step / 2.0
	var outer := _arc_points(center, outer_radius - 4.0, a0 + gap / outer_radius, a1 - gap / outer_radius)
	var inner := _arc_points(center, inner_radius + 4.0, a0 + gap / inner_radius, a1 - gap / inner_radius)
	inner.reverse()
	var polygon := outer + inner

	var fill := segment_color
	if slot == held_slot:
		fill = segment_held_color
	elif slot == hovered_slot:
		fill = segment_hover_color
	draw_colored_polygon(polygon, fill)
	# Metal frame: dark outer line with a lighter line on top.
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, metal_dark, 5.0, true)
	draw_polyline(outline, metal_light if slot == held_slot or slot == hovered_slot else metal_light.darkened(0.25), 2.0, true)

	# Item text at the middle of the segment.
	var info: Dictionary = slot_info[slot] if slot < slot_info.size() and slot_info[slot] != null else {}
	var text_pos := center + Vector2(cos(mid), sin(mid)) * (inner_radius + outer_radius) / 2.0
	var font := get_theme_default_font()
	if info.is_empty():
		_draw_centered(font, "-", text_pos, 18, empty_text_color)
	else:
		_draw_centered(font, info.get("title", ""), text_pos + Vector2(0, -8), 15, text_color, 118.0)
		_draw_centered(font, info.get("subtitle", ""), text_pos + Vector2(0, 14), 12, text_color.darkened(0.35), 118.0)


func _arc_points(center: Vector2, radius: float, from: float, to: float, steps := 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := lerpf(from, to, float(i) / steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw_centered(font: Font, text: String, pos: Vector2, font_size: int, color: Color, max_width := -1.0) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if max_width > 0.0 and width > max_width:
		# Shrink long names so they fit inside the segment.
		font_size = maxi(int(font_size * max_width / width), 9)
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, pos + Vector2(-width / 2.0, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
