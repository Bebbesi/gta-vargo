class_name Actor
extends CharacterBody3D
## Base comune per protagonisti, pedoni e nemici: salute, spinte, cadute,
## gravità e collisioni.

signal died(actor: Actor)

const GRAVITY := 22.0

var world: Node
var model: CharacterModel
var max_health := 100.0
var health := 100.0
var dead := false
var down_time := 0.0
var knock_vel := Vector3.ZERO
var knock_up := 0.0
var invuln := 0.0
var yaw := 0.0
var damage_taken_mult := 1.0


func setup_body(look: Dictionary, radius: float = 0.32, height: float = 1.75) -> void:
	model = CharacterModel.new()
	add_child(model)
	model.build(look)
	model.position.y = 0.04
	var s: float = look.get("scale", 1.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius * s
	cap.height = height * s
	cs.shape = cap
	cs.position = Vector3(0, height * s * 0.5, 0)
	add_child(cs)
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	add_to_group("actors")


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func set_yaw(y: float) -> void:
	yaw = y
	if model:
		model.rotation.y = yaw


func face_dir(dir: Vector3, delta: float, rate: float = 12.0) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	var target := atan2(-dir.x, -dir.z)
	set_yaw(lerp_angle(yaw, target, clampf(rate * delta, 0.0, 1.0)))


func move_body(delta: float, horizontal: Vector3, jump_speed: float = 0.0) -> void:
	var v := velocity
	v.x = horizontal.x + knock_vel.x
	v.z = horizontal.z + knock_vel.z
	if is_on_floor():
		if jump_speed > 0.0:
			v.y = jump_speed
		elif v.y < 0.0:
			v.y = -0.5
	if knock_up > 0.0:
		v.y = knock_up
		knock_up = 0.0
	v.y -= GRAVITY * delta
	velocity = v
	move_and_slide()
	var decay := 10.0 if is_on_floor() else 2.0
	knock_vel.x = move_toward(knock_vel.x, 0.0, decay * delta * maxf(1.0, absf(knock_vel.x)))
	knock_vel.z = move_toward(knock_vel.z, 0.0, decay * delta * maxf(1.0, absf(knock_vel.z)))


func take_damage(amount: float, source: Node = null, push: Vector3 = Vector3.ZERO) -> void:
	if dead or invuln > 0.0:
		return
	health -= amount * damage_taken_mult
	knock_vel += Vector3(push.x, 0, push.z)
	if push.y > 0.0:
		knock_up = push.y
	if model:
		model.flash()
	_on_damaged(amount, source)
	if health <= 0.0:
		health = 0.0
		_on_die(source)


## Colpo d'arma da fuoco (scintille, nessun effetto cruento).
func take_bullet(amount: float, source: Node, dir: Vector3) -> void:
	if dead:
		return
	Gfx.burst(world, global_position + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.4), 6, 3.0, 0.07, 0.3)
	take_damage(amount, source, Vector3(dir.x, 0, dir.z) * 1.5)


func hit_by_car(car: Node, spd: float, push: Vector3) -> void:
	take_damage(spd * 1.3, car, push)
	if not dead:
		knock_down(1.4)


func knock_down(t: float) -> void:
	down_time = maxf(down_time, t)
	if model:
		model.set_down(true)


func update_down(delta: float) -> bool:
	if down_time <= 0.0:
		return false
	down_time -= delta
	if down_time <= 0.0 and not dead:
		model.set_down(false)
	move_body(delta, Vector3.ZERO)
	return true


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)


func in_vehicle() -> bool:
	return false


func _on_damaged(_amount: float, _source: Node) -> void:
	pass


func _on_die(_source: Node) -> void:
	dead = true
	if model:
		model.set_down(true)
	died.emit(self)
