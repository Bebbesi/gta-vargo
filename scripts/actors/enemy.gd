class_name Enemy
extends Actor
## Nemico arcade (Vipere, guardie del corpo, Dex, polizia).
## Insegue il protagonista attivo e attacca corpo a corpo oppure, se ha
## un'arma (`gun`), spara mantenendo la distanza.

signal defeated(enemy: Enemy)

var speed := 5.0
var damage := 8.0
var attack_cd := 0.0
var windup := 0.0
var stagger := 0.0
var drop_boost := 0.3
var boss := false
var remove_on_defeat := true
var dead_time := 0.0
var engage := true
var label: Label3D
var _orbit := 1.0
var gun := ""
var accuracy := 0.5
var is_cop := false
var arrest_only := false
var passive := false
var fire_cd := 1.0
var look_id := "viper"


func setup(w: Node, look: String, hp: float = 60.0, title: String = "") -> void:
	world = w
	look_id = look
	max_health = hp
	health = hp
	setup_body(Game.NPC_LOOKS.get(look, Game.NPC_LOOKS["viper"]))
	add_to_group("enemies")
	_orbit = 1.0 if randf() < 0.5 else -1.0
	if title != "":
		label = Gfx.label3d(self, title, Vector3(0, 2.6, 0), 48, Color(1.0, 0.5, 0.9))


func _physics_process(delta: float) -> void:
	if dead:
		dead_time += delta
		move_body(delta, Vector3.ZERO)
		if remove_on_defeat and dead_time > 2.5:
			queue_free()
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	if update_down(delta):
		return
	var target: Node3D = world.player
	var tpos: Vector3 = world.player_pos()
	var to := tpos - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := Vector3.ZERO
	if passive:
		move_body(delta, Vector3.ZERO)
		model.animate(delta, 0.0, is_on_floor())
		return
	if gun != "" and not arrest_only and stagger <= 0.0:
		_ranged(delta, to, dist)
		return
	if windup > 0.0:
		windup -= delta
		face_dir(to, delta, 10.0)
		if windup <= 0.0:
			_strike(target)
	elif stagger > 0.0:
		stagger -= delta
	elif not engage:
		# In attesa del proprio turno: gira attorno al bersaglio a distanza.
		var radial := to / maxf(dist, 0.001)
		var side := radial.cross(Vector3.UP) * _orbit
		var push := 0.0
		if dist < 4.0:
			push = -1.0
		elif dist > 6.5:
			push = 1.0
		dir = (radial * push + side * 0.6).normalized() * speed * 0.6
		face_dir(to, delta, 8.0)
	elif dist > 1.45:
		dir = to / maxf(dist, 0.001) * speed
		face_dir(to, delta, 10.0)
	else:
		face_dir(to, delta, 10.0)
		if attack_cd <= 0.0 and not arrest_only and not world.player.in_vehicle():
			windup = 0.32
			attack_cd = 1.25 if not boss else 0.95
			model.play_punch()
	move_body(delta, dir)
	model.animate(delta, dir.length() / 8.0, is_on_floor())


## Solo i `max_attackers` nemici più vicini attaccano, gli altri attendono.
static func assign_attackers(list: Array, center: Vector3, max_attackers: int) -> void:
	var alive: Array = []
	for e in list:
		if is_instance_valid(e) and not e.dead:
			alive.append(e)
	alive.sort_custom(func(a, b): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	for i in alive.size():
		alive[i].engage = i < max_attackers or alive[i].boss


## Comportamento con arma da fuoco: si avvicina, mantiene 6-15 m, si sposta
## lateralmente e spara con una precisione limitata.
func _ranged(delta: float, to: Vector3, dist: float) -> void:
	var radial := to / maxf(dist, 0.001)
	var dir := Vector3.ZERO
	if dist > 15.0:
		dir = radial * speed
	elif dist < 6.0:
		dir = -radial * speed * 0.6
	else:
		dir = radial.cross(Vector3.UP) * _orbit * speed * 0.35
	face_dir(to, delta, 10.0)
	fire_cd -= delta
	if fire_cd <= 0.0 and dist < 34.0 and not world.player.dead:
		var rate: float = Game.WEAPONS.get(gun, Game.WEAPONS["pistol"])["rate"]
		fire_cd = rate * (4.0 if gun == "pistol" else 3.0) + randf() * 0.7
		model.aim(0.6)
		world.npc_shoot(self, global_position + Vector3(0, 1.45, 0) + forward() * 0.6, accuracy, damage, gun)
	move_body(delta, dir)
	model.animate(delta, dir.length() / 8.0, is_on_floor())


func arm(weapon: String, acc: float) -> void:
	gun = weapon
	accuracy = acc
	arrest_only = weapon == ""
	damage = {"pistol": 7.0, "smg": 5.0, "rifle": 8.0, "shotgun": 9.0}.get(weapon, damage)
	model.set_weapon(weapon if weapon != "" else "fists")


func _strike(target: Node3D) -> void:
	if not (target is Protagonist):
		return
	var p := target as Protagonist
	if p.in_vehicle() or p.dead:
		return
	var rel := p.global_position - global_position
	rel.y = 0.0
	if rel.length() < 2.0:
		p.take_damage(damage, self, rel.normalized() * 3.0)
		Sfx.play("punch", -3.0, 0.85)


func _on_damaged(_amount: float, source: Node) -> void:
	stagger = 0.35 if not boss else 0.15
	if gun != "":
		stagger = 0.12
	windup = 0.0
	if is_cop:
		world.crime_by(source, "cop_hit", global_position)


func _on_die(source: Node) -> void:
	super._on_die(source)
	collision_layer = 0
	if label:
		label.visible = false
	Gfx.burst(world, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 14, 4.0, 0.12, 0.6)
	if randf() < drop_boost:
		world.spawn_pickup("boost", global_position + Vector3(0, 0, 0.5), 0.0)
	if gun != "" and randf() < 0.4:
		world.spawn_pickup("weapon", global_position + Vector3(0.6, 0, 0), 0.0, gun)
	if is_cop:
		world.crime_by(source, "cop_ko", global_position)
	defeated.emit(self)
