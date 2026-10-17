class_name GameCamera
extends Camera3D
## Telecamera in terza persona: segue il protagonista o l'auto, si ruota col
## trascinamento, evita i muri, trema negli urti e gestisce le transizioni
## cinematiche (cambio personaggio, menu, scene narrative).

var world: Node
var yaw := 0.0
var pitch := -0.3
var dist := 5.5
var mode := "orbit"
var last_drag := 10.0
var shake_amt := 0.0
var cine_pos := Vector3.ZERO
var cine_look := Vector3.ZERO
var orbit_angle := 0.0
var _switch_t := -1.0
var _switch_from := Vector3.ZERO
var _switch_look_from := Vector3.ZERO


func _ready() -> void:
	fov = 70.0
	near = 0.1
	far = 260.0


func drag(rel: Vector2) -> void:
	if mode != "follow":
		return
	var s: float = Game.settings["cam_sens"]
	yaw -= rel.x * 0.006 * s
	var inv := -1.0 if bool(Game.settings["invert_y"]) else 1.0
	pitch = clampf(pitch - rel.y * 0.004 * s * inv, -1.2, 0.3)
	last_drag = 0.0


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func set_cinematic(pos: Vector3, look: Vector3) -> void:
	mode = "cinematic"
	cine_pos = pos
	cine_look = look


func snap_behind() -> void:
	if world == null or world.player == null:
		return
	var p: Protagonist = world.player
	if p.in_vehicle():
		yaw = p.vehicle.rotation.y
		dist = 9.0
	else:
		yaw = p.yaw
		dist = 5.2
	pitch = -0.3
	mode = "follow"
	_follow(1.0, true)


func start_switch(from_pos: Vector3) -> void:
	_switch_from = from_pos
	_switch_look_from = from_pos + Vector3(0, -10, 0)
	_switch_t = 0.0
	mode = "switch"


func _physics_process(delta: float) -> void:
	shake_amt = move_toward(shake_amt, 0.0, delta * 1.5)
	match mode:
		"follow":
			_follow(delta, false)
		"cinematic":
			global_position = global_position.lerp(cine_pos, clampf(delta * 3.0, 0.0, 1.0))
			_look(cine_look)
		"cinematic_hard":
			global_position = cine_pos
			_look(cine_look)
		"orbit":
			orbit_angle += delta * 0.05
			var c := Vector3(60, 0, 0)
			global_position = c + Vector3(cos(orbit_angle) * 230.0, 95.0, sin(orbit_angle) * 230.0)
			_look(c + Vector3(0, 10, 0))
		"switch":
			_switch(delta)
	if shake_amt > 0.0:
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_amt * 0.35


func _look(target: Vector3) -> void:
	var d := target - global_position
	if d.length_squared() < 0.0001:
		return
	var up := Vector3.UP
	if absf(d.normalized().dot(Vector3.UP)) > 0.98:
		up = Vector3.FORWARD
	look_at(target, up)


func _target_info() -> Array:
	var p: Protagonist = world.player
	if p.in_vehicle():
		var big := p.vehicle.car_type == "van"
		return [p.vehicle, 11.0 if big else 9.0, 2.4 if big else 2.0, true]
	return [p, 5.2, 1.55, false]


func _follow(delta: float, instant: bool) -> void:
	if world == null or world.player == null:
		return
	last_drag += delta
	var info := _target_info()
	var target: Node3D = info[0]
	var want_dist: float = info[1]
	var height: float = info[2]
	var in_car: bool = info[3]
	dist = want_dist if instant else lerpf(dist, want_dist, clampf(3.0 * delta, 0.0, 1.0))
	if in_car and last_drag > 1.2:
		var car: Car = target
		var car_yaw := car.rotation.y
		var spd := absf(car.speed)
		if spd > 1.0 or instant:
			yaw = lerp_angle(yaw, car_yaw, clampf((1.0 + spd * 0.08) * delta, 0.0, 1.0)) if not instant else car_yaw
			pitch = lerpf(pitch, -0.24, clampf(1.5 * delta, 0.0, 1.0))
	var pivot := target.global_position + Vector3(0, height, 0)
	var offset := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	var want := pivot + offset
	var q := PhysicsRayQueryParameters3D.create(pivot, want, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = hit["position"] + (pivot - want).normalized() * 0.35
	global_position = want
	_look(pivot)
	var spd_fov := 0.0
	if in_car:
		spd_fov = clampf(absf((target as Car).speed) / 40.0, 0.0, 1.2) * 12.0
	fov = lerpf(fov, 70.0 + spd_fov, clampf(2.0 * delta, 0.0, 1.0))


func _switch(delta: float) -> void:
	_switch_t += delta / 1.5
	var p: Protagonist = world.player
	var dest_node: Node3D = p.vehicle if p.in_vehicle() else p
	var dest := dest_node.global_position
	var high := 70.0
	var t := clampf(_switch_t, 0.0, 1.0)
	var pos := Vector3.ZERO
	if t < 0.33:
		var k := t / 0.33
		pos = _switch_from.lerp(_switch_from + Vector3(0, high, 8.0), k * k)
	elif t < 0.66:
		var k2 := (t - 0.33) / 0.33
		pos = (_switch_from + Vector3(0, high, 8.0)).lerp(dest + Vector3(0, high, 8.0), smoothstep(0.0, 1.0, k2))
	else:
		var k3 := (t - 0.66) / 0.34
		var behind := dest + Vector3(0, 1.8, 0) + Vector3(0, 0, 5.5).rotated(Vector3.UP, yaw)
		pos = (dest + Vector3(0, high, 8.0)).lerp(behind, 1.0 - pow(1.0 - k3, 2.0))
	global_position = pos
	var look_t := dest if t > 0.33 else _switch_from
	_look(look_t + Vector3(0, 0.5, 0))
	if _switch_t >= 1.0:
		_switch_t = -1.0
		mode = "follow"
