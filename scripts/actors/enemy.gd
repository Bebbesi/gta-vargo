class_name Enemy
extends Actor
## Nemico da combattimento arcade (Vipere, guardie del corpo, Dex).
## Insegue il protagonista attivo e attacca corpo a corpo.

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
var label: Label3D


func setup(w: Node, look_id: String, hp: float = 60.0, title: String = "") -> void:
	world = w
	max_health = hp
	health = hp
	setup_body(Game.NPC_LOOKS.get(look_id, Game.NPC_LOOKS["viper"]))
	add_to_group("enemies")
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
	if windup > 0.0:
		windup -= delta
		face_dir(to, delta, 10.0)
		if windup <= 0.0:
			_strike(target)
	elif stagger > 0.0:
		stagger -= delta
	elif dist > 1.45:
		dir = to / maxf(dist, 0.001) * speed
		face_dir(to, delta, 10.0)
	else:
		face_dir(to, delta, 10.0)
		if attack_cd <= 0.0 and not world.player.in_vehicle():
			windup = 0.32
			attack_cd = 1.25 if not boss else 0.95
			model.play_punch()
	move_body(delta, dir)
	model.animate(delta, dir.length() / 8.0, is_on_floor())


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


func _on_damaged(_amount: float, _source: Node) -> void:
	stagger = 0.35 if not boss else 0.15
	windup = 0.0


func _on_die(source: Node) -> void:
	super._on_die(source)
	collision_layer = 0
	if label:
		label.visible = false
	Gfx.burst(world, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 14, 4.0, 0.12, 0.6)
	if randf() < drop_boost:
		world.spawn_pickup("boost", global_position + Vector3(0, 0, 0.5), 0.0)
	defeated.emit(self)
