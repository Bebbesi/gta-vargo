class_name TouchControls
extends Control
## Comandi touch: joystick virtuale (a sinistra), trascinamento della visuale
## (a destra) e pulsanti contestuali a piedi / in auto. Multi-touch.

const JOY_R := 85.0

var world: Node
var buttons: Dictionary = {}
var mode := "hidden"
var joy_finger := -1
var joy_center := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_vec := Vector2.ZERO
var cam_finger := -1
var joy_home := Vector2(170, 560)

const FOOT := ["attack", "jump", "vehicle", "special", "use_boost", "switch_char", "pause"]
const CAR := ["accelerate", "brake", "vehicle", "special", "use_boost", "horn", "switch_char", "pause"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add("attack", "PUGNO", 62, Color(0.85, 0.25, 0.2))
	_add("jump", "SALTA", 44, Color(0.25, 0.55, 0.85))
	_add("vehicle", "AUTO", 46, Color(0.95, 0.65, 0.15))
	_add("special", "NITRO", 42, Color(0.55, 0.35, 0.85))
	_add("use_boost", "BOOST", 38, Color(0.55, 0.33, 0.14))
	_add("switch_char", "CAMBIA", 38, Color(0.2, 0.6, 0.5))
	_add("pause", "II", 28, Color(0.2, 0.2, 0.25))
	_add("accelerate", "GAS", 64, Color(0.2, 0.7, 0.3))
	_add("brake", "FRENO", 50, Color(0.8, 0.2, 0.2))
	_add("horn", "CLACSON", 34, Color(0.4, 0.4, 0.45))
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_mode("hidden")


func _add(action: String, label_text: String, r: float, c: Color) -> void:
	var b := TouchButton.new(action, label_text, r, c)
	add_child(b)
	buttons[action] = b


func _layout() -> void:
	var vs := get_viewport_rect().size
	var places := {
		"attack": Vector2(vs.x - 110, vs.y - 120),
		"accelerate": Vector2(vs.x - 110, vs.y - 120),
		"jump": Vector2(vs.x - 235, vs.y - 70),
		"brake": Vector2(vs.x - 245, vs.y - 80),
		"vehicle": Vector2(vs.x - 95, vs.y - 260),
		"special": Vector2(vs.x - 215, vs.y - 205),
		"use_boost": Vector2(vs.x - 345, vs.y - 62),
		"horn": Vector2(vs.x - 335, vs.y - 165),
		"switch_char": Vector2(vs.x - 75, vs.y - 380),
		"pause": Vector2(vs.x - 280, 52),
	}
	for k in places:
		var b: TouchButton = buttons[k]
		b.position = places[k] - b.size * 0.5
	joy_home = Vector2(175, vs.y - 165)
	if joy_finger == -1:
		joy_center = joy_home
		joy_pos = joy_home
	queue_redraw()


func set_mode(m: String) -> void:
	mode = m
	var list: Array = []
	if m == "foot":
		list = FOOT
	elif m == "car":
		list = CAR
	for k in buttons:
		var b: TouchButton = buttons[k]
		var show := list.has(k)
		if not show and b.pressed:
			b.finger = -1
			b.set_pressed(false)
		b.visible = show
	if m == "hidden" or m == "cutscene":
		release_all()
	queue_redraw()


func release_all() -> void:
	for k in buttons:
		var b: TouchButton = buttons[k]
		b.finger = -1
		b.set_pressed(false)
	if joy_finger != -1:
		joy_finger = -1
		_apply_joy(Vector2.ZERO)
	cam_finger = -1
	joy_center = joy_home
	joy_pos = joy_home
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not is_visible_in_tree() or get_tree().paused or mode == "hidden" or mode == "cutscene":
				return
			for k in buttons:
				var b: TouchButton = buttons[k]
				if b.finger == -1 and b.hit(st.position):
					b.finger = st.index
					b.set_pressed(true)
					get_viewport().set_input_as_handled()
					return
			var vs := get_viewport_rect().size
			if joy_finger == -1 and st.position.x < vs.x * 0.42 and st.position.y > vs.y * 0.28:
				joy_finger = st.index
				joy_center = st.position
				joy_pos = st.position
				_update_joy()
				get_viewport().set_input_as_handled()
				return
			if cam_finger == -1:
				cam_finger = st.index
				get_viewport().set_input_as_handled()
		else:
			_release_finger(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == joy_finger:
			joy_pos = sd.position
			_update_joy()
			get_viewport().set_input_as_handled()
		elif sd.index == cam_finger and world != null:
			world.camera.drag(sd.relative)
			get_viewport().set_input_as_handled()


func _release_finger(idx: int) -> void:
	for k in buttons:
		var b: TouchButton = buttons[k]
		if b.finger == idx:
			b.finger = -1
			b.set_pressed(false)
	if idx == joy_finger:
		joy_finger = -1
		joy_center = joy_home
		joy_pos = joy_home
		_apply_joy(Vector2.ZERO)
		queue_redraw()
	if idx == cam_finger:
		cam_finger = -1


func _update_joy() -> void:
	var d := joy_pos - joy_center
	if d.length() > JOY_R:
		joy_center = joy_pos - d.normalized() * JOY_R
		d = joy_pos - joy_center
	_apply_joy(d / JOY_R)
	queue_redraw()


func _apply_joy(v: Vector2) -> void:
	joy_vec = v
	_set_action("move_right", maxf(v.x, 0.0))
	_set_action("move_left", maxf(-v.x, 0.0))
	_set_action("move_back", maxf(v.y, 0.0))
	_set_action("move_forward", maxf(-v.y, 0.0))


func _set_action(a: String, s: float) -> void:
	if s > 0.05:
		Input.action_press(a, clampf(s, 0.0, 1.0))
	else:
		Input.action_release(a)


func _process(_delta: float) -> void:
	modulate.a = float(Game.settings["touch_opacity"])


func _draw() -> void:
	if mode != "foot" and mode != "car":
		return
	draw_circle(joy_center, JOY_R, Color(0, 0, 0, 0.28))
	draw_arc(joy_center, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
	var knob := joy_center + joy_vec * JOY_R
	draw_circle(knob, 38.0, Color(1, 1, 1, 0.5 if joy_finger != -1 else 0.3))
	if mode == "car":
		var f := get_theme_default_font()
		draw_string(f, joy_center + Vector2(-JOY_R - 4, -JOY_R - 14), "< STERZO >", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.7))
