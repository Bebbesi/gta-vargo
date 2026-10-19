class_name NetAvatar
extends CharacterBody3D
## Un altro giocatore in multiplayer: segue la posizione ricevuta dalla rete
## (interpolata), ha un corpo fisico per collisioni e proiettili e inoltra i
## colpi ricevuti al suo proprietario.

var net: Node
var peer_id := 0
var char_id := "mike"
var player_name := ""
var color := Color.WHITE
var model: CharacterModel
var label: Label3D
var collider: CollisionShape3D
var dead := false
var in_car := false
var health := 100.0
var hit_cd := 0.0
var _pos := Vector3.ZERO
var _yaw := 0.0
var _speed := 0.0
var _floor := true
var _has_state := false


func setup(n: Node, id: int, info: Dictionary) -> void:
	net = n
	peer_id = id
	name = "Avatar_%d" % id
	char_id = str(info.get("char", "mike"))
	var d: Dictionary = Game.char_data(char_id)
	color = d["color"]
	model = CharacterModel.new()
	add_child(model)
	model.build(d["look"])
	model.position.y = 0.04
	collider = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.8
	collider.shape = cap
	collider.position.y = 0.9
	add_child(collider)
	collision_layer = 2
	collision_mask = 0
	label = Gfx.label3d(self, "", Vector3(0, 2.45, 0), 44, color.lightened(0.3))
	label.no_depth_test = true
	add_to_group("net_avatars")
	set_info(info)


func set_info(info: Dictionary) -> void:
	player_name = str(info.get("name", "Giocatore"))
	label.text = player_name


func initial() -> String:
	return player_name.substr(0, 1).to_upper()


func skin() -> Color:
	return Game.char_data(char_id)["look"]["skin"]


func apply_state(d: Array) -> void:
	_pos = d[0]
	_yaw = d[1]
	_speed = d[2]
	_floor = d[3]
	var was_dead := dead
	dead = d[4]
	var weapon: String = d[5]
	in_car = int(d[6]) >= 0
	health = d[11]
	if not _has_state:
		_has_state = true
		global_position = _pos
	if weapon != model.weapon_id:
		model.set_weapon(weapon)
	if bool(d[12]):
		model.aim(0.3)
	if dead != was_dead:
		model.set_down(dead)
	model.visible = not in_car
	label.visible = not in_car
	collider.disabled = in_car or dead


func aim_point() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func take_bullet(amount: float, _source: Node, _dir: Vector3) -> void:
	if dead or in_car:
		return
	Gfx.burst(net.world, global_position + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.4), 6, 3.0, 0.07, 0.3)
	net.hit_player(peer_id, amount, "shot")


## Colpo da pugno o investimento inferto dal giocatore locale.
func net_hit(amount: float, kind: String) -> void:
	if dead or in_car:
		return
	if kind == "car":
		if hit_cd > 0.0:
			return
		hit_cd = 1.0
	net.hit_player(peer_id, amount, kind)


func _process(delta: float) -> void:
	hit_cd = maxf(0.0, hit_cd - delta)
	if not _has_state:
		return
	if global_position.distance_to(_pos) > 10.0:
		global_position = _pos
	else:
		global_position = global_position.lerp(_pos, clampf(delta * 14.0, 0.0, 1.0))
	model.rotation.y = lerp_angle(model.rotation.y, _yaw, clampf(delta * 14.0, 0.0, 1.0))
	if not dead:
		model.animate(delta, _speed / 8.0, _floor)
