class_name Menus
extends RefCounted
## Pannelli riutilizzabili dal menu principale e dalla pausa.


static func settings(parent: Control, on_close: Callable) -> void:
	var panel := UIKit.panel()
	UIKit.centered(parent, panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var t := UIKit.label("IMPOSTAZIONI", 38, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	_slider_row(grid, "Volume generale", "master", 0.0, 1.0, 0.05)
	_slider_row(grid, "Musica", "music", 0.0, 1.0, 0.05)
	_slider_row(grid, "Effetti sonori", "sfx", 0.0, 1.0, 0.05)
	_slider_row(grid, "Sensibilità visuale", "cam_sens", 0.3, 2.5, 0.1)
	_slider_row(grid, "Opacità comandi touch", "touch_opacity", 0.25, 1.0, 0.05)
	grid.add_child(UIKit.label("Qualità grafica", 22, Color.WHITE, 3))
	var qh := UIKit.hbox(8)
	var names := ["BASSA", "MEDIA", "ALTA"]
	var qbuttons: Array[Button] = []
	for i in 3:
		var b := UIKit.button(names[i], 20, Vector2(104, 48))
		b.toggle_mode = true
		b.button_pressed = int(Game.settings["quality"]) == i
		qbuttons.append(b)
		qh.add_child(b)
	for i in 3:
		qbuttons[i].pressed.connect(func(): Menus._on_quality(i, qbuttons))
	grid.add_child(qh)
	_check_row(grid, "Inverti asse verticale", "invert_y")
	_check_row(grid, "Vibrazione", "vibration")
	_check_row(grid, "Mostra FPS", "show_fps")
	var note := UIKit.label("Le modifiche a traffico e pedoni si applicano alla prossima partita.", 16, Color(0.75, 0.75, 0.8), 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var close := UIKit.button("INDIETRO", 24, Vector2(260, 58))
	close.pressed.connect(on_close)
	var cc := CenterContainer.new()
	cc.add_child(close)
	v.add_child(cc)


static func _on_quality(i: int, qbuttons: Array[Button]) -> void:
	Game.set_setting("quality", i)
	for j in qbuttons.size():
		qbuttons[j].set_pressed_no_signal(j == i)


static func _slider_row(grid: GridContainer, title: String, key: String, mn: float, mx: float, step: float) -> void:
	grid.add_child(UIKit.label(title, 22, Color.WHITE, 3))
	var s := UIKit.slider(mn, mx, step, float(Game.settings[key]))
	s.value_changed.connect(func(val: float): Game.set_setting(key, val))
	grid.add_child(s)


static func _check_row(grid: GridContainer, title: String, key: String) -> void:
	grid.add_child(UIKit.label(title, 22, Color.WHITE, 3))
	var c := CheckButton.new()
	c.button_pressed = bool(Game.settings[key])
	c.custom_minimum_size = Vector2(80, 44)
	c.toggled.connect(func(on: bool): Game.set_setting(key, on))
	grid.add_child(c)


static func help(parent: Control, on_close: Callable) -> void:
	var panel := UIKit.panel()
	UIKit.centered(parent, panel)
	var v := UIKit.vbox(8)
	panel.add_child(v)
	var t := UIKit.label("COME SI GIOCA", 36, UIKit.ACCENT, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var text := """TOUCH
•  Joystick a sinistra: muoviti (in auto: sterza).  Trascina a destra: ruota la visuale.
•  PUGNO, SALTA, ENTRA/ESCI dall'auto, GAS e FRENO (tieni premuto per la retromarcia).
•  CAMBIA: passa da Mike, Tom e Norman.  Speciale: NITRO, ANALISI o FURIA.
•  BOOST: consuma un Brown Boost conservato e recupera salute.
•  ARMA: cambia arma. Con un'arma in mano PUGNO diventa SPARA (mira automatica, tieni premuto).

TASTIERA (PC)
•  WASD/frecce muovi e guidi · Spazio salta · J pugno · F auto · R speciale
•  B Brown Boost · E/X cambia arma · Tab/Q cambia personaggio (1-2-3) · H clacson · M mappa · Esc pausa

POLIZIA
•  I crimini fanno salire le stelle (fino a 5): pattuglie, agenti armati, SWAT ed elicottero.
•  Per seminarla esci dal cerchio di ricerca sulla mappa e resta fuori vista; oppure fai riverniciare l'auto da Gus.
•  Con 1 stella, se un agente ti blocca a piedi vieni arrestato: multa e armi sequestrate.

CONSIGLI
•  Le missioni sono indicate sulla minimappa con una lettera: S storia, M Mike, T Tom, N Norman.
•  Il cerchio verde SALVA davanti al rifugio salva la partita e ripristina la salute.
•  Se vai K.O. torni al rifugio (o all'ultimo checkpoint) pagando $100 di spese mediche.
•  Armi in vendita all'ARMERIA ($ sulla mappa) e sparse per la città.
•  MULTIPLAYER LAN: dal menu principale crea una partita o unisciti a quella di un amico sulla stessa Wi-Fi."""
	var l := UIKit.label(text, 19, Color(0.95, 0.95, 0.95), 0)
	l.custom_minimum_size = Vector2(900, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var close := UIKit.button("INDIETRO", 24, Vector2(260, 58))
	close.pressed.connect(on_close)
	var cc := CenterContainer.new()
	cc.add_child(close)
	v.add_child(cc)
