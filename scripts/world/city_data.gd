class_name CityData
extends RefCounted
## Mappa di Port Ardena: griglia stradale, quartieri, luoghi chiave e grafo
## stradale usato da traffico, inseguitori e minimappa.

const GRID := [-180.0, -120.0, -60.0, 0.0, 60.0, 120.0, 180.0]
const CENTERS := [-150.0, -90.0, -30.0, 30.0, 90.0, 150.0]
const ROAD_W := 14.0
const HALF_ROAD := 7.0
const LANE := 3.2
const BLOCK_HALF := 23.0     # metà del lotto incluso il marciapiede
const INNER_HALF := 20.0     # metà dell'area edificabile
const WALK_HALF := 21.4      # percorso pedonale sul marciapiede

# Righe: z = -150 (nord) ... 150 (sud); colonne: x = -150 (ovest) ... 150 (est)
const LAYOUT := [
	["residential", "residential", "park", "residential", "parking", "safehouse"],
	["residential", "garage", "downtown", "downtown", "downtown", "residential"],
	["park", "downtown", "plaza", "downtown", "downtown", "police"],
	["residential", "downtown", "downtown", "downtown", "shops", "shops"],
	["industrial", "industrial", "lot", "industrial", "industrial", "industrial"],
	["industrial", "yard", "industrial", "industrial", "industrial", "industrial"],
]

const DISTRICT_NAMES := {
	"residential": "Colline Nord", "park": "Parco", "parking": "Parcheggio",
	"safehouse": "Rifugio", "garage": "Garage", "downtown": "Centro",
	"plaza": "Piazza del Corvo", "shops": "Mercato", "industrial": "Zona Industriale",
	"lot": "Zona Industriale", "yard": "Magazzino Vipere", "police": "Questura",
}

# --- Luoghi chiave
const AIRPORT_PLANE := Vector3(322, 0, -40)
const AIRPORT_SPAWN := Vector3(298, 0, -40)
const AIRPORT_EXIT := Vector3(244, 0, -40)
const TERMINAL_BOOST := Vector3(266, 0, -40)
const SAFEHOUSE_DOOR := Vector3(150, 0, -140)
const SAFEHOUSE_MARK := Vector3(144, 0, -136)
const SAVE_POINT := Vector3(156, 0, -139)
const PARKING_LOT := Vector3(90, 0, -150)
const GARAGE_DOOR := Vector3(-70, 0, -90)
const GARAGE_INSIDE := Vector3(-92, 0, -90)
const GARAGE_MARK := Vector3(-70, 0, -104)
const GARAGE_CAR := Vector3(-66, 0, -78)
const GUS_POS := Vector3(-100, 0, -82)
const DOCKS_PACKAGE := Vector3(40, 0, 197)
const PLAZA := Vector3(-30, 0, -30)
const LENNY_POS := Vector3(-30, 0, -19)
const YARD_CENTER := Vector3(-90, 0, 143)
const YARD_MARK := Vector3(-90, 0, 128)
const HANGAR := Vector3(298, 0, 122)
const JET := Vector3(322, 0, 122)
const RACE_START := Vector3(-56.5, 0, -112)
const POLICE_DOOR := Vector3(150, 0, -24)
const ARMORY_POS := Vector3(101, 0, 8.6)

# Armi raccoglibili in città: [arma, posizione]
const WEAPON_SPOTS := [
	["pistol", Vector3(-68.6, 0, -78)], ["pistol", Vector3(8.6, 0, 138)], ["pistol", Vector3(212, 0, -30)],
	["smg", Vector3(-18, 0, -8.6)], ["smg", Vector3(128.6, 0, 102)],
	["shotgun", Vector3(-128.6, 0, 138)], ["shotgun", Vector3(78, 0, -128.6)],
	["rifle", Vector3(361, 0, -188)],
]

const CLUES := [
	Vector3(266, 0, -88),
	Vector3(30, 0, 30),
	Vector3(-100, 0, 196),
	Vector3(150, 0, 133),
]

const BOOST_SPOTS := [
	Vector3(-128.6, 0, -30), Vector3(-30, 0, -128.6), Vector3(51.4, 0, -90),
	Vector3(-90, 0, -8.6), Vector3(90, 0, 8.6), Vector3(-51.4, 0, 30),
	Vector3(150, 0, -68.6), Vector3(128.6, 0, 30), Vector3(-150, 0, 68.6),
	Vector3(-8.6, 0, 90), Vector3(90, 0, 128.6), Vector3(-30, 0, 196),
	Vector3(228, 0, -20), Vector3(-171.4, 0, -150), Vector3(30, 0, -171.4),
	Vector3(171.4, 0, 150),
]

const FEATHER_SPOTS := [
	Vector3(-150, 0, -150), Vector3(-160, 0, -38), Vector3(395, 0, -195),
	Vector3(272, 0, 72), Vector3(-196, 0, 190), Vector3(160, 0, -160),
	Vector3(250, 0, -110), Vector3(108, 0, 196), Vector3(-30, 0, -158),
	Vector3(-195, 0, -195),
]

# Aree in cui il generatore non deve costruire.
const RESERVED := [
	[Vector3(30, 0, 30), 5.0], [Vector3(150, 0, 133), 5.0], [Vector3(-30, 0, -30), 9.0],
	[Vector3(-150, 0, -150), 4.0], [Vector3(-160, 0, -38), 3.0], [Vector3(160, 0, -160), 4.0],
	[Vector3(-30, 0, -158), 4.0],
]

static var nodes: Array = []
static var links: Array = []
static var _built := false


static func block_type(xi: int, zi: int) -> String:
	return LAYOUT[zi][xi]


static func district_at(p: Vector3) -> String:
	if p.x > 190.0:
		return "Aeroporto"
	if p.z > 186.0:
		return "Porto"
	if absf(p.x) > 186.0 or p.z < -186.0:
		return "Periferia"
	var xi := clampi(int(floor((p.x + 180.0) / 60.0)), 0, 5)
	var zi := clampi(int(floor((p.z + 180.0) / 60.0)), 0, 5)
	return DISTRICT_NAMES.get(block_type(xi, zi), "Port Ardena")


static func is_reserved(p: Vector3, radius: float) -> bool:
	for r in RESERVED:
		var c: Vector3 = r[0]
		if Vector2(p.x - c.x, p.z - c.z).length() < radius + float(r[1]):
			return true
	return false


# ---------------------------------------------------------------- grafo stradale

static func ensure_graph() -> void:
	if _built:
		return
	_built = true
	nodes.clear()
	links.clear()
	for zi in GRID.size():
		for xi in GRID.size():
			nodes.append(Vector3(GRID[xi], 0, GRID[zi]))
			links.append([])
	var n := GRID.size()
	for zi in n:
		for xi in n:
			var i := zi * n + xi
			if xi < n - 1:
				_link(i, i + 1)
			if zi < n - 1:
				_link(i, i + n)
	# Strade dell'aeroporto (a est della città)
	var east := 3 * n + (n - 1)
	var a0 := _add(Vector3(240, 0, 0))
	var a1 := _add(Vector3(240, 0, -100))
	var a2 := _add(Vector3(240, 0, 100))
	_link(east, a0)
	_link(a0, a1)
	_link(a0, a2)


static func _add(p: Vector3) -> int:
	nodes.append(p)
	links.append([])
	return nodes.size() - 1


static func _link(a: int, b: int) -> void:
	links[a].append(b)
	links[b].append(a)


static var _edges_cache: Array = []


static func edges() -> Array:
	ensure_graph()
	if not _edges_cache.is_empty():
		return _edges_cache
	var out := []
	for a in nodes.size():
		for b in links[a]:
			if b > a:
				out.append([nodes[a], nodes[b]])
	_edges_cache = out
	return out


static func nearest_node(p: Vector3) -> int:
	ensure_graph()
	var best := 0
	var best_d := INF
	for i in nodes.size():
		var d := Vector2(p.x - nodes[i].x, p.z - nodes[i].z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


## Percorso più breve (BFS, archi di lunghezza simile) tra due nodi.
static func path(from_i: int, to_i: int) -> Array:
	ensure_graph()
	if from_i == to_i:
		return [to_i]
	var prev := {}
	prev[from_i] = -1
	var queue := [from_i]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to_i:
			break
		for nb in links[cur]:
			if not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)
	if not prev.has(to_i):
		return []
	var out := []
	var c: int = to_i
	while c != -1:
		out.push_front(c)
		c = prev[c]
	return out


## Punto sulla strada più vicino a `p` (proiezione sugli archi del grafo).
static func nearest_road_point(p: Vector3) -> Dictionary:
	ensure_graph()
	var best := {}
	var best_d := INF
	for a in nodes.size():
		for b in links[a]:
			if b < a:
				continue
			var pa: Vector3 = nodes[a]
			var pb: Vector3 = nodes[b]
			var ab := pb - pa
			var t := clampf((p - pa).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var q := pa + ab * t
			var d := Vector2(p.x - q.x, p.z - q.z).length_squared()
			if d < best_d:
				best_d = d
				best = {"point": q, "a": a, "b": b, "dir": ab.normalized()}
	return best


static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)
