extends Node
## Test end-to-end eseguiti dentro il gioco vero (scene, fisica, IA, missioni).
## Uso:  godot --headless --fixed-fps 60 --path . -- --run-tests
## Esce con codice 0 se tutti i controlli passano, 1 altrimenti.

var world: World
var passed := 0
var failed := 0
var failures: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		print("  [OK]   ", what)
	else:
		failed += 1
		failures.append(what)
		print("  [FAIL] ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func section(t: String) -> void:
	print("\n== ", t)


func _run() -> void:
	print("=== GTA: Three Legends - test automatici ===")
	if FileAccess.file_exists(Game.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	var t0 := Time.get_ticks_msec()
	await frames(10)
	await _test_world()
	await _test_new_game_and_m1()
	await _test_characters()
	await _test_boost()
	await _test_touch()
	await _test_driving()
	await _test_collision()
	await _test_m2()
	await _test_m3_m4()
	await _test_m5()
	await _test_m6()
	await _test_m7()
	await _test_m8()
	await _test_weapons()
	await _test_police()
	await _test_death()
	await _test_save_load()
	await _test_settings()
	print("\n=== RISULTATO: %d superati, %d falliti (%.1f s) ===" % [passed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	for f in failures:
		print("   - FALLITO: ", f)
	get_tree().quit(1 if failed > 0 else 0)


func _start_mission(i: int, chosen: String = "") -> Mission:
	if world.player.in_vehicle():
		world.force_exit(world.player)
	Game.missions_done = i
	world.missions.refresh_marker()
	world.missions.start_mission(i, chosen)
	var m: Mission = world.missions.current
	await wait_until(func(): return m.started, 120)
	await frames(2)
	return m


func _tp(pos: Vector3) -> void:
	var p: Protagonist = world.player
	if p.in_vehicle():
		var car: Car = p.vehicle
		car.global_position = pos + Vector3(0, 0.1, 0)
		car.speed = 0.0
		car.velocity = Vector3.ZERO
	else:
		p.teleport(pos, p.yaw)


func _mission_done() -> bool:
	return world.missions.current == null


# ---------------------------------------------------------------- mondo

func _test_world() -> void:
	section("Mondo di gioco")
	check(world.chars.size() == 3, "Tre protagonisti creati (Mike, Tom, Norman)")
	check(world.cars.size() >= 25, "Auto in città: %d" % world.cars.size())
	check(world.traffic.size() >= 6, "Traffico attivo: %d auto" % world.traffic.size())
	check(world.peds.size() >= 12, "Pedoni: %d" % world.peds.size())
	var col: Node = world.get_node("CityCollision")
	check(col.get_child_count() > 300, "Collisioni della città: %d forme" % col.get_child_count())
	var boosts := 0
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.kind == "boost":
			boosts += 1
	check(boosts >= 16, "Brown Boost nella città: %d" % boosts)
	check(CityData.nodes.size() == 52 and CityData.edges().size() == 87, "Grafo stradale completo")
	var chunks: int = world.get_node("CityGround").get_child_count() + world.get_node("CityBuildings").get_child_count()
	check(chunks >= 8 and chunks <= 80, "Geometria città unita in %d blocchi con culling" % chunks)
	var start_pos := {}
	for c in world.traffic:
		start_pos[c] = c.global_position
	var ped_pos := {}
	for p in world.peds:
		ped_pos[p] = p.global_position
	await frames(240)
	var moved := 0
	for c in start_pos:
		if is_instance_valid(c) and c.global_position.distance_to(start_pos[c]) > 8.0:
			moved += 1
	check(moved >= world.traffic.size() / 2, "Il traffico si muove (%d/%d auto)" % [moved, start_pos.size()])
	var ped_moved := 0
	for p in ped_pos:
		if p.global_position.distance_to(ped_pos[p]) > 1.0:
			ped_moved += 1
	check(ped_moved >= 1, "I pedoni camminano (%d)" % ped_moved)


func _test_new_game_and_m1() -> void:
	section("Nuova partita e Missione 1 - Arrivo in città")
	Game.new_game()
	world.start_new_game(true)
	await frames(5)
	check(world.state == "play", "Partita avviata")
	check(world.missions.current != null and world.missions.current_index == 0, "Missione 1 avviata automaticamente")
	var m: Mission = world.missions.current
	await wait_until(func(): return m.started, 60)
	var mike: Protagonist = world.chars["mike"]
	check(world.player == mike, "Si inizia con Mike Vargo")
	check(mike.health < mike.max_health, "Mike è ferito dopo l'atterraggio (%d)" % int(mike.health))
	var p0 := mike.global_position
	world.camera.yaw = PI * 0.5
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(mike.global_position.distance_to(p0) > 4.0, "Movimento a piedi con l'input (%.1f m)" % mike.global_position.distance_to(p0))
	var h0 := mike.health
	_tp(CityData.TERMINAL_BOOST)
	await frames(5)
	check(mike.health >= h0 + 30.0, "Brown Boost raccolto: salute %d -> %d" % [int(h0), int(mike.health)])
	_tp(CityData.AIRPORT_EXIT)
	await frames(3)
	check(m.stage == 1, "Obiettivo 1 completato: uscita dell'aeroporto")
	_tp(CityData.SAFEHOUSE_DOOR)
	await wait_until(_mission_done, 200)
	check(Game.missions_done == 1, "Missione 1 completata")
	check(Game.money > 250, "Ricompensa ricevuta ($%d)" % Game.money)
	check(world.missions.marker != null, "Indicatore della missione 2 presente")


func _test_characters() -> void:
	section("Cambio protagonista")
	for id in ["tom", "norman", "mike"]:
		world.request_switch(id)
		await frames(110)
		var p: Protagonist = world.player
		check(p.char_id == id and p.active, "Ora giochi con %s" % p.data["name"])
		check(world.camera.mode == "follow", "Telecamera tornata sul personaggio")
		var a := p.global_position
		world.camera.yaw = PI
		Input.action_press("move_forward")
		await frames(30)
		Input.action_release("move_forward")
		check(p.global_position.distance_to(a) > 1.5, "%s si muove" % p.data["name"])
		p.special_cd = 0.0
		check(p.use_special(), "Abilità speciale %s" % p.data["special"])
		await frames(5)
	var actives := 0
	for id in world.chars:
		if world.chars[id].active:
			actives += 1
	check(actives == 1, "Un solo protagonista controllato alla volta")
	check(world.chars["norman"].max_health > world.chars["mike"].max_health, "Norman ha più salute")
	check(world.chars["mike"].data["drive"] > 1.0, "Mike è più veloce alla guida")


func _test_boost() -> void:
	section("Brown Boost: raccolta, scorta e uso")
	var p: Protagonist = world.player
	p.health = p.max_health
	var b0 := Game.boosts
	world.spawn_pickup("boost", p.global_position + Vector3(0.4, 0, 0), 0.0)
	await frames(5)
	check(Game.boosts == b0 + 1, "Con salute piena il Brown Boost va in scorta (%d)" % Game.boosts)
	p.health = 40.0
	world.use_boost_item()
	check(is_equal_approx(p.health, 40.0 + Game.BOOST_HEAL), "Il pulsante BOOST ripristina salute (%d)" % int(p.health))
	check(Game.boosts == b0, "Scorta consumata")


## Converte coordinate dell'interfaccia in coordinate schermo (il viewport
## applica lo stretch inverso agli eventi in ingresso).
func _screen(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _screen(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _screen(pos)
	ev.relative = get_tree().root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(ev)


func _test_touch() -> void:
	section("Comandi touch")
	var tc: TouchControls = world.hud.touch
	check(tc.mode == "foot", "Comandi a piedi visibili")
	var p: Protagonist = world.player
	p.health = 50.0
	Game.add_boost()
	var btn: TouchButton = tc.buttons["use_boost"]
	_touch(0, btn.center_global(), true)
	await frames(3)
	check(p.health > 50.0, "Tocco sul pulsante BOOST")
	_touch(0, btn.center_global(), false)
	await frames(2)
	check(not Input.is_action_pressed("use_boost"), "Rilascio del pulsante")
	var vs := tc.get_viewport_rect().size
	var start := Vector2(200, vs.y - 160)
	_touch(1, start, true)
	_drag(1, start + Vector2(0, -80), Vector2(0, -80))
	await frames(2)
	check(Input.get_action_strength("move_forward") > 0.5, "Joystick virtuale avanti")
	_touch(1, start + Vector2(0, -80), false)
	await frames(2)
	check(Input.get_action_strength("move_forward") == 0.0, "Joystick rilasciato")
	var yaw0 := world.camera.yaw
	_touch(2, Vector2(vs.x * 0.6, vs.y * 0.45), true)
	_drag(2, Vector2(vs.x * 0.6 + 120, vs.y * 0.45), Vector2(120, 0))
	await frames(2)
	_touch(2, Vector2(vs.x * 0.6 + 120, vs.y * 0.45), false)
	check(absf(angle_difference(yaw0, world.camera.yaw)) > 0.3, "Trascinamento ruota la visuale")


func _test_driving() -> void:
	section("Guida delle automobili")
	var p: Protagonist = world.player
	var car: Car = world.nearest_car(Vector3(81, 0, -140), 3.0)
	check(car != null, "Auto parcheggiata trovata")
	if car == null:
		return
	p.teleport(car.global_position + car.global_transform.basis.x * -2.6, 0.0)
	await frames(3)
	world.toggle_vehicle()
	check(p.vehicle == car, "Entrata nell'auto (%s)" % car.display_name())
	await frames(2)
	check(world.hud.touch.mode == "car", "Comandi di guida mostrati")
	var start := car.global_position
	Input.action_press("accelerate")
	await frames(70)
	check(car.speed > 8.0, "Accelerazione: %d km/h" % int(car.speed * 3.6))
	check(car.global_position.distance_to(start) > 8.0, "L'auto si sposta (%.1f m)" % car.global_position.distance_to(start))
	var yaw0 := car.rotation.y
	Input.action_press("move_left")
	await frames(25)
	Input.action_release("move_left")
	Input.action_release("accelerate")
	check(absf(angle_difference(yaw0, car.rotation.y)) > 0.25, "Sterzata")
	var v0 := absf(car.speed)
	Input.action_press("brake")
	await frames(30)
	Input.action_release("brake")
	check(absf(car.speed) < v0, "Frenata (%d -> %d km/h)" % [int(v0 * 3.6), int(absf(car.speed) * 3.6)])
	await frames(60)
	world.toggle_vehicle()
	check(p.vehicle == null, "Uscita dall'auto")
	check(p.global_position.distance_to(car.global_position) < 5.0, "Il protagonista scende accanto all'auto")
	var traffic_car: Car = null
	for c in world.traffic:
		if is_instance_valid(c) and c.npc_driver:
			traffic_car = c
			break
	if traffic_car != null:
		p.teleport(traffic_car.global_position + traffic_car.global_transform.basis.x * -2.6, 0.0)
		traffic_car.speed = 0.0
		await frames(2)
		world.enter_vehicle(p, traffic_car)
		check(p.vehicle == traffic_car and traffic_car.ai_mode == Car.AI.NONE, "Furto di un'auto del traffico (autista fatto scendere)")
		world.force_exit(p)


func _test_collision() -> void:
	section("Collisioni")
	var p: Protagonist = world.player
	var c2: Car = world.spawn_car("sedan", Vector3(-93, 0, -122), PI)
	world.put_in_car(p, c2)
	Input.action_press("accelerate")
	await frames(150)
	Input.action_release("accelerate")
	check(c2.global_position.z < -104.0, "L'auto non attraversa il muro del garage (z=%.1f)" % c2.global_position.z)
	check(c2.health < c2.max_health, "Danni da urto (%d/%d)" % [int(c2.health), int(c2.max_health)])
	world.force_exit(p)
	var a: Car = world.spawn_car("muscle", Vector3(-30, 0, -63.2), -PI * 0.5)
	var b: Car = world.spawn_car("van", Vector3(-10, 0, -63.2), 0.0)
	world.put_in_car(p, a)
	Input.action_press("accelerate")
	await frames(120)
	Input.action_release("accelerate")
	check(b.health < b.max_health and a.health < a.max_health, "Urto tra veicoli danneggia entrambi")
	world.force_exit(p)


func _test_m2() -> void:
	section("Missione 2 - Prima automobile")
	var m = await _start_mission(1)
	check(m.stage == 0, "Obiettivo: trova un'auto")
	var car: Car = world.spawn_car("sedan", world.player.global_position + Vector3(4, 0, 4), 0.0)
	world.put_in_car(world.player, car)
	await frames(3)
	check(m.stage == 1, "Salito in auto: guida fino al garage")
	_tp(CityData.GARAGE_DOOR)
	await frames(3)
	check(m.stage == 2, "Arrivato al garage")
	_tp(CityData.GARAGE_INSIDE)
	await wait_until(_mission_done, 200)
	check(Game.missions_done == 2, "Missione 2 completata")
	world.force_exit(world.player)


func _test_m3_m4() -> void:
	section("Missione 3 - Il pacco misterioso")
	var m = await _start_mission(2)
	_tp(CityData.DOCKS_PACKAGE)
	await frames(5)
	check(m.stage == 1, "Pacco recuperato al porto")
	_tp(CityData.LENNY_POS + Vector3(0, 0, 2))
	await wait_until(_mission_done, 200)
	check(Game.missions_done == 3, "Missione 3 completata")
	section("Missione 4 - Fuga improvvisa")
	await wait_until(func(): return world.missions.current != null and world.missions.current_index == 3 and world.missions.current.started, 400)
	var m4 = world.missions.current
	check(m4 != null and world.missions.current_index == 3, "Missione 4 parte subito dopo l'imboscata")
	if m4 == null:
		return
	check(m4.chasers.size() == 3, "Tre auto delle Vipere all'inseguimento")
	world.put_in_car(world.player, m4.getaway)
	await frames(200)
	var chasing := 0
	for c in m4.chasers:
		if c.ai_mode == Car.AI.CHASE:
			chasing += 1
	check(chasing == 3, "Le Vipere inseguono il giocatore")
	_tp(Vector3(361, 0, 150))
	await wait_until(_mission_done, 600)
	check(Game.missions_done == 4, "Missione 4 completata: Vipere seminate")
	world.force_exit(world.player)


func _test_m5() -> void:
	section("Missione 5 - Il piano di Tom")
	world.switch_to("mike", true)
	await frames(2)
	Game.missions_done = 4
	world.missions.refresh_marker()
	world.player.teleport(CityData.SAFEHOUSE_MARK, 0.0)
	await frames(10)
	check(world.missions.current == null, "La missione di Tom non parte con Mike")
	world.switch_to("tom", true)
	var m = await _start_mission(4)
	check(m.cams.size() >= 8, "Telecamere di sorveglianza attive: %d" % m.cams.size())
	var cam: SecurityCam = m.cams[0]
	var y := cam.head.global_rotation.y
	var dir := Vector3(-sin(y), 0, -cos(y))
	world.player.teleport(Vector3(cam.global_position.x, 0, cam.global_position.z) + dir * 5.0, 0.0)
	await frames(15)
	check(m.alarm > 0.0, "La telecamera vede Tom (allarme %d%%)" % int(m.alarm))
	world.player.special_cd = 0.0
	world.player.use_special()
	check(cam.disabled_time > 0.0, "ANALISI di Tom disattiva le telecamere")
	for c in CityData.CLUES:
		_tp(c)
		await frames(6)
	check(m.found == 4 and m.stage == 1, "Quattro indizi raccolti")
	_tp(CityData.SAFEHOUSE_DOOR)
	await wait_until(_mission_done, 200)
	check(Game.missions_done == 5, "Missione 5 completata")


func _test_m6() -> void:
	section("Missione 6 - La corsa di Mike")
	world.switch_to("mike", true)
	var m = await _start_mission(5)
	check(world.player.vehicle == m.car, "Mike è al volante dell'auto da corsa")
	await wait_until(func(): return m.race_started, 400)
	check(m.timer > 0.0, "Timer della gara attivo (%d s)" % int(m.timer))
	await frames(60)
	check(m.rival.global_position.distance_to(CityData.RACE_START) > 5.0, "Razor (IA) corre il percorso")
	for i in m.ROUTE.size():
		_tp(m.ROUTE[i])
		await frames(4)
	await wait_until(_mission_done, 300)
	check(Game.missions_done == 6, "Missione 6 completata entro il tempo")
	world.force_exit(world.player)


func _test_m7() -> void:
	section("Missione 7 - La sfida di Norman")
	world.switch_to("norman", true)
	var m = await _start_mission(6)
	var norman: Protagonist = world.player
	norman.invuln = 60.0
	_tp(CityData.YARD_CENTER)
	await frames(5)
	check(m.stage == 1 and m.wave == 1, "Prima ondata di Vipere")
	var e: Enemy = m.enemies[0]
	e.global_position = norman.global_position + norman.forward() * 1.2
	var hp := e.health
	norman.punch_cd = 0.0
	norman.punch()
	await frames(15)
	check(e.health < hp, "Il pugno di Norman colpisce (%d -> %d)" % [int(hp), int(e.health)])
	var waves_seen := 0
	for w in 3:
		await wait_until(func(): return m.stage == 1 and m.wave == w + 1, 600)
		waves_seen = m.wave
		for en in m.enemies:
			if is_instance_valid(en) and not en.dead:
				en.take_damage(9999.0, norman)
		await frames(10)
	check(waves_seen == 3, "Tre ondate affrontate")
	await wait_until(_mission_done, 600)
	check(Game.missions_done == 7, "Missione 7 completata")
	norman.invuln = 0.0


func _test_m8() -> void:
	section("Missione 8 - La verità sulla valigetta")
	var m = await _start_mission(7, "mike")
	check(world.player.char_id == "mike", "Protagonista scelto per il finale: Mike")
	check(m.timer > 0.0, "Corsa contro il tempo verso l'aeroporto")
	world.player.invuln = 60.0
	_tp(CityData.HANGAR)
	await wait_until(func(): return m.stage == 1, 300)
	check(m.dex_car != null and m.dex_car.ai_mode == Car.AI.PATH, "Dex fugge in auto")
	m.dex_car.take_damage(9999.0, null)
	await wait_until(func(): return m.stage == 2, 60)
	check(m.dex != null and m.guards.size() == 3, "Dex e tre guardie a piedi")
	m.dex.take_damage(9999.0, world.player)
	for g in m.guards:
		g.take_damage(9999.0, world.player)
	await wait_until(func(): return m.stage == 3, 60)
	check(m.briefcase != null, "La valigetta è a terra")
	_tp(m.briefcase.global_position)
	await wait_until(_mission_done, 300)
	check(Game.missions_done == 8, "Missione finale completata: storia conclusa")
	check(world.hud.is_menu_open(), "Titoli di coda mostrati")
	world.hud.close_menu()
	world.player.invuln = 0.0
	await frames(3)


func _test_weapons() -> void:
	section("Armi")
	var p: Protagonist = world.player
	if p.in_vehicle():
		world.force_exit(p)
	world.police.clear()
	p.invuln = 60.0
	p.teleport(Vector3(0, 0, -90), 0.0)
	world.camera.yaw = 0.0
	world.camera.snap_behind()
	world.camera.yaw = 0.0
	Game.confiscate_weapons()
	check(Game.current_weapon == "fists", "Si parte a mani nude")
	Game.give_weapon("pistol", 24)
	check(Game.current_weapon == "pistol" and Game.ammo() == 24, "Pistola in mano con 24 colpi")
	check(p.model.weapon_mesh != null, "Arma visibile nella mano del protagonista")
	var e: Enemy = world.spawn_enemy("viper", Vector3(0, 0, -98), 200.0)
	e.passive = true
	await frames(3)
	var hp := e.health
	for i in 3:
		p.fire_cd = 0.0
		p.attack(false)
		await frames(2)
	check(e.health < hp, "La pistola colpisce il bersaglio con la mira automatica (%d -> %d)" % [int(hp), int(e.health)])
	check(Game.ammo() == 21, "Munizioni consumate (%d)" % Game.ammo())
	Game.give_weapon("shotgun", 12)
	Game.equip_weapon("shotgun")
	e.global_position = Vector3(0, 0.1, -94)
	await frames(2)
	var hp2 := e.health
	p.fire_cd = 0.0
	p.attack(false)
	await frames(2)
	check(hp2 - e.health > 15.0, "Il fucile a pompa spara più pallini (danno %d)" % int(hp2 - e.health))
	Game.equip_weapon("pistol")
	var nxt := Game.next_weapon()
	check(nxt == "shotgun", "Pulsante ARMA: passa all'arma successiva (%s)" % nxt)
	e.queue_free()
	world.spawn_pickup("weapon", p.global_position + Vector3(0.5, 0, 0), 0.0, "smg")
	await frames(4)
	check(Game.weapons.has("smg"), "Mitraglietta raccolta da terra")
	Game.add_money(5000)
	var money := Game.money
	world.hud.open_armory()
	world.hud._buy_weapon("rifle", int(Game.WEAPONS["rifle"]["price"]))
	world.hud.close_menu()
	check(Game.weapons.has("rifle") and Game.money == money - int(Game.WEAPONS["rifle"]["price"]), "Fucile d'assalto comprato all'armeria")
	var car: Car = world.spawn_car("sedan", Vector3(4, 0, -110), 0.0)
	var ch := car.health
	car.take_bullet(30.0, p, Vector3.FORWARD)
	check(car.health < ch, "I proiettili danneggiano le auto")
	car.queue_free()
	world.police.clear()
	await frames(2)


func _test_police() -> void:
	section("Polizia e livello di ricercato")
	var pol: Police = world.police
	var p: Protagonist = world.player
	p.invuln = 0.0
	p.health = p.max_health
	pol.clear()
	check(pol.stars == 0, "Nessuna stella all'inizio")
	Game.equip_weapon("pistol")
	p.fire_cd = 0.0
	p.attack(false)
	check(pol.stars == 1, "Sparare in strada: 1 stella")
	await frames(10)
	check(pol.cars.size() >= 1, "Arriva una pattuglia (%d)" % pol.cars.size())
	var pc: Car = pol.cars[0] if pol.cars.size() > 0 else null
	check(pc != null and pc.car_type == "police" and pc.model.siren_on, "Auto della polizia con sirena accesa")
	pol.set_stars(3)
	check(pol.stars == 3, "Crimini gravi: 3 stelle")
	var deployed := await wait_until(func(): return pol.cops.size() >= 2, 1500)
	check(deployed, "Gli agenti scendono dalle auto e ti inseguono a piedi (%d)" % pol.cops.size())
	var armed := 0
	for c in pol.cops:
		if is_instance_valid(c) and c.gun == "pistol":
			armed += 1
	check(armed >= 1, "Con 3 stelle gli agenti sono armati")
	var h0 := p.health
	var shot := await wait_until(func(): return p.health < h0, 900)
	check(shot, "Gli agenti sparano al protagonista (salute %d -> %d)" % [int(h0), int(p.health)])
	p.health = p.max_health
	p.invuln = 60.0
	pol.set_stars(5)
	await frames(10)
	check(pol.heli != null, "Con 5 stelle arriva l'elicottero")
	check(pol.cars.size() + pol.cops.size() >= 3, "Risposta massiccia della polizia (%d unità)" % (pol.cars.size() + pol.cops.size()))
	if pol.heli != null:
		var heli := pol.heli
		heli.take_bullet(9999.0, p, Vector3.UP)
		check(heli.crashing, "L'elicottero può essere abbattuto")
	# seminare la polizia
	pol.clear()
	pol.set_stars(1)
	pol._spawn_cd = 999.0
	p.teleport(Vector3(-128.6, 0, 60), 0.0)
	var lost := await wait_until(func(): return pol.stars == 0, 900)
	check(lost, "Fuori dall'area di ricerca e senza essere visti: polizia seminata")
	# arresto a 1 stella
	pol.set_stars(1)
	pol._spawn_cd = 999.0
	p.invuln = 0.0
	Game.give_weapon("pistol", 10)
	var money := Game.money
	var cop: Enemy = world.spawn_enemy("cop", p.global_position + Vector3(1.2, 0, 0), 60.0)
	cop.is_cop = true
	cop.arm("", 0.0)
	pol.cops.append(cop)
	var busted := await wait_until(func(): return world._respawning, 300)
	check(busted, "Un agente ti arresta (1 stella, a piedi)")
	await wait_until(func(): return not world._respawning, 400)
	check(p.global_position.distance_to(CityData.POLICE_DOOR) < 3.0, "Si riparte dalla questura")
	check(Game.current_weapon == "fists" and not Game.weapons.has("pistol"), "Armi sequestrate")
	check(Game.money < money, "Multa pagata")
	check(pol.stars == 0, "Stelle azzerate dopo l'arresto")
	# riverniciatura al garage
	pol.set_stars(2)
	pol._spawn_cd = 999.0
	var car: Car = world.spawn_car("sedan", CityData.GARAGE_INSIDE, -PI * 0.5)
	world.put_in_car(p, car)
	pol.seen = false
	var sprayed := await wait_until(func(): return pol.stars == 0, 200)
	check(sprayed, "Riverniciatura al garage di Gus: stelle cancellate")
	world.force_exit(p)
	# K.O. azzera le stelle
	pol.set_stars(2)
	pol._spawn_cd = 999.0
	p.invuln = 0.0
	p.take_damage(9999.0)
	await wait_until(func(): return not world._respawning and not p.dead, 400)
	check(pol.stars == 0, "Dopo il K.O. la polizia smette di cercarti")
	pol.clear()
	for u in pol._dismissed:
		if is_instance_valid(u):
			u.queue_free()
	await frames(5)


func _test_death() -> void:
	section("K.O. e ritorno al checkpoint")
	var p: Protagonist = world.player
	if p.in_vehicle():
		world.force_exit(p)
	p.teleport(Vector3(0, 0, -60), 0.0)
	await frames(3)
	var money0 := Game.money
	p.invuln = 0.0
	p.take_damage(9999.0)
	check(p.dead, "Salute a zero: K.O.")
	await wait_until(func(): return not p.dead and world.lock_count == 0, 400)
	check(is_equal_approx(p.health, p.max_health), "Salute ripristinata dopo il respawn")
	check(p.global_position.distance_to(world.checkpoint) < 3.0, "Respawn all'ultimo checkpoint")
	check(Game.money == money0 - mini(money0, Game.KO_FEE), "Spese mediche addebitate")


func _test_save_load() -> void:
	section("Salvataggio e caricamento")
	var p: Protagonist = world.player
	p.teleport(Vector3(10, 0, -55), 1.0)
	await frames(3)
	check(world.save_now(), "Salvataggio eseguito")
	check(Game.has_save(), "File di salvataggio presente")
	var money := Game.money
	var done := Game.missions_done
	var pos := p.global_position
	var feathers := Game.feathers.size()
	Game.add_money(12345)
	Game.missions_done = 0
	p.teleport(Vector3(100, 0, 100), 0.0)
	check(Game.load_game(), "Caricamento eseguito")
	world.apply_loaded_state()
	await frames(2)
	check(Game.money == money, "Denaro ripristinato ($%d)" % Game.money)
	check(Game.missions_done == done, "Progressi ripristinati (%d missioni)" % Game.missions_done)
	check(world.player.global_position.distance_to(pos) < 1.0, "Posizione ripristinata")
	check(Game.feathers.size() == feathers, "Collezionabili ripristinati")
	var txt := FileAccess.get_file_as_string(Game.SAVE_PATH)
	check(txt.contains("\"missions_done\"") and txt.contains("\"chars\""), "Formato JSON del salvataggio")
	var f: Pickup = world.feathers[0] if world.feathers.size() > 0 else null
	if f != null:
		var n0 := Game.feathers.size()
		_tp(f.global_position)
		await frames(5)
		check(Game.feathers.size() == n0 + 1, "Piuma del Corvo raccolta (contenuto secondario)")


func _test_settings() -> void:
	section("Impostazioni")
	Game.set_setting("sfx", 0.5)
	var idx := AudioServer.get_bus_index("SFX")
	check(idx >= 0 and absf(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.5)) < 0.1, "Volume effetti applicato")
	check(FileAccess.file_exists(Game.SETTINGS_PATH), "Impostazioni salvate su file")
	Game.set_setting("quality", 0)
	check(not world.sun.shadow_enabled, "Qualità bassa: ombre disattivate")
	Game.set_setting("quality", 1)
	check(world.sun.shadow_enabled, "Qualità media: ombre attive")
	Game.set_setting("sfx", 0.9)
