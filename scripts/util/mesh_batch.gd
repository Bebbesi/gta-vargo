class_name MeshBatch
extends RefCounted
## Accumula primitive low-poly (box, prismi, cilindri) con colori per vertice
## in un unico ArrayMesh: poche draw call, ideale per smartphone.
## Godot usa l'ordine orario dei vertici per le facce frontali.

# Per ogni faccia: normale n e assi u, v con u x v = n.
const FACES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
]

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()


func is_empty() -> bool:
	return verts.is_empty()


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	var base := verts.size()
	verts.append(a)
	verts.append(b)
	verts.append(c)
	verts.append(d)
	for i in 4:
		norms.append(n)
		cols.append(col)
	idx.append(base)
	idx.append(base + 1)
	idx.append(base + 2)
	idx.append(base)
	idx.append(base + 2)
	idx.append(base + 3)


func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var base := verts.size()
	verts.append(a)
	verts.append(b)
	verts.append(c)
	for i in 3:
		norms.append(n)
		cols.append(col)
	idx.append(base)
	idx.append(base + 1)
	idx.append(base + 2)


static func _axis_extent(axis: Vector3, h: Vector3) -> float:
	return absf(axis.x) * h.x + absf(axis.y) * h.y + absf(axis.z) * h.z


## Box centrato in `center`, ruotato attorno a Y di `rot_y`.
func box(center: Vector3, size: Vector3, col: Color, rot_y: float = 0.0, bottom: bool = false) -> void:
	var h := size * 0.5
	var bas := Basis(Vector3.UP, rot_y)
	for f in FACES:
		var n: Vector3 = f[0]
		if n.y < -0.5 and not bottom:
			continue
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var cn := n * _axis_extent(n, h)
		var eu := u * _axis_extent(u, h)
		var ev := v * _axis_extent(v, h)
		quad(center + bas * (cn - eu + ev), center + bas * (cn + eu + ev),
			center + bas * (cn + eu - ev), center + bas * (cn - eu - ev), bas * n, col)


## Solo la faccia superiore (segnaletica orizzontale, strisce, ecc.).
func top_quad(center: Vector3, size_x: float, size_z: float, col: Color, rot_y: float = 0.0) -> void:
	var bas := Basis(Vector3.UP, rot_y)
	var u := Vector3(0, 0, size_z * 0.5)
	var v := Vector3(size_x * 0.5, 0, 0)
	quad(center + bas * (-u + v), center + bas * (u + v), center + bas * (u - v), center + bas * (-u - v), Vector3.UP, col)


## Tetto a capanna con colmo lungo l'asse X locale.
func gable(center: Vector3, size: Vector3, col: Color, rot_y: float = 0.0) -> void:
	var bas := Basis(Vector3.UP, rot_y)
	var x0 := -size.x * 0.5
	var x1 := size.x * 0.5
	var zf := size.z * 0.5
	var y0 := 0.0
	var yt := size.y
	var ns := (Vector3(0, size.z * 0.5, size.y)).normalized()
	var nn := (Vector3(0, size.z * 0.5, -size.y)).normalized()
	# falda sud (+Z)
	quad(center + bas * Vector3(x0, yt, 0), center + bas * Vector3(x1, yt, 0),
		center + bas * Vector3(x1, y0, zf), center + bas * Vector3(x0, y0, zf), bas * ns, col)
	# falda nord (-Z)
	quad(center + bas * Vector3(x1, yt, 0), center + bas * Vector3(x0, yt, 0),
		center + bas * Vector3(x0, y0, -zf), center + bas * Vector3(x1, y0, -zf), bas * nn, col)
	var gc := col.lightened(0.15)
	tri(center + bas * Vector3(x1, yt, 0), center + bas * Vector3(x1, y0, -zf),
		center + bas * Vector3(x1, y0, zf), bas * Vector3.RIGHT, gc)
	tri(center + bas * Vector3(x0, yt, 0), center + bas * Vector3(x0, y0, zf),
		center + bas * Vector3(x0, y0, -zf), bas * Vector3.LEFT, gc)


## Cilindro / cono lungo Y (prisma a `sides` lati, ombreggiatura piatta).
func cylinder(center: Vector3, r_bottom: float, r_top: float, height: float, sides: int, col: Color, caps: bool = true) -> void:
	var y0 := center.y - height * 0.5
	var y1 := center.y + height * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var mid := (d0 + d1).normalized()
		var n := (mid * height + Vector3.UP * (r_bottom - r_top)).normalized()
		var b0 := Vector3(center.x, y0, center.z) + d0 * r_bottom
		var b1 := Vector3(center.x, y0, center.z) + d1 * r_bottom
		var t0 := Vector3(center.x, y1, center.z) + d0 * r_top
		var t1 := Vector3(center.x, y1, center.z) + d1 * r_top
		quad(t1, t0, b0, b1, n, col)
		if caps and r_top > 0.001:
			tri(Vector3(center.x, y1, center.z), t0, t1, Vector3.UP, col)
		if caps and r_bottom > 0.001 and y0 > 0.01:
			tri(Vector3(center.x, y0, center.z), b1, b0, Vector3.DOWN, col)


## Cilindro orientato lungo un asse arbitrario (ruote, fusoliera...).
func cylinder_axis(center: Vector3, axis: Vector3, radius_a: float, radius_b: float, length: float, sides: int, col: Color) -> void:
	var ax := axis.normalized()
	var ref := Vector3.UP if absf(ax.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var p := ax.cross(ref).normalized()
	var q := ax.cross(p).normalized()
	var ca := center - ax * length * 0.5
	var cb := center + ax * length * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := p * cos(a0) + q * sin(a0)
		var d1 := p * cos(a1) + q * sin(a1)
		var n := (d0 + d1).normalized()
		_tri_auto(ca + d0 * radius_a, cb + d0 * radius_b, cb + d1 * radius_b, n, col)
		_tri_auto(ca + d0 * radius_a, cb + d1 * radius_b, ca + d1 * radius_a, n, col)
		if radius_b > 0.001:
			_tri_auto(cb, cb + d0 * radius_b, cb + d1 * radius_b, ax, col)
		if radius_a > 0.001:
			_tri_auto(ca, ca + d1 * radius_a, ca + d0 * radius_a, -ax, col)


## Triangolo con ordine dei vertici corretto automaticamente rispetto a `n`.
func _tri_auto(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	# In Godot la faccia frontale è oraria vista dall'esterno: (b-a)x(c-a) punta verso l'interno.
	if (b - a).cross(c - a).dot(n) > 0.0:
		tri(a, c, b, n, col)
	else:
		tri(a, b, c, n, col)


func commit() -> ArrayMesh:
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
