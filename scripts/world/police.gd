class_name Police
extends Node
## Livello di ricercato da 0 a 5 stelle e risposta della polizia.
## I crimini aumentano il "calore"; ogni soglia è una stella. La polizia manda
## pattuglie (fino a 5), agenti a piedi che arrestano (1 stella) o sparano
## (2+), squadre SWAT (4+) e un elicottero (4+). Per seminarla bisogna uscire
## dall'area di ricerca e restare fuori vista per qualche secondo.

signal stars_changed(stars: int)

const THRESHOLDS := [1.0, 4.0, 10.0, 20.0, 35.0]
const LOSE_TIME := [0.0, 7.0, 9.0, 11.0, 13.0, 15.0]
const MAX_COPS := 10

var world: Node
var heat := 0.0
var stars := 0
var seen := false
var unseen_t := 0.0
var last_seen := Vector3.ZERO
var arrest_t := 0.0
var cars: Array = []
var cops: Array = []
var heli: Helicopter = null
var _spawn_cd := 0.0
var _check_t := 0.0
var _shots_cd := 0.0
var _dismissed: Array = []


func search_radius() -> float:
	return 45.0 + 15.0 * stars


func report(kind: String, pos: Vector3) -> void:
	if world.mp or world.state != "play":
		return
	match kind:
		"shots":
			if _shots_cd > 0.0:
				return
			_shots_cd = 2.0
			heat = maxf(heat, 1.0)
		"assault":
			heat = maxf(heat, 1.0) + 0.5
		"hijack":
			if _units_near(pos, 50.0):
				heat += 2.0
			else:
				return
		"hijack_police":
			heat += 4.0
		"ped_ko":
			heat += 3.0
		"car_destroyed":
			heat += 2.0
		"cop_hit":
			heat = maxf(heat, 4.0) + 1.0
		"cop_ko":
			heat += 6.0
		"cop_car_destroyed":
			heat += 5.0
		"heli_down":
			heat = maxf(heat, THRESHOLDS[4])
		_:
			return
	heat = minf(heat, 60.0)
	last_seen = world.player_pos()
	unseen_t = 0.0
	_update_stars()


func set_stars(n: int) -> void:
	n = clampi(n, 0, 5)
	heat = 0.0 if n == 0 else THRESHOLDS[n - 1]
	last_seen = world.player_pos()
	unseen_t = 0.0
	_update_stars()


func _update_stars() -> void:
	var s := 0
	for i in THRESHOLDS.size():
		if heat >= THRESHOLDS[i]:
			s = i + 1
	if s == stars:
		return
	var up := s > stars
	stars = s
	stars_changed.emit(stars)
	if up:
		world.hud.flash_stars()
		Sfx.play("alarm", -12.0)
		for e in cops:
			if is_instance_valid(e) and not e.dead:
				_arm(e)


func clear() -> void:
	var had := stars > 0
	heat = 0.0
	stars = 0
	unseen_t = 0.0
	arrest_t = 0.0
	_shots_cd = 0.0
	_spawn_cd = 0.0
	stars_changed.emit(0)
	for c in cars:
		if is_instance_valid(c):
			c.ai_mode = Car.AI.NONE
			c.model.set_siren(false)
			_dismissed.append(c)
	for e in cops:
		if is_instance_valid(e):
			e.passive = true
			_dismissed.append(e)
	cars.clear()
	cops.clear()
	if heli != null and is_instance_valid(heli):
		heli.leaving = true
	heli = null
	if had:
		Sfx.set_siren(0.0)


func _physics_process(delta: float) -> void:
	if world.state != "play" or world.mp:
		Sfx.set_siren(0.0)
		Sfx.set_heli(0.0)
		return
	_shots_cd -= delta
	_cleanup()
	if stars > 0:
		_check_t -= delta
		if _check_t <= 0.0:
			_check_t = 0.25
			seen = _sees_player()
			if seen:
				last_seen = world.player_pos()
		var outside := Vector2(world.player_pos().x - last_seen.x, world.player_pos().z - last_seen.z).length() > search_radius()
		if seen:
			unseen_t = 0.0
		elif outside:
			unseen_t += delta
		if unseen_t > LOSE_TIME[stars]:
			clear()
			world.hud.show_message("SEMINATI!", "La polizia ha perso le tue tracce", Color(0.5, 0.8, 1.0), 2.5)
			return
		_spawn(delta)
		_drive_units()
		_arrest(delta)
	_audio()


func _units_near(pos: Vector3, r: float) -> bool:
	for c in cars:
		if is_instance_valid(c) and c.global_position.distance_to(pos) < r:
			return true
	for e in cops:
		if is_instance_valid(e) and e.global_position.distance_to(pos) < r:
			return true
	for c in world.cars:
		if is_instance_valid(c) and c.car_type == "police" and c.global_position.distance_to(pos) < r:
			return true
	return false


func _los(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _sees_player() -> bool:
	var pp: Vector3 = world.player_pos() + Vector3(0, 1.2, 0)
	var reach := 45.0 + stars * 12.0
	for c in cars:
		if is_instance_valid(c) and not c.wrecked:
			var o: Vector3 = c.global_position + Vector3(0, 1.5, 0)
			if o.distance_to(pp) < reach and _los(o, pp):
				return true
	for e in cops:
		if is_instance_valid(e) and not e.dead:
			var o2: Vector3 = e.global_position + Vector3(0, 1.6, 0)
			if o2.distance_to(pp) < reach and _los(o2, pp):
				return true
	if heli != null and is_instance_valid(heli) and not heli.crashing:
		if heli.global_position.distance_to(pp) < 150.0:
			return true
	return false


func _alive_cars() -> int:
	var n := 0
	for c in cars:
		if is_instance_valid(c) and not c.wrecked and not c.get_meta("deployed", false):
			n += 1
	return n


func _spawn(delta: float) -> void:
	if stars >= 4 and (heli == null or not is_instance_valid(heli)):
		heli = Helicopter.new()
		world.add_child(heli)
		heli.setup(world, world.player_pos() + Vector3(-60, 45, -60))
	_spawn_cd -= delta
	if _spawn_cd > 0.0:
		return
	if _alive_cars() < stars:
		_spawn_cd = maxf(1.5, 5.0 - stars * 0.7)
		var sp: Dictionary = world.road_spawn(world.player_pos(), 75.0, 150.0)
		var type := "swat" if stars >= 4 and _alive_cars() % 2 == 1 else "police"
		var c: Car = world.spawn_car(type, sp["pos"], sp["yaw"])
		c.hostile = true
		c.npc_driver = true
		c.model.set_driver(true, Color(0.85, 0.68, 0.55))
		c.model.set_siren(true)
		c.ai_mode = Car.AI.CHASE
		c.ai_target = world.player
		c.ai_max_speed = 24.0 + stars * 3.0
		c.set_meta("police", true)
		cars.append(c)


func _drive_units() -> void:
	var p: Protagonist = world.player
	for c in cars:
		if not is_instance_valid(c) or c.wrecked or c.get_meta("deployed", false):
			continue
		c.ai_target = p
		c.ai_max_speed = 24.0 + stars * 3.0
		if not p.in_vehicle() and c.global_position.distance_to(p.global_position) < 22.0 and cops.size() < MAX_COPS:
			_deploy(c)


func _deploy(c: Car) -> void:
	c.set_meta("deployed", true)
	c.ai_mode = Car.AI.NONE
	c.npc_driver = false
	c.hostile = false
	c.model.set_driver(false)
	var swat := c.car_type == "swat"
	for side: float in [-1.0, 1.0]:
		var pos: Vector3 = c.global_position + c.global_transform.basis.x * side * (c.size.x * 0.5 + 0.9)
		var e: Enemy = world.spawn_enemy("swat" if swat else "cop", pos, 90.0 if swat else 60.0)
		e.is_cop = true
		e.drop_boost = 0.1
		e.speed = 5.4
		_arm(e)
		cops.append(e)


func _arm(e: Enemy) -> void:
	if stars <= 1:
		e.arm("", 0.0)
	elif stars <= 3:
		e.arm("pistol", 0.4 + stars * 0.05)
	else:
		e.arm("smg" if randf() < 0.6 else "rifle", 0.5)


func _arrest(delta: float) -> void:
	var p: Protagonist = world.player
	var near := false
	if not p.in_vehicle() and not p.dead:
		for e in cops:
			if is_instance_valid(e) and not e.dead and e.arrest_only and e.down_time <= 0.0 \
					and e.global_position.distance_to(p.global_position) < 1.8:
				near = true
				break
	if near:
		if arrest_t <= 0.0:
			world.hud.toast("Un agente ti sta arrestando! Scappa o reagisci.", 1.5)
		arrest_t += delta
		if arrest_t > 1.4:
			arrest_t = 0.0
			world.on_busted()
	else:
		arrest_t = maxf(0.0, arrest_t - delta * 0.5)


func _cleanup() -> void:
	var pp: Vector3 = world.player_pos()
	for list in [cars, cops]:
		for u in list.duplicate():
			if not is_instance_valid(u):
				list.erase(u)
			elif u.global_position.distance_to(pp) > 260.0:
				list.erase(u)
				if not (u is Car and u.driver != null):
					u.queue_free()
	for u in _dismissed.duplicate():
		if not is_instance_valid(u):
			_dismissed.erase(u)
		elif u.global_position.distance_to(pp) > 70.0:
			_dismissed.erase(u)
			if not (u is Car and u.driver != null):
				u.queue_free()


func _audio() -> void:
	var pp: Vector3 = world.player_pos()
	var nearest := INF
	for c in cars:
		if is_instance_valid(c) and not c.wrecked and not c.get_meta("deployed", false):
			nearest = minf(nearest, c.global_position.distance_to(pp))
	Sfx.set_siren(clampf(1.0 - nearest / 120.0, 0.0, 1.0) if stars > 0 else 0.0)
	var hd := INF
	if heli != null and is_instance_valid(heli):
		hd = heli.global_position.distance_to(pp)
	Sfx.set_heli(clampf(1.0 - hd / 160.0, 0.0, 1.0))


func unit_blips() -> Array:
	var out := []
	var blink := (Time.get_ticks_msec() / 300) % 2 == 0
	var col := Color(0.25, 0.45, 1.0) if blink else Color(1.0, 0.2, 0.2)
	for c in cars:
		if is_instance_valid(c) and not c.wrecked:
			out.append({"pos": c.global_position, "color": col, "label": "", "kind": "enemy_far"})
	for e in cops:
		if is_instance_valid(e) and not e.dead:
			out.append({"pos": e.global_position, "color": col, "label": "", "kind": "enemy"})
	if heli != null and is_instance_valid(heli):
		out.append({"pos": heli.global_position, "color": col, "label": "H", "kind": "icon"})
	return out
