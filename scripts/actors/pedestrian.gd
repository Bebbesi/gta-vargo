class_name Pedestrian
extends Actor
## Pedone: passeggia sul marciapiede attorno a un isolato, scappa se c'è
## violenza, cade se investito e si rialza (nessun contenuto cruento).

const LOOK_JACKETS := [
	Color(0.8, 0.3, 0.3), Color(0.3, 0.5, 0.8), Color(0.9, 0.8, 0.3), Color(0.4, 0.7, 0.4),
	Color(0.6, 0.4, 0.7), Color(0.95, 0.6, 0.3), Color(0.3, 0.3, 0.35), Color(0.85, 0.85, 0.85),
]
const LOOK_SKINS := [Color(0.95, 0.8, 0.68), Color(0.89, 0.7, 0.55), Color(0.7, 0.5, 0.38), Color(0.5, 0.35, 0.25)]
const LOOK_HAIR := [Color(0.1, 0.08, 0.06), Color(0.35, 0.22, 0.1), Color(0.8, 0.65, 0.35), Color(0.6, 0.6, 0.6), Color(0.6, 0.2, 0.1)]
const STYLES := ["short", "long", "cap", "beanie", "bald", "slick"]

var loop_pts: Array = []
var loop_i := 0
var loop_dir := 1
var walk_speed := 1.6
var flee_time := 0.0
var flee_from := Vector3.ZERO
var ko_time := 0.0
var _sleep := false
## Seme dell'aspetto: in multiplayer gli altri giocatori ricostruiscono lo
## stesso pedone a partire da questo numero.
var look_seed := 0


static func make_look(look_seed_value: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = look_seed_value
	return {
		"jacket": LOOK_JACKETS[r.randi() % LOOK_JACKETS.size()],
		"shirt": Color(0.95, 0.95, 0.92),
		"pants": [Color(0.2, 0.25, 0.4), Color(0.3, 0.3, 0.3), Color(0.5, 0.42, 0.3), Color(0.15, 0.15, 0.17)][r.randi() % 4],
		"skin": LOOK_SKINS[r.randi() % LOOK_SKINS.size()],
		"hair": LOOK_HAIR[r.randi() % LOOK_HAIR.size()],
		"shoes": Color(0.12, 0.1, 0.1),
		"hair_style": STYLES[r.randi() % STYLES.size()],
		"extra": "",
		"scale": r.randf_range(0.9, 1.06),
	}


func setup(w: Node, rng: RandomNumberGenerator) -> void:
	world = w
	look_seed = rng.randi()
	var look := make_look(look_seed)
	max_health = 40.0
	health = max_health
	walk_speed = rng.randf_range(1.3, 2.0)
	loop_dir = 1 if rng.randf() < 0.5 else -1
	setup_body(look)
	add_to_group("peds")


func assign_block(c: Vector3, start_corner: int) -> void:
	var h: float = CityData.WALK_HALF
	loop_pts = [c + Vector3(-h, 0, -h), c + Vector3(h, 0, -h), c + Vector3(h, 0, h), c + Vector3(-h, 0, h)]
	loop_i = start_corner % 4


func flee(from: Vector3, t: float = 6.0) -> void:
	if dead:
		return
	flee_from = from
	flee_time = t


func _physics_process(delta: float) -> void:
	var far: bool = world.nearest_player_distance(global_position) > 120.0
	if far != _sleep:
		_sleep = far
		model.visible = not far
	if far and not dead:
		return
	if dead:
		ko_time += delta
		move_body(delta, Vector3.ZERO)
		if ko_time > 10.0:
			world.recycle_ped(self)
		return
	if update_down(delta):
		return
	var dir := Vector3.ZERO
	var spd := walk_speed
	if flee_time > 0.0:
		flee_time -= delta
		dir = global_position - flee_from
		spd = 5.5
		if flee_time <= 0.0:
			_nearest_corner()
	elif not loop_pts.is_empty():
		var target: Vector3 = loop_pts[loop_i]
		dir = target - global_position
		if Vector2(dir.x, dir.z).length() < 0.8:
			loop_i = (loop_i + loop_dir + 4) % 4
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
		face_dir(dir, delta, 8.0)
	move_body(delta, dir * spd)
	model.animate(delta, spd / 8.0, is_on_floor())


func _nearest_corner() -> void:
	var best := 0
	var bd := INF
	for i in loop_pts.size():
		var d: float = global_position.distance_squared_to(loop_pts[i])
		if d < bd:
			bd = d
			best = i
	loop_i = best


func _on_die(source: Node) -> void:
	super._on_die(source)
	world.crime_by(source, "ped_ko", global_position)


func _on_damaged(_amount: float, source: Node) -> void:
	world.crime_by(source, "assault", global_position)
	if source is Node3D:
		flee((source as Node3D).global_position, 8.0)
	else:
		flee(global_position - forward(), 8.0)


func revive_at(pos: Vector3) -> void:
	dead = false
	ko_time = 0.0
	down_time = 0.0
	flee_time = 0.0
	health = max_health
	knock_vel = Vector3.ZERO
	model.set_down(false)
	global_position = pos
