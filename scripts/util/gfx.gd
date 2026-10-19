class_name Gfx
extends RefCounted
## Materiali condivisi e piccoli effetti visivi (particelle, testi fluttuanti).

static var _mats: Dictionary = {}
static var _vc: Dictionary = {}
static var _meshes: Dictionary = {}
static var _particle_mat: StandardMaterial3D


static func mat(c: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [c.to_html(true), emission, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.metallic_specular = 0.25
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


## Materiale per mesh con colori per vertice; `tint` moltiplica i colori.
static func vc_mat(tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := tint.to_html(true)
	if _vc.has(key):
		return _vc[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = tint
	m.roughness = 0.9
	m.metallic_specular = 0.15
	_vc[key] = m
	return m


static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "box%s" % size
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	return _meshes[key]


static func add_box(parent: Node, size: Vector3, c: Color, pos: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = mat(c, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_batch(parent: Node, batch: MeshBatch, shadows: bool = true, tint: Color = Color.WHITE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = batch.commit()
	mi.material_override = vc_mat(tint)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func label3d(parent: Node, text: String, pos: Vector3, size: int = 64, c: Color = Color.WHITE, billboard: bool = true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = maxi(4, size / 6)
	l.modulate = c
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.pixel_size = 0.01
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	parent.add_child(l)
	return l


static func _pmat() -> StandardMaterial3D:
	if _particle_mat == null:
		_particle_mat = StandardMaterial3D.new()
		_particle_mat.vertex_color_use_as_albedo = true
		_particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _particle_mat


## Esplosione di cubetti colorati (raccolte, colpi, scintille).
static func burst(parent: Node, pos: Vector3, c: Color, amount: int = 20, speed: float = 5.0, size: float = 0.15, life: float = 0.8) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	bm.material = _pmat()
	p.mesh = bm
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color = c
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)


## Testo che sale e svanisce (es. "+35").
static func popup(parent: Node, pos: Vector3, text: String, c: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := label3d(parent, text, Vector3.ZERO, 72, c)
	l.global_position = pos
	l.no_depth_test = true
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(0, 1.6, 0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## Emettitore continuo (fumo, fuoco, nitro).
static func emitter(parent: Node, c: Color, amount: int = 12, size: float = 0.4, up_speed: float = 2.0, life: float = 1.2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	bm.material = _pmat()
	p.mesh = bm
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = up_speed * 0.6
	p.initial_velocity_max = up_speed
	p.gravity = Vector3(0, 0.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = c
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.emitting = false
	parent.add_child(p)
	return p


## Scia luminosa di un proiettile (dura un istante).
static func tracer(parent: Node, from: Vector3, to: Vector3, c: Color = Color(1.0, 0.9, 0.5)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var length := from.distance_to(to)
	if length < 0.2:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(Vector3(0.05, 0.05, 1.0))
	mi.material_override = mat(Color(c.r, c.g, c.b, 0.85), 2.0, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.FORWARD)
	mi.scale = Vector3(1, 1, length)
	mi.get_tree().create_timer(0.07).timeout.connect(mi.queue_free)


## Lampo alla bocca dell'arma.
static func muzzle_flash(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(Vector3(0.22, 0.22, 0.22))
	mi.material_override = mat(Color(1.0, 0.85, 0.3), 3.0, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	mi.get_tree().create_timer(0.05).timeout.connect(mi.queue_free)
