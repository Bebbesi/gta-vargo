class_name SecurityCam
extends Node3D
## Telecamera di sicurezza con cono visivo che oscilla. Se il giocatore resta
## nel cono troppo a lungo scatta l'allarme (missione di Tom).

var world: Node
var view_range := 17.0
var half_angle := deg_to_rad(24.0)
var base_yaw := 0.0
var sweep := deg_to_rad(40.0)
var sweep_speed := 0.6
var disabled_time := 0.0
var head: Node3D
var cone: MeshInstance3D
var _t := 0.0


func setup(w: Node, pos: Vector3, facing_yaw: float, height: float = 4.5) -> void:
	world = w
	global_position = pos
	base_yaw = facing_yaw
	_t = randf() * TAU
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.1
	cm.height = height
	cm.radial_segments = 6
	pole.mesh = cm
	pole.material_override = Gfx.mat(Color(0.3, 0.3, 0.32))
	pole.position.y = height * 0.5
	add_child(pole)
	head = Node3D.new()
	head.position.y = height
	add_child(head)
	Gfx.add_box(head, Vector3(0.35, 0.3, 0.6), Color(0.85, 0.85, 0.82), Vector3(0, 0, -0.2))
	Gfx.add_box(head, Vector3(0.12, 0.12, 0.05), Color(0.9, 0.1, 0.1), Vector3(0, 0, -0.52), 2.0)
	cone = MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = tan(half_angle) * view_range
	cone_mesh.height = view_range
	cone_mesh.radial_segments = 12
	cone_mesh.cap_bottom = false
	cone.mesh = cone_mesh
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.rotation.x = PI * 0.5
	cone.position = Vector3(0, 0, -view_range * 0.5)
	var pitch := Node3D.new()
	pitch.rotation.x = -atan2(height - 0.6, view_range * 0.65)
	head.add_child(pitch)
	pitch.add_child(cone)
	_update_cone_color()


func _process(delta: float) -> void:
	_t += delta * sweep_speed
	head.rotation.y = base_yaw + sin(_t) * sweep
	if disabled_time > 0.0:
		disabled_time -= delta
		if disabled_time <= 0.0:
			_update_cone_color()


func disable(t: float) -> void:
	disabled_time = t
	_update_cone_color()


func _update_cone_color() -> void:
	if disabled_time > 0.0:
		cone.material_override = Gfx.mat(Color(0.5, 0.5, 0.55, 0.12), 0.0, true)
	else:
		cone.material_override = Gfx.mat(Color(1.0, 0.15, 0.1, 0.22), 0.0, true)


func sees(p: Vector3) -> bool:
	if disabled_time > 0.0:
		return false
	var origin := head.global_position
	var to := p - origin
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > view_range or flat.length() < 0.5:
		return false
	var yaw := head.global_rotation.y
	var dir := Vector3(-sin(yaw), 0, -cos(yaw))
	if dir.angle_to(flat.normalized()) > half_angle:
		return false
	var q := PhysicsRayQueryParameters3D.create(origin, p + Vector3(0, 1.0, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()
