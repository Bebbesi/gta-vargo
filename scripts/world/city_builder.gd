class_name CityBuilder
extends RefCounted
## Genera proceduralmente Port Ardena: strade, quartieri, porto e aeroporto.
## Tutta la geometria statica finisce in due mesh (suolo + edifici) e in un
## solo StaticBody3D con forme box: poche draw call e fisica leggera.

const C_GRASS := Color(0.37, 0.56, 0.28)
const C_PARK := Color(0.33, 0.6, 0.3)
const C_ROAD := Color(0.21, 0.21, 0.23)
const C_SIDEWALK := Color(0.64, 0.63, 0.6)
const C_LINE := Color(0.95, 0.95, 0.9)
const C_YELLOW := Color(0.96, 0.8, 0.22)
const C_CONCRETE := Color(0.56, 0.55, 0.52)
const C_ASPHALT := Color(0.27, 0.27, 0.29)
const C_WATER := Color(0.16, 0.42, 0.62)
const C_TRUNK := Color(0.42, 0.28, 0.16)

const TOWER_COLORS := [
	Color(0.78, 0.74, 0.67), Color(0.56, 0.62, 0.7), Color(0.84, 0.8, 0.72), Color(0.62, 0.56, 0.5),
	Color(0.47, 0.52, 0.6), Color(0.86, 0.86, 0.83), Color(0.72, 0.6, 0.52), Color(0.6, 0.66, 0.62),
]
const GLASS_COLORS := [Color(0.22, 0.34, 0.48), Color(0.28, 0.45, 0.55), Color(0.2, 0.28, 0.36), Color(0.35, 0.5, 0.6)]
const HOUSE_COLORS := [
	Color(0.94, 0.86, 0.7), Color(0.84, 0.9, 0.95), Color(0.96, 0.8, 0.74), Color(0.82, 0.9, 0.78),
	Color(0.98, 0.95, 0.85), Color(0.9, 0.8, 0.9),
]
const ROOF_COLORS := [Color(0.62, 0.26, 0.2), Color(0.36, 0.31, 0.32), Color(0.46, 0.3, 0.24), Color(0.3, 0.38, 0.5)]
const LEAF_COLORS := [Color(0.24, 0.5, 0.22), Color(0.3, 0.56, 0.24), Color(0.2, 0.44, 0.26), Color(0.4, 0.58, 0.22)]
const CONTAINER_COLORS := [
	Color(0.8, 0.3, 0.2), Color(0.2, 0.45, 0.7), Color(0.25, 0.6, 0.35), Color(0.88, 0.66, 0.2), Color(0.55, 0.55, 0.58),
]
const SHOP_COLORS := [Color(0.9, 0.3, 0.3), Color(0.25, 0.6, 0.85), Color(0.95, 0.75, 0.2), Color(0.4, 0.75, 0.4), Color(0.8, 0.45, 0.8)]

var world: Node3D
var ground := ChunkedBatch.new()
var solid := ChunkedBatch.new()
var body: StaticBody3D
var labels: Node3D
var rng := RandomNumberGenerator.new()
var _shapes: Dictionary = {}
var shape_count := 0


func build(w: Node3D) -> void:
	world = w
	rng.seed = 1977
	CityData.ensure_graph()
	body = StaticBody3D.new()
	body.name = "CityCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	w.add_child(body)
	labels = Node3D.new()
	labels.name = "Signs"
	w.add_child(labels)
	_base()
	_roads()
	for zi in 6:
		for xi in 6:
			_block(xi, zi)
	armory_sign()
	_docks()
	_airport()
	_outskirts()
	_bounds()
	var g := Node3D.new()
	g.name = "CityGround"
	w.add_child(g)
	ground.commit_to(g, false)
	var s := Node3D.new()
	s.name = "CityBuildings"
	w.add_child(s)
	solid.commit_to(s, true)


# ---------------------------------------------------------------- helper

func col(center: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	var key := "%s" % size
	if not _shapes.has(key):
		var b := BoxShape3D.new()
		b.size = size
		_shapes[key] = b
	var cs := CollisionShape3D.new()
	cs.shape = _shapes[key]
	cs.position = center
	cs.rotation.y = rot_y
	body.add_child(cs)
	shape_count += 1


func sbox(center: Vector3, size: Vector3, c: Color, rot_y: float = 0.0, collide: bool = true) -> void:
	solid.box(center, size, c, rot_y)
	if collide:
		col(center, size, rot_y)


func pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


func sign_label(text: String, pos: Vector3, rot_y: float, size: int = 72, c: Color = Color.WHITE) -> void:
	var l := Gfx.label3d(labels, text, pos, size, c, false)
	l.rotation.y = rot_y
	l.pixel_size = 0.012


# ---------------------------------------------------------------- terreno e strade

func _base() -> void:
	# prato fino al porto, poi il mare
	ground.top_quad(Vector3(100, 0, -247), 1400, 906, C_GRASS)
	ground.top_quad(Vector3(100, -0.45, 556), 1400, 700, C_WATER)
	col(Vector3(100, -0.5, 0), Vector3(1400, 1, 1400))


func _roads() -> void:
	for e in CityData.edges():
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var d := b - a
		var length := d.length()
		var dir := d / length
		var mid := (a + b) * 0.5
		var rot := atan2(dir.x, dir.z)
		ground.box(Vector3(mid.x, 0.015, mid.z), Vector3(CityData.ROAD_W, 0.03, length + CityData.ROAD_W), C_ROAD, rot)
		var s := CityData.HALF_ROAD + 4.0
		while s < length - CityData.HALF_ROAD - 6.0:
			var p := a + dir * (s + 1.5)
			ground.top_quad(Vector3(p.x, 0.034, p.z), 0.28, 3.0, C_LINE, rot)
			s += 6.5
		var perp := Vector3(dir.z, 0, -dir.x)
		for end_i in 2:
			var base := a + dir * (CityData.HALF_ROAD + 1.8) if end_i == 0 else b - dir * (CityData.HALF_ROAD + 1.8)
			for k in 6:
				var p2 := base + perp * ((k - 2.5) * 2.1)
				ground.top_quad(Vector3(p2.x, 0.034, p2.z), 0.9, 2.6, C_LINE, rot)


# ---------------------------------------------------------------- isolati

func _block(xi: int, zi: int) -> void:
	var c := Vector3(CityData.CENTERS[xi], 0, CityData.CENTERS[zi])
	var t := CityData.block_type(xi, zi)
	var slab := C_SIDEWALK
	if t in ["industrial", "lot", "yard"]:
		slab = Color(0.6, 0.59, 0.55)
	ground.box(Vector3(c.x, 0.03, c.z), Vector3(46, 0.06, 46), slab)
	match t:
		"downtown":
			_inner(c, Color(0.6, 0.6, 0.58))
			_downtown(c)
		"plaza":
			_plaza(c)
		"park":
			_inner(c, C_PARK)
			_park(c)
		"residential":
			_inner(c, C_GRASS)
			_residential(c)
		"safehouse":
			_inner(c, C_GRASS)
			_safehouse(c)
		"parking", "lot":
			_inner(c, C_ASPHALT)
			_parking(c)
		"shops":
			_inner(c, Color(0.62, 0.6, 0.57))
			_shops(c)
		"garage":
			_inner(c, C_CONCRETE)
			_garage(c)
		"police":
			_inner(c, C_CONCRETE)
			_police_station(c)
		"yard":
			_inner(c, Color(0.45, 0.44, 0.42))
			_yard(c)
		_:
			_inner(c, C_CONCRETE)
			_industrial(c)
	_lamps(c)


func _inner(c: Vector3, color: Color) -> void:
	ground.box(Vector3(c.x, 0.035, c.z), Vector3(40, 0.07, 40), color)


func _lamps(c: Vector3) -> void:
	var spots := [
		Vector3(c.x + 22.4, 0, c.z - 10), Vector3(c.x - 22.4, 0, c.z + 10),
		Vector3(c.x - 10, 0, c.z - 22.4), Vector3(c.x + 10, 0, c.z + 22.4),
	]
	for p: Vector3 in spots:
		var outward := Vector3(signf(p.x - c.x) if absf(p.x - c.x) > 20 else 0.0, 0, signf(p.z - c.z) if absf(p.z - c.z) > 20 else 0.0)
		solid.cylinder(Vector3(p.x, 2.6, p.z), 0.12, 0.09, 5.2, 4, Color(0.3, 0.32, 0.35))
		var head := p + outward * 0.9
		solid.box(Vector3(head.x, 5.2, head.z), Vector3(0.5, 0.2, 0.5) + outward.abs() * 1.4, Color(0.3, 0.32, 0.35))
		solid.box(Vector3(head.x, 5.05, head.z) + outward * 0.6, Vector3(0.45, 0.12, 0.45), Color(1.0, 0.95, 0.7))
		col(Vector3(p.x, 2.5, p.z), Vector3(0.3, 5, 0.3))


func _tree(p: Vector3, s: float = 1.0) -> void:
	var h := rng.randf_range(3.6, 5.4) * s
	solid.cylinder(Vector3(p.x, h * 0.3, p.z), 0.26 * s, 0.2 * s, h * 0.6, 5, C_TRUNK)
	var leaf: Color = pick(LEAF_COLORS)
	solid.cylinder(Vector3(p.x, h * 0.62, p.z), 2.0 * s, 1.3 * s, h * 0.36, 6, leaf.darkened(0.08))
	solid.cylinder(Vector3(p.x, h * 1.0, p.z), 1.7 * s, 0.0, h * 0.6, 6, leaf)
	col(Vector3(p.x, 1.5, p.z), Vector3(0.6, 3.0, 0.6))


func _bench(p: Vector3, rot: float) -> void:
	sbox(Vector3(p.x, 0.45, p.z), Vector3(2.2, 0.15, 0.6), Color(0.55, 0.36, 0.2), rot)
	solid.box(Vector3(p.x, 0.22, p.z), Vector3(1.9, 0.45, 0.4), Color(0.25, 0.25, 0.27), rot)


func _downtown(c: Vector3) -> void:
	for lx: int in [-1, 1]:
		for lz: int in [-1, 1]:
			var lc := c + Vector3(lx * 10.5, 0, lz * 10.5)
			var w := rng.randf_range(12.0, 16.5)
			var d := rng.randf_range(12.0, 16.5)
			if CityData.is_reserved(lc, maxf(w, d) * 0.5):
				continue
			var dist_center := Vector2(lc.x, lc.z).length()
			var h := rng.randf_range(14.0, 26.0) + maxf(0.0, 150.0 - dist_center) * 0.22
			_tower(lc, Vector3(w, h, d), pick(TOWER_COLORS))


func _tower(p: Vector3, size: Vector3, c: Color) -> void:
	sbox(Vector3(p.x, size.y * 0.5, p.z), size, c)
	var glass: Color = pick(GLASS_COLORS)
	var y := 4.6
	while y < size.y - 2.0:
		solid.box(Vector3(p.x, y, p.z), Vector3(size.x + 0.14, 1.6, size.z + 0.14), glass)
		y += 3.6
	solid.box(Vector3(p.x, 1.4, p.z), Vector3(size.x + 0.1, 2.8, size.z + 0.1), c.darkened(0.35))
	solid.box(Vector3(p.x, size.y + 0.5, p.z), Vector3(size.x + 0.4, 1.0, size.z + 0.4), c.darkened(0.15))
	solid.box(Vector3(p.x + size.x * 0.15, size.y + 1.6, p.z - size.z * 0.1), Vector3(size.x * 0.35, 1.6, size.z * 0.3), Color(0.55, 0.56, 0.58))
	if size.y > 40.0:
		solid.cylinder(Vector3(p.x - size.x * 0.25, size.y + 4.0, p.z + size.z * 0.2), 0.15, 0.05, 6.0, 4, Color(0.8, 0.2, 0.2))


func _plaza(c: Vector3) -> void:
	ground.box(Vector3(c.x, 0.035, c.z), Vector3(40, 0.07, 40), Color(0.78, 0.74, 0.66))
	for i in 4:
		ground.top_quad(Vector3(c.x, 0.075, c.z), 2.5, 40.0, Color(0.68, 0.62, 0.55), i * PI * 0.25)
	var stone := Color(0.74, 0.72, 0.66)
	solid.cylinder(Vector3(c.x, 0.4, c.z), 4.4, 4.4, 0.8, 14, stone)
	solid.cylinder(Vector3(c.x, 0.81, c.z), 3.9, 3.9, 0.04, 14, C_WATER)
	solid.cylinder(Vector3(c.x, 1.7, c.z), 0.9, 0.7, 1.9, 8, stone.darkened(0.1))
	var cz := Vector3(c.x, 3.1, c.z)
	var dark := Color(0.08, 0.08, 0.1)
	solid.box(cz, Vector3(0.7, 0.7, 1.3), dark)
	solid.box(cz + Vector3(0, 0.45, -0.7), Vector3(0.5, 0.5, 0.5), dark)
	solid.box(cz + Vector3(0, 0.4, -1.1), Vector3(0.14, 0.14, 0.4), Color(0.85, 0.7, 0.2))
	solid.box(cz + Vector3(0.75, 0.25, 0.1), Vector3(1.0, 0.12, 0.8), dark, 0.3)
	solid.box(cz + Vector3(-0.75, 0.25, 0.1), Vector3(1.0, 0.12, 0.8), dark, -0.3)
	solid.box(cz + Vector3(0, -0.1, 0.9), Vector3(0.5, 0.12, 0.7), dark)
	col(Vector3(c.x, 0.9, c.z), Vector3(8.4, 1.8, 8.4))
	sign_label("PIAZZA DEL CORVO", Vector3(c.x, 1.3, c.z + 4.45), 0.0, 40, Color(0.2, 0.15, 0.1))
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			_tree(c + Vector3(sx * 15.0, 0, sz * 15.0), 1.1)
			_bench(c + Vector3(sx * 9.0, 0, sz * 13.0), 0.0)


func _park(c: Vector3) -> void:
	var path_c := Color(0.8, 0.74, 0.6)
	ground.box(Vector3(c.x, 0.04, c.z), Vector3(40, 0.08, 3.0), path_c)
	ground.box(Vector3(c.x, 0.04, c.z), Vector3(3.0, 0.08, 40), path_c)
	var pond := c + Vector3(9, 0, -9)
	if not CityData.is_reserved(pond, 5.0):
		solid.cylinder(Vector3(pond.x, 0.06, pond.z), 5.5, 5.5, 0.12, 10, C_WATER)
		solid.cylinder(Vector3(pond.x, 0.05, pond.z), 6.0, 6.0, 0.1, 10, Color(0.6, 0.55, 0.45))
	for i in 12:
		var p := c + Vector3(rng.randf_range(-18, 18), 0, rng.randf_range(-18, 18))
		if absf(p.x - c.x) < 3.0 or absf(p.z - c.z) < 3.0:
			continue
		if p.distance_to(pond) < 7.5 or CityData.is_reserved(p, 2.0):
			continue
		_tree(p, rng.randf_range(0.9, 1.3))
	_bench(c + Vector3(-6, 0, 3), 0.0)
	_bench(c + Vector3(6, 0, -3), 0.0)
	_bench(c + Vector3(-3, 0, -7), PI * 0.5)


func _residential(c: Vector3) -> void:
	for lx: int in [-1, 1]:
		for lz: int in [-1, 1]:
			var lc := c + Vector3(lx * 10.5, 0, lz * 10.5)
			if CityData.is_reserved(lc, 6.0):
				continue
			var w := rng.randf_range(9.0, 12.0)
			var d := rng.randf_range(8.0, 10.0)
			var h := rng.randf_range(4.0, 6.8)
			var wall: Color = pick(HOUSE_COLORS)
			sbox(Vector3(lc.x, h * 0.5, lc.z), Vector3(w, h, d), wall)
			solid.gable(Vector3(lc.x, h, lc.z), Vector3(w + 0.8, rng.randf_range(2.2, 3.2), d + 0.8), pick(ROOF_COLORS))
			var fz := lc.z + lz * (d * 0.5 + 0.04)
			solid.box(Vector3(lc.x, 1.1, fz), Vector3(1.2, 2.2, 0.08), Color(0.4, 0.25, 0.15))
			for wx: float in [-w * 0.3, w * 0.3]:
				solid.box(Vector3(lc.x + wx, h * 0.55, fz), Vector3(1.5, 1.2, 0.08), Color(0.55, 0.75, 0.9))
			var tp := lc + Vector3(lx * 7.2, 0, lz * 7.2)
			if not CityData.is_reserved(tp, 1.5):
				_tree(tp)


func _safehouse(c: Vector3) -> void:
	var wall := Color(0.93, 0.87, 0.72)
	var trim := Color(0.55, 0.38, 0.25)
	sbox(Vector3(150, 3.5, -152), Vector3(18, 7, 14), wall)
	solid.box(Vector3(150, 3.6, -152), Vector3(18.15, 0.3, 14.15), trim)
	solid.gable(Vector3(150, 7, -152), Vector3(19.2, 3.6, 15.2), Color(0.58, 0.22, 0.16))
	solid.box(Vector3(150, 1.25, -144.95), Vector3(1.8, 2.5, 0.12), Color(0.35, 0.2, 0.1))
	for wx: float in [-5.5, 5.5]:
		solid.box(Vector3(150 + wx, 1.8, -144.95), Vector3(2.4, 1.6, 0.1), Color(0.55, 0.75, 0.9))
		solid.box(Vector3(150 + wx, 5.3, -144.95), Vector3(2.4, 1.4, 0.1), Color(0.55, 0.75, 0.9))
	solid.box(Vector3(150, 5.3, -144.95), Vector3(2.0, 1.4, 0.1), Color(0.55, 0.75, 0.9))
	ground.box(Vector3(150, 0.09, -143.2), Vector3(4.0, 0.06, 3.5), Color(0.7, 0.6, 0.5))
	ground.box(Vector3(150, 0.08, -136.5), Vector3(2.5, 0.04, 10.0), Color(0.75, 0.7, 0.6))
	sbox(Vector3(162, 2.0, -152), Vector3(6, 4, 10), wall.darkened(0.05))
	solid.box(Vector3(162, 4.15, -152), Vector3(6.4, 0.3, 10.4), trim)
	solid.box(Vector3(162, 1.5, -146.95), Vector3(4.6, 3.0, 0.1), Color(0.8, 0.8, 0.82))
	sign_label("RIFUGIO", Vector3(150, 3.0, -144.85), 0.0, 64, Color(1.0, 0.85, 0.4))
	_tree(Vector3(137, 0, -164))
	_tree(Vector3(137, 0, -136))
	_tree(Vector3(166, 0, -135))
	# siepe bassa decorativa
	for hx: int in [-1, 1]:
		solid.box(Vector3(150 + hx * 11.5, 0.45, -131.2), Vector3(17, 0.9, 0.8), Color(0.22, 0.45, 0.2))


func _parking(c: Vector3) -> void:
	for row: int in [-1, 1]:
		for i in 7:
			var x := c.x - 18.0 + i * 6.0
			ground.top_quad(Vector3(x, 0.075, c.z + row * 10.0), 0.18, 7.0, C_LINE)
	ground.top_quad(Vector3(c.x, 0.075, c.z), 40.0, 0.25, C_YELLOW)
	for sx: int in [-1, 1]:
		_tree(c + Vector3(sx * 17.5, 0, 0), 0.8)


func _shops(c: Vector3) -> void:
	for lx: int in [-1, 1]:
		for lz: int in [-1, 1]:
			var lc := c + Vector3(lx * 10.5, 0, lz * 10.5)
			var w := rng.randf_range(13.0, 16.0)
			var d := rng.randf_range(11.0, 14.0)
			var h := rng.randf_range(5.0, 9.0)
			var wall: Color = pick(HOUSE_COLORS)
			sbox(Vector3(lc.x, h * 0.5, lc.z), Vector3(w, h, d), wall.darkened(0.08))
			var face := lc.z + lz * (d * 0.5 + 0.05)
			var acc: Color = pick(SHOP_COLORS)
			solid.box(Vector3(lc.x, 1.5, face), Vector3(w * 0.8, 2.2, 0.08), Color(0.35, 0.55, 0.65))
			solid.box(Vector3(lc.x, 3.1, lc.z + lz * (d * 0.5 + 0.8)), Vector3(w * 0.86, 0.22, 1.6), acc)
			solid.box(Vector3(lc.x, h + 0.7, lc.z), Vector3(w * 0.5, 1.4, 0.4), acc.lightened(0.2))
			solid.box(Vector3(lc.x, h + 0.2, lc.z), Vector3(w + 0.3, 0.4, d + 0.3), wall.darkened(0.25))


func armory_sign() -> void:
	var p := CityData.ARMORY_POS
	sign_label("ARMERIA", Vector3(p.x, 4.2, p.z + 3.4), PI, 90, Color(1.0, 0.55, 0.2))


func _industrial(c: Vector3) -> void:
	var w := rng.randf_range(24.0, 34.0)
	var d := rng.randf_range(13.0, 17.0)
	var h := rng.randf_range(8.0, 12.0)
	var wc := c + Vector3(rng.randf_range(-2.0, 2.0), 0, 19.0 - d * 0.5)
	if not CityData.is_reserved(wc, d * 0.5):
		var wall: Color = pick([Color(0.58, 0.6, 0.62), Color(0.64, 0.56, 0.46), Color(0.5, 0.54, 0.56), Color(0.6, 0.5, 0.42)])
		sbox(Vector3(wc.x, h * 0.5, wc.z), Vector3(w, h, d), wall)
		solid.box(Vector3(wc.x, h + 0.25, wc.z), Vector3(w + 0.5, 0.5, d + 0.5), wall.darkened(0.3))
		solid.box(Vector3(wc.x, h * 0.75, wc.z), Vector3(w + 0.1, 0.6, d + 0.1), Color(0.85, 0.65, 0.15))
		solid.box(Vector3(wc.x, 2.5, wc.z - d * 0.5 - 0.05), Vector3(6.0, 5.0, 0.1), Color(0.3, 0.32, 0.34))
	for i in rng.randi_range(2, 5):
		var p := c + Vector3(rng.randf_range(-15.0, 15.0), 0, rng.randf_range(-16.0, -2.0))
		if CityData.is_reserved(p, 4.0):
			continue
		var rot := 0.0 if rng.randf() < 0.5 else PI * 0.5
		var cc: Color = pick(CONTAINER_COLORS)
		sbox(Vector3(p.x, 1.3, p.z), Vector3(2.5, 2.6, 6.0), cc, rot)
		if rng.randf() < 0.4:
			solid.box(Vector3(p.x, 3.9, p.z), Vector3(2.5, 2.6, 6.0), pick(CONTAINER_COLORS), rot)
	if rng.randf() < 0.6:
		var tp := c + Vector3(rng.randf_range(-14.0, 14.0), 0, -14.0)
		if not CityData.is_reserved(tp, 3.0):
			solid.cylinder(Vector3(tp.x, 3.5, tp.z), 2.4, 2.4, 7.0, 10, Color(0.75, 0.76, 0.78))
			solid.cylinder(Vector3(tp.x, 7.3, tp.z), 2.4, 0.6, 0.6, 10, Color(0.65, 0.66, 0.68))
			col(Vector3(tp.x, 3.5, tp.z), Vector3(4.2, 7.0, 4.2))
	if rng.randf() < 0.5:
		var ch := wc + Vector3(w * 0.35, 0, 0)
		solid.cylinder(Vector3(ch.x, h + 7.0, ch.z), 1.1, 0.8, 14.0, 8, Color(0.6, 0.35, 0.3))


func _garage(_c: Vector3) -> void:
	var x0 := -108.0
	var x1 := -78.0
	var z0 := -104.0
	var z1 := -76.0
	var h := 7.0
	var wall := Color(0.66, 0.63, 0.57)
	var orange := Color(0.95, 0.55, 0.15)
	sbox(Vector3((x0 + x1) * 0.5, h * 0.5, z0 + 0.4), Vector3(x1 - x0, h, 0.8), wall)
	sbox(Vector3((x0 + x1) * 0.5, h * 0.5, z1 - 0.4), Vector3(x1 - x0, h, 0.8), wall)
	sbox(Vector3(x0 + 0.4, h * 0.5, (z0 + z1) * 0.5), Vector3(0.8, h, z1 - z0), wall)
	sbox(Vector3(x1 - 0.4, h * 0.5, -101.0), Vector3(0.8, h, 6.0), wall)
	sbox(Vector3(x1 - 0.4, h * 0.5, -79.0), Vector3(0.8, h, 6.0), wall)
	sbox(Vector3(x1 - 0.4, h - 1.0, -90.0), Vector3(0.9, 2.0, 16.0), orange)
	sbox(Vector3((x0 + x1) * 0.5, h + 0.25, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.6, 0.5, z1 - z0 + 0.6), Color(0.4, 0.4, 0.42))
	ground.top_quad(Vector3(-92, 0.075, -90), 9.0, 0.3, orange)
	ground.top_quad(Vector3(-92, 0.075, -95.5), 9.0, 0.3, orange)
	ground.top_quad(Vector3(-92, 0.075, -84.5), 9.0, 0.3, orange)
	sbox(Vector3(-106, 0.6, -84), Vector3(2.5, 1.2, 6.0), Color(0.45, 0.3, 0.2))
	sbox(Vector3(-106.5, 1.8, -97), Vector3(1.2, 3.6, 7.0), Color(0.3, 0.35, 0.45))
	for i in 3:
		solid.cylinder(Vector3(-104.0, 0.25 + i * 0.4, -101.5), 0.6, 0.6, 0.38, 8, Color(0.1, 0.1, 0.1))
	col(Vector3(-104.0, 0.6, -101.5), Vector3(1.2, 1.2, 1.2))
	sign_label("GARAGE DA GUS", Vector3(x1 + 0.1, h - 1.0, -90.0), PI * 0.5, 90, Color(1.0, 0.95, 0.85))


func _police_station(c: Vector3) -> void:
	var wall := Color(0.9, 0.92, 0.95)
	var blue := Color(0.12, 0.22, 0.5)
	sbox(Vector3(c.x, 4.5, c.z - 9), Vector3(30, 9, 18), wall)
	solid.box(Vector3(c.x, 9.25, c.z - 9), Vector3(30.6, 0.5, 18.6), blue)
	solid.box(Vector3(c.x, 3.2, c.z - 9), Vector3(30.1, 0.6, 18.1), blue)
	for gy: float in [1.6, 5.8]:
		solid.box(Vector3(c.x, gy, c.z - 9), Vector3(30.12, 1.4, 18.12), Color(0.35, 0.5, 0.65))
	solid.box(Vector3(c.x, 1.3, c.z - 0.0 + 0.04), Vector3(3.2, 2.6, 0.12), Color(0.2, 0.25, 0.35))
	sbox(Vector3(c.x - 2.2, 1.4, c.z + 1.2), Vector3(0.4, 2.8, 0.4), blue)
	sbox(Vector3(c.x + 2.2, 1.4, c.z + 1.2), Vector3(0.4, 2.8, 0.4), blue)
	solid.box(Vector3(c.x, 2.9, c.z + 1.0), Vector3(5.0, 0.3, 2.6), blue)
	sign_label("POLIZIA - QUESTURA", Vector3(c.x, 7.6, c.z + 0.08), 0.0, 80, Color(0.85, 0.92, 1.0))
	ground.box(Vector3(c.x, 0.075, c.z + 10.5), Vector3(38, 0.03, 15), C_ASPHALT)
	for i in 6:
		ground.top_quad(Vector3(c.x - 15 + i * 6.0, 0.095, c.z + 10.5), 0.18, 6.0, C_LINE)
	for sx: float in [-17.0, 17.0]:
		_tree(Vector3(c.x + sx, 0, c.z - 15.0), 0.9)


func _yard(_c: Vector3) -> void:
	var x0 := -110.0
	var x1 := -70.0
	var z0 := 130.0
	var z1 := 170.0
	var wh := 3.2
	var wall := Color(0.5, 0.47, 0.46)
	sbox(Vector3((x0 - 96.0) * 0.5, wh * 0.5, z0 + 0.3), Vector3(-96.0 - x0, wh, 0.6), wall)
	sbox(Vector3((-84.0 + x1) * 0.5, wh * 0.5, z0 + 0.3), Vector3(x1 + 84.0, wh, 0.6), wall)
	sbox(Vector3(x0 + 0.3, wh * 0.5, (z0 + z1) * 0.5), Vector3(0.6, wh, z1 - z0), wall)
	sbox(Vector3(x1 - 0.3, wh * 0.5, (z0 + z1) * 0.5), Vector3(0.6, wh, z1 - z0), wall)
	sbox(Vector3(-96.5, 2.2, z0 + 0.3), Vector3(1.0, 4.4, 1.0), Color(0.45, 0.15, 0.5))
	sbox(Vector3(-83.5, 2.2, z0 + 0.3), Vector3(1.0, 4.4, 1.0), Color(0.45, 0.15, 0.5))
	var wcol := Color(0.4, 0.34, 0.42)
	sbox(Vector3(-90, 4.5, 164), Vector3(36, 9, 11), wcol)
	solid.box(Vector3(-90, 9.25, 164), Vector3(36.5, 0.5, 11.5), wcol.darkened(0.3))
	solid.box(Vector3(-90, 6.8, 164), Vector3(36.1, 0.7, 11.1), Color(0.55, 0.15, 0.6))
	solid.box(Vector3(-90, 2.6, 158.44), Vector3(7.0, 5.2, 0.1), Color(0.2, 0.2, 0.22))
	sign_label("VIPERE", Vector3(-90, 7.9, 158.3), PI, 120, Color(0.8, 0.4, 1.0))
	for p: Vector3 in [Vector3(-104, 0, 136), Vector3(-76, 0, 137), Vector3(-101, 0, 151), Vector3(-78, 0, 150)]:
		sbox(Vector3(p.x, 0.75, p.z), Vector3(1.5, 1.5, 1.5), Color(0.55, 0.4, 0.22))
		solid.box(Vector3(p.x + 1.6, 0.6, p.z), Vector3(1.2, 1.2, 1.2), Color(0.6, 0.45, 0.25))


# ---------------------------------------------------------------- porto

func _docks() -> void:
	ground.box(Vector3(-2.5, 0.03, 196.6), Vector3(405, 0.06, 19.2), Color(0.6, 0.58, 0.54))
	solid.box(Vector3(-2.5, -0.3, 206.3), Vector3(405, 0.8, 0.4), Color(0.45, 0.43, 0.4))
	ground.top_quad(Vector3(-2.5, 0.065, 205.2), 405.0, 0.4, C_YELLOW)
	var x := -190.0
	while x < 200.0:
		sbox(Vector3(x, 0.4, 205.3), Vector3(0.5, 0.8, 0.5), Color(0.2, 0.2, 0.22))
		x += 18.0
	for cx: float in [-120.0, 0.0, 120.0]:
		_crane(Vector3(cx, 0, 196))
	for cx: float in [-170.0, -150.0, -60.0, 62.0, 80.0, 160.0, 180.0]:
		sbox(Vector3(cx, 1.3, 200.0), Vector3(6.0, 2.6, 2.5), pick(CONTAINER_COLORS))
		if rng.randf() < 0.6:
			solid.box(Vector3(cx, 3.9, 200.0), Vector3(6.0, 2.6, 2.5), pick(CONTAINER_COLORS))
	# nave cargo all'ancora (decorazione)
	var ship := Vector3(40, 0, 250)
	solid.box(ship + Vector3(0, 1.5, 0), Vector3(70, 7, 15), Color(0.6, 0.15, 0.12))
	solid.box(ship + Vector3(0, 5.2, 0), Vector3(70.2, 0.6, 15.2), Color(0.85, 0.85, 0.85))
	solid.box(ship + Vector3(28, 9.5, 0), Vector3(10, 8, 12), Color(0.92, 0.92, 0.9))
	for i in 5:
		solid.box(ship + Vector3(-25 + i * 10, 7.2, 0), Vector3(8, 3.5, 12), pick(CONTAINER_COLORS))


func _crane(p: Vector3) -> void:
	var yel := Color(0.95, 0.72, 0.15)
	for lx: float in [-6.0, 6.0]:
		for lz: float in [-7.0, 7.0]:
			sbox(Vector3(p.x + lx, 11, p.z + lz), Vector3(1.2, 22, 1.2), yel)
	solid.box(Vector3(p.x, 22.6, p.z), Vector3(14, 1.6, 16), yel)
	solid.box(Vector3(p.x, 23.6, p.z + 20), Vector3(3, 1.2, 42), yel)
	solid.box(Vector3(p.x, 25.4, p.z - 2), Vector3(5, 3, 5), Color(0.85, 0.85, 0.82))
	solid.box(Vector3(p.x, 18.0, p.z + 30), Vector3(0.2, 10, 0.2), Color(0.2, 0.2, 0.2))


# ---------------------------------------------------------------- aeroporto

func _airport() -> void:
	ground.box(Vector3(313.5, 0.025, 0), Vector3(63, 0.05, 320), Color(0.56, 0.56, 0.55))
	ground.box(Vector3(361.5, 0.035, 0), Vector3(33, 0.07, 360), C_ASPHALT)
	var z := -170.0
	while z < 170.0:
		ground.top_quad(Vector3(361.5, 0.075, z), 0.5, 8.0, C_LINE)
		z += 16.0
	for side: float in [-1.0, 1.0]:
		for k in 8:
			ground.top_quad(Vector3(349.0 + k * 3.5, 0.075, side * 174.0), 1.6, 8.0, C_LINE)
		ground.top_quad(Vector3(345.6, 0.075, 0), 0.4, 356.0, C_LINE)
		ground.top_quad(Vector3(377.4, 0.075, 0), 0.4, 356.0, C_LINE)
	for k in 12:
		ground.top_quad(Vector3(300.0, 0.06, -150.0 + k * 26.0), 0.3, 12.0, C_YELLOW)
	# parcheggio dell'aeroporto
	ground.box(Vector3(216, 0.025, -80), Vector3(32, 0.05, 40), C_ASPHALT)
	for i in 6:
		ground.top_quad(Vector3(202.0 + i * 6.0, 0.055, -88), 0.18, 7.0, C_LINE)
		ground.top_quad(Vector3(202.0 + i * 6.0, 0.055, -72), 0.18, 7.0, C_LINE)
	_terminal()
	# torre di controllo
	solid.cylinder(Vector3(262, 13, -110), 3.0, 2.4, 26.0, 8, Color(0.88, 0.88, 0.86))
	col(Vector3(262, 13, -110), Vector3(5.0, 26.0, 5.0))
	solid.box(Vector3(262, 27.6, -110), Vector3(8, 3.2, 8), Color(0.25, 0.4, 0.5))
	solid.box(Vector3(262, 29.5, -110), Vector3(9, 0.6, 9), Color(0.95, 0.95, 0.95))
	solid.cylinder(Vector3(262, 31.0, -110), 0.1, 0.05, 2.5, 4, Color(0.9, 0.2, 0.2))
	_hangar(Vector3(272.5, 0, 72.5), "HANGAR 1")
	_hangar(Vector3(272.5, 0, 122.5), "HANGAR 2")
	# manica a vento e luci pista
	solid.cylinder(Vector3(385, 3, -60), 0.1, 0.1, 6.0, 4, Color(0.8, 0.8, 0.8))
	solid.cylinder_axis(Vector3(385, 5.6, -58.5), Vector3(0, 0, 1), 0.45, 0.2, 3.0, 6, Color(1.0, 0.45, 0.1))
	z = -175.0
	while z <= 175.0:
		for lx: float in [343.5, 379.5]:
			solid.box(Vector3(lx, 0.2, z), Vector3(0.3, 0.4, 0.3), Color(1.0, 0.9, 0.4))
		z += 25.0


func _terminal() -> void:
	ground.box(Vector3(265, 0.03, -40), Vector3(34, 0.06, 66), Color(0.72, 0.7, 0.66))
	var wall := Color(0.88, 0.89, 0.9)
	var glass := Color(0.35, 0.55, 0.72)
	for part: Array in [[-57.0, 26.0], [-23.0, 26.0]]:
		var zc: float = part[0]
		var dz: float = part[1]
		sbox(Vector3(265, 6, zc), Vector3(30, 12, dz), wall)
		for gy: float in [3.0, 7.5]:
			solid.box(Vector3(265, gy, zc), Vector3(30.15, 2.4, dz + 0.15), glass)
		solid.box(Vector3(265, 12.3, zc), Vector3(31, 0.6, dz + 1.0), Color(0.7, 0.72, 0.75))
	solid.box(Vector3(265, 11.0, -40), Vector3(30, 2.0, 8.4), wall)
	ground.top_quad(Vector3(265, 0.065, -40), 30.0, 8.0, Color(0.55, 0.5, 0.45))
	sign_label("PORT ARDENA AIRPORT", Vector3(249.8, 9.6, -57.0), -PI * 0.5, 110, Color(1, 1, 1))
	sign_label("ARRIVI", Vector3(249.8, 10.4, -40.0), -PI * 0.5, 80, Color(1.0, 0.85, 0.3))
	sign_label("USCITA  >", Vector3(280.2, 10.4, -40.0), PI * 0.5, 80, Color(1.0, 0.85, 0.3))


func _hangar(c: Vector3, title: String) -> void:
	var w := 35.0
	var d := 35.0
	var h := 12.0
	var wall := Color(0.62, 0.65, 0.68)
	var x0 := c.x - w * 0.5
	var x1 := c.x + w * 0.5
	var z0 := c.z - d * 0.5
	var z1 := c.z + d * 0.5
	ground.box(Vector3(c.x, 0.04, c.z), Vector3(w, 0.08, d), Color(0.6, 0.6, 0.6))
	sbox(Vector3(c.x, h * 0.5, z0 + 0.4), Vector3(w, h, 0.8), wall)
	sbox(Vector3(c.x, h * 0.5, z1 - 0.4), Vector3(w, h, 0.8), wall)
	sbox(Vector3(x0 + 0.4, h * 0.5, c.z), Vector3(0.8, h, d), wall)
	sbox(Vector3(c.x, h + 0.4, c.z), Vector3(w + 0.6, 0.8, d + 0.6), wall.darkened(0.25))
	solid.gable(Vector3(c.x, h + 0.8, c.z), Vector3(w + 0.6, 2.5, d + 0.6), wall.darkened(0.15), PI * 0.5)
	solid.box(Vector3(x1 - 0.3, h - 0.8, c.z), Vector3(0.6, 1.6, d), Color(0.9, 0.5, 0.15))
	sign_label(title, Vector3(x1 + 0.05, h - 0.8, c.z), PI * 0.5, 90, Color(1, 1, 1))


# ---------------------------------------------------------------- periferia e confini

func _outskirts() -> void:
	for i in 70:
		var p := Vector3.ZERO
		match i % 4:
			0:
				p = Vector3(rng.randf_range(-203.0, -191.0), 0, rng.randf_range(-200.0, 180.0))
			1:
				p = Vector3(rng.randf_range(-200.0, 188.0), 0, rng.randf_range(-203.0, -191.0))
			2:
				p = Vector3(rng.randf_range(192.0, 230.0), 0, rng.randf_range(-200.0, 180.0))
			_:
				p = Vector3(rng.randf_range(250.0, 400.0), 0, rng.randf_range(-203.0, -185.0))
		if absf(p.z) < 11.0 and p.x > 185.0:
			continue
		if p.x > 196.0 and p.x < 236.0 and p.z > -104.0 and p.z < -56.0:
			continue
		var near_spot := false
		for s in CityData.BOOST_SPOTS + CityData.FEATHER_SPOTS:
			if Vector2(p.x - s.x, p.z - s.z).length() < 3.0:
				near_spot = true
		if near_spot:
			continue
		_tree(p, rng.randf_range(0.9, 1.4))
	var fence := Color(0.45, 0.42, 0.38)
	solid.box(Vector3(-205.5, 0.6, 0), Vector3(0.3, 1.2, 412), fence)
	solid.box(Vector3(100, 0.6, -205.5), Vector3(612, 1.2, 0.3), fence)
	solid.box(Vector3(405.5, 0.6, 0), Vector3(0.3, 1.2, 412), fence)


func _bounds() -> void:
	col(Vector3(-206.5, 10, 0), Vector3(2, 20, 470))
	col(Vector3(406.5, 10, 0), Vector3(2, 20, 470))
	col(Vector3(100, 10, -206.5), Vector3(630, 20, 2))
	col(Vector3(100, 10, 207.8), Vector3(630, 20, 2))
