class_name TouchButton
extends Control
## Pulsante circolare multi-touch che preme/rilascia un'azione di input.

var action := ""
var text := ""
var radius := 48.0
var color := Color(0.2, 0.2, 0.25)
var finger := -1
var pressed := false
var highlight := false
var cooldown := 0.0
var badge := ""
var font: Font


func _init(act: String, label_text: String, r: float, c: Color) -> void:
	action = act
	text = label_text
	radius = r
	color = c
	size = Vector2(r * 2.0, r * 2.0)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	font = get_theme_default_font()


func center_global() -> Vector2:
	return global_position + size * 0.5


func hit(p: Vector2) -> bool:
	return is_visible_in_tree() and p.distance_to(center_global()) <= radius * 1.18


func set_pressed(on: bool) -> void:
	if pressed == on:
		return
	pressed = on
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)
	queue_redraw()


func set_label(t: String) -> void:
	if t != text:
		text = t
		queue_redraw()


func set_highlight(on: bool) -> void:
	if on != highlight:
		highlight = on
		queue_redraw()


func set_cooldown(v: float) -> void:
	if absf(v - cooldown) > 0.01:
		cooldown = v
		queue_redraw()


func set_badge(t: String) -> void:
	if t != badge:
		badge = t
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var base := color
	base.a = 0.55 if not pressed else 0.85
	if highlight:
		base = base.lightened(0.25)
	draw_circle(c, radius, base)
	draw_arc(c, radius - 2.0, 0.0, TAU, 40, Color(1, 1, 1, 0.75 if highlight else 0.45), 3.0, true)
	if cooldown > 0.0:
		draw_arc(c, radius - 7.0, -PI * 0.5, -PI * 0.5 + TAU * cooldown, 40, Color(0, 0, 0, 0.55), 10.0, true)
	if font == null:
		return
	var fs := int(clampf(radius * 0.36, 13.0, 24.0))
	if text.length() > 6:
		fs = int(fs * 0.85)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string_outline(font, Vector2(c.x - tw * 0.5, c.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(c.x - tw * 0.5, c.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if badge != "":
		var bp := c + Vector2(radius * 0.68, -radius * 0.68)
		draw_circle(bp, 14.0, Color(0.85, 0.2, 0.15))
		var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
		draw_string(font, bp + Vector2(-bw * 0.5, 6), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
