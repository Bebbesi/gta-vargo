class_name Props
extends RefCounted
## Fabbrica di elementi di scena: indicatori di missione, faro obiettivo,
## freccia di direzione, telecamere di sicurezza, PNG statici e aerei.


static func mission_marker(parent: Node, pos: Vector3, c: Color, letter: String) -> Node3D:
	var root := Node3D.new()
	root.name = "MissionMarker"
	parent.add_child(root)
	root.global_position = pos
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.4
	cm.height = 2.4
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	cyl.mesh = cm
	cyl.material_override = Gfx.mat(Color(c.r, c.g, c.b, 0.35), 1.0, true)
	cyl.position.y = 1.2
	cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cyl)
	var lab := Gfx.label3d(root, letter, Vector3(0, 3.4, 0), 140, c)
	lab.name = "Letter"
	lab.no_depth_test = true
	var anim := root.create_tween().set_loops()
	anim.tween_property(lab, "position:y", 3.8, 0.8).set_trans(Tween.TRANS_SINE)
	anim.tween_property(lab, "position:y", 3.4, 0.8).set_trans(Tween.TRANS_SINE)
	return root


static func save_marker(parent: Node, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.1
	cm.height = 0.08
	cm.radial_segments = 16
	disc.mesh = cm
	disc.material_override = Gfx.mat(Color(0.3, 1.0, 0.5, 0.6), 1.0, true)
	disc.position.y = 0.1
	root.add_child(disc)
	Gfx.label3d(root, "SALVA", Vector3(0, 1.6, 0), 60, Color(0.4, 1.0, 0.6))
	return root


static func beacon(parent: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "Beacon"
	parent.add_child(root)
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	cyl.mesh = cm
	cyl.name = "Column"
	cyl.material_override = Gfx.mat(Color(1.0, 0.85, 0.2, 0.28), 1.0, true)
	cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cyl)
	root.visible = false
	return root


static func arrow(parent: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "ObjectiveArrow"
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.32
	cm.height = 0.9
	cm.radial_segments = 4
	mi.mesh = cm
	mi.rotation.x = -PI * 0.5
	mi.material_override = Gfx.mat(Color(1.0, 0.85, 0.2), 0.8, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.visible = false
	return root


static func npc(parent: Node, look_id: String, pos: Vector3, yaw: float, title: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "NPC_" + look_id
	parent.add_child(root)
	root.global_position = pos
	var m := CharacterModel.new()
	root.add_child(m)
	m.build(Game.NPC_LOOKS.get(look_id, {}))
	m.position.y = 0.04
	m.rotation.y = yaw
	if title != "":
		Gfx.label3d(root, title, Vector3(0, 2.5, 0), 44, Color(1.0, 0.85, 0.4))
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.88
	body.add_child(cs)
	root.add_child(body)
	return root


## Aereo low-poly. `small` = jet privato. Muso verso -Z.
static func plane(parent: Node, small: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Jet" if small else "Airliner"
	parent.add_child(root)
	var s := 0.5 if small else 1.0
	var white := Color(0.95, 0.95, 0.96)
	var livery := Color(0.12, 0.12, 0.14) if small else Color(0.85, 0.2, 0.18)
	var b := MeshBatch.new()
	var fy := 3.0 * s
	var length := 26.0 * s
	var r := 2.0 * s
	b.cylinder_axis(Vector3(0, fy, 0), Vector3(0, 0, 1), r, r, length, 12, white)
	b.cylinder_axis(Vector3(0, fy - 0.2 * s, -length * 0.5 - 2.0 * s), Vector3(0, 0, -1), r, 0.35 * s, 4.0 * s, 12, white)
	b.cylinder_axis(Vector3(0, fy + 0.3 * s, length * 0.5 + 2.6 * s), Vector3(0, 0, 1), r, 0.5 * s, 5.2 * s, 12, white)
	b.box(Vector3(0, fy + 0.5 * s, 0), Vector3(r * 2.04, 0.5 * s, length * 0.86), Color(0.15, 0.2, 0.3))
	b.box(Vector3(0, fy - 0.45 * s, 0), Vector3(r * 2.06, 0.35 * s, length * 0.95), livery)
	b.box(Vector3(0, fy - 0.2 * s, -length * 0.5 - 1.6 * s), Vector3(r * 1.4, 0.5 * s, 0.9 * s), Color(0.15, 0.2, 0.3))
	var wing_y := fy - 0.9 * s
	b.box(Vector3(0, wing_y, -1.0 * s), Vector3(30.0 * s, 0.4 * s, 5.0 * s), Color(0.85, 0.86, 0.88))
	b.box(Vector3(0, fy + 0.6 * s, length * 0.5 + 3.5 * s), Vector3(11.0 * s, 0.3 * s, 3.0 * s), Color(0.85, 0.86, 0.88))
	b.box(Vector3(0, fy + 3.0 * s, length * 0.5 + 3.8 * s), Vector3(0.4 * s, 5.0 * s, 4.0 * s), livery)
	if not small:
		for ex: float in [-6.5, 6.5]:
			b.cylinder_axis(Vector3(ex, wing_y - 1.0, -2.0), Vector3(0, 0, 1), 0.95, 0.85, 4.2, 10, Color(0.75, 0.76, 0.78))
	else:
		for ex: float in [-2.0, 2.0]:
			b.cylinder_axis(Vector3(ex, fy + 0.6, length * 0.5 + 0.5), Vector3(0, 0, 1), 0.6, 0.5, 2.6, 8, Color(0.75, 0.76, 0.78))
	for gz: float in [-length * 0.45, 0.5 * s]:
		for gx in ([0.0] if gz < 0 else [-2.6 * s, 2.6 * s]):
			b.box(Vector3(gx, fy * 0.45, gz), Vector3(0.25 * s, fy * 0.7, 0.25 * s), Color(0.3, 0.3, 0.32))
			b.cylinder_axis(Vector3(gx, 0.45 * s, gz), Vector3(1, 0, 0), 0.45 * s, 0.45 * s, 0.4 * s, 8, Color(0.08, 0.08, 0.08))
	var mi := Gfx.add_batch(root, b)
	mi.name = "Mesh"
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(r * 2.0, r * 2.0, length + 6.0 * s)
	cs.shape = bs
	cs.position = Vector3(0, fy, 0)
	body.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(30.0 * s, 0.6 * s, 5.0 * s)
	cs2.shape = bs2
	cs2.position = Vector3(0, wing_y, -1.0 * s)
	body.add_child(cs2)
	return root


static func shop_marker(parent: Node, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "ShopMarker"
	parent.add_child(root)
	root.global_position = pos
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.2
	cm.height = 0.08
	cm.radial_segments = 16
	disc.mesh = cm
	disc.material_override = Gfx.mat(Color(1.0, 0.55, 0.15, 0.6), 1.0, true)
	disc.position.y = 0.1
	root.add_child(disc)
	Gfx.label3d(root, "$ ARMI", Vector3(0, 1.7, 0), 60, Color(1.0, 0.65, 0.25))
	return root


## Indicatore rosso sopra il bersaglio della mira automatica.
static func aim_marker(parent: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "AimMarker"
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = Gfx.box_mesh(Vector3(0.32, 0.32, 0.32))
	var m := Gfx.mat(Color(1.0, 0.15, 0.1, 0.9), 2.0, true).duplicate() as StandardMaterial3D
	m.no_depth_test = true
	mi.material_override = m
	mi.rotation = Vector3(deg_to_rad(45), 0, deg_to_rad(45))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.visible = false
	return root
