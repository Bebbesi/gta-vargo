class_name UIKit
extends RefCounted
## Helper per costruire l'interfaccia via codice con uno stile coerente.

const ACCENT := Color(1.0, 0.72, 0.2)
const PANEL := Color(0.06, 0.06, 0.09, 0.88)


static func style(c: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	return s


static func label(text: String, size: int = 24, c: Color = Color.WHITE, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size: int = 26, min_size: Vector2 = Vector2(340, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", style(Color(0.13, 0.13, 0.18, 0.95), 12, Color(1, 1, 1, 0.12), 2))
	b.add_theme_stylebox_override("hover", style(Color(0.22, 0.2, 0.28, 0.98), 12, ACCENT, 2))
	b.add_theme_stylebox_override("pressed", style(Color(0.9, 0.62, 0.15, 1.0), 12, ACCENT, 2))
	b.add_theme_stylebox_override("focus", style(Color(0.22, 0.2, 0.28, 0.98), 12, ACCENT, 2))
	b.add_theme_stylebox_override("disabled", style(Color(0.1, 0.1, 0.12, 0.7), 12))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.05))
	b.pressed.connect(func(): Sfx.play("click", -6.0))
	return b


static func panel(c: Color = PANEL, radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(c, radius, Color(1, 1, 1, 0.08), 2))
	return p


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func dim(alpha: float = 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func centered(parent: Control, child: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	cc.add_child(child)
	return cc


static func slider(min_v: float, max_v: float, step: float, value: float, width: float = 320.0) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(width, 44)
	var grab := style(ACCENT, 16)
	grab.content_margin_left = 0
	grab.content_margin_right = 0
	s.add_theme_stylebox_override("slider", style(Color(0.25, 0.25, 0.3), 6))
	s.add_theme_stylebox_override("grabber_area", style(ACCENT.darkened(0.2), 6))
	s.add_theme_stylebox_override("grabber_area_highlight", style(ACCENT, 6))
	return s
