class_name Protagonist
extends Actor
## Uno dei tre protagonisti giocabili (Mike, Tom, Norman). Il giocatore ne
## controlla uno alla volta; gli altri restano dove li ha lasciati.

var char_id := "mike"
var data: Dictionary = {}
var active := false
var vehicle: Car = null
var punch_cd := 0.0
var fire_cd := 0.0
var special_cd := 0.0
var special_time := 0.0
var _hurt_sfx_cd := 0.0
var collider: CollisionShape3D


func setup(id: String, w: Node) -> void:
	char_id = id
	world = w
	data = Game.char_data(id)
	name = "Protagonist_" + id
	max_health = data["max_health"]
	health = max_health
	setup_body(data["look"])
	for c in get_children():
		if c is CollisionShape3D:
			collider = c
	add_to_group("protagonists")


func in_vehicle() -> bool:
	return vehicle != null


func _physics_process(delta: float) -> void:
	punch_cd = maxf(0.0, punch_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	special_cd = maxf(0.0, special_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	_hurt_sfx_cd = maxf(0.0, _hurt_sfx_cd - delta)
	if special_time > 0.0:
		special_time -= delta
		if special_time <= 0.0:
			_end_special()
	if vehicle != null:
		global_position = vehicle.global_position + Vector3(0, 0.3, 0)
		return
	if dead:
		move_body(delta, Vector3.ZERO)
		return
	if update_down(delta):
		return
	var dir := Vector3.ZERO
	var jump := 0.0
	var spd: float = data["run_speed"]
	if char_id == "mike" and special_time > 0.0:
		spd *= 1.5
	var aiming: bool = active and world.aiming
	if aiming:
		# in mira: guarda dove guarda la telecamera e si sposta di lato
		set_yaw(lerp_angle(yaw, world.camera.yaw, clampf(delta * 18.0, 0.0, 1.0)))
		model.aim(0.2)
		spd *= 0.45
	if active and world.can_control():
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Vector3(v.x, 0, v.y).rotated(Vector3.UP, world.camera.yaw)
		if Input.is_action_just_pressed("jump") and is_on_floor():
			jump = 8.0
	var mag := minf(dir.length(), 1.0)
	if mag > 0.01:
		if not aiming:
			face_dir(dir, delta)
		var walk := 0.35 if mag < 0.45 else 1.0
		dir = dir.normalized() * spd * walk
	move_body(delta, dir, jump)
	model.animate(delta, Vector2(velocity.x, velocity.z).length() / 8.0, is_on_floor())
	if global_position.y < -15.0:
		world.respawn_fallen(self)


# ---------------------------------------------------------------- combattimento

## Pulsante di attacco: pugno a mani nude, altrimenti spara con l'arma in mano.
## `held` = pulsante tenuto premuto (fuoco continuo al ritmo dell'arma).
func attack(held: bool) -> void:
	if vehicle != null or dead or down_time > 0.0:
		return
	if Game.current_weapon == "fists":
		if not held:
			punch()
		return
	fire_weapon()


func fire_weapon() -> void:
	if fire_cd > 0.0:
		return
	var w: String = Game.current_weapon
	var def: Dictionary = Game.WEAPONS[w]
	if not Game.use_ammo():
		fire_cd = 0.35
		Sfx.play("empty")
		world.hud.toast("%s: munizioni finite!" % def["name"], 1.2)
		Game.next_weapon()
		return
	fire_cd = float(def["rate"])
	var reach: float = def["range"]
	var head := global_position + Vector3(0, 1.45 * model.scale.y, 0)
	var aim_dir: Vector3 = world.camera_flat_forward()
	var origin := head + forward() * 0.6
	if active and world.aiming:
		# mira manuale: il colpo va dove punta il mirino al centro dello schermo
		var ch: Dictionary = world.crosshair_target(reach)
		var tp: Vector3 = ch["point"]
		var flat_t := Vector3(tp.x - global_position.x, 0, tp.z - global_position.z)
		if flat_t.length() > 0.3:
			set_yaw(atan2(-flat_t.x, -flat_t.z))
		origin = head + forward() * 0.6
		aim_dir = tp - origin
		if aim_dir.length() < 0.8 or aim_dir.normalized().dot(forward()) < -0.2:
			aim_dir = -world.camera.global_transform.basis.z
	else:
		var target: Node3D = world.find_aim_target(self, reach) if bool(Game.settings["auto_aim"]) else null
		if target != null:
			aim_dir = world.aim_point(target) - head
		var flat := Vector3(aim_dir.x, 0, aim_dir.z)
		if flat.length() > 0.01:
			set_yaw(atan2(-flat.x, -flat.z))
		origin = head + forward() * 0.6
	aim_dir = aim_dir.normalized()
	model.aim(0.6)
	var spread := tan(deg_to_rad(float(def["spread"])))
	var dmg: float = float(def["damage"]) * (1.5 if char_id == "norman" and special_time > 0.0 else 1.0)
	for i in int(def["pellets"]):
		var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread
		var d := (aim_dir + jitter).normalized()
		var res: Dictionary = world.shoot_ray(origin, d, reach, [get_rid()])
		if res["node"] != null:
			res["node"].take_bullet(dmg, self, d)
		Gfx.tracer(world, origin, res["pos"])
		world.net_shot(origin, res["pos"], w)
	Gfx.muzzle_flash(world, origin)
	Sfx.play(def["sound"], -3.0, randf_range(0.95, 1.05))
	world.camera.shake(0.18 if w == "shotgun" else 0.05)
	world.alert_peds(global_position, 30.0)
	world.report_crime("shots", global_position)


func punch() -> void:
	if punch_cd > 0.0 or dead or down_time > 0.0 or vehicle != null:
		return
	punch_cd = 0.42
	model.play_punch()
	Sfx.play("swing", -8.0)
	await get_tree().create_timer(0.12).timeout
	if dead or vehicle != null or not is_inside_tree():
		return
	var dmg: float = data["punch"]
	if char_id == "norman" and special_time > 0.0:
		dmg *= 2.0
	var fwd := forward()
	var hit := false
	for a in get_tree().get_nodes_in_group("actors"):
		if a == self or a is Protagonist or a.dead:
			continue
		var rel: Vector3 = a.global_position - global_position
		rel.y = 0.0
		if rel.length() < 2.2 and rel.normalized().dot(fwd) > 0.3:
			var push := rel.normalized() * (6.0 if char_id == "norman" else 3.5)
			a.take_damage(dmg, self, push)
			hit = true
			Gfx.burst(world, a.global_position + Vector3(0, 1.4, 0), Color(1.0, 0.9, 0.4), 8, 3.0, 0.1, 0.4)
	for av in get_tree().get_nodes_in_group("net_avatars"):
		var rel2: Vector3 = av.global_position - global_position
		rel2.y = 0.0
		if rel2.length() < 2.2 and rel2.normalized().dot(fwd) > 0.3:
			av.net_hit(dmg, "punch")
			hit = true
	for pup in get_tree().get_nodes_in_group("net_npcs"):
		var rel3: Vector3 = pup.global_position - global_position
		rel3.y = 0.0
		if not pup.dead and rel3.length() < 2.2 and rel3.normalized().dot(fwd) > 0.3:
			pup.take_damage(dmg, self, rel3.normalized() * (6.0 if char_id == "norman" else 3.5))
			hit = true
	if hit:
		Sfx.play("punch")
		world.camera.shake(0.12)
		Game.vibrate(30)
	world.alert_peds(global_position, 14.0)


func use_special() -> bool:
	if special_cd > 0.0 or dead:
		world.hud.toast("%s in ricarica: %d s" % [data["special"], ceili(special_cd)], 1.5)
		return false
	match char_id:
		"mike":
			if vehicle != null:
				vehicle.start_nitro(3.0)
			else:
				special_time = 4.0
			special_cd = 12.0
			Sfx.play("nitro")
		"tom":
			special_time = 10.0
			special_cd = 20.0
			Sfx.play("switch")
			world.on_tom_analysis(self)
		"norman":
			special_time = 8.0
			special_cd = 20.0
			damage_taken_mult = 0.5
			model.set_aura(true, data["color"])
			Sfx.play("punch", 4.0, 0.6)
			world.camera.shake(0.35)
			Gfx.burst(world, global_position + Vector3(0, 0.3, 0), Color(0.6, 1.0, 0.4), 30, 9.0, 0.18, 0.6)
			for a in get_tree().get_nodes_in_group("actors"):
				if a == self or a is Protagonist or a.dead:
					continue
				var rel: Vector3 = a.global_position - global_position
				if rel.length() < 6.0:
					a.take_damage(15.0, self, rel.normalized() * 9.0 + Vector3(0, 5, 0))
					a.knock_down(1.2)
	world.hud.flash_special()
	return true


func _end_special() -> void:
	if char_id == "norman":
		damage_taken_mult = 1.0
		model.set_aura(false, Color.WHITE)


func take_damage(amount: float, source: Node = null, push: Vector3 = Vector3.ZERO) -> void:
	if not active or world.lock_count > 0:
		return
	super.take_damage(amount, source, push)


func _on_damaged(amount: float, _source: Node) -> void:
	world.hud.flash_damage()
	if _hurt_sfx_cd <= 0.0:
		Sfx.play("hurt", -4.0)
		_hurt_sfx_cd = 0.4
	if amount > 10.0:
		Game.vibrate(60)


func _on_die(_source: Node) -> void:
	super._on_die(_source)
	world.on_player_ko(self)


func revive() -> void:
	dead = false
	down_time = 0.0
	health = max_health
	knock_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	special_time = 0.0
	_end_special()
	model.set_down(false)
	invuln = 2.0


func teleport(pos: Vector3, new_yaw: float) -> void:
	global_position = pos + Vector3(0, 0.1, 0)
	velocity = Vector3.ZERO
	knock_vel = Vector3.ZERO
	set_yaw(new_yaw)


func set_in_vehicle(car: Car) -> void:
	vehicle = car
	var inside := car != null
	model.visible = not inside
	collider.disabled = inside
	velocity = Vector3.ZERO
	if not inside:
		model.set_down(false)


func save_state() -> Dictionary:
	var p := global_position
	if vehicle != null:
		p = vehicle.global_position + vehicle.global_transform.basis.x * -2.6
	return {"health": health, "pos": [p.x, maxf(p.y, 0.0), p.z], "yaw": yaw}


func load_state(d: Dictionary) -> void:
	health = clampf(float(d.get("health", max_health)), 1.0, max_health)
	var arr: Array = d.get("pos", [])
	if arr.size() == 3:
		teleport(Vector3(float(arr[0]), float(arr[1]), float(arr[2])), float(d.get("yaw", 0.0)))
