class_name Helicopter
extends Node3D
## Elicottero della polizia (4-5 stelle): gira attorno al giocatore e spara.
## Può essere abbattuto con le armi.

var world: Node
var health := 320.0
var max_health := 320.0
var crashing := false
var leaving := false
var rotor: Node3D
var tail_rotor: Node3D
var body: StaticBody3D
var angle := 0.0
var fire_cd := 2.5
var _fall_speed := 0.0
var _last_pos := Vector3.ZERO


func setup(w: Node, pos: Vector3) -> void:
	world = w
	global_position = pos
	_last_pos = pos
	angle = randf() * TAU
	add_to_group("aim_targets")
	var b := MeshBatch.new()
	var navy := Color(0.12, 0.16, 0.3)
	var white := Color(0.92, 0.92, 0.94)
	b.box(Vector3(0, 0, 0), Vector3(2.4, 2.0, 4.6), navy)
	b.box(Vector3(0, -0.35, -0.2), Vector3(2.42, 0.6, 4.62), white)
	b.box(Vector3(0, 0.25, -2.25), Vector3(2.0, 1.2, 0.6), Color(0.2, 0.3, 0.4))
	b.box(Vector3(0, 0.3, 4.6), Vector3(0.45, 0.45, 5.0), navy)
	b.box(Vector3(0, 1.0, 6.9), Vector3(0.15, 1.6, 0.9), white)
	for sx: float in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.9, -1.35, 0), Vector3(0.12, 0.12, 4.2), Color(0.15, 0.15, 0.15))
		b.box(Vector3(sx * 0.9, -1.1, -1.0), Vector3(0.1, 0.5, 0.1), Color(0.15, 0.15, 0.15))
		b.box(Vector3(sx * 0.9, -1.1, 1.0), Vector3(0.1, 0.5, 0.1), Color(0.15, 0.15, 0.15))
	b.box(Vector3(0, 1.15, 0), Vector3(0.5, 0.35, 0.5), Color(0.2, 0.2, 0.2))
	Gfx.add_batch(self, b)
	rotor = Node3D.new()
	rotor.position = Vector3(0, 1.4, 0)
	add_child(rotor)
	Gfx.add_box(rotor, Vector3(11.0, 0.06, 0.4), Color(0.1, 0.1, 0.1))
	Gfx.add_box(rotor, Vector3(0.4, 0.06, 11.0), Color(0.1, 0.1, 0.1))
	tail_rotor = Node3D.new()
	tail_rotor.position = Vector3(0.3, 1.0, 6.9)
	add_child(tail_rotor)
	Gfx.add_box(tail_rotor, Vector3(0.05, 1.8, 0.2), Color(0.1, 0.1, 0.1))
	for sx: float in [-0.7, 0.7]:
		Gfx.add_box(self, Vector3(0.25, 0.12, 0.12), Color(1.0, 0.1, 0.1) if sx < 0 else Color(0.2, 0.4, 1.0), Vector3(sx, -0.95, -2.2), 3.0)
	var lab := Gfx.label3d(self, "POLIZIA", Vector3(1.22, 0.1, 0.5), 60, Color.WHITE, false)
	lab.rotation.y = PI * 0.5
	body = StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.6, 2.2, 5.0)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func aim_point() -> Vector3:
	return global_position


func take_bullet(amount: float, source: Node, _dir: Vector3) -> void:
	if crashing:
		return
	health -= amount
	Gfx.burst(world, global_position, Color(1.0, 0.9, 0.6), 6, 4.0, 0.08, 0.3)
	if health <= 0.0:
		crashing = true
		remove_from_group("aim_targets")
		Sfx.play_at("explosion", global_position, world.camera.global_position, 200.0, 2.0)
		Gfx.burst(world, global_position, Color(1.0, 0.5, 0.1), 30, 8.0, 0.3, 1.0)
		if world.is_player_source(source):
			world.report_crime("heli_down", global_position)
			world.hud.toast("Elicottero abbattuto!", 2.0)


func _physics_process(delta: float) -> void:
	rotor.rotation.y += delta * (14.0 if crashing else 26.0)
	tail_rotor.rotation.x += delta * 30.0
	if crashing:
		_fall_speed += 14.0 * delta
		global_position.y -= _fall_speed * delta
		rotation.y += delta * 4.0
		if global_position.y < 1.5:
			Sfx.play_at("explosion", global_position, world.camera.global_position, 200.0, 4.0)
			Gfx.burst(world, global_position, Color(1.0, 0.55, 0.1), 40, 10.0, 0.4, 1.2)
			world.camera.shake(0.4)
			queue_free()
		return
	if leaving:
		global_position += Vector3(0, 10.0, 0) * delta + -global_transform.basis.z * 20.0 * delta
		if global_position.y > 140.0:
			queue_free()
		return
	angle += delta * 0.35
	var pp: Vector3 = world.player_pos()
	var target := pp + Vector3(cos(angle) * 24.0, 24.0, sin(angle) * 24.0)
	global_position = global_position.lerp(target, clampf(delta * 0.7, 0.0, 1.0))
	var vel := (global_position - _last_pos) / maxf(delta, 0.001)
	_last_pos = global_position
	var flat := Vector3(pp.x - global_position.x, 0, pp.z - global_position.z)
	if flat.length() > 1.0:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), clampf(delta * 2.0, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, -clampf(vel.length() / 60.0, 0.0, 0.25), clampf(delta * 2.0, 0.0, 1.0))
	fire_cd -= delta
	var stars: int = world.police.stars if world.police != null else 4
	if fire_cd <= 0.0 and global_position.distance_to(pp) < 75.0 and not world.player.dead:
		fire_cd = 1.0 if stars >= 5 else 1.6
		world.npc_shoot(self, global_position + Vector3(0, -1.2, -2.0), 0.35, 6.0, "rifle")
