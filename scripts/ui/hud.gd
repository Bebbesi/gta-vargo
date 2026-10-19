class_name HUD
extends CanvasLayer
## Interfaccia di gioco: salute, denaro, Brown Boost, obiettivo, minimappa,
## tachimetro, messaggi, comandi touch, dialoghi e menu (pausa, mappa,
## impostazioni, cambio personaggio, scelta finale, titoli di coda).

class Portrait extends Control:
	var col := Color.WHITE
	var letter := "M"

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, size.x * 0.5, Color(0, 0, 0, 0.65))
		draw_circle(c, size.x * 0.5 - 4.0, col)
		var f := get_theme_default_font()
		var fs := 34
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, c + Vector2(-w * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.8))
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


class Stars extends Control:
	var count := 0
	var blink := false
	var flash_t := 0.0

	func _process(delta: float) -> void:
		flash_t = maxf(0.0, flash_t - delta)
		if count > 0 or flash_t > 0.0:
			queue_redraw()

	func _draw() -> void:
		if count == 0 and flash_t <= 0.0:
			return
		var on := (Time.get_ticks_msec() / 260) % 2 == 0
		for i in 5:
			var c := Vector2(size.x - 18.0 - (4 - i) * 32.0, 16.0)
			var filled := i < count
			var col := Color(1.0, 0.82, 0.2) if filled else Color(0.1, 0.1, 0.12, 0.55)
			if filled and (blink or flash_t > 0.0) and not on:
				col = Color(1.0, 1.0, 1.0, 0.45)
			_star(c, 14.0, col)

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + k * PI / 5.0
			var rr := r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.85), 2.0, true)


## Mirino al centro dello schermo durante la MIRA (rosso sopra un bersaglio).
class Crosshair extends Control:
	var on_target := false

	func set_on_target(v: bool) -> void:
		if v != on_target:
			on_target = v
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1.0, 0.22, 0.18) if on_target else Color(1, 1, 1, 0.95)
		var sh := Color(0, 0, 0, 0.55)
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			draw_line(c + d * 8.0, c + d * 25.0, sh, 6.0)
			draw_line(c + d * 8.0, c + d * 25.0, col, 3.0)
		draw_circle(c, 4.0, sh)
		draw_circle(c, 2.6, col)


var world: Node
var hud_root: Control
var crosshair: Crosshair
var menu_layer: Control
var touch: TouchControls
var minimap: Minimap
var dialogue: DialogueBox
var portrait: Portrait
var name_label: Label
var health_fill: ColorRect
var health_text: Label
var money_label: Label
var boost_label: Label
var special_label: Label
var weapon_label: Label
var stars: Stars
var busted_overlay: Control
var score_label: Label
var obj_panel: PanelContainer
var obj_label: Label
var extra_label: Label
var timer_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var big_title: Label
var big_sub: Label
var speed_panel: PanelContainer
var speed_label: Label
var car_fill: ColorRect
var district_label: Label
var damage_flash: ColorRect
var ko_overlay: Control
var fade_rect: ColorRect
var fps_label: Label
var skip_btn: Button
var _skip_cb: Callable
var _toast_t := 0.0
var _big_tween: Tween
var _district := ""
var _district_t := 0.0
var _menu: Control
var _menu_frame := -1
var _shown_money := 0.0
var _hud_visible := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud_root = UIKit.full(Control.new())
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	_build_top_left()
	_build_objective()
	_build_minimap()
	_build_speedo()
	_build_messages()
	crosshair = Crosshair.new()
	UIKit.full(crosshair)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	hud_root.add_child(crosshair)
	touch = TouchControls.new()
	touch.world = world
	add_child(touch)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	damage_flash = ColorRect.new()
	UIKit.full(damage_flash)
	damage_flash.color = Color(0.9, 0.05, 0.05, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_flash)
	_build_ko()
	menu_layer = UIKit.full(Control.new())
	menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_layer)
	skip_btn = UIKit.button("SALTA  >>", 22, Vector2(170, 54))
	skip_btn.anchor_left = 1.0
	skip_btn.anchor_right = 1.0
	skip_btn.offset_left = -190
	skip_btn.offset_right = -20
	skip_btn.offset_top = 16
	skip_btn.offset_bottom = 70
	skip_btn.visible = false
	skip_btn.pressed.connect(func():
		if _skip_cb.is_valid():
			_skip_cb.call())
	add_child(skip_btn)
	fade_rect = ColorRect.new()
	UIKit.full(fade_rect)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	fps_label = UIKit.label("", 16, Color(0.6, 1.0, 0.6), 3)
	fps_label.position = Vector2(8, 696)
	add_child(fps_label)
	set_hud_visible(false)
	on_character_changed()
	_shown_money = Game.money


# ---------------------------------------------------------------- costruzione

func _build_top_left() -> void:
	var tl := Control.new()
	tl.position = Vector2(14, 10)
	tl.size = Vector2(320, 140)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(tl)
	portrait = Portrait.new()
	portrait.position = Vector2(0, 4)
	portrait.size = Vector2(70, 70)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(portrait)
	name_label = UIKit.label("MIKE VARGO", 21, Color.WHITE, 5)
	name_label.position = Vector2(82, 0)
	tl.add_child(name_label)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = Vector2(82, 32)
	bg.size = Vector2(220, 22)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(bg)
	health_fill = ColorRect.new()
	health_fill.position = Vector2(3, 3)
	health_fill.size = Vector2(214, 16)
	health_fill.color = Color(0.3, 0.85, 0.35)
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(health_fill)
	health_text = UIKit.label("100", 15, Color.WHITE, 4)
	health_text.position = Vector2(0, 0)
	health_text.size = Vector2(220, 22)
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg.add_child(health_text)
	money_label = UIKit.label("$ 0", 28, Color(0.45, 0.95, 0.45), 6)
	money_label.position = Vector2(82, 56)
	tl.add_child(money_label)
	boost_label = UIKit.label("", 18, Color(0.95, 0.7, 0.4), 4)
	boost_label.position = Vector2(4, 92)
	tl.add_child(boost_label)
	special_label = UIKit.label("", 16, Color(0.85, 0.75, 1.0), 4)
	special_label.position = Vector2(4, 116)
	tl.add_child(special_label)
	weapon_label = UIKit.label("", 20, Color(1.0, 0.8, 0.5), 5)
	weapon_label.position = Vector2(4, 138)
	tl.add_child(weapon_label)
	score_label = UIKit.label("", 17, Color.WHITE, 4)
	score_label.position = Vector2(4, 168)
	tl.add_child(score_label)


func _build_objective() -> void:
	obj_panel = UIKit.panel(Color(0, 0, 0, 0.55), 10)
	obj_panel.anchor_left = 0.5
	obj_panel.anchor_right = 0.5
	obj_panel.offset_left = -265
	obj_panel.offset_right = 265
	obj_panel.offset_top = 10
	obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(obj_panel)
	obj_label = UIKit.label("", 21, Color(1.0, 0.95, 0.8), 3)
	obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_label.custom_minimum_size = Vector2(496, 0)
	obj_panel.add_child(obj_label)
	obj_panel.visible = false
	extra_label = UIKit.label("", 22, Color(1.0, 0.85, 0.3), 5)
	extra_label.anchor_left = 0.5
	extra_label.anchor_right = 0.5
	extra_label.offset_left = -300
	extra_label.offset_right = 300
	extra_label.offset_top = 92
	extra_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(extra_label)
	timer_label = UIKit.label("", 38, Color.WHITE, 7)
	timer_label.anchor_left = 0.5
	timer_label.anchor_right = 0.5
	timer_label.offset_left = -150
	timer_label.offset_right = 150
	timer_label.offset_top = 122
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(timer_label)


func _build_minimap() -> void:
	minimap = Minimap.new()
	minimap.world = world
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -222
	minimap.offset_right = -18
	minimap.offset_top = 14
	minimap.offset_bottom = 218
	hud_root.add_child(minimap)
	district_label = UIKit.label("", 24, Color(1.0, 0.95, 0.85), 6)
	district_label.anchor_left = 1.0
	district_label.anchor_right = 1.0
	district_label.offset_left = -420
	district_label.offset_right = -18
	district_label.offset_top = 256
	district_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_root.add_child(district_label)
	stars = Stars.new()
	stars.anchor_left = 1.0
	stars.anchor_right = 1.0
	stars.offset_left = -222
	stars.offset_right = -18
	stars.offset_top = 222
	stars.offset_bottom = 254
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(stars)


func _build_speedo() -> void:
	speed_panel = UIKit.panel(Color(0, 0, 0, 0.55), 12)
	speed_panel.anchor_left = 0.5
	speed_panel.anchor_right = 0.5
	speed_panel.anchor_top = 1.0
	speed_panel.anchor_bottom = 1.0
	speed_panel.offset_left = -95
	speed_panel.offset_right = 95
	speed_panel.offset_top = -92
	speed_panel.offset_bottom = -14
	speed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(speed_panel)
	var v := UIKit.vbox(4)
	speed_panel.add_child(v)
	speed_label = UIKit.label("0 km/h", 28, Color.WHITE, 4)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(speed_label)
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15, 0.9)
	bg.custom_minimum_size = Vector2(158, 10)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bg)
	car_fill = ColorRect.new()
	car_fill.size = Vector2(158, 10)
	car_fill.color = Color(0.95, 0.65, 0.2)
	car_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(car_fill)
	speed_panel.visible = false


func _build_messages() -> void:
	toast_panel = UIKit.panel(Color(0, 0, 0, 0.72), 10)
	toast_panel.position = Vector2(16, 212)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(toast_panel)
	toast_label = UIKit.label("", 19, Color.WHITE, 0)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(360, 0)
	toast_panel.add_child(toast_label)
	toast_panel.visible = false
	big_title = UIKit.label("", 56, UIKit.ACCENT, 10)
	big_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	big_title.anchor_left = 0.0
	big_title.anchor_right = 1.0
	big_title.offset_left = 0
	big_title.offset_right = 0
	big_title.offset_top = -150
	big_title.offset_bottom = -80
	big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(big_title)
	big_sub = UIKit.label("", 30, Color.WHITE, 6)
	big_sub.anchor_left = 0.0
	big_sub.anchor_right = 1.0
	big_sub.anchor_top = 0.5
	big_sub.anchor_bottom = 0.5
	big_sub.offset_top = -78
	big_sub.offset_bottom = -30
	big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(big_sub)
	big_title.modulate.a = 0.0
	big_sub.modulate.a = 0.0


func _build_ko() -> void:
	ko_overlay = UIKit.full(Control.new())
	ko_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := ColorRect.new()
	UIKit.full(tint)
	tint.color = Color(0.25, 0.0, 0.0, 0.45)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ko_overlay.add_child(tint)
	var l := UIKit.label("K.O.!", 110, Color(0.95, 0.15, 0.12), 14)
	UIKit.full(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ko_overlay.add_child(l)
	ko_overlay.visible = false
	add_child(ko_overlay)
	busted_overlay = UIKit.full(Control.new())
	busted_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bt := ColorRect.new()
	UIKit.full(bt)
	bt.color = Color(0.0, 0.08, 0.3, 0.5)
	bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busted_overlay.add_child(bt)
	var bl := UIKit.label("ARRESTATO!", 100, Color(0.45, 0.65, 1.0), 14)
	UIKit.full(bl)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	busted_overlay.add_child(bl)
	busted_overlay.visible = false
	add_child(busted_overlay)


# ---------------------------------------------------------------- aggiornamento

func _process(delta: float) -> void:
	fps_label.visible = bool(Game.settings["show_fps"])
	if fps_label.visible:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()
		fps_label.position.y = get_viewport().get_visible_rect().size.y - 26
	if _menu != null and Engine.get_process_frames() != _menu_frame and Input.is_action_just_pressed("pause"):
		close_menu()
	if world == null or world.player == null:
		return
	damage_flash.color.a = move_toward(damage_flash.color.a, 0.0, delta * 1.6)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_panel.visible = false
	if not _hud_visible:
		return
	var p: Protagonist = world.player
	var ratio := clampf(p.health / p.max_health, 0.0, 1.0)
	health_fill.size.x = 214.0 * ratio
	health_fill.color = Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.85, 0.35), ratio)
	if ratio < 0.25:
		health_fill.color = health_fill.color.lerp(Color.WHITE, absf(sin(Time.get_ticks_msec() * 0.008)) * 0.4)
	health_text.text = "%d / %d" % [ceili(p.health), int(p.max_health)]
	_shown_money = move_toward(_shown_money, Game.money, maxf(20.0, absf(Game.money - _shown_money) * 4.0) * delta)
	money_label.text = "$ %s" % _fmt_money(int(_shown_money))
	boost_label.text = "Brown Boost x%d" % Game.boosts
	var sp: String = p.data["special"]
	if p.special_time > 0.0:
		special_label.text = "%s ATTIVO  %ds" % [sp, ceili(p.special_time)]
	elif p.special_cd > 0.0:
		special_label.text = "%s in ricarica  %ds" % [sp, ceili(p.special_cd)]
	else:
		special_label.text = "%s pronto" % sp
	var sb: TouchButton = touch.buttons["special"]
	sb.set_label(sp)
	sb.set_cooldown(clampf(p.special_cd / (12.0 if p.char_id == "mike" else 20.0), 0.0, 1.0))
	touch.buttons["use_boost"].set_badge(str(Game.boosts) if Game.boosts > 0 else "")
	var wdef: Dictionary = Game.WEAPONS[Game.current_weapon]
	if Game.current_weapon == "fists":
		weapon_label.text = "PUGNI"
		touch.buttons["attack"].set_label("PUGNO")
	else:
		weapon_label.text = "%s   %d" % [wdef["name"], Game.ammo()]
		touch.buttons["attack"].set_label("SPARA")
	touch.buttons["weapon_next"].set_badge(str(Game.ammo()) if Game.current_weapon != "fists" else "")
	var ab: TouchButton = touch.buttons["aim"]
	ab.visible = touch.mode == "foot" and Game.current_weapon != "fists"
	ab.set_highlight(world.aiming)
	ab.set_label("MIRA" if not world.aiming else "LIBERA")
	crosshair.visible = world.aiming
	if world.aiming:
		crosshair.set_on_target(bool(world.crosshair["on_target"]))
	if world.police != null:
		stars.count = world.police.stars
		stars.blink = world.police.stars > 0 and not world.police.seen
	if world.mp and world.net != null:
		score_label.text = world.net.score_text()
	else:
		score_label.text = ""
	if p.in_vehicle():
		var car: Car = p.vehicle
		speed_panel.visible = true
		speed_label.text = "%d km/h" % int(absf(car.speed) * 3.6)
		car_fill.size.x = 158.0 * clampf(car.health / car.max_health, 0.0, 1.0)
		touch.buttons["vehicle"].set_label("ESCI")
		touch.buttons["vehicle"].set_highlight(false)
	else:
		speed_panel.visible = false
		var near: Car = world.nearest_car(p.global_position, 4.6)
		touch.buttons["vehicle"].set_label("ENTRA" if near != null else "AUTO")
		touch.buttons["vehicle"].set_highlight(near != null)
	var d := CityData.district_at(world.player_pos())
	if d != _district:
		_district = d
		_district_t = 3.0
		district_label.text = d
	if _district_t > 0.0:
		_district_t -= delta
		district_label.modulate.a = clampf(_district_t, 0.0, 1.0)


static func _fmt_money(v: int) -> String:
	var s := str(v)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out


func set_hud_visible(v: bool) -> void:
	_hud_visible = v
	hud_root.visible = v
	refresh_controls()


func refresh_controls() -> void:
	if touch == null:
		return
	if not _hud_visible or world == null or world.state != "play" or _menu != null:
		touch.set_mode("hidden")
	elif world.lock_count > 0:
		touch.set_mode("cutscene")
	elif world.player != null and world.player.in_vehicle():
		touch.set_mode("car")
	else:
		touch.set_mode("foot")
	hud_root.visible = _hud_visible


func on_character_changed() -> void:
	if world == null or world.player == null:
		return
	var p: Protagonist = world.player
	portrait.col = p.data["color"]
	portrait.letter = p.data["initial"]
	portrait.queue_redraw()
	name_label.text = String(p.data["name"]).to_upper()
	name_label.add_theme_color_override("font_color", p.data["color"].lightened(0.35))
	refresh_controls()


func set_objective(text: String) -> void:
	obj_label.text = text
	obj_panel.visible = text != ""


func set_extra(text: String) -> void:
	extra_label.text = text


func set_timer(t: float) -> void:
	if t < 0.0:
		timer_label.text = ""
		return
	var secs := ceili(t)
	timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25) if t < 10.0 else Color.WHITE)


func toast(text: String, dur: float = 3.0) -> void:
	toast_label.text = text
	toast_panel.visible = true
	_toast_t = dur
	if Game.test_mode:
		print("[HUD] ", text)


func show_message(title: String, sub: String = "", c: Color = UIKit.ACCENT, dur: float = 3.0) -> void:
	big_title.text = title
	big_title.add_theme_color_override("font_color", c)
	big_sub.text = sub
	if _big_tween != null and _big_tween.is_valid():
		_big_tween.kill()
	big_title.modulate.a = 1.0
	big_sub.modulate.a = 1.0
	big_title.scale = Vector2.ONE
	_big_tween = create_tween()
	_big_tween.tween_interval(dur)
	_big_tween.tween_property(big_title, "modulate:a", 0.0, 0.6)
	_big_tween.parallel().tween_property(big_sub, "modulate:a", 0.0, 0.6)
	if Game.test_mode:
		print("[HUD] ", title, " - ", sub)


func flash_stars() -> void:
	stars.flash_t = 1.5


func show_busted(on: bool) -> void:
	busted_overlay.visible = on
	if on:
		touch.set_mode("cutscene")


func flash_damage() -> void:
	damage_flash.color.a = 0.35


func flash_special() -> void:
	var c: Color = world.player.data["color"]
	damage_flash.color = Color(c.r, c.g, c.b, 0.3)


func show_ko(on: bool) -> void:
	ko_overlay.visible = on
	if on:
		touch.set_mode("cutscene")


func fade(to_black: bool, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0 if to_black else 0.0, dur)
	await tw.finished


func fade_instant(black: bool) -> void:
	fade_rect.color.a = 1.0 if black else 0.0


func show_skip(on: bool, cb: Callable) -> void:
	skip_btn.visible = on
	_skip_cb = cb


# ---------------------------------------------------------------- menu

func _open_menu() -> Control:
	close_menu()
	# In multiplayer il mondo non si ferma mai.
	get_tree().paused = world == null or not world.mp
	touch.release_all()
	Sfx.set_engine(false)
	_menu = UIKit.full(Control.new())
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_frame = Engine.get_process_frames()
	menu_layer.add_child(_menu)
	_menu.add_child(UIKit.dim(0.6))
	return _menu


func close_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	get_tree().paused = false
	refresh_controls()


func is_menu_open() -> bool:
	return _menu != null


func open_pause() -> void:
	if world.mp:
		_open_mp_pause()
		return
	var m := _open_menu()
	var panel := UIKit.panel()
	UIKit.centered(m, panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var t := UIKit.label("PAUSA", 44, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var mins := int(Game.play_time / 60.0)
	var info := UIKit.label("Missioni %d/%d   ·   $%s   ·   Piume %d/%d   ·   %dh %02dm" % [
		Game.missions_done, Game.TOTAL_MISSIONS, _fmt_money(Game.money), Game.feathers.size(), Game.TOTAL_FEATHERS,
		mins / 60, mins % 60], 18, Color(0.85, 0.85, 0.9), 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var entries := [
		["RIPRENDI", close_menu],
		["MAPPA", open_map],
		["SALVA PARTITA", _on_save_pressed],
		["CARICA PARTITA", _on_load_pressed],
		["IMPOSTAZIONI", _settings_from_pause],
		["COMANDI", _help_from_pause],
		["MENU PRINCIPALE", _on_main_menu_pressed],
	]
	for e in entries:
		var b := UIKit.button(e[0], 24, Vector2(300, 60))
		b.pressed.connect(e[1])
		grid.add_child(b)


func _open_mp_pause() -> void:
	var m := _open_menu()
	var panel := UIKit.panel()
	UIKit.centered(m, panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var t := UIKit.label("MULTIPLAYER LAN", 40, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var info := UIKit.label(world.net.session_info() if world.net != null else "", 19, Color(0.85, 0.85, 0.9), 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var entries := [
		["RIPRENDI", close_menu],
		["GIOCATORI", open_scoreboard],
		["MAPPA", open_map],
		["IMPOSTAZIONI", _settings_from_pause],
		["COMANDI", _help_from_pause],
		["ESCI DALLA PARTITA", _on_main_menu_pressed],
	]
	for e in entries:
		var b := UIKit.button(e[0], 24, Vector2(300, 60))
		b.pressed.connect(e[1])
		grid.add_child(b)


func open_scoreboard() -> void:
	if world.net == null:
		return
	var m := _open_menu()
	var panel := UIKit.panel()
	UIKit.centered(m, panel)
	var v := UIKit.vbox(8)
	panel.add_child(v)
	var t := UIKit.label("GIOCATORI", 38, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var mode := UIKit.label(world.net.mode_text(), 20, Color(0.85, 0.85, 0.9), 0)
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mode)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	v.add_child(grid)
	for h in ["GIOCATORE", "PERSONAGGIO", "K.O. FATTI", "K.O. SUBITI"]:
		grid.add_child(UIKit.label(h, 18, UIKit.ACCENT, 3))
	for row in world.net.scoreboard():
		var c: Color = Game.CHARACTERS.get(row["char"], Game.CHARACTERS["mike"])["color"]
		grid.add_child(UIKit.label(row["name"] + ("  (tu)" if row["me"] else ""), 20, c.lightened(0.3), 3))
		grid.add_child(UIKit.label(Game.CHARACTERS.get(row["char"], Game.CHARACTERS["mike"])["name"], 18, Color.WHITE, 3))
		grid.add_child(UIKit.label(str(row["kills"]), 20, Color.WHITE, 3))
		grid.add_child(UIKit.label(str(row["deaths"]), 20, Color.WHITE, 3))
	var b := UIKit.button("CHIUDI", 22, Vector2(200, 54))
	b.pressed.connect(close_menu)
	var cc := CenterContainer.new()
	cc.add_child(b)
	v.add_child(cc)


func open_armory() -> void:
	var m := _open_menu()
	var panel := UIKit.panel()
	UIKit.centered(m, panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var t := UIKit.label("ARMERIA DI PORT ARDENA", 36, Color(1.0, 0.6, 0.25), 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var money := UIKit.label("Contanti: $%s" % _fmt_money(Game.money), 22, Color(0.45, 0.95, 0.45), 4)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(money)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for id in Game.WEAPON_ORDER:
		if id == "fists":
			continue
		var def: Dictionary = Game.WEAPONS[id]
		var owned := Game.weapons.has(id)
		grid.add_child(UIKit.label(def["name"], 22, Color.WHITE, 3))
		grid.add_child(UIKit.label("Colpi: %d" % int(Game.weapons.get(id, 0)) if owned else "Danno %d · Gittata %dm" % [int(def["damage"]) * int(def["pellets"]), int(def["range"])], 18, Color(0.8, 0.8, 0.85), 0))
		var price: int = def["ammo_price"] if owned else def["price"]
		var label_text := ("MUNIZIONI +%d  $%d" % [int(def["ammo_pack"]), price]) if owned else ("COMPRA  $%d" % price)
		var b := UIKit.button(label_text, 20, Vector2(270, 50))
		b.disabled = Game.money < price
		b.pressed.connect(_buy_weapon.bind(id, price))
		grid.add_child(b)
	var note := UIKit.label("Le armi sparano con mira automatica sul bersaglio più vicino davanti a te.", 16, Color(0.75, 0.75, 0.8), 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var close := UIKit.button("ESCI DAL NEGOZIO", 22, Vector2(280, 54))
	close.pressed.connect(close_menu)
	var cc := CenterContainer.new()
	cc.add_child(close)
	v.add_child(cc)


func _buy_weapon(id: String, price: int) -> void:
	if Game.money < price:
		return
	Game.add_money(-price)
	Game.give_weapon(id, int(Game.WEAPONS[id]["ammo_pack"]))
	Game.equip_weapon(id)
	Sfx.play("cash")
	open_armory()


func _on_save_pressed() -> void:
	world.save_now()


func _on_load_pressed() -> void:
	if Game.has_save():
		world.main.load_saved_game()
	else:
		toast("Nessun salvataggio trovato.", 2.0)


func _on_main_menu_pressed() -> void:
	world.main.back_to_menu()


func _settings_from_pause() -> void:
	var m := _open_menu()
	Menus.settings(m, func(): open_pause())


func _help_from_pause() -> void:
	var m := _open_menu()
	Menus.help(m, func(): open_pause())


func open_map() -> void:
	var m := _open_menu()
	var panel := UIKit.panel(Color(0.05, 0.05, 0.07, 0.95))
	panel.anchor_left = 0.04
	panel.anchor_right = 0.96
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	m.add_child(panel)
	var v := UIKit.vbox(8)
	panel.add_child(v)
	var h := UIKit.hbox(12)
	v.add_child(h)
	var t := UIKit.label("MAPPA DI PORT ARDENA", 30, UIKit.ACCENT, 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var close := UIKit.button("CHIUDI", 22, Vector2(160, 50))
	close.pressed.connect(close_menu)
	h.add_child(close)
	var mm := Minimap.new()
	mm.world = world
	mm.full = true
	mm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(mm)


func open_char_select() -> void:
	if world.mp:
		open_scoreboard()
		return
	if world.missions.current != null and not world.missions.current.allow_switch:
		toast("Non puoi cambiare personaggio durante una missione.", 2.0)
		return
	var m := _open_menu()
	var v := UIKit.vbox(18)
	UIKit.centered(m, v)
	var t := UIKit.label("CAMBIA PROTAGONISTA", 38, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := UIKit.hbox(16)
	v.add_child(h)
	for id in Game.CHAR_ORDER:
		var p: Protagonist = world.chars[id]
		var d: Dictionary = p.data
		var where := CityData.district_at(p.vehicle.global_position if p.in_vehicle() else p.global_position)
		var txt := "%s\n%s\n\nSalute %d/%d\nSpeciale: %s\n%s" % [d["name"].to_upper(), d["role"], ceili(p.health), int(p.max_health), d["special"], where]
		var b := UIKit.button(txt, 20, Vector2(270, 230))
		b.add_theme_stylebox_override("normal", UIKit.style(Color(d["color"]).darkened(0.55), 16, d["color"], 3))
		b.add_theme_stylebox_override("hover", UIKit.style(Color(d["color"]).darkened(0.35), 16, Color.WHITE, 3))
		if p == world.player:
			b.disabled = true
			b.text = txt + "\n(in uso)"
		b.pressed.connect(func():
			close_menu()
			world.request_switch(id))
		h.add_child(b)
	var close := UIKit.button("ANNULLA", 22, Vector2(200, 54))
	close.pressed.connect(close_menu)
	var cc := CenterContainer.new()
	cc.add_child(close)
	v.add_child(cc)


func open_final_choice(cb: Callable) -> void:
	var m := _open_menu()
	var v := UIKit.vbox(18)
	UIKit.centered(m, v)
	var t := UIKit.label("CHI AFFRONTERÀ DEX?", 40, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UIKit.label("Scegli il protagonista per la missione finale", 22, Color.WHITE, 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var h := UIKit.hbox(16)
	v.add_child(h)
	var perks := {
		"mike": "Auto sportiva + NITRO.\nRaggiunge Dex in un lampo.",
		"tom": "+30 secondi sul timer.\nL'auto di Dex è più lenta.",
		"norman": "Colpi devastanti.\nPiù salute contro le guardie.",
	}
	for id in Game.CHAR_ORDER:
		var d: Dictionary = Game.CHARACTERS[id]
		var b := UIKit.button("%s\n\n%s" % [d["name"].to_upper(), perks[id]], 20, Vector2(280, 210))
		b.add_theme_stylebox_override("normal", UIKit.style(Color(d["color"]).darkened(0.55), 16, d["color"], 3))
		b.pressed.connect(func():
			close_menu()
			cb.call(id))
		h.add_child(b)
	var later := UIKit.button("NON ANCORA", 22, Vector2(220, 54))
	later.pressed.connect(func():
		close_menu()
		cb.call(""))
	var cc := CenterContainer.new()
	cc.add_child(later)
	v.add_child(cc)


func show_credits() -> void:
	var m := _open_menu()
	var v := UIKit.vbox(10)
	UIKit.centered(m, v)
	var lines := [
		["FINE", 70, UIKit.ACCENT],
		["Aprilia Simulator 2026", 34, Color.WHITE],
		["La valigetta del Corvo è stata recuperata.", 24, Color(0.9, 0.9, 0.9)],
		["Silas Crane è stato smascherato e Port Ardena è un po' più pulita.", 22, Color(0.85, 0.85, 0.85)],
		["", 12, Color.WHITE],
		["Mike Vargo  ·  Tom Pearl  ·  Norman Summerton", 26, Color(1.0, 0.85, 0.5)],
		["Gioco realizzato con Godot Engine (MIT) · grafica e audio procedurali originali", 18, Color(0.75, 0.75, 0.8)],
		["Grazie per aver giocato!", 28, Color(0.5, 1.0, 0.6)],
	]
	for l in lines:
		var lab := UIKit.label(l[0], l[1], l[2], 6)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
	var b := UIKit.button("CONTINUA A ESPLORARE", 26, Vector2(420, 66))
	b.pressed.connect(close_menu)
	var cc := CenterContainer.new()
	cc.add_child(b)
	v.add_child(cc)
	Sfx.music(true, -8.0)
