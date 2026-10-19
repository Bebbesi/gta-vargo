class_name NetSession
extends Node
## Sessione multiplayer in rete locale (ENet su UDP). L'host è anche un
## giocatore; fino a 3 client si collegano al suo IP. Ogni peer simula il
## proprio protagonista e l'auto che guida e invia lo stato agli altri
## 20 volte al secondo. L'host decide chi guida quale auto e tiene i punteggi.

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_PLAYERS := 4
const SEND_RATE := 0.05
const MAGIC := "GTA3L"

signal players_changed

var world: Node
var is_host := false
var port := PORT
var host_ip := ""
var mode := "free"
var target_kills := 10
var players: Dictionary = {}
var avatars: Dictionary = {}
var car_owner: Dictionary = {}
var last_attacker := 0
var my_id := 1
var connected := false
var _send_t := 0.0
var _beacon: PacketPeerUDP
var _beacon_t := 0.0
var _closing := false
## Nei test automatici la sessione non torna al menu quando si chiude.
var stay_on_fail := false
var _round_over := false


func start(params: Dictionary) -> void:
	mode = str(params.get("mode", "free"))
	port = int(params.get("port", PORT))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var peer := ENetMultiplayerPeer.new()
	if bool(params.get("host", false)):
		is_host = true
		var err := peer.create_server(port, MAX_PLAYERS - 1)
		if err != OK:
			_fail("Impossibile creare la partita: la porta %d è già in uso." % port)
			return
		multiplayer.multiplayer_peer = peer
		my_id = 1
		connected = true
		players[1] = {"name": Game.player_name(), "char": world.player.char_id, "kills": 0, "deaths": 0}
		_beacon = PacketPeerUDP.new()
		_beacon.set_broadcast_enabled(true)
		world.hud.show_message("PARTITA CREATA", "IP %s  ·  in attesa di giocatori" % local_ip(), Color(0.5, 1.0, 0.6), 4.0)
		print("[NET] host avviato sulla porta %d (IP %s)" % [port, local_ip()])
	else:
		host_ip = str(params.get("ip", "127.0.0.1"))
		var err2 := peer.create_client(host_ip, port)
		if err2 != OK:
			_fail("Indirizzo non valido: %s" % host_ip)
			return
		multiplayer.multiplayer_peer = peer
		world.hud.toast("Connessione a %s..." % host_ip, 6.0)
		get_tree().create_timer(10.0).timeout.connect(_connect_timeout)
	players_changed.emit()


func _exit_tree() -> void:
	_closing = true
	if _beacon != null:
		_beacon.close()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _connect_timeout() -> void:
	if not connected and not _closing:
		_fail("Nessuna risposta da %s. Controlla che siate sulla stessa rete Wi-Fi." % host_ip)


func _fail(msg: String) -> void:
	if _closing:
		return
	_closing = true
	push_warning("[NET] " + msg)
	print("[NET] ", msg)
	if stay_on_fail:
		return
	Game.pending_message = msg
	Game.pending_mp = {}
	world.main.back_to_menu.call_deferred()


# ---------------------------------------------------------------- connessione

func _on_connected() -> void:
	my_id = multiplayer.get_unique_id()
	_register.rpc_id(1, Game.player_name(), world.player.char_id, Game.VERSION)


func _on_connection_failed() -> void:
	_fail("Connessione a %s non riuscita." % host_ip)


func _on_server_disconnected() -> void:
	_fail("L'host ha chiuso la partita.")


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	var nm: String = players.get(id, {}).get("name", "Un giocatore")
	_remove_avatar(id)
	if is_host:
		players.erase(id)
		for nid in car_owner.keys():
			if car_owner[nid] == id:
				var car := world_car(nid)
				if car != null:
					_car_released.rpc(nid, car.global_position, car.rotation.y)
					_car_released(nid, car.global_position, car.rotation.y)
		_sync_players.rpc(players, mode, target_kills)
		_sync_players(players, mode, target_kills)
		_feed.rpc("%s ha lasciato la partita" % nm)
		_feed("%s ha lasciato la partita" % nm)


@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String, pchar: String, version: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if version != Game.VERSION:
		_rejected.rpc_id(id, "Versione diversa: l'host ha la %s, tu la %s." % [Game.VERSION, version])
		return
	if players.size() >= MAX_PLAYERS:
		_rejected.rpc_id(id, "La partita è piena (%d giocatori)." % MAX_PLAYERS)
		return
	if not Game.CHARACTERS.has(pchar):
		pchar = "mike"
	players[id] = {"name": _unique_name(pname.substr(0, 16)), "char": pchar, "kills": 0, "deaths": 0}
	_sync_players.rpc(players, mode, target_kills)
	_sync_players(players, mode, target_kills)
	_car_snapshot.rpc_id(id, _car_states())
	var msg := "%s è entrato in partita" % players[id]["name"]
	for pid in players:
		if pid != 1 and pid != id:
			_feed.rpc_id(pid, msg)
	_feed(msg)


func _unique_name(n: String) -> String:
	var base := n if n.strip_edges() != "" else "Giocatore"
	var out := base
	var k := 2
	var taken := true
	while taken:
		taken = false
		for id in players:
			if players[id]["name"] == out:
				taken = true
		if taken:
			out = "%s %d" % [base, k]
			k += 1
	return out


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	_fail(reason)


@rpc("authority", "call_remote", "reliable")
func _sync_players(p: Dictionary, m: String, target: int) -> void:
	players = p
	mode = m
	target_kills = target
	if not connected and not is_host:
		connected = true
		world.hud.show_message("CONNESSO!", "%d giocatori in partita" % players.size(), Color(0.5, 1.0, 0.6), 3.0)
		print("[NET] connesso come peer %d" % my_id)
	for id in players:
		if id != my_id and not avatars.has(id):
			_add_avatar(id)
		elif avatars.has(id):
			avatars[id].set_info(players[id])
	for id in avatars.keys():
		if not players.has(id):
			_remove_avatar(id)
	players_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _feed(msg: String) -> void:
	world.hud.toast(msg, 3.0)


func _add_avatar(id: int) -> void:
	var av := NetAvatar.new()
	av.setup(self, id, players[id])
	world.add_child(av)
	av.global_position = Vector3(0, -50, 0)
	avatars[id] = av


func _remove_avatar(id: int) -> void:
	if avatars.has(id):
		var av: NetAvatar = avatars[id]
		if is_instance_valid(av):
			av.queue_free()
		avatars.erase(id)


# ---------------------------------------------------------------- stato

func _physics_process(delta: float) -> void:
	if is_host and _beacon != null:
		_beacon_t -= delta
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			_send_beacon()
	if not connected or multiplayer.multiplayer_peer == null:
		return
	_send_t -= delta
	if _send_t > 0.0:
		return
	_send_t = SEND_RATE
	var p: Protagonist = world.player
	var car_id := -1
	var cpos := Vector3.ZERO
	var cyaw := 0.0
	var cspd := 0.0
	var cst := 0.0
	if p.vehicle != null:
		car_id = p.vehicle.net_id
		cpos = p.vehicle.global_position
		cyaw = p.vehicle.rotation.y
		cspd = p.vehicle.speed
		cst = p.vehicle.steer
	var data := [p.global_position, p.yaw, Vector2(p.velocity.x, p.velocity.z).length(), p.is_on_floor(), p.dead,
		Game.current_weapon, car_id, cpos, cyaw, cspd, cst, p.health, p.model.aim_t > 0.0]
	_state.rpc(data)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(data: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not avatars.has(id) or data.size() < 13:
		return
	var av: NetAvatar = avatars[id]
	av.apply_state(data)
	var car_id: int = data[6]
	if car_id >= 0:
		var car := world_car(car_id)
		if car != null and car.driver == null:
			if car.remote_driver != id:
				car.remote_driver = id
				car_owner[car_id] = id
				car.model.set_driver(true, av.skin())
			car.apply_net_state(data[7], data[8], data[9], data[10])


# ---------------------------------------------------------------- auto

func world_car(nid: int) -> Car:
	for c in world.cars:
		if is_instance_valid(c) and c.net_id == nid:
			return c
	return null


func _car_states() -> Array:
	var out := []
	for c in world.cars:
		if is_instance_valid(c) and c.net_id >= 0:
			out.append([c.net_id, c.global_position, c.rotation.y, int(car_owner.get(c.net_id, 0))])
	return out


@rpc("authority", "call_remote", "reliable")
func _car_snapshot(states: Array) -> void:
	for st in states:
		var car := world_car(st[0])
		if car == null:
			continue
		car.global_position = st[1]
		car.rotation.y = st[2]
		car_owner[st[0]] = st[3]
		car.remote_driver = st[3] if st[3] != my_id else 0
		car.apply_net_state(st[1], st[2], 0.0, 0.0)


func request_car(car: Car) -> void:
	if car.net_id < 0:
		world.enter_vehicle(world.player, car)
		return
	if is_host:
		_grant_car(car.net_id, my_id)
	else:
		_req_car.rpc_id(1, car.net_id)


@rpc("any_peer", "call_remote", "reliable")
func _req_car(nid: int) -> void:
	if is_host:
		_grant_car(nid, multiplayer.get_remote_sender_id())


func _grant_car(nid: int, peer: int) -> void:
	var owner: int = car_owner.get(nid, 0)
	if owner != 0 and owner != peer and players.has(owner):
		if peer == my_id:
			world.hud.toast("Quell'auto è guidata da un altro giocatore.", 1.5)
		else:
			_feed.rpc_id(peer, "Quell'auto è guidata da un altro giocatore.")
		return
	car_owner[nid] = peer
	_car_owner.rpc(nid, peer)
	_car_owner(nid, peer)


@rpc("authority", "call_remote", "reliable")
func _car_owner(nid: int, peer: int) -> void:
	car_owner[nid] = peer
	var car := world_car(nid)
	if car == null:
		return
	if peer == my_id:
		car.remote_driver = 0
		var p: Protagonist = world.player
		if not p.in_vehicle() and not p.dead and p.global_position.distance_to(car.global_position) < 7.0:
			world.enter_vehicle(p, car)
		else:
			release_car(car)
	elif peer != 0:
		car.remote_driver = peer
		car.apply_net_state(car.global_position, car.rotation.y, 0.0, 0.0)
		if avatars.has(peer):
			car.model.set_driver(true, avatars[peer].skin())


func release_car(car: Car) -> void:
	if car == null or car.net_id < 0:
		return
	_car_released.rpc(car.net_id, car.global_position, car.rotation.y)
	_car_released(car.net_id, car.global_position, car.rotation.y)


@rpc("any_peer", "call_remote", "reliable")
func _car_released(nid: int, pos: Vector3, yaw: float) -> void:
	car_owner[nid] = 0
	var car := world_car(nid)
	if car == null or car.driver != null:
		return
	car.remote_driver = 0
	car.global_position = pos
	car.rotation.y = yaw
	car.speed = 0.0
	car.velocity = Vector3.ZERO
	car.model.set_driver(false)


# ---------------------------------------------------------------- combattimento

func hit_player(peer: int, dmg: float, kind: String) -> void:
	if peer == my_id or not players.has(peer):
		return
	_hit.rpc_id(peer, dmg, kind)


@rpc("any_peer", "call_remote", "reliable")
func _hit(dmg: float, _kind: String) -> void:
	var p: Protagonist = world.player
	if p.dead:
		return
	last_attacker = multiplayer.get_remote_sender_id()
	p.take_damage(dmg, null, Vector3.ZERO)


func on_local_ko() -> void:
	var killer := last_attacker
	last_attacker = 0
	if is_host:
		_register_ko(my_id, killer)
	else:
		_ko.rpc_id(1, killer)


@rpc("any_peer", "call_remote", "reliable")
func _ko(killer: int) -> void:
	if is_host:
		_register_ko(multiplayer.get_remote_sender_id(), killer)


func _register_ko(victim: int, killer: int) -> void:
	if not players.has(victim):
		return
	players[victim]["deaths"] = int(players[victim]["deaths"]) + 1
	var msg := "%s è finito K.O." % players[victim]["name"]
	if killer != 0 and killer != victim and players.has(killer):
		players[killer]["kills"] = int(players[killer]["kills"]) + 1
		msg = "%s ha messo K.O. %s" % [players[killer]["name"], players[victim]["name"]]
	_scores.rpc(players, msg)
	_scores(players, msg)
	if mode == "deathmatch" and not _round_over and killer != 0 and players.has(killer) \
			and int(players[killer]["kills"]) >= target_kills:
		_round_over = true
		_match_end.rpc(players[killer]["name"])
		_match_end(players[killer]["name"])
		get_tree().create_timer(8.0).timeout.connect(_new_round)


@rpc("authority", "call_remote", "reliable")
func _scores(p: Dictionary, msg: String) -> void:
	players = p
	world.hud.toast(msg, 3.0)
	players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _match_end(winner: String) -> void:
	world.hud.show_message("VINCE %s!" % winner.to_upper(), "Nuovo round tra pochi secondi", Color(1.0, 0.82, 0.25), 6.0)
	Sfx.play("mission_pass")


func _new_round() -> void:
	if not is_host or _closing:
		return
	_round_over = false
	for id in players:
		players[id]["kills"] = 0
		players[id]["deaths"] = 0
	_scores.rpc(players, "Nuovo round: primo a %d K.O.!" % target_kills)
	_scores(players, "Nuovo round: primo a %d K.O.!" % target_kills)


func send_shot_fx(from: Vector3, to: Vector3, weapon: String) -> void:
	if connected:
		_shot_fx.rpc(from, to, weapon)


@rpc("any_peer", "call_remote", "unreliable")
func _shot_fx(from: Vector3, to: Vector3, weapon: String) -> void:
	Gfx.tracer(world, from, to)
	Gfx.muzzle_flash(world, from)
	var snd: String = Game.WEAPONS.get(weapon, Game.WEAPONS["pistol"])["sound"]
	Sfx.play_at(snd, from, world.camera.global_position, 90.0, -4.0)


# ---------------------------------------------------------------- scoperta in LAN

func _send_beacon() -> void:
	var msg := JSON.stringify({
		"game": MAGIC, "name": players[1]["name"], "players": players.size(), "max": MAX_PLAYERS,
		"mode": mode, "port": port, "version": Game.VERSION,
	}).to_utf8_buffer()
	for addr in broadcast_addresses():
		_beacon.set_dest_address(addr, DISCOVERY_PORT)
		_beacon.put_packet(msg)


static func _private_ipv4() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		var s := str(a)
		if s.count(".") != 3:
			continue
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			out.append(s)
	out.sort_custom(func(x, y): return str(x).begins_with("192.168.") and not str(y).begins_with("192.168."))
	return out


static func local_ip() -> String:
	var ips := _private_ipv4()
	return ips[0] if not ips.is_empty() else "127.0.0.1"


static func broadcast_addresses() -> Array:
	var out := ["255.255.255.255"]
	for ip in _private_ipv4():
		var parts := str(ip).split(".")
		var b := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not out.has(b):
			out.append(b)
	return out


# ---------------------------------------------------------------- interfaccia

func nearest_avatar_distance(p: Vector3) -> float:
	var best := 999.0
	for id in avatars:
		var av: NetAvatar = avatars[id]
		if is_instance_valid(av):
			best = minf(best, av.global_position.distance_to(p))
	return best


func get_blips() -> Array:
	var out := []
	for id in avatars:
		var av: NetAvatar = avatars[id]
		if is_instance_valid(av) and not av.dead:
			out.append({"pos": av.global_position, "color": av.color, "label": av.initial(), "kind": "char"})
	return out


func scoreboard() -> Array:
	var rows := []
	for id in players:
		var d: Dictionary = players[id]
		rows.append({"name": d["name"], "char": d["char"], "kills": int(d["kills"]), "deaths": int(d["deaths"]), "me": id == my_id})
	rows.sort_custom(func(a, b): return a["kills"] > b["kills"])
	return rows


func mode_text() -> String:
	if mode == "deathmatch":
		return "Deathmatch: vince chi arriva per primo a %d K.O." % target_kills
	return "Modalità libera: esplora, guida e sfida gli amici"


func session_info() -> String:
	var role := "Host · IP %s · porta %d" % [local_ip(), port] if is_host else "Collegato a %s" % host_ip
	return "%s\n%d/%d giocatori · %s" % [role, players.size(), MAX_PLAYERS, mode_text()]


func score_text() -> String:
	if not players.has(my_id):
		return "MP · connessione..."
	var me: Dictionary = players[my_id]
	return "MP %d giocatori · K.O. %d · subiti %d" % [players.size(), int(me["kills"]), int(me["deaths"])]
