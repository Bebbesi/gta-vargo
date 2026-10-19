class_name MainMenu
extends Control
## Menu principale sopra la città in volo d'uccello.

var main: Node
var content: Control
var discovery: LanDiscovery
var _mp_char := "mike"
var _mp_mode := "free"
var _hosts_box: VBoxContainer
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _notice: String = ""


func _ready() -> void:
	UIKit.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_home()


func show_notice(msg: String) -> void:
	_notice = msg
	_show_home()


func _clear() -> void:
	if discovery != null:
		discovery.queue_free()
		discovery = null
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
	var mpb := UIKit.button("MULTIPLAYER LAN", 24, Vector2(360, 58))
	mpb.pressed.connect(_show_multiplayer)
	right.add_child(mpb)
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
	if _notice != "":
		var np := UIKit.panel(Color(0.45, 0.08, 0.06, 0.92), 12)
		np.anchor_left = 0.05
		np.anchor_top = 0.62
		np.offset_top = -20
		var nl := UIKit.label(_notice, 19, Color.WHITE, 0)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(520, 0)
		np.add_child(nl)
		content.add_child(np)
		_notice = ""
	var ver := UIKit.label("v" + Game.VERSION, 16, Color(1, 1, 1, 0.5), 3)
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


# ---------------------------------------------------------------- multiplayer

func _show_multiplayer() -> void:
	_clear()
	content.add_child(UIKit.dim(0.6))
	var panel := UIKit.panel()
	UIKit.centered(content, panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var t := UIKit.label("MULTIPLAYER IN RETE LOCALE", 34, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UIKit.label("Fino a 4 giocatori sulla stessa rete Wi-Fi  ·  il tuo IP: %s" % NetSession.local_ip(), 18, Color(0.85, 0.85, 0.9), 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := UIKit.hbox(12)
	v.add_child(row)
	row.add_child(UIKit.label("Nome", 22, Color.WHITE, 3))
	_name_edit = LineEdit.new()
	_name_edit.text = Game.player_name()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(260, 48)
	_name_edit.add_theme_font_size_override("font_size", 22)
	row.add_child(_name_edit)
	row.add_child(UIKit.label("   Personaggio", 22, Color.WHITE, 3))
	var cbtns: Array[Button] = []
	for id in Game.CHAR_ORDER:
		var b := UIKit.button(Game.CHARACTERS[id]["short"], 20, Vector2(120, 48))
		b.toggle_mode = true
		b.button_pressed = id == _mp_char
		b.add_theme_stylebox_override("pressed", UIKit.style(Game.CHARACTERS[id]["color"], 12, Color.WHITE, 2))
		cbtns.append(b)
		row.add_child(b)
	for i in cbtns.size():
		cbtns[i].pressed.connect(func(): _pick_char(i, cbtns))
	var host_row := UIKit.hbox(12)
	v.add_child(host_row)
	host_row.add_child(UIKit.label("Nuova partita", 22, Color.WHITE, 3))
	var mbtns: Array[Button] = []
	for m in [["free", "LIBERA"], ["deathmatch", "DEATHMATCH (10 K.O.)"]]:
		var mb := UIKit.button(m[1], 20, Vector2(250 if m[0] == "deathmatch" else 140, 48))
		mb.toggle_mode = true
		mb.button_pressed = m[0] == _mp_mode
		mbtns.append(mb)
		host_row.add_child(mb)
	mbtns[0].pressed.connect(func(): _pick_mode("free", mbtns))
	mbtns[1].pressed.connect(func(): _pick_mode("deathmatch", mbtns))
	var hb := UIKit.button("CREA PARTITA", 22, Vector2(240, 48))
	hb.pressed.connect(_host_game)
	host_row.add_child(hb)
	v.add_child(UIKit.label("Partite trovate sulla rete:", 20, UIKit.ACCENT, 3))
	_hosts_box = UIKit.vbox(6)
	v.add_child(_hosts_box)
	var ip_row := UIKit.hbox(12)
	v.add_child(ip_row)
	ip_row.add_child(UIKit.label("Oppure collegati all'IP", 20, Color.WHITE, 3))
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.10"
	_ip_edit.custom_minimum_size = Vector2(240, 48)
	_ip_edit.add_theme_font_size_override("font_size", 22)
	ip_row.add_child(_ip_edit)
	var jb := UIKit.button("CONNETTI", 22, Vector2(180, 48))
	jb.pressed.connect(func(): _join_game(_ip_edit.text.strip_edges()))
	ip_row.add_child(jb)
	var back := UIKit.button("INDIETRO", 22, Vector2(220, 52))
	back.pressed.connect(_show_home)
	var cc := CenterContainer.new()
	cc.add_child(back)
	v.add_child(cc)
	discovery = LanDiscovery.new()
	add_child(discovery)
	discovery.hosts_changed.connect(_refresh_hosts)
	if not discovery.start_listen():
		pass
	_refresh_hosts()


func _pick_char(i: int, btns: Array[Button]) -> void:
	_mp_char = Game.CHAR_ORDER[i]
	for j in btns.size():
		btns[j].set_pressed_no_signal(j == i)


func _pick_mode(m: String, btns: Array[Button]) -> void:
	_mp_mode = m
	btns[0].set_pressed_no_signal(m == "free")
	btns[1].set_pressed_no_signal(m == "deathmatch")


func _refresh_hosts() -> void:
	if _hosts_box == null or not is_instance_valid(_hosts_box):
		return
	for c in _hosts_box.get_children():
		c.queue_free()
	if discovery == null or discovery.hosts.is_empty():
		var msg := "Ricerca in corso... (l'host deve aver premuto CREA PARTITA)"
		if discovery != null and not discovery.listening:
			msg = "Ricerca automatica non disponibile su questo dispositivo: usa l'IP."
		_hosts_box.add_child(UIKit.label(msg, 18, Color(0.75, 0.75, 0.8), 0))
		return
	for ip in discovery.hosts:
		var h: Dictionary = discovery.hosts[ip]
		var mode_name := "Deathmatch" if h.get("mode", "") == "deathmatch" else "Libera"
		var txt := "%s  ·  %d/%d giocatori  ·  %s  ·  %s" % [h.get("name", "?"), int(h.get("players", 1)), int(h.get("max", 4)), mode_name, ip]
		var b := UIKit.button(txt, 19, Vector2(760, 46))
		if str(h.get("version", "")) != Game.VERSION:
			b.disabled = true
			b.text = txt + "  (versione %s)" % h.get("version", "?")
		b.pressed.connect(_join_game.bind(str(ip), int(h.get("port", NetSession.PORT))))
		_hosts_box.add_child(b)


func _save_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n != "":
		Game.settings["player_name"] = n.substr(0, 16)


func _host_game() -> void:
	_save_name()
	main.start_multiplayer({"host": true, "char": _mp_char, "mode": _mp_mode, "port": NetSession.PORT})


func _join_game(ip: String, port: int = NetSession.PORT) -> void:
	if ip == "":
		_ip_edit.placeholder_text = "Scrivi l'IP dell'host"
		return
	_save_name()
	main.start_multiplayer({"host": false, "ip": ip, "char": _mp_char, "port": port})


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
