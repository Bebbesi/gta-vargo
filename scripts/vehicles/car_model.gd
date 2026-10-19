class_name CarModel
extends Node3D
## Modello low-poly dell'auto (carrozzeria in un'unica mesh + 4 ruote animate)
## con effetti di danno, incendio e nitro.

static var _wheel_mesh: CylinderMesh

var body_mesh: MeshInstance3D
var steer_pivots: Array[Node3D] = []
var spin_nodes: Array[Node3D] = []
var smoke: CPUParticles3D
var fire: CPUParticles3D
var nitro_fx: CPUParticles3D
var driver_head: MeshInstance3D
var size := Vector3.ONE
var _spin := 0.0
var siren_lights: Array[MeshInstance3D] = []
var siren_on := false


static func wheel_mesh() -> CylinderMesh:
	if _wheel_mesh == null:
		_wheel_mesh = CylinderMesh.new()
		_wheel_mesh.top_radius = 0.38
		_wheel_mesh.bottom_radius = 0.38
		_wheel_mesh.height = 0.3
		_wheel_mesh.radial_segments = 10
		_wheel_mesh.rings = 0
		_wheel_mesh.material = Gfx.mat(Color(0.08, 0.08, 0.09))
	return _wheel_mesh


func build(type: String, c: Color, sz: Vector3) -> void:
	size = sz
	var w := sz.x
	var h := sz.y
	var l := sz.z
	var cl := 0.3
	var lower_h := h * 0.4
	var dark := Color(0.12, 0.12, 0.13)
	var glass := Color(0.16, 0.22, 0.3)
	var b := MeshBatch.new()
	var cab_z := 0.0
	var top_y := h
	if type == "van" or type == "swat":
		b.box(Vector3(0, cl + (h - cl) * 0.5, 0.35), Vector3(w, h - cl, l - 0.7), c)
		b.box(Vector3(0, cl + lower_h * 0.5, -l * 0.5 + 0.4), Vector3(w * 0.98, lower_h, 0.8), c)
		b.box(Vector3(0, cl + h * 0.58, -l * 0.5 + 0.72), Vector3(w * 0.9, h * 0.32, 0.06), glass)
		b.box(Vector3(0, cl + h * 0.58, -l * 0.5 + 1.4), Vector3(w + 0.03, h * 0.3, 1.1), glass)
		b.box(Vector3(0, cl + h * 0.35, 0.8), Vector3(w + 0.02, 0.25, l * 0.6), c.lightened(0.25))
		cab_z = -l * 0.5 + 1.4
	else:
		b.box(Vector3(0, cl + lower_h * 0.5, 0), Vector3(w, lower_h, l), c)
		var cab_l := l * (0.4 if type == "sport" else 0.5)
		cab_z = 0.12 * l if type in ["sport", "muscle"] else 0.04 * l
		var cab_h := h - lower_h - cl
		var cab_y := cl + lower_h
		b.box(Vector3(0, cab_y + cab_h * 0.5, cab_z), Vector3(w * 0.84, cab_h, cab_l), c.darkened(0.04))
		b.box(Vector3(0, cab_y + cab_h * 0.42, cab_z), Vector3(w * 0.86, cab_h * 0.62, cab_l + 0.05), glass)
		b.box(Vector3(0, cab_y + cab_h * 0.88, cab_z), Vector3(w * 0.85, cab_h * 0.24, cab_l * 0.97), c)
		top_y = cab_y + cab_h
	b.box(Vector3(0, cl + 0.12, -l * 0.5 - 0.06), Vector3(w * 0.96, 0.24, 0.14), dark)
	b.box(Vector3(0, cl + 0.12, l * 0.5 + 0.06), Vector3(w * 0.96, 0.24, 0.14), dark)
	for sx: float in [-1.0, 1.0]:
		b.box(Vector3(sx * w * 0.33, cl + lower_h * 0.62, -l * 0.5 - 0.03), Vector3(0.38, 0.16, 0.06), Color(1.0, 0.97, 0.78))
		b.box(Vector3(sx * w * 0.35, cl + lower_h * 0.62, l * 0.5 + 0.03), Vector3(0.36, 0.14, 0.06), Color(0.9, 0.1, 0.1))
	match type:
		"sport":
			b.box(Vector3(0, cl + lower_h + 0.32, l * 0.5 - 0.25), Vector3(w * 0.92, 0.08, 0.42), dark)
			for sx: float in [-0.6, 0.6]:
				b.box(Vector3(sx, cl + lower_h + 0.15, l * 0.5 - 0.25), Vector3(0.08, 0.3, 0.08), dark)
		"muscle", "viper":
			var stripe := Color(1, 1, 1) if type == "muscle" else Color(0.6, 0.2, 0.8)
			for sx: float in [-0.22, 0.22]:
				b.box(Vector3(sx, cl + lower_h + 0.006, -l * 0.27), Vector3(0.2, 0.02, l * 0.42), stripe)
				b.box(Vector3(sx, top_y + 0.006, cab_z), Vector3(0.2, 0.02, l * 0.3), stripe)
			b.box(Vector3(0, cl + lower_h + 0.1, -l * 0.18), Vector3(0.7, 0.2, 0.8), dark)
		"taxi":
			b.box(Vector3(0, top_y + 0.13, cab_z), Vector3(0.8, 0.26, 0.32), Color(1.0, 0.95, 0.45))
			b.box(Vector3(0, cl + lower_h * 0.5, 0), Vector3(w + 0.02, 0.18, l * 0.7), Color(0.1, 0.1, 0.1))
		"police":
			b.box(Vector3(0, cl + lower_h * 0.5, 0.1), Vector3(w + 0.02, lower_h * 0.55, l * 0.55), Color(0.1, 0.16, 0.38))
			b.box(Vector3(0, cl + lower_h + 0.006, -l * 0.3), Vector3(w * 0.7, 0.02, 0.5), Color(0.1, 0.16, 0.38))
		"swat":
			b.box(Vector3(0, cl + h * 0.35, 0.8), Vector3(w + 0.03, 0.3, l * 0.6), Color(0.85, 0.85, 0.2))
		"luxury":
			b.box(Vector3(0, cl + lower_h * 0.75, 0), Vector3(w + 0.02, 0.06, l * 0.96), Color(0.85, 0.85, 0.9))
			b.box(Vector3(0, cl + lower_h * 0.6, -l * 0.5 - 0.05), Vector3(w * 0.4, 0.3, 0.06), Color(0.8, 0.8, 0.85))
	body_mesh = Gfx.add_batch(self, b)
	body_mesh.visibility_range_end = 220.0
	if type == "police" or type == "swat":
		var roof := (h - 0.02) if type == "swat" else top_y
		Gfx.add_box(self, Vector3(1.2, 0.1, 0.32), Color(0.15, 0.15, 0.17), Vector3(0, roof + 0.05, cab_z))
		for sx: float in [-0.32, 0.32]:
			var light := Gfx.add_box(self, Vector3(0.5, 0.16, 0.3), Color(0.9, 0.1, 0.1) if sx < 0 else Color(0.15, 0.3, 1.0), Vector3(sx, roof + 0.16, cab_z))
			light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			siren_lights.append(light)
		_update_siren()

	var wx := w * 0.5 - 0.1
	var wz := l * 0.5 - (1.0 if type == "van" else 0.85)
	for i in 4:
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var pivot := Node3D.new()
		pivot.position = Vector3(side * wx, 0.38, -wz if front else wz)
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var mi := MeshInstance3D.new()
		mi.mesh = wheel_mesh()
		mi.rotation.z = PI * 0.5
		spin.add_child(mi)
		mi.visibility_range_end = 90.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if front:
			steer_pivots.append(pivot)
		spin_nodes.append(spin)

	driver_head = Gfx.add_box(self, Vector3(0.28, 0.3, 0.28), Color(0.85, 0.68, 0.55), Vector3(-w * 0.2, top_y - 0.4, cab_z))
	driver_head.visible = false

	smoke = Gfx.emitter(self, Color(0.35, 0.35, 0.37), 10, 0.5, 2.2, 1.5)
	smoke.position = Vector3(0, cl + lower_h, -l * 0.38)
	fire = Gfx.emitter(self, Color(1.0, 0.5, 0.1), 16, 0.4, 3.5, 0.6)
	fire.position = Vector3(0, cl + lower_h, -l * 0.3)
	nitro_fx = Gfx.emitter(self, Color(0.45, 0.75, 1.0), 18, 0.22, 0.0, 0.25)
	nitro_fx.position = Vector3(0, cl + 0.2, l * 0.5 + 0.25)
	nitro_fx.direction = Vector3(0, 0, 1)
	nitro_fx.spread = 8.0
	nitro_fx.initial_velocity_min = 7.0
	nitro_fx.initial_velocity_max = 10.0
	nitro_fx.gravity = Vector3.ZERO


func update_visuals(delta: float, speed: float, steer: float) -> void:
	_spin += speed * delta / 0.38
	for s in spin_nodes:
		s.rotation.x = -_spin
	for p in steer_pivots:
		p.rotation.y = lerpf(p.rotation.y, steer * 0.45, clampf(10.0 * delta, 0.0, 1.0))
	if siren_on:
		_update_siren()
	body_mesh.rotation.z = lerpf(body_mesh.rotation.z, -steer * clampf(absf(speed) / 30.0, 0.0, 1.0) * 0.05, clampf(6.0 * delta, 0.0, 1.0))


func set_siren(on: bool) -> void:
	siren_on = on
	_update_siren()


func _update_siren() -> void:
	if siren_lights.size() < 2:
		return
	var phase := (Time.get_ticks_msec() / 220) % 2 == 0
	var red := Color(1.0, 0.12, 0.1)
	var blue := Color(0.2, 0.35, 1.0)
	siren_lights[0].material_override = Gfx.mat(red, 3.0 if siren_on and phase else 0.0, siren_on and phase)
	siren_lights[1].material_override = Gfx.mat(blue, 3.0 if siren_on and not phase else 0.0, siren_on and not phase)


func set_damage(ratio: float) -> void:
	smoke.emitting = ratio > 0.6


func set_wrecked() -> void:
	smoke.emitting = true
	fire.emitting = true
	body_mesh.material_override = Gfx.vc_mat(Color(0.28, 0.27, 0.27))
	driver_head.visible = false


func set_nitro(on: bool) -> void:
	nitro_fx.emitting = on


func set_driver(on: bool, skin: Color = Color(0.85, 0.68, 0.55)) -> void:
	driver_head.visible = on
	if on:
		driver_head.material_override = Gfx.mat(skin)
