class_name NetPuppet
extends CharacterBody3D
## Passante o agente simulato da un altro giocatore: segue la posizione
## ricevuta dalla rete, ha un corpo per collisioni e proiettili e inoltra i
## colpi al proprietario, che decide danni e reati.

var ents: Node
var owner_peer := 0
var eid := 0
var kind := NetWorld.K_PED
var model: CharacterModel
var collider: CollisionShape3D
var dead := false
var down := false
var hit_cd := 0.0
var _pos := Vector3.ZERO
var _yaw := 0.0
var _speed := 0.0
var _has_state := false


func setup(n: Node, owner: int, id: int, k: int, look: Dictionary) -> void:
	ents = n
	owner_peer = owner
	eid = id
	kind = k
	name = "Puppet_%d_%d" % [owner, id]
	model = CharacterModel.new()
	add_child(model)
	model.build(look)
	model.position.y = 0.04
	var s: float = look.get("scale", 1.0)
	collider = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32 * s
	cap.height = 1.75 * s
	collider.shape = cap
	collider.position.y = 0.875 * s
	add_child(collider)
	collision_layer = 2
	collision_mask = 0
	add_to_group("net_npcs")


func is_ped() -> bool:
	return kind == NetWorld.K_PED


func apply(e: Array) -> void:
	_pos = e[2]
	_yaw = e[3]
	_speed = e[4]
	var st: int = e[5]
	if not _has_state:
		_has_state = true
		global_position = _pos
		model.rotation.y = _yaw
	var now_down := st != 0
	if now_down != down:
		down = now_down
		model.set_down(down)
	dead = st == 2
	collider.disabled = dead
	if kind == NetWorld.K_COP and e.size() >= 9:
		var gun: String = e[7]
		var wid := gun if gun != "" else "fists"
		if wid != model.weapon_id:
			model.set_weapon(wid)
		if bool(e[8]):
			model.aim(0.3)


func aim_point() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func _process(delta: float) -> void:
	hit_cd = maxf(0.0, hit_cd - delta)
	if not _has_state:
		return
	if global_position.distance_to(_pos) > 8.0:
		global_position = _pos
	else:
		global_position = global_position.lerp(_pos, clampf(delta * 10.0, 0.0, 1.0))
	model.rotation.y = lerp_angle(model.rotation.y, _yaw, clampf(delta * 10.0, 0.0, 1.0))
	if not down:
		model.animate(delta, _speed / 8.0, true)


# ---------------------------------------------------------------- colpi

func take_bullet(amount: float, _source: Node, dir: Vector3) -> void:
	if dead:
		return
	Gfx.burst(ents.world, global_position + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.4), 6, 3.0, 0.07, 0.3)
	ents.hit_entity(owner_peer, eid, amount, "shot", Vector3(dir.x, 0, dir.z).normalized())


## Pugno del giocatore locale.
func take_damage(amount: float, _source: Node = null, push: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	model.flash()
	ents.hit_entity(owner_peer, eid, amount, "punch", push)


## Investito dall'auto guidata dal giocatore locale.
func hit_by_car(_car: Node, spd: float, push: Vector3) -> void:
	if dead or down or hit_cd > 0.0:
		return
	hit_cd = 1.0
	ents.hit_entity(owner_peer, eid, spd * 1.3, "car", push)
