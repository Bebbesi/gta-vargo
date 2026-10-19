extends Node
## Giro fotografico automatico per verificare la grafica (richiede un display,
## es. xvfb):  godot --rendering-driver opengl3 --path . -- --screenshots --shot-dir <dir>

var world: World
var main: Node
var out_dir := "user://shots"


func _ready() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("screenshot: ", shot_name)


## Le stelle lampeggiano quando la polizia non ti vede: scatta nella fase accesa.
func _stars_lit() -> void:
	while Time.get_ticks_msec() % 520 > 90:
		await get_tree().process_frame


func _place(pos: Vector3, yaw: float) -> void:
	var p: Protagonist = world.player
	if p.in_vehicle():
		world.force_exit(p)
	p.teleport(pos, yaw)
	world.camera.snap_behind()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot-dir")
	if i >= 0 and i + 1 < args.size():
		out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ci := args.find("--cam")
	if ci >= 0 and ci + 1 < args.size():
		var v := args[ci + 1].split_floats(",")
		Game.new_game()
		world.start_new_game(true)
		world.hud.set_hud_visible(false)
		await frames(30)
		world.camera.mode = "cinematic_hard"
		world.camera.cine_pos = Vector3(v[0], v[1], v[2])
		world.camera.cine_look = Vector3(v[3], v[4], v[5])
		await frames(30)
		await shot("cam")
		get_tree().quit()
		return
	main.show_main_menu()
	await frames(90)
	await shot("01_menu_principale")
	main.menu._show_multiplayer()
	await frames(30)
	await shot("01b_menu_multiplayer")
	main.menu._show_home()
	await frames(5)
	# Intro completa (volo, guasto, atterraggio) con dialoghi fatti avanzare in automatico.
	main.start_new_game()
	var shots_taken := 0
	for k in 3000:
		if world.state == "play":
			break
		if k % 45 == 44:
			world.hud.dialogue.advance()
			world.hud.dialogue.advance()
		if world.intro != null and world.intro.phase == shots_taken + 1 and k % 45 == 20:
			shots_taken += 1
			await shot("00_intro_fase_%d" % shots_taken)
		await frames(1)
	print("intro terminata, stato: ", world.state)
	await frames(120)
	await shot("02_arrivo_aeroporto")

	_place(Vector3(8.6, 0, -40), 0.0)
	await frames(60)
	await shot("03_centro_a_piedi")

	var car: Car = world.spawn_car("sport", Vector3(-3.2, 0, 90), 0.0, Color(0.95, 0.8, 0.1))
	world.put_in_car(world.player, car)
	Input.action_press("accelerate")
	await frames(70)
	Input.action_release("accelerate")
	await shot("04_guida_sportiva")
	await frames(40)
	world.force_exit(world.player)

	_place(Vector3(150, 0, -128), 0.0)
	await frames(50)
	await shot("05_rifugio")

	_place(Vector3(20, 0, 194), -PI * 0.5)
	await frames(50)
	await shot("06_porto")

	world.camera.mode = "cinematic_hard"
	world.camera.cine_pos = Vector3(-170, 110, 230)
	world.camera.cine_look = Vector3(40, 0, -10)
	await frames(30)
	await shot("07_veduta_citta")
	world.camera.cine_pos = Vector3(250, 45, 60)
	world.camera.cine_look = Vector3(330, 0, -40)
	await frames(30)
	await shot("08_aeroporto_aereo")
	world.camera.snap_behind()

	if world.missions.current != null:
		world.missions.current.fail("tour")
	await frames(5)
	world.switch_to("norman", true)
	_place(CityData.YARD_CENTER + Vector3(0, 0, -10), 0.0)
	Game.missions_done = 6
	world.missions.start_mission(6)
	for k in 200:
		if world.missions.current.started:
			break
		world.hud.dialogue.advance()
		world.hud.dialogue.abort()
		await frames(1)
	world.player.invuln = 99.0
	world.player.teleport(CityData.YARD_CENTER, PI)
	world.camera.snap_behind()
	await frames(150)
	await shot("09_sfida_norman")
	if world.missions.current != null:
		world.missions.current.fail("test")
	await frames(10)

	world.switch_to("tom", true)
	_place(Vector3(-51.4, 0, -30), PI * 0.5)
	world.hud.dialogue.play([["tom", "Il Corvo sapeva tutto del nostro volo. Qualcuno gli ha passato le informazioni."]])
	await frames(120)
	await shot("10_dialogo")
	world.hud.dialogue.abort()

	world.hud.open_char_select()
	await frames(20)
	await shot("11_cambio_personaggio")
	world.hud.close_menu()
	world.hud.open_map()
	await frames(20)
	await shot("12_mappa")
	world.hud.close_menu()
	world.hud.open_pause()
	await frames(20)
	await shot("13_pausa")
	world.hud.close_menu()

	# --- armi e polizia
	world.switch_to("mike", true)
	world.hud.close_menu()
	Game.add_money(5000)
	_place(CityData.ARMORY_POS + Vector3(0, 0, -6), PI)
	world.hud.open_armory()
	await frames(20)
	await shot("15_armeria")
	world.hud.close_menu()
	Game.give_weapon("smg", 120)
	Game.equip_weapon("smg")
	world.player.invuln = 999.0
	_place(Vector3(0, 0, -84), 0.0)
	var foes: Array = []
	for k in 3:
		var e: Enemy = world.spawn_enemy("viper", Vector3(-3 + k * 3, 0, -97), 400.0)
		e.passive = true
		foes.append(e)
	await frames(20)
	for k in 14:
		world.player.attack(true)
		await frames(4)
	await shot("16_sparatoria")
	for e in foes:
		e.queue_free()
	world.police.set_stars(3)
	await frames(420)
	await _stars_lit()
	await shot("17_polizia_3_stelle")
	world.police.set_stars(5)
	await frames(300)
	if world.police.heli != null:
		var hp: Vector3 = world.police.heli.global_position
		var back := world.player_pos() - hp
		back.y = 0.0
		world.camera.mode = "cinematic_hard"
		world.camera.cine_pos = world.player_pos() + back.normalized() * 11.0 + Vector3(0, 2.5, 0)
		world.camera.cine_look = world.player_pos().lerp(hp, 0.45)
		await frames(5)
	await _stars_lit()
	await shot("18_elicottero_5_stelle")
	world.police.clear()
	world.camera.snap_behind()

	var intro := IntroCutscene.new()
	intro.world = world
	world.add_child(intro)
	intro.plane = world.airliner
	intro.phase = 1
	intro._place_on_circle(-0.32)
	world.camera.mode = "cinematic_hard"
	intro._update_camera(0.0)
	world.hud.set_hud_visible(false)
	await frames(30)
	await shot("14_volo_iniziale")
	get_tree().quit()
