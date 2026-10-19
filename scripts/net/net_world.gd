class_name NetWorld
extends Node
## Personaggi non giocanti in multiplayer. L'host simula passanti e traffico;
## ogni giocatore simula la propria polizia (pattuglie, agenti, elicottero).
## Ogni peer invia 10 volte al secondo lo stato delle entità che simula a chi
## è abbastanza vicino da vederle; gli altri le mostrano come "marionette".
## I colpi alle marionette vanno al proprietario, che applica il danno e
## segnala l'eventuale reato a chi ha sparato (che riceve le stelle).

const RATE := 0.1
const RANGE := 210.0
const TIMEOUT := 1.2
const CHUNK := 12
const K_CAR := 0
const K_PED := 1
const K_COP := 2
const K_HELI := 3
const PUPPET_SKIN := Color(0.85, 0.68, 0.55)

var net: Node
var world: Node
## Entità simulate qui, per id di rete (per le auto dell'host è il net_id).
var local_ents: Dictionary = {}
## Marionette delle entità altrui: "proprietario:id" -> {node, t}.
var proxies: Dictionary = {}
var _next_id := 1000
var _send_t := 0.0
var _seq := 0
var _last_seq: Dictionary = {}
var _now := 0.0


func alloc_id() -> int:
	_next_id += 1
	return _next_id


func _eid(n: Node) -> int:
	if n is Car and net.is_host and n.net_id >= 0:
		return n.net_id
	if not n.has_meta("eid"):
		n.set_meta("eid", alloc_id())
	return int(n.get_meta("eid"))


func _physics_process(delta: float) -> void:
	_now += delta
	if not net.connected or multiplayer.multiplayer_peer == null:
		return
	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = RATE
		_send()
	_expire()


# ---------------------------------------------------------------- invio

func _collect() -> Array:
	var out := []
	local_ents.clear()
	for c in world.cars:
		if not is_instance_valid(c) or c.net_puppet:
			continue
		if not net.is_host and c.net_id >= 0:
			continue
		var cid := _eid(c)
		local_ents[cid] = c
		# l'auto dell'host guidata da un giocatore arriva con lo stato di chi guida
		if c.net_id >= 0 and (c.driver != null or c.remote_driver != 0):
			continue
		out.append([K_CAR, cid, c.global_position, c.rotation.y, c.speed, c.steer, c.car_type, c.paint,
			c.npc_driver, c.model.siren_on, c.driver != null])
	if net.is_host:
		for ped in world.peds:
			if not is_instance_valid(ped) or ped._sleep:
				continue
			var pid := _eid(ped)
			local_ents[pid] = ped
			out.append([K_PED, pid, ped.global_position, ped.yaw, Vector2(ped.velocity.x, ped.velocity.z).length(),
				_actor_state(ped), ped.look_seed])
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Enemy):
			continue
		var en := e as Enemy
		var id := _eid(en)
		local_ents[id] = en
		out.append([K_COP, id, en.global_position, en.yaw, Vector2(en.velocity.x, en.velocity.z).length(),
			_actor_state(en), en.look_id, en.gun, en.model.aim_t > 0.0])
	for h in get_tree().get_nodes_in_group("helis"):
		if not is_instance_valid(h) or h.puppet:
			continue
		var hid := _eid(h)
		local_ents[hid] = h
		out.append([K_HELI, hid, h.global_position, h.rotation.y, h.crashing])
	return out


static func _actor_state(a: Actor) -> int:
	if a.dead:
		return 2
	return 1 if a.down_time > 0.0 else 0


func _send() -> void:
	var ents := _collect()
	if ents.is_empty():
		return
	_seq += 1
	for peer in net.players:
		if peer == net.my_id:
			continue
		var ppos: Variant = net.peer_position(peer)
		var batch := []
		for e in ents:
			if ppos == null or (e[2] as Vector3).distance_to(ppos) < RANGE:
				batch.append(e)
				if batch.size() >= CHUNK:
					_ents.rpc_id(peer, _seq, batch)
					batch = []
		if not batch.is_empty():
			_ents.rpc_id(peer, _seq, batch)


# ---------------------------------------------------------------- ricezione

@rpc("any_peer", "call_remote", "unreliable")
func _ents(seq: int, batch: Array) -> void:
	var owner := multiplayer.get_remote_sender_id()
	if seq < int(_last_seq.get(owner, 0)):
		return
	_last_seq[owner] = seq
	for e in batch:
		if not (e is Array) or (e as Array).size() < 5:
			continue
		match int(e[0]):
			K_CAR:
				_recv_car(owner, e)
			K_PED, K_COP:
				_recv_npc(owner, e)
			K_HELI:
				_recv_heli(owner, e)


func _key(owner: int, eid: int) -> String:
	return "%d:%d" % [owner, eid]


func _proxy(key: String) -> Node:
	if not proxies.has(key):
		return null
	var n: Variant = proxies[key]["node"]
	if n == null or not is_instance_valid(n):
		proxies.erase(key)
		return null
	return n


func _recv_car(owner: int, e: Array) -> void:
	var eid: int = e[1]
	var key := _key(owner, eid)
	var car: Car = null
	if owner == 1:
		car = net.world_car(eid)
	else:
		car = _proxy(key) as Car
	if car == null:
		car = make_car_proxy(owner, eid, str(e[6]), e[7], e[2], e[3])
	proxies[key] = {"node": car, "t": _now}
	if car.driver != null or car.remote_driver != 0:
		return
	car.apply_net_state(e[2], e[3], e[4], e[5])
	# guidata dal suo proprietario: gli investimenti li rileva chi guida
	car.puppet_player_driven = e.size() > 10 and bool(e[10])
	var npc := bool(e[8])
	if npc != car.npc_driver:
		car.npc_driver = npc
		car.model.set_driver(npc, PUPPET_SKIN)
	if car.model.siren_on != bool(e[9]):
		car.model.set_siren(bool(e[9]))


## Auto di un altro peer mostrata qui (per l'host: net_id = id, guidabile).
func make_car_proxy(owner: int, eid: int, type: String, color: Variant, pos: Vector3, yaw: float) -> Car:
	var car: Car = world.spawn_car(type, pos, yaw, color if color is Color else null)
	car.net_id = eid if owner == 1 else -1
	car.puppet_owner = owner
	car.set_net_puppet(true)
	car.damage_taken_mult = 0.0
	proxies[_key(owner, eid)] = {"node": car, "t": _now}
	return car


func _recv_npc(owner: int, e: Array) -> void:
	var key := _key(owner, int(e[1]))
	var pup := _proxy(key) as NetPuppet
	if pup == null:
		var look: Dictionary
		if int(e[0]) == K_PED:
			look = Pedestrian.make_look(int(e[6]))
		else:
			look = Game.NPC_LOOKS.get(str(e[6]), Game.NPC_LOOKS["cop"])
		pup = NetPuppet.new()
		pup.setup(self, owner, int(e[1]), int(e[0]), look)
		world.add_child(pup)
		pup.global_position = e[2]
	proxies[key] = {"node": pup, "t": _now}
	pup.apply(e)


func _recv_heli(owner: int, e: Array) -> void:
	var key := _key(owner, int(e[1]))
	var h := _proxy(key) as Helicopter
	if h == null:
		h = Helicopter.new()
		h.puppet = true
		h.net_owner = owner
		h.net_eid = int(e[1])
		h.ents = self
		world.add_child(h)
		h.setup(world, e[2])
	proxies[key] = {"node": h, "t": _now}
	h.apply_net(e[2], e[3], bool(e[4]))


func _expire() -> void:
	for key in proxies.keys():
		var n := _proxy(key)
		if n == null:
			continue
		if _now - float(proxies[key]["t"]) < TIMEOUT:
			continue
		if n is Car:
			var car := n as Car
			# le auto parcheggiate dell'host restano; quelle guidate da un giocatore pure
			if car.driver != null or car.remote_driver != 0 or (car.net_id >= 0 and car.net_id < 1000):
				proxies[key]["t"] = _now
				continue
		proxies.erase(key)
		n.queue_free()


## Un giocatore è uscito: spariscono le sue marionette.
func remove_owner(owner: int) -> void:
	for key in proxies.keys():
		if str(key).begins_with("%d:" % owner):
			var n := _proxy(key)
			proxies.erase(key)
			if n != null and not (n is Car and (n as Car).driver != null):
				n.queue_free()


# ---------------------------------------------------------------- colpi

## Colpo a una marionetta: lo applica il proprietario dell'entità.
func hit_entity(owner: int, eid: int, amount: float, kind: String, push: Vector3) -> void:
	if owner == net.my_id or not net.players.has(owner):
		return
	_hit_ent.rpc_id(owner, eid, amount, kind, push)


@rpc("any_peer", "call_remote", "reliable")
func _hit_ent(eid: int, amount: float, kind: String, push: Vector3) -> void:
	var n: Variant = local_ents.get(eid)
	if n == null or not is_instance_valid(n):
		return
	var src: Node = net.avatars.get(multiplayer.get_remote_sender_id())
	if n is Actor:
		var a := n as Actor
		match kind:
			"car":
				a.hit_by_car(src, amount / 1.3, push)
			"punch":
				a.take_damage(amount, src, push)
			_:
				a.take_bullet(amount, src, push)
	elif (n as Node).has_method("take_bullet"):
		n.take_bullet(amount, src, push)


func puppet_count(kind: int, owner: int = -1) -> int:
	var c := 0
	for key in proxies.keys():
		var n := _proxy(key)
		if n == null or (owner >= 0 and not str(key).begins_with("%d:" % owner)):
			continue
		if (kind == K_CAR and n is Car) or (kind == K_HELI and n is Helicopter) \
				or (n is NetPuppet and (n as NetPuppet).kind == kind):
			c += 1
	return c
