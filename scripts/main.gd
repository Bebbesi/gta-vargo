extends Node
## Punto d'ingresso: costruisce il mondo una sola volta, mostra il menu
## principale e gestisce nuova partita, continua, ritorno al menu e il tasto
## "indietro" di Android.

var world: World
var ui: CanvasLayer
var menu: MainMenu
var loading: Control


func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 40
	add_child(ui)
	loading = _make_loading()
	ui.add_child(loading)
	await get_tree().process_frame
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var mp_test := ""
	var mp_port := NetSession.PORT
	for a in args:
		if a.begins_with("--mp-test="):
			mp_test = a.get_slice("=", 1)
		elif a.begins_with("--mp-port="):
			mp_port = int(a.get_slice("=", 1))
	if mp_test != "":
		Game.pending_mp = {"host": mp_test == "host", "ip": "127.0.0.1", "port": mp_port,
			"char": "mike" if mp_test == "host" else "tom", "mode": "deathmatch"}
		Game.settings["player_name"] = "Host" if mp_test == "host" else "Ospite"
	world = World.new()
	world.name = "World"
	world.main = self
	add_child(world)
	world.build()
	loading.queue_free()
	if not Game.pending_mp.is_empty():
		world.start_multiplayer()
		if mp_test != "":
			var tester: Node = load("res://tests/mp_test.gd").new()
			tester.set("world", world)
			tester.set("role", mp_test)
			add_child(tester)
		return
	if Game.test_mode:
		var runner: Node = load("res://tests/test_runner.gd").new()
		runner.set("world", world)
		add_child(runner)
		return
	if args.has("--screenshots"):
		var tour: Node = load("res://tests/screenshot_tour.gd").new()
		tour.set("world", world)
		tour.set("main", self)
		add_child(tour)
		return
	if Game.pending_continue:
		Game.pending_continue = false
		if Game.load_game():
			world.continue_game()
			return
	show_main_menu()


func _make_loading() -> Control:
	var c := UIKit.full(Control.new())
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	UIKit.full(bg)
	c.add_child(bg)
	var v := UIKit.vbox(8)
	UIKit.centered(c, v)
	var t := UIKit.label("APRILIA SIMULATOR 2026", 54, UIKit.ACCENT, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := UIKit.label("Caricamento di Port Ardena...", 24, Color.WHITE, 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return c


func show_main_menu() -> void:
	world.enter_menu_mode()
	menu = MainMenu.new()
	menu.main = self
	ui.add_child(menu)
	if Game.pending_message != "":
		menu.show_notice(Game.pending_message)
		Game.pending_message = ""


func _close_menu() -> void:
	if menu != null:
		menu.queue_free()
		menu = null


func start_new_game() -> void:
	_close_menu()
	Game.new_game()
	world.start_new_game()


func continue_game() -> void:
	if Game.load_game():
		_close_menu()
		world.continue_game()


## Avvia una partita multiplayer: la scena viene ricaricata in modalità rete.
func start_multiplayer(params: Dictionary) -> void:
	Game.pending_mp = params
	Game.pending_continue = false
	Game.save_settings()
	_reload()


func load_saved_game() -> void:
	Game.pending_continue = true
	_reload()


func back_to_menu() -> void:
	Game.pending_continue = false
	Game.pending_mp = {}
	_reload()


func _reload() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Sfx.set_engine(false)
	Sfx.music(false)
	get_tree().reload_current_scene()


func _notification(what: int) -> void:
	if world == null or world.hud == null:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if world.state == "play":
			if world.hud.is_menu_open():
				world.hud.close_menu()
			else:
				world.hud.open_pause()
		elif menu != null:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if world.state == "play" and not world.hud.is_menu_open():
			world.hud.open_pause()
