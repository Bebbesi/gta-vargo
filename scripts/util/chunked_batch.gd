class_name ChunkedBatch
extends RefCounted
## Stessa interfaccia di MeshBatch, ma divide la geometria in blocchi da
## CHUNK metri: ogni blocco è una mesh separata e il motore scarta quelle
## fuori dall'inquadratura (frustum culling), utile sugli smartphone.

const CHUNK := 120.0

var chunks: Dictionary = {}


func _at(center: Vector3) -> MeshBatch:
	var key := Vector2i(floori(center.x / CHUNK), floori(center.z / CHUNK))
	if not chunks.has(key):
		chunks[key] = MeshBatch.new()
	return chunks[key]


func box(center: Vector3, size: Vector3, col: Color, rot_y: float = 0.0, bottom: bool = false) -> void:
	_at(center).box(center, size, col, rot_y, bottom)


func top_quad(center: Vector3, size_x: float, size_z: float, col: Color, rot_y: float = 0.0) -> void:
	_at(center).top_quad(center, size_x, size_z, col, rot_y)


func gable(center: Vector3, size: Vector3, col: Color, rot_y: float = 0.0) -> void:
	_at(center).gable(center, size, col, rot_y)


func cylinder(center: Vector3, r_bottom: float, r_top: float, height: float, sides: int, col: Color, caps: bool = true) -> void:
	_at(center).cylinder(center, r_bottom, r_top, height, sides, col, caps)


func cylinder_axis(center: Vector3, axis: Vector3, radius_a: float, radius_b: float, length: float, sides: int, col: Color) -> void:
	_at(center).cylinder_axis(center, axis, radius_a, radius_b, length, sides, col)


func vertex_count() -> int:
	var n := 0
	for k in chunks:
		n += (chunks[k] as MeshBatch).verts.size()
	return n


## Crea un MeshInstance3D per blocco sotto `parent`; restituisce il numero di mesh.
func commit_to(parent: Node3D, shadows: bool) -> int:
	var count := 0
	for k in chunks:
		var b: MeshBatch = chunks[k]
		if b.is_empty():
			continue
		var mi := Gfx.add_batch(parent, b, shadows)
		mi.name = "Chunk_%d_%d" % [k.x, k.y]
		count += 1
	return count
