class_name MainMenu
extends Control
## Menu principale sopra la città in volo d'uccello.

var main: Node
var content: Control


func _ready() -> void:
	UIKit.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_home()


func _clear() -> void:
	if content != null:
		content.queue_free()
	content = UIKit.full(Control.new())
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)


func _show_home() -> void:
	_clear()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.45)
	UIKit.full(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(shade)
	var left := UIKit.vbox(6)
	left.anchor_left = 0.05
	left.anchor_top = 0.08
	left.anchor_right = 0.6
	left.anchor_bottom = 0.6
	content.add_child(left)
	var gta := UIKit.label("GTA", 120, UIKit.ACCENT, 16)
	left.add_child(gta)
	var tl := UIKit.label("THREE LEGENDS", 54, Color.WHITE, 12)
	left.add_child(tl)
	var sub := UIKit.label("Mike Vargo  ·  Tom Pearl  ·  Norman Summerton", 24, Color(1.0, 0.85, 0.6), 6)
	left.add_child(sub)
	var tag := UIKit.label("Port Ardena. Una valigetta scomparsa. Un traditore tra le nuvole.", 20, Color(0.9, 0.9, 0.95), 5)
	left.add_child(tag)

	var right := UIKit.vbox(10)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.5
	right.anchor_bottom = 0.5
	right.offset_left = -400
	right.offset_right = -40
	right.offset_top = -230
	right.offset_bottom = 260
	content.add_child(right)
	var cont := UIKit.button("CONTINUA", 28, Vector2(360, 66))
	cont.disabled = not Game.has_save()
	cont.pressed.connect(func(): main.continue_game())
	right.add_child(cont)
	if Game.has_save():
		var info := UIKit.label(Game.save_info(), 17, Color(0.8, 0.8, 0.85), 4)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(info)
	var newg := UIKit.button("NUOVA PARTITA", 28, Vector2(360, 66))
	newg.pressed.connect(_on_new_game)
	right.add_child(newg)
	var sett := UIKit.button("IMPOSTAZIONI", 24, Vector2(360, 58))
	sett.pressed.connect(_show_settings)
	right.add_child(sett)
	var helpb := UIKit.button("COME SI GIOCA", 24, Vector2(360, 58))
	helpb.pressed.connect(_show_help)
	right.add_child(helpb)
	var cred := UIKit.button("CREDITI", 24, Vector2(360, 58))
	cred.pressed.connect(_show_credits)
	right.add_child(cred)
	var quit := UIKit.button("ESCI", 24, Vector2(360, 58))
	quit.pressed.connect(func(): get_tree().quit())
	right.add_child(quit)

	var cards := UIKit.hbox(14)
	cards.anchor_left = 0.05
	cards.anchor_top = 1.0
	cards.anchor_bottom = 1.0
	cards.offset_top = -210
	cards.offset_bottom = -24
	content.add_child(cards)
	for id in Game.CHAR_ORDER:
		var d: Dictionary = Game.CHARACTERS[id]
		var p := UIKit.panel(Color(d["color"]).darkened(0.6), 14)
		p.custom_minimum_size = Vector2(250, 170)
		var v := UIKit.vbox(2)
		p.add_child(v)
		v.add_child(UIKit.label(String(d["name"]).to_upper(), 22, Color(d["color"]).lightened(0.4), 4))
		v.add_child(UIKit.label(d["role"], 18, Color.WHITE, 3))
		var desc := UIKit.label(d["desc"], 15, Color(0.9, 0.9, 0.9), 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(220, 0)
		v.add_child(desc)
		v.add_child(UIKit.label("Speciale: " + String(d["special"]), 16, UIKit.ACCENT, 3))
		cards.add_child(p)
	var ver := UIKit.label("v1.0.0", 16, Color(1, 1, 1, 0.5), 3)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -90
	ver.offset_top = -34
	content.add_child(ver)


func _on_new_game() -> void:
	if not Game.has_save():
		main.start_new_game()
		return
	_clear()
	content.add_child(UIKit.dim(0.5))
	var panel := UIKit.panel()
	UIKit.centered(content, panel)
	var v := UIKit.vbox(14)
	panel.add_child(v)
	var l := UIKit.label("Iniziare una nuova partita?\nIl salvataggio esistente verrà sovrascritto\nal primo salvataggio automatico.", 24, Color.WHITE, 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := UIKit.hbox(14)
	v.add_child(h)
	var yes := UIKit.button("SÌ, NUOVA PARTITA", 22, Vector2(280, 58))
	yes.pressed.connect(func(): main.start_new_game())
	h.add_child(yes)
	var no := UIKit.button("ANNULLA", 22, Vector2(200, 58))
	no.pressed.connect(_show_home)
	h.add_child(no)


func _show_settings() -> void:
	_clear()
	content.add_child(UIKit.dim(0.5))
	Menus.settings(content, _show_home)


func _show_help() -> void:
	_clear()
	content.add_child(UIKit.dim(0.5))
	Menus.help(content, _show_home)


func _show_credits() -> void:
	_clear()
	content.add_child(UIKit.dim(0.6))
	var panel := UIKit.panel()
	UIKit.centered(content, panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var t := UIKit.label("CREDITI", 38, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var txt := """GTA: Three Legends — versione 1.0.0
Storia, personaggi e dialoghi originali.
Programmazione in GDScript su Godot Engine 4 (licenza MIT, godotengine.org).
Modelli 3D low-poly, città, effetti e audio generati proceduralmente dal codice del gioco:
nessun asset esterno o protetto da copyright.

Progetto amatoriale non affiliato a Rockstar Games o Take-Two Interactive.
I Brown Boost sono oggetti immaginari del gioco."""
	var l := UIKit.label(txt, 20, Color(0.95, 0.95, 0.95), 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var b := UIKit.button("INDIETRO", 24, Vector2(260, 58))
	b.pressed.connect(_show_home)
	var cc := CenterContainer.new()
	cc.add_child(b)
	v.add_child(cc)
