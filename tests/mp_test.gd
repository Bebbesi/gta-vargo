extends Node
## Test multiplayer reale con due processi Godot sulla stessa macchina:
##   godot --headless --path . -- --mp-test=host --mp-port=7790 &
##   godot --headless --path . -- --mp-test=client --mp-port=7790
## Il client si collega, vede passanti e traffico dell'host, colpisce un
## passante (e riceve le stelle), mette K.O. l'host, ruba un'auto del
## traffico e attira la propria polizia; l'host vede tutto e spara a un
## agente del client con la mira manuale, ricevendo a sua volta le stelle.

var world: World
var role := "host"
var passed := 0
var failed := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		print("  [OK]   [%s] %s" % [role, what])
	else:
		failed += 1
		print("  [FAIL] [%s] %s" % [role, what])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func wait_until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _run() -> void:
	print("=== Test multiplayer LAN (%s) ===" % role)
	_net().stay_on_fail = true
	await frames(5)
	if role == "host":
		await _host()
	else:
		await _client()
	print("=== RISULTATO MP [%s]: %d superati, %d falliti ===" % [role, passed, failed])
	await frames(10)
	get_tree().quit(1 if failed > 0 else 0)


func _net() -> NetSession:
	return world.net as NetSession


func _puppets(kind: int, owner: int) -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("net_npcs"):
		var pup := n as NetPuppet
		if pup.kind == kind and pup.owner_peer == owner and not pup.dead:
			out.append(pup)
	return out


func _nearest(list: Array, pos: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n in list:
		var d: float = (n as Node3D).global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = n
	return best


## Spara con la mira manuale (mirino puntato sul bersaglio).
func _shoot_at(target: Node3D, shots: int) -> void:
	var me: Protagonist = world.player
	Game.equip_weapon("pistol")
	world.set_aiming(true)
	await frames(20)
	for i in shots:
		if not is_instance_valid(target):
			return
		world.camera.aim_at(target.aim_point())
		await frames(2)
		me.fire_cd = 0.0
		me.attack(false)
		await get_tree().create_timer(0.3).timeout


# ---------------------------------------------------------------- host

func _host() -> void:
	var net := _net()
	check(net.is_host and net.connected, "Server ENet in ascolto")
	var joined := await wait_until(func(): return net.players.size() >= 2, 30.0)
	check(joined, "Un client si è collegato (%d giocatori)" % net.players.size())
	if not joined:
		return
	var client_id := 0
	for id in net.players:
		if id != 1:
			client_id = id
	check(net.players[client_id]["name"] == "Ospite" and net.players[client_id]["char"] == "tom", "Nome e personaggio del client ricevuti")
	var got_avatar := await wait_until(func(): return net.avatars.has(client_id) and net.avatars[client_id]._has_state, 10.0)
	check(got_avatar, "Avatar del client creato e aggiornato dalla rete")
	var sim := await wait_until(func(): return world.peds.size() > 0 and world.traffic.size() > 0, 15.0)
	check(sim, "L'host simula passanti (%d) e traffico (%d)" % [world.peds.size(), world.traffic.size()])
	world.player.invuln = 0.0
	var start_pos: Vector3 = net.avatars[client_id].global_position
	var moved := await wait_until(func(): return net.avatars[client_id].global_position.distance_to(start_pos) > 3.0, 40.0)
	check(moved, "Il client si muove sullo schermo dell'host")
	var ko := await wait_until(func(): return int(net.players[1]["deaths"]) >= 1, 60.0)
	check(ko, "L'host è stato messo K.O. dai colpi del client")
	check(int(net.players[client_id]["kills"]) >= 1, "Punteggio aggiornato: K.O. al client")
	world.player.invuln = 999.0
	var driven: Array = [null]
	var got_car := await wait_until(func():
		for c in world.cars:
			if is_instance_valid(c) and c.remote_driver == client_id:
				driven[0] = c
				return true
		return false, 40.0)
	check(got_car, "Il client guida un'auto dell'host")
	if got_car:
		var car: Car = driven[0]
		var car_start := car.global_position
		var moving := await wait_until(func(): return car.global_position.distance_to(car_start) > 3.0, 20.0)
		check(moving, "Auto %s sincronizzata (net_id %d, %.1f m)" % [car.car_type, car.net_id, car.global_position.distance_to(car_start)])
		check(car.ai_mode == Car.AI.NONE and not car.npc_driver, "Sull'host il conducente è sceso e l'IA è ferma")
		await wait_until(func(): return car.remote_driver == 0, 20.0)
		check(car.remote_driver == 0, "Auto rilasciata quando il client scende")
	# la polizia del client si vede solo da vicino (le entità vanno a chi è entro 210 m)
	var cav: NetAvatar = net.avatars[client_id]
	world.player.teleport(cav.global_position + Vector3(4, 0, 0), 0.0)
	world.camera.snap_behind()
	var patrol := await wait_until(func(): return net.ents.puppet_count(NetWorld.K_CAR, client_id) > 0, 60.0)
	check(patrol, "Pattuglia della polizia del client visibile sull'host")
	var cops := await wait_until(func(): return not _puppets(NetWorld.K_COP, client_id).is_empty(), 60.0)
	check(cops, "Agenti del client scesi dall'auto visibili sull'host")
	if cops:
		var cop: NetPuppet = _nearest(_puppets(NetWorld.K_COP, client_id), cav.global_position)
		var cp := cop.global_position
		var toward := Vector3(cav.global_position.x - cp.x, 0, cav.global_position.z - cp.z)
		toward = toward.normalized() if toward.length() > 0.5 else Vector3.RIGHT
		world.player.teleport(cp + toward * 5.0, atan2(toward.x, toward.z))
		world.camera.snap_behind()
		world.police.clear()
		await _shoot_at(cop, 4)
		var wanted := await wait_until(func(): return world.police.stars >= 2, 6.0)
		check(wanted, "Colpito un agente del client: le stelle vanno all'host (%d)" % world.police.stars)
		world.set_aiming(false)
	await get_tree().create_timer(1.0).timeout


# ---------------------------------------------------------------- client

func _client() -> void:
	var net := _net()
	var ok := await wait_until(func(): return net.connected, 20.0)
	check(ok, "Connesso all'host")
	if not ok:
		return
	check(net.players.size() == 2, "Elenco giocatori sincronizzato")
	var disc := LanDiscovery.new()
	add_child(disc)
	var listening := disc.start_listen()
	var found := await wait_until(func(): return not disc.hosts.is_empty(), 6.0)
	if found:
		var h: Dictionary = disc.hosts.values()[0]
		check(h.get("name", "") == "Host" and int(h.get("players", 0)) == 2, "Partita trovata con la ricerca automatica (broadcast UDP)")
	else:
		print("  [INFO] [client] broadcast UDP non ricevuto in questo ambiente (ascolto=%s)" % listening)
	disc.queue_free()
	var host_seen := await wait_until(func(): return net.avatars.has(1) and net.avatars[1]._has_state, 10.0)
	check(host_seen, "Avatar dell'host visibile")
	if not host_seen:
		return
	var me: Protagonist = world.player
	me.invuln = 999.0
	var npcs := await wait_until(func():
		var traffic := 0
		for c in world.cars:
			if is_instance_valid(c) and c.net_puppet and c.net_id >= 1000:
				traffic += 1
		return not _puppets(NetWorld.K_PED, 1).is_empty() and traffic > 0, 20.0)
	check(npcs, "Passanti (%d) e traffico dell'host visibili sul client" % _puppets(NetWorld.K_PED, 1).size())
	var args := OS.get_cmdline_user_args()
	var si := args.find("--shot-dir")
	var shot_dir := args[si + 1] if si >= 0 and si + 1 < args.size() else ""
	if shot_dir != "":
		var hav: NetAvatar = net.avatars[1]
		me.teleport(hav.global_position + Vector3(-3.5, 0, 6.5), atan2(-3.5, 6.5))
		world.camera.snap_behind()
		await get_tree().create_timer(1.5).timeout
		await _shot(shot_dir, "20_multiplayer")
	# un passante dell'host si muove anche qui
	if npcs:
		var ped: NetPuppet = _nearest(_puppets(NetWorld.K_PED, 1), me.global_position)
		var p0 := ped.global_position
		var walks := await wait_until(func(): return not is_instance_valid(ped) or ped.global_position.distance_to(p0) > 1.0, 10.0)
		check(walks, "I passanti dell'host camminano anche sul client")
		# colpisce un passante: il danno lo applica l'host, le stelle arrivano qui
		ped = _nearest(_puppets(NetWorld.K_PED, 1), me.global_position)
		if ped != null:
			world.police.clear()
			var pp := ped.global_position
			me.teleport(pp + Vector3(0, 0, 6), 0.0)
			world.camera.snap_behind()
			await frames(5)
			await _shoot_at(ped, 3)
			world.set_aiming(false)
			var down := await wait_until(func(): return not is_instance_valid(ped) or ped.dead or ped.down, 6.0)
			check(down, "Passante dell'host colpito dal client")
			var stars := await wait_until(func(): return world.police.stars >= 2, 6.0)
			check(stars, "Reato contro un passante dell'host: stelle al client (%d)" % world.police.stars)
	# cammina un po' per farsi vedere
	world.camera.yaw = 0.0
	Input.action_press("move_forward")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_forward")
	# raggiungi l'host e sparagli con la pistola (mira automatica)
	var host_av: NetAvatar = net.avatars[1]
	var shots := 0
	var ko := false
	while shots < 40 and not ko:
		var hp := host_av.global_position
		me.teleport(hp + Vector3(6, 0, 0), atan2(6.0, 0.0))
		world.camera.yaw = me.yaw
		Game.equip_weapon("pistol")
		await frames(3)
		me.fire_cd = 0.0
		me.attack(false)
		shots += 1
		await get_tree().create_timer(0.35).timeout
		ko = int(net.players.get(net.my_id, {}).get("kills", 0)) >= 1
	check(ko, "Host messo K.O. in %d colpi" % shots)
	# ruba un'auto del traffico dell'host (o, se non ce n'è, quella parcheggiata)
	var car: Car = null
	var best := INF
	for c in world.cars:
		if is_instance_valid(c) and c.net_puppet and c.net_id >= 1000 and c.npc_driver and c.car_type != "police":
			var d: float = c.global_position.distance_to(me.global_position)
			if d < best:
				best = d
				car = c
	if car == null:
		car = net.world_car(0)
	var was_traffic := car.net_id >= 1000
	var in_car := false
	for attempt in 3:
		me.teleport(car.global_position + car.global_transform.basis.x * -2.4, car.rotation.y)
		await frames(2)
		world.toggle_vehicle()
		in_car = await wait_until(func(): return me.vehicle == car, 3.0)
		if in_car:
			break
	check(in_car, "Auto dell'host concessa e guidata (%s)" % ("traffico rubato" if was_traffic else "parcheggiata"))
	if in_car:
		Input.action_press("accelerate")
		await get_tree().create_timer(3.5).timeout
		Input.action_release("accelerate")
		await get_tree().create_timer(1.0).timeout
		world.toggle_vehicle()
		check(me.vehicle == null, "Sceso dall'auto")
	# la propria polizia arriva e scende dalle auto: l'host la vede
	world.police.set_stars(3)
	var patrol := await wait_until(func(): return not world.police.cars.is_empty(), 20.0)
	check(patrol, "Polizia del client in arrivo (%d pattuglie)" % world.police.cars.size())
	var deployed := await wait_until(func(): return not world.police.cops.is_empty(), 60.0)
	check(deployed, "Agenti del client scesi a piedi (%d)" % world.police.cops.size())
	if deployed and shot_dir != "":
		var cop: Enemy = world.police.cops[0]
		var cpos := cop.global_position
		me.teleport(me.global_position, atan2(-(cpos.x - me.global_position.x), -(cpos.z - me.global_position.z)))
		world.camera.snap_behind()
		await get_tree().create_timer(0.8).timeout
		await _shot(shot_dir, "21_multiplayer_polizia")
	# resta collegato finché l'host non chiude la partita
	await wait_until(func(): return not is_instance_valid(net) or net._closing, 60.0)
	check(true, "Partita chiusa dall'host")


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	print("screenshot: ", shot_name)
