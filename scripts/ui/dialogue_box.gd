class_name DialogueBox
extends Control
## Box dei dialoghi con effetto macchina da scrivere. Tocca per continuare.

signal finished

var lines: Array = []
var index := 0
var panel: PanelContainer
var name_label: Label
var text_label: Label
var hint: Label
var _tween: Tween
var _typing := false
var _active := false
var _cooldown := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = UIKit.panel(Color(0.04, 0.04, 0.06, 0.88), 16)
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -190
	panel.offset_bottom = -24
	add_child(panel)
	var v := UIKit.vbox(6)
	panel.add_child(v)
	name_label = UIKit.label("", 26, Color.WHITE, 5)
	v.add_child(name_label)
	text_label = UIKit.label("", 25, Color(0.95, 0.95, 0.92), 3)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(600, 70)
	v.add_child(text_label)
	hint = UIKit.label("Tocca per continuare", 16, Color(1, 1, 1, 0.55), 2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	visible = false


func play(new_lines: Array) -> void:
	lines = new_lines
	index = 0
	_active = true
	visible = not Game.test_mode
	if Game.test_mode:
		_end.call_deferred()
		return
	_show_line()


func abort() -> void:
	if _active:
		_end()


func _show_line() -> void:
	if index >= lines.size():
		_end()
		return
	var line: Array = lines[index]
	var who: String = line[0]
	var sp: Array = Game.SPEAKERS.get(who, ["", Color.WHITE])
	name_label.text = sp[0]
	name_label.add_theme_color_override("font_color", sp[1])
	name_label.visible = sp[0] != ""
	text_label.text = line[1]
	text_label.visible_ratio = 0.0
	if who == "narrator":
		text_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.7))
	else:
		text_label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.95))
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_typing = true
	_tween = create_tween()
	_tween.tween_property(text_label, "visible_ratio", 1.0, clampf(String(line[1]).length() * 0.022, 0.3, 2.2))
	_tween.tween_callback(func(): _typing = false)
	_cooldown = 0.15


func _end() -> void:
	if not _active:
		return
	_active = false
	visible = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()


func advance() -> void:
	if not _active or _cooldown > 0.0:
		return
	if _typing:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		text_label.visible_ratio = 1.0
		_typing = false
		_cooldown = 0.12
		return
	index += 1
	_show_line()


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func _input(event: InputEvent) -> void:
	if not _active or not visible or get_tree().paused:
		return
	var go := false
	if event is InputEventScreenTouch and event.pressed:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		advance()
