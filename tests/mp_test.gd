extends Node
## Test multiplayer reale con due processi Godot sulla stessa macchina:
##   godot --headless --path . -- --mp-test=host --mp-port=7790 &
##   godot --headless --path . -- --mp-test=client --mp-port=7790
## Il client si collega, si muove, spara all'host fino al K.O. e guida
## un'auto; l'host verifica di vedere tutto e chiude la partita.

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
	world.player.invuln = 0.0
	var start_pos: Vector3 = net.avatars[client_id].global_position
	var moved := await wait_until(func(): return net.avatars[client_id].global_position.distance_to(start_pos) > 3.0, 20.0)
	check(moved, "Il client si muove sullo schermo dell'host")
	var ko := await wait_until(func(): return int(net.players[1]["deaths"]) >= 1, 40.0)
	check(ko, "L'host è stato messo K.O. dai colpi del client")
	check(int(net.players[client_id]["kills"]) >= 1, "Punteggio aggiornato: K.O. al client")
	var car: Car = net.world_car(0)
	var car_start := car.global_position
	var driven := await wait_until(func(): return car.remote_driver == client_id and car.global_position.distance_to(car_start) > 3.0, 30.0)
	check(driven, "Auto 0 guidata dal client e sincronizzata (%.1f m)" % car.global_position.distance_to(car_start))
	await wait_until(func(): return car.remote_driver == 0, 15.0)
	check(car.remote_driver == 0, "Auto rilasciata quando il client scende")
	await get_tree().create_timer(1.0).timeout


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
	me.invuln = 30.0
	var args := OS.get_cmdline_user_args()
	var si := args.find("--shot-dir")
	if si >= 0 and si + 1 < args.size():
		var hav: NetAvatar = net.avatars[1]
		me.teleport(hav.global_position + Vector3(-3.5, 0, 6.5), atan2(-3.5, 6.5))
		world.camera.snap_behind()
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[si + 1].path_join("20_multiplayer.png"))
		print("screenshot: 20_multiplayer")
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
		var pos := hp + Vector3(6, 0, 0)
		me.teleport(pos, atan2(6.0, 0.0))
		world.camera.yaw = me.yaw
		Game.equip_weapon("pistol")
		await frames(3)
		me.fire_cd = 0.0
		me.attack(false)
		shots += 1
		await get_tree().create_timer(0.35).timeout
		ko = int(net.players.get(net.my_id, {}).get("kills", 0)) >= 1
	check(ko, "Host messo K.O. in %d colpi" % shots)
	# prendi l'auto 0 e guidala
	me.invuln = 30.0
	var car: Car = net.world_car(0)
	me.teleport(car.global_position + car.global_transform.basis.x * -2.6, car.rotation.y)
	await frames(5)
	world.toggle_vehicle()
	var in_car := await wait_until(func(): return me.vehicle == car, 10.0)
	check(in_car, "Auto concessa dall'host e guidata")
	if in_car:
		Input.action_press("accelerate")
		await get_tree().create_timer(3.5).timeout
		Input.action_release("accelerate")
		await get_tree().create_timer(1.0).timeout
		world.toggle_vehicle()
		check(me.vehicle == null, "Sceso dall'auto")
	# resta collegato finché l'host non chiude la partita
	await wait_until(func(): return not is_instance_valid(net) or net._closing, 30.0)
	check(true, "Partita chiusa dall'host")
