class_name Minimap
extends Control
## Minimappa disegnata in 2D (nessuna seconda telecamera: leggera su mobile).
## In modalità `full` mostra l'intera città con legenda.

var world: Node
var full := false
var zoom := 0.62
var _font: Font
var _blocks: Array = []

const C_BG := Color(0.24, 0.36, 0.24)
const C_ROAD := Color(0.62, 0.62, 0.64)
const C_WATER := Color(0.17, 0.38, 0.6)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	for zi in 6:
		for xi in 6:
			var t := CityData.block_type(xi, zi)
			var c := Color(0.55, 0.55, 0.52)
			match t:
				"downtown", "plaza", "shops":
					c = Color(0.62, 0.6, 0.56)
				"park":
					c = Color(0.3, 0.55, 0.28)
				"residential", "safehouse":
					c = Color(0.42, 0.55, 0.36)
				"industrial", "lot", "yard":
					c = Color(0.5, 0.48, 0.45)
				"parking":
					c = Color(0.4, 0.4, 0.42)
			_blocks.append([Vector3(CityData.CENTERS[xi], 0, CityData.CENTERS[zi]), c])


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _scale() -> float:
	if full:
		return minf(size.x / 640.0, size.y / 440.0)
	return zoom


func _center() -> Vector3:
	if full or world == null or world.player == null:
		return Vector3(100, 0, 0)
	return world.player_pos()


func to_map(w: Vector3) -> Vector2:
	var c := _center()
	return size * 0.5 + Vector2(w.x - c.x, w.z - c.z) * _scale()


func _rect_w(x0: float, z0: float, x1: float, z1: float, col: Color) -> void:
	var a := to_map(Vector3(x0, 0, z0))
	var b := to_map(Vector3(x1, 0, z1))
	draw_rect(Rect2(a, b - a), col)


func _draw() -> void:
	if world == null:
		return
	var s := _scale()
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	_rect_w(-700, 206, 900, 900, C_WATER)
	_rect_w(-205, 187, 200, 206, Color(0.58, 0.56, 0.52))
	for b in _blocks:
		var c: Vector3 = b[0]
		_rect_w(c.x - 23, c.z - 23, c.x + 23, c.z + 23, b[1])
	_rect_w(282, -160, 345, 160, Color(0.6, 0.6, 0.58))
	_rect_w(345, -180, 378, 180, Color(0.25, 0.25, 0.27))
	_rect_w(250, -70, 280, -10, Color(0.85, 0.86, 0.9))
	_rect_w(255, 55, 290, 140, Color(0.7, 0.72, 0.75))
	for e in CityData.edges():
		draw_line(to_map(e[0]), to_map(e[1]), C_ROAD, maxf(CityData.ROAD_W * s, 2.0))
	if not full:
		for p in get_tree().get_nodes_in_group("pickups"):
			var pk := p as Pickup
			if pk.kind == "boost" and pk.active and pk.global_position.distance_to(_center()) < 140.0:
				draw_circle(to_map(pk.global_position), 3.5, Color(0.55, 0.32, 0.12))
	for bl in world.get_blips():
		_draw_blip(bl)
	_draw_player()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.9), false, 3.0)
	if full:
		_legend()


func _draw_blip(bl: Dictionary) -> void:
	var p := to_map(bl["pos"])
	var col: Color = bl["color"]
	var kind: String = bl.get("kind", "dot")
	var inside := Rect2(Vector2(10, 10), size - Vector2(20, 20)).has_point(p)
	if not inside:
		if kind == "objective" or kind == "mission" or kind == "enemy_far":
			p = Vector2(clampf(p.x, 10, size.x - 10), clampf(p.y, 10, size.y - 10))
		else:
			return
	match kind:
		"objective":
			draw_circle(p, 8.0, Color(0, 0, 0, 0.8))
			draw_circle(p, 6.0, col)
		"enemy", "enemy_far":
			draw_circle(p, 5.0, Color(0, 0, 0, 0.8))
			draw_circle(p, 4.0, col)
		"dot":
			draw_circle(p, 4.0, col)
		_:
			draw_circle(p, 10.0, Color(0, 0, 0, 0.85))
			draw_circle(p, 8.5, col)
			var label: String = bl.get("label", "")
			if label != "" and _font != null:
				var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
				draw_string(_font, p + Vector2(-tw * 0.5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.05, 0.05, 0.05))


func _draw_player() -> void:
	var p := to_map(world.player_pos())
	var y: float = world.player.vehicle.rotation.y if world.player.in_vehicle() else world.player.yaw
	var f := Vector2(-sin(y), -cos(y))
	var r := Vector2(-f.y, f.x)
	var pts := PackedVector2Array([p + f * 11.0, p - f * 7.0 + r * 7.0, p - f * 3.0, p - f * 7.0 - r * 7.0])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.9))
	var pts2 := PackedVector2Array([p + f * 9.0, p - f * 5.5 + r * 5.5, p - f * 2.0, p - f * 5.5 - r * 5.5])
	draw_colored_polygon(pts2, world.player.data["color"].lightened(0.3))


func _legend() -> void:
	var items := [
		["R", Color(0.3, 0.95, 0.5), "Rifugio (salvataggio)"], ["G", Color(1.0, 0.6, 0.2), "Garage"],
		["A", Color(0.7, 0.8, 1.0), "Aeroporto"], ["S", Color(1.0, 0.85, 0.3), "Missione storia"],
		["M", Color(0.92, 0.3, 0.22), "Missione di Mike"], ["T", Color(0.3, 0.6, 0.95), "Missione di Tom"],
		["N", Color(0.45, 0.8, 0.35), "Missione di Norman"], ["", Color(1.0, 0.85, 0.2), "Obiettivo"],
	]
	var y := 20.0
	draw_rect(Rect2(Vector2(12, 10), Vector2(250, items.size() * 26 + 14)), Color(0, 0, 0, 0.6))
	for it in items:
		var pos := Vector2(30, y + 10)
		draw_circle(pos, 9.0, it[1])
		if it[0] != "":
			draw_string(_font, pos + Vector2(-4, 5), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.05, 0.05, 0.05))
		draw_string(_font, pos + Vector2(18, 6), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		y += 26.0
