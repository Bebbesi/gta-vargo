class_name Car
extends CharacterBody3D
## Auto con guida arcade (accelera, frena, retromarcia, sterza, derapa),
## collisioni reali con edifici e altri veicoli, danni e IA (traffico,
## inseguimento, percorso). La stessa fisica vale per giocatore e IA.

signal damaged(amount: float, by: Node)
signal destroyed(car: Car)

enum AI { NONE, TRAFFIC, CHASE, PATH }

const TYPES := {
	"sport": {"name": "Ardena Vortex", "speed": 44.0, "accel": 17.0, "steer": 2.3, "grip": 7.5, "health": 120.0, "size": Vector3(1.9, 1.08, 4.3)},
	"sedan": {"name": "Comet", "speed": 34.0, "accel": 12.0, "steer": 2.1, "grip": 6.5, "health": 150.0, "size": Vector3(2.0, 1.42, 4.5)},
	"taxi": {"name": "Taxi Comet", "speed": 33.0, "accel": 12.0, "steer": 2.1, "grip": 6.5, "health": 150.0, "size": Vector3(2.0, 1.42, 4.5)},
	"van": {"name": "Mulo", "speed": 27.0, "accel": 8.5, "steer": 1.7, "grip": 5.5, "health": 220.0, "size": Vector3(2.2, 2.3, 5.2)},
	"muscle": {"name": "Bruto", "speed": 40.0, "accel": 15.0, "steer": 1.9, "grip": 4.6, "health": 170.0, "size": Vector3(2.0, 1.28, 4.6)},
	"viper": {"name": "Vipera", "speed": 38.0, "accel": 14.0, "steer": 2.0, "grip": 6.0, "health": 170.0, "size": Vector3(2.0, 1.3, 4.6)},
	"luxury": {"name": "Regale", "speed": 31.0, "accel": 11.0, "steer": 1.9, "grip": 6.0, "health": 180.0, "size": Vector3(2.0, 1.38, 4.9)},
	"police": {"name": "Pattuglia", "speed": 41.0, "accel": 15.5, "steer": 2.2, "grip": 6.8, "health": 190.0, "size": Vector3(2.0, 1.42, 4.6)},
	"swat": {"name": "Blindato SWAT", "speed": 33.0, "accel": 11.0, "steer": 1.8, "grip": 6.0, "health": 320.0, "size": Vector3(2.3, 2.4, 5.4)},
}
const COLORS := [
	Color(0.85, 0.15, 0.12), Color(0.15, 0.35, 0.75), Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.12),
	Color(0.25, 0.6, 0.3), Color(0.95, 0.75, 0.15), Color(0.55, 0.55, 0.6), Color(0.45, 0.2, 0.55),
	Color(0.95, 0.45, 0.15), Color(0.3, 0.75, 0.85),
]
const BRAKE := 30.0
const REVERSE_MAX := 9.0

var world: Node
var car_type := "sedan"
var stats: Dictionary = {}
var size := Vector3(2.0, 1.42, 4.5)
var model: CarModel
var collider: CollisionShape3D
var speed := 0.0
var throttle := 0.0
var steer := 0.0
var max_health := 100.0
var health := 100.0
var damage_taken_mult := 1.0
var wrecked := false
var driver: Protagonist = null
var npc_driver := false
var hostile := false
var frozen := false
var is_traffic := false
var ai_mode := AI.NONE
var ai_max_speed := 13.0
var ai_target: Node3D = null
var ai_points: Array = []
var ai_index := 0
var ai_loop := false
var ai_radius := 9.0
var path_done := false
var ai_prev := -1
var ai_next := -1
var ai_phase := 0
var ai_turn_point := Vector3.ZERO
var ai_route: Array = []
var ai_repath := 0.0
var stuck_time := 0.0
var reverse_time := 0.0
var blocked_time := 0.0
var ignore_block := 0.0
var nitro := 0.0
var push_vel := Vector3.ZERO
var impact_cd := 0.0
var horn_cd := 0.0
var last_hit_by: Node = null
## Multiplayer: indice condiviso dell'auto e peer che la sta guidando da remoto.
var net_id := -1
var remote_driver := 0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0


func setup(type: String, color: Color, w: Node) -> void:
	world = w
	car_type = type if TYPES.has(type) else "sedan"
	stats = TYPES[car_type]
	size = stats["size"]
	max_health = stats["health"]
	health = max_health
	name = "Car_%s_%d" % [car_type, get_instance_id()]
	collision_layer = 4
	collision_mask = 1 | 4
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(40.0)
	safe_margin = 0.04
	collider = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var sy := size.y - 0.15
	bs.size = Vector3(size.x, sy, size.z)
	collider.shape = bs
	collider.position = Vector3(0, 0.03 + sy * 0.5, 0)
	add_child(collider)
	model = CarModel.new()
	add_child(model)
	model.build(car_type, color, size)
	add_to_group("cars")


func display_name() -> String:
	return stats.get("name", "Auto")


func forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _physics_process(delta: float) -> void:
	impact_cd = maxf(0.0, impact_cd - delta)
	horn_cd -= delta
	if remote_driver != 0:
		_remote_follow(delta)
		return
	if wrecked:
		speed = move_toward(speed, 0.0, 25.0 * delta)
		throttle = 0.0
		steer = 0.0
		_move(delta)
		return
	if driver == null and ai_mode == AI.NONE and absf(speed) < 0.05 and push_vel.length_squared() < 0.01 \
			and Vector2(velocity.x, velocity.z).length_squared() < 0.01 and is_on_floor():
		return
	_gather_input(delta)
	_drive(delta)
	_move(delta)
	if absf(speed) > 4.0:
		_hit_actors()
	model.update_visuals(delta, speed, steer)
	if nitro > 0.0:
		nitro -= delta
		if nitro <= 0.0:
			model.set_nitro(false)
	if driver != null and driver.active:
		Sfx.set_engine(true, absf(speed) / 40.0)


# ---------------------------------------------------------------- guida

func _gather_input(delta: float) -> void:
	throttle = 0.0
	steer = 0.0
	if frozen:
		return
	if driver != null:
		if driver.active and world.can_control():
			steer = -Input.get_axis("move_left", "move_right")
			throttle = Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
	elif ai_mode != AI.NONE:
		_ai(delta)


func _drive(delta: float) -> void:
	var spd_mult := 1.0
	var acc_mult := 1.0
	if driver != null and driver.char_id == "mike":
		spd_mult = float(driver.data["drive"])
		acc_mult = 1.15
	elif driver != null and driver.char_id == "norman":
		spd_mult = float(driver.data["drive"])
	if nitro > 0.0:
		spd_mult *= 1.35
		acc_mult *= 2.2
	var vmax: float = float(stats["speed"]) * spd_mult
	if driver == null and ai_mode != AI.NONE:
		vmax = minf(vmax, ai_max_speed)
	var accel: float = float(stats["accel"]) * acc_mult
	if throttle > 0.05:
		if speed < -0.5:
			speed = move_toward(speed, 0.0, BRAKE * delta)
		else:
			speed = move_toward(speed, vmax * throttle, accel * delta)
	elif throttle < -0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, BRAKE * delta)
		else:
			speed = move_toward(speed, -REVERSE_MAX * -throttle, accel * 0.7 * delta)
	else:
		speed = move_toward(speed, 0.0, (5.0 if driver != null else 9.0) * delta)
	var steer_factor := clampf(absf(speed) / 5.0, 0.0, 1.0) * lerpf(1.0, 0.5, clampf(absf(speed) / 45.0, 0.0, 1.0))
	rotation.y += steer * float(stats["steer"]) * steer_factor * signf(speed) * delta


func _move(delta: float) -> void:
	var fwd := forward()
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var grip: float = float(stats["grip"]) * (0.4 if wrecked else 1.0)
	hv = hv.lerp(fwd * speed, clampf(grip * delta, 0.0, 1.0)) + push_vel
	push_vel = Vector3.ZERO
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y -= 30.0 * delta
	move_and_slide()
	var hit_wall := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if n.y > 0.6:
			continue
		hit_wall = true
		var impact := -hv.dot(n)
		if impact > 3.5 and impact_cd <= 0.0:
			impact_cd = 0.4
			_impact(impact, c.get_collider(), n, c.get_position())
	if hit_wall:
		speed = lerpf(speed, velocity.dot(fwd), 0.6)
	if global_position.y < -20.0 and world != null:
		world.recover_car(self)


func _impact(impact: float, other: Object, n: Vector3, at: Vector3) -> void:
	var dmg := (impact - 3.0) * 1.5
	take_damage(dmg, other as Node)
	if other is Car:
		var oc := other as Car
		oc.take_damage(dmg * 0.9, self)
		oc.push_vel += -n * impact * 0.6
	var listener: Vector3 = world.camera.global_position
	Sfx.play_at("crash", global_position, listener, 70.0, -4.0 + minf(impact, 20.0) * 0.3)
	if driver != null and driver.active:
		world.camera.shake(clampf(impact * 0.03, 0.1, 0.6))
		Game.vibrate(int(clampf(impact * 8.0, 30.0, 200.0)))
	Gfx.burst(world, at + Vector3(0, 0.3, 0), Color(1.0, 0.8, 0.4), 8, 4.0, 0.1, 0.4)


func take_damage(amount: float, by: Node = null) -> void:
	if wrecked or amount <= 0.0:
		return
	health -= amount * damage_taken_mult
	if by != null:
		last_hit_by = by
	damaged.emit(amount, by)
	model.set_damage(1.0 - health / max_health)
	if health <= 0.0:
		wreck()


func wreck() -> void:
	if wrecked:
		return
	if world.is_player_source(last_hit_by) and driver == null:
		world.report_crime("cop_car_destroyed" if car_type in ["police", "swat"] else "car_destroyed", global_position)
	wrecked = true
	health = 0.0
	model.set_wrecked()
	model.set_nitro(false)
	Sfx.play_at("explosion", global_position, world.camera.global_position, 120.0, 2.0)
	Gfx.burst(world, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.1), 30, 9.0, 0.3, 0.9)
	if driver != null:
		var d := driver
		world.force_exit(d)
		d.take_damage(20.0, self, Vector3(0, 5, 0))
	npc_driver = false
	ai_mode = AI.NONE
	destroyed.emit(self)


## Proiettile: danneggia l'auto e in parte chi è al volante.
func take_bullet(amount: float, source: Node, _dir: Vector3) -> void:
	Gfx.burst(world, global_position + Vector3(0, size.y * 0.6, 0), Color(1.0, 0.9, 0.6), 5, 3.0, 0.06, 0.3)
	take_damage(amount * 0.4, source)
	if driver != null:
		driver.take_damage(amount * 0.3, source)
	elif remote_driver != 0 and world.mp and world.net != null:
		world.net.hit_player(remote_driver, amount * 0.3, "shot")


## Nuova vernice (riverniciatura al garage): ricostruisce il modello.
func repaint(c: Color) -> void:
	var had_driver := model.driver_head.visible
	model.queue_free()
	model = CarModel.new()
	add_child(model)
	model.build(car_type, c, size)
	model.set_driver(had_driver)
	repair()


func repair() -> void:
	wrecked = false
	health = max_health
	model.fire.emitting = false
	model.smoke.emitting = false
	model.body_mesh.material_override = Gfx.vc_mat()
	speed = 0.0
	velocity = Vector3.ZERO


# ---------------------------------------------------------------- multiplayer

## Stato ricevuto dalla rete per un'auto guidata da un altro giocatore.
func apply_net_state(pos: Vector3, yaw: float, spd: float, st: float) -> void:
	_net_pos = pos
	_net_yaw = yaw
	speed = spd
	steer = st


func _remote_follow(delta: float) -> void:
	var k := clampf(delta * 12.0, 0.0, 1.0)
	if global_position.distance_to(_net_pos) > 12.0:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos, k)
	rotation.y = lerp_angle(rotation.y, _net_yaw, k)
	velocity = Vector3.ZERO
	model.update_visuals(delta, speed, steer)


func start_nitro(t: float) -> void:
	nitro = t
	model.set_nitro(true)


func _hit_actors() -> void:
	var spd := absf(speed)
	var inv := global_transform.basis.inverse()
	if world.mp and driver != null and driver == world.player:
		for av in get_tree().get_nodes_in_group("net_avatars"):
			var lr: Vector3 = inv * (av.global_position - global_position)
			if absf(lr.x) < size.x * 0.5 + 0.4 and absf(lr.z) < size.z * 0.5 + 0.4 and absf(lr.y) < 2.0:
				av.net_hit(spd * 1.3, "car")
	for a in get_tree().get_nodes_in_group("actors"):
		var actor := a as Actor
		if actor == null or actor.dead or actor.down_time > 0.0 or actor.in_vehicle():
			continue
		var rel := actor.global_position - global_position
		if rel.length_squared() > 16.0:
			continue
		var local := inv * rel
		if absf(local.x) < size.x * 0.5 + 0.35 and absf(local.z) < size.z * 0.5 + 0.35 and local.y > -1.0 and local.y < 2.5:
			var side := Vector3(rel.x, 0.0, rel.z).normalized()
			var push := forward() * speed * 0.6 + side * 3.0 + Vector3(0, 4.0 + spd * 0.1, 0)
			actor.hit_by_car(self, spd, push)
			speed *= 0.9
			if driver != null and driver.active:
				world.camera.shake(0.12)
			Sfx.play_at("punch", global_position, world.camera.global_position, 40.0)


# ---------------------------------------------------------------- IA

func _ai(delta: float) -> void:
	var target := global_position
	match ai_mode:
		AI.TRAFFIC:
			target = _traffic_target()
		AI.CHASE:
			target = _chase_target(delta)
		AI.PATH:
			target = _path_target()
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var fwd := forward()
	var ang := 0.0
	if dist > 0.5:
		ang = fwd.signed_angle_to(to / dist, Vector3.UP)
	var want := ai_max_speed
	if absf(ang) > 0.6:
		want *= 0.4
	elif absf(ang) > 0.25:
		want *= 0.7
	if ai_mode == AI.PATH and path_done:
		want = 0.0
	if ai_mode == AI.TRAFFIC:
		ignore_block = maxf(0.0, ignore_block - delta)
		if ignore_block <= 0.0 and _blocked_ahead():
			want = 0.0
			blocked_time += delta
			if blocked_time > 1.5 and horn_cd <= 0.0:
				horn_cd = 4.0
				Sfx.play_at("horn", global_position, world.camera.global_position, 45.0, -6.0)
			if blocked_time > 5.0:
				ignore_block = 2.5
				blocked_time = 0.0
		else:
			blocked_time = 0.0
	if reverse_time > 0.0:
		reverse_time -= delta
		throttle = -1.0
		steer = -signf(ang)
		return
	steer = clampf(ang * 2.2, -1.0, 1.0)
	throttle = clampf((want - speed) * 0.35, -1.0, 1.0)
	if want < 0.5 and absf(speed) < 0.6:
		throttle = 0.0
	if throttle > 0.3 and absf(speed) < 1.0:
		stuck_time += delta
	else:
		stuck_time = maxf(0.0, stuck_time - delta * 0.5)
	if stuck_time > 1.4:
		stuck_time = 0.0
		reverse_time = 1.3


func _traffic_target() -> Vector3:
	if ai_next < 0:
		var near: Dictionary = CityData.nearest_road_point(global_position)
		ai_prev = near["a"]
		ai_next = near["b"]
		var nb: Vector3 = CityData.nodes[ai_next]
		if (nb - global_position).dot(forward()) < 0.0:
			var t := ai_prev
			ai_prev = ai_next
			ai_next = t
		ai_phase = 0
	if ai_phase == 1:
		var rel2 := ai_turn_point - global_position
		rel2.y = 0.0
		if rel2.length() < 5.0:
			ai_phase = 0
		else:
			return ai_turn_point
	var a: Vector3 = CityData.nodes[ai_prev]
	var b: Vector3 = CityData.nodes[ai_next]
	var d := (b - a).normalized()
	var right := d.cross(Vector3.UP)
	var tp := b + right * CityData.LANE - d * 6.0
	var rel := tp - global_position
	rel.y = 0.0
	if rel.length() < 5.0 or rel.dot(d) < 0.0:
		var options: Array = []
		for x in CityData.links[ai_next]:
			if x != ai_prev:
				options.append(x)
		if options.is_empty():
			options = [ai_prev]
		var nxt: int = options[randi() % options.size()]
		var nb2: Vector3 = CityData.nodes[nxt]
		var d2 := (nb2 - b).normalized()
		var r2 := d2.cross(Vector3.UP)
		ai_turn_point = b + d2 * 7.0 + r2 * CityData.LANE
		ai_prev = ai_next
		ai_next = nxt
		ai_phase = 1
		return ai_turn_point
	return tp


func _chase_target(delta: float) -> Vector3:
	if not is_instance_valid(ai_target):
		return global_position + forward() * 10.0
	var tp: Vector3 = ai_target.global_position
	if global_position.distance_to(tp) < 55.0:
		return tp
	ai_repath -= delta
	if ai_repath <= 0.0 or ai_route.is_empty():
		ai_repath = 1.0
		ai_route = CityData.path(CityData.nearest_node(global_position), CityData.nearest_node(tp))
	while ai_route.size() > 1 and global_position.distance_to(CityData.nodes[ai_route[0]]) < 12.0:
		ai_route.pop_front()
	if ai_route.is_empty():
		return tp
	return CityData.nodes[ai_route[0]]


func _path_target() -> Vector3:
	if ai_points.is_empty():
		return global_position + forward()
	var p: Vector3 = ai_points[ai_index]
	if Vector2(global_position.x - p.x, global_position.z - p.z).length() < ai_radius:
		if ai_index + 1 < ai_points.size():
			ai_index += 1
		elif ai_loop:
			ai_index = 0
		else:
			path_done = true
	return ai_points[ai_index]


func _blocked_ahead() -> bool:
	var fwd := forward()
	var right := fwd.cross(Vector3.UP)
	for c in world.cars:
		if c == self or not is_instance_valid(c):
			continue
		var rel: Vector3 = c.global_position - global_position
		var f := rel.dot(fwd)
		if f < 1.5 or f > 11.0:
			continue
		if absf(rel.dot(right)) < 2.4:
			return true
	if world.player != null and not world.player.in_vehicle():
		var rel2: Vector3 = world.player.global_position - global_position
		var f2 := rel2.dot(fwd)
		if f2 > 1.0 and f2 < 8.0 and absf(rel2.dot(right)) < 1.8:
			return true
	return false


func set_traffic(prev_node: int, next_node: int) -> void:
	ai_mode = AI.TRAFFIC
	is_traffic = true
	ai_prev = prev_node
	ai_next = next_node
	ai_phase = 0
	npc_driver = true
	model.set_driver(true)
