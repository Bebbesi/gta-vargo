class_name CharacterModel
extends Node3D
## Personaggio low-poly costruito con box a colori per vertice (5 mesh in tutto)
## e animato via codice: camminata, corsa, salto, pugno, caduta.

var body: MeshInstance3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var parts: Array[MeshInstance3D] = []
var phase := 0.0
var punch_t := 0.0
var punch_left := false
var is_down := false
var flash_t := 0.0
var aura: MeshInstance3D


func build(look: Dictionary) -> void:
	var jacket: Color = look.get("jacket", Color.GRAY)
	var shirt: Color = look.get("shirt", Color.WHITE)
	var pants: Color = look.get("pants", Color.DIM_GRAY)
	var skin: Color = look.get("skin", Color(0.9, 0.72, 0.58))
	var hair: Color = look.get("hair", Color(0.2, 0.15, 0.1))
	var shoes: Color = look.get("shoes", Color(0.1, 0.1, 0.1))
	var style: String = look.get("hair_style", "short")
	var extra: String = look.get("extra", "")
	var s: float = look.get("scale", 1.0)
	scale = Vector3(s, s, s)

	var b := MeshBatch.new()
	b.box(Vector3(0, 1.24, 0), Vector3(0.5, 0.56, 0.28), jacket)
	if shirt != jacket:
		b.box(Vector3(0, 1.26, -0.142), Vector3(0.17, 0.5, 0.02), shirt)
	b.box(Vector3(0, 0.97, 0), Vector3(0.48, 0.08, 0.27), pants.darkened(0.3))
	b.box(Vector3(0, 1.55, 0), Vector3(0.13, 0.08, 0.13), skin)
	b.box(Vector3(0, 1.73, 0), Vector3(0.3, 0.32, 0.3), skin)
	var eye := Color(0.08, 0.08, 0.1)
	b.box(Vector3(-0.07, 1.75, -0.152), Vector3(0.05, 0.05, 0.02), eye)
	b.box(Vector3(0.07, 1.75, -0.152), Vector3(0.05, 0.05, 0.02), eye)
	b.box(Vector3(0, 1.64, -0.152), Vector3(0.1, 0.025, 0.02), skin.darkened(0.35))
	b.box(Vector3(0, 1.7, -0.165), Vector3(0.05, 0.07, 0.04), skin.darkened(0.08))
	match style:
		"short":
			b.box(Vector3(0, 1.91, 0.01), Vector3(0.32, 0.08, 0.32), hair)
			b.box(Vector3(0, 1.8, 0.145), Vector3(0.32, 0.2, 0.05), hair)
		"slick":
			b.box(Vector3(0, 1.91, 0.02), Vector3(0.32, 0.07, 0.33), hair)
			b.box(Vector3(0, 1.93, -0.12), Vector3(0.3, 0.09, 0.09), hair)
			b.box(Vector3(0, 1.82, 0.145), Vector3(0.32, 0.18, 0.05), hair)
		"spiky":
			for i in 5:
				b.box(Vector3(-0.12 + i * 0.06, 1.95, 0.0), Vector3(0.05, 0.14, 0.26), hair)
		"cap":
			b.box(Vector3(0, 1.92, 0), Vector3(0.33, 0.1, 0.33), hair)
			b.box(Vector3(0, 1.88, -0.21), Vector3(0.3, 0.03, 0.14), hair.darkened(0.2))
		"beanie":
			b.box(Vector3(0, 1.93, 0), Vector3(0.33, 0.16, 0.33), hair)
		"long":
			b.box(Vector3(0, 1.91, 0.01), Vector3(0.32, 0.08, 0.32), hair)
			b.box(Vector3(0, 1.68, 0.15), Vector3(0.32, 0.4, 0.06), hair)
		_:
			pass
	match extra:
		"shades":
			b.box(Vector3(0, 1.755, -0.162), Vector3(0.31, 0.07, 0.025), Color(0.05, 0.05, 0.06))
		"glasses_tie":
			b.box(Vector3(-0.07, 1.755, -0.163), Vector3(0.09, 0.07, 0.015), Color(0.75, 0.78, 0.8))
			b.box(Vector3(0.07, 1.755, -0.163), Vector3(0.09, 0.07, 0.015), Color(0.75, 0.78, 0.8))
			b.box(Vector3(0, 1.28, -0.156), Vector3(0.07, 0.38, 0.02), Color(0.75, 0.12, 0.15))
		"beard":
			b.box(Vector3(0, 1.62, -0.145), Vector3(0.3, 0.13, 0.04), hair.lightened(0.05))
			b.box(Vector3(0, 1.67, -0.16), Vector3(0.16, 0.035, 0.02), hair)
		"bandana":
			b.box(Vector3(0, 1.64, -0.155), Vector3(0.31, 0.12, 0.03), shirt)
		"crow_pin":
			b.box(Vector3(-0.15, 1.38, -0.148), Vector3(0.07, 0.05, 0.02), Color(0.05, 0.05, 0.05))
	body = _part(self, b)

	arm_l = _limb(Vector3(-0.33, 1.47, 0), jacket, skin, true)
	arm_r = _limb(Vector3(0.33, 1.47, 0), jacket, skin, true)
	leg_l = _limb(Vector3(-0.12, 0.95, 0), pants, shoes, false)
	leg_r = _limb(Vector3(0.12, 0.95, 0), pants, shoes, false)


func _part(parent: Node3D, b: MeshBatch) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = Gfx.vc_mat()
	mi.visibility_range_end = 110.0
	parent.add_child(mi)
	parts.append(mi)
	return mi


func _limb(pivot: Vector3, c_main: Color, c_end: Color, is_arm: bool) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	add_child(n)
	var b := MeshBatch.new()
	if is_arm:
		b.box(Vector3(0, -0.26, 0), Vector3(0.15, 0.56, 0.17), c_main)
		b.box(Vector3(0, -0.6, 0), Vector3(0.12, 0.13, 0.13), c_end)
	else:
		b.box(Vector3(0, -0.44, 0), Vector3(0.19, 0.84, 0.21), c_main)
		b.box(Vector3(0, -0.89, -0.04), Vector3(0.21, 0.12, 0.3), c_end)
	_part(n, b)
	return n


## speed_ratio: 0 fermo, 1 corsa piena.
func animate(delta: float, speed_ratio: float, on_floor: bool) -> void:
	if is_down:
		return
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			_set_tint(Color.WHITE)
	var sr := clampf(speed_ratio, 0.0, 1.2)
	phase += delta * (3.0 + 9.0 * sr)
	var swing := sin(phase) * 0.95 * sr
	if not on_floor:
		leg_l.rotation.x = 0.6
		leg_r.rotation.x = -0.35
		arm_l.rotation.x = -0.4
		arm_r.rotation.x = -0.4
		arm_l.rotation.z = -0.5
		arm_r.rotation.z = 0.5
	else:
		leg_l.rotation.x = swing
		leg_r.rotation.x = -swing
		arm_l.rotation.x = -swing * 0.8
		arm_r.rotation.x = swing * 0.8
		arm_l.rotation.z = 0.0
		arm_r.rotation.z = 0.0
	body.position.y = absf(sin(phase)) * 0.05 * sr
	if sr < 0.05:
		body.position.y = sin(phase * 0.5) * 0.008
	if punch_t > 0.0:
		punch_t -= delta
		var k := clampf(punch_t / 0.3, 0.0, 1.0)
		var reach := sin(k * PI) * 1.65
		if punch_left:
			arm_l.rotation.x = reach
		else:
			arm_r.rotation.x = reach
		body.rotation.y = sin(k * PI) * (0.25 if not punch_left else -0.25)
	else:
		body.rotation.y = 0.0


func play_punch() -> void:
	punch_left = not punch_left
	punch_t = 0.3


func flash(c: Color = Color(1.0, 0.45, 0.45)) -> void:
	flash_t = 0.12
	_set_tint(c)


func _set_tint(c: Color) -> void:
	var m := Gfx.vc_mat(c)
	for p in parts:
		p.material_override = m


func set_down(down: bool) -> void:
	is_down = down
	if down:
		rotation.x = -PI * 0.5
		position.y = 0.18
		arm_l.rotation = Vector3(0, 0, -1.2)
		arm_r.rotation = Vector3(0, 0, 1.2)
		leg_l.rotation = Vector3.ZERO
		leg_r.rotation = Vector3.ZERO
	else:
		rotation.x = 0.0
		position.y = 0.04
		arm_l.rotation = Vector3.ZERO
		arm_r.rotation = Vector3.ZERO


func set_aura(on: bool, c: Color) -> void:
	if on and aura == null:
		aura = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.75
		cm.bottom_radius = 0.75
		cm.height = 0.05
		cm.radial_segments = 16
		aura.mesh = cm
		aura.material_override = Gfx.mat(Color(c.r, c.g, c.b, 0.45), 1.5, true)
		aura.position.y = 0.06
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(aura)
	elif not on and aura != null:
		aura.queue_free()
		aura = null
