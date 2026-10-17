class_name Pickup
extends Node3D
## Oggetto raccoglibile: Brown Boost (salute), pacchi, indizi, valigetta,
## piume del Corvo. La raccolta avviene per vicinanza (anche in auto).

signal collected(pickup: Pickup)

var world: Node
var kind := "boost"
var id := ""
var radius := 1.6
var respawn := 0.0
var active := true
var visual: Node3D
var _t := 0.0
var _wait := 0.0
var _full_hint := 0.0
var revealed := false


func setup(w: Node, k: String, respawn_time: float = 45.0) -> void:
	world = w
	kind = k
	respawn = respawn_time
	visual = Node3D.new()
	add_child(visual)
	match kind:
		"boost":
			var gem := Gfx.add_box(visual, Vector3(0.5, 0.5, 0.5), Color(0.5, 0.29, 0.12), Vector3.ZERO, 0.35)
			gem.rotation = Vector3(deg_to_rad(45), 0, deg_to_rad(35))
			var core := Gfx.add_box(visual, Vector3(0.3, 0.3, 0.3), Color(0.78, 0.52, 0.25), Vector3.ZERO, 0.6)
			core.rotation = Vector3(0, deg_to_rad(45), deg_to_rad(45))
			_ring(Color(0.95, 0.75, 0.3), 0.55)
			Gfx.label3d(visual, "B", Vector3(0, 0.75, 0), 56, Color(1.0, 0.85, 0.5))
		"package":
			Gfx.add_box(visual, Vector3(0.8, 0.6, 0.8), Color(0.62, 0.45, 0.25))
			Gfx.add_box(visual, Vector3(0.82, 0.08, 0.15), Color(0.85, 0.2, 0.2), Vector3(0, 0.0, 0))
			Gfx.add_box(visual, Vector3(0.15, 0.62, 0.82), Color(0.85, 0.2, 0.2))
			_ring(Color(1.0, 0.9, 0.3), 0.8)
		"clue":
			Gfx.add_box(visual, Vector3(0.55, 0.06, 0.7), Color(0.95, 0.95, 0.9), Vector3.ZERO, 0.3)
			Gfx.add_box(visual, Vector3(0.4, 0.07, 0.05), Color(0.2, 0.2, 0.25), Vector3(0, 0.01, -0.15))
			_ring(Color(0.3, 0.9, 1.0), 0.6)
			Gfx.label3d(visual, "?", Vector3(0, 0.7, 0), 64, Color(0.4, 0.95, 1.0))
		"briefcase":
			Gfx.add_box(visual, Vector3(0.9, 0.65, 0.22), Color(0.12, 0.1, 0.1))
			Gfx.add_box(visual, Vector3(0.35, 0.1, 0.08), Color(0.8, 0.7, 0.3), Vector3(0, 0.38, 0))
			Gfx.add_box(visual, Vector3(0.92, 0.05, 0.24), Color(0.8, 0.7, 0.3), Vector3(0, 0.1, 0))
			_ring(Color(1.0, 0.85, 0.2), 0.9)
		"feather":
			Gfx.add_box(visual, Vector3(0.12, 0.9, 0.04), Color(0.1, 0.08, 0.15), Vector3.ZERO, 0.4)
			var vane := Gfx.add_box(visual, Vector3(0.3, 0.6, 0.03), Color(0.25, 0.12, 0.35), Vector3(0.05, 0.1, 0), 0.5)
			vane.rotation.z = 0.15
			_ring(Color(0.7, 0.4, 1.0), 0.5)
			visible = false
	add_to_group("pickups")


func _ring(c: Color, r: float) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r * 0.85
	t.outer_radius = r
	t.rings = 12
	t.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = Gfx.mat(c, 1.2, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mi)


func _physics_process(delta: float) -> void:
	_t += delta
	_full_hint = maxf(0.0, _full_hint - delta)
	if not active:
		if respawn > 0.0:
			_wait -= delta
			if _wait <= 0.0 and world.player_pos().distance_to(global_position) > 25.0:
				active = true
				visible = true
		return
	visual.rotation.y += delta * 2.2
	visual.position.y = 0.95 + sin(_t * 3.0) * 0.15
	if kind == "feather":
		visible = revealed or world.player_pos().distance_to(global_position) < 30.0
	if world.state != "play" or world.player == null or world.player.dead:
		return
	var r := radius + (1.8 if world.player.in_vehicle() else 0.0)
	var pp: Vector3 = world.player_pos()
	if Vector2(pp.x - global_position.x, pp.z - global_position.z).length() < r and absf(pp.y - global_position.y) < 3.0:
		try_collect()


func try_collect() -> bool:
	var p: Protagonist = world.player
	match kind:
		"boost":
			if p.health < p.max_health - 0.5:
				var before := p.health
				p.heal(Game.BOOST_HEAL)
				Gfx.popup(world, global_position + Vector3(0, 1.8, 0), "+%d" % int(round(p.health - before)), Color(1.0, 0.75, 0.4))
				world.hud.toast("Brown Boost! Salute recuperata.", 1.6)
			elif Game.add_boost():
				Gfx.popup(world, global_position + Vector3(0, 1.8, 0), "+1 BOOST", Color(1.0, 0.75, 0.4))
				world.hud.toast("Brown Boost conservato (%d/%d). Usalo con il pulsante BOOST." % [Game.boosts, Game.MAX_BOOSTS], 2.2)
			else:
				if _full_hint <= 0.0:
					world.hud.toast("Salute piena e scorta di Brown Boost al completo.", 1.6)
					_full_hint = 4.0
				return false
			Sfx.play("boost")
			Gfx.burst(world, global_position + Vector3(0, 1.0, 0), Color(0.65, 0.4, 0.18), 26, 6.0, 0.16, 0.9)
			Gfx.burst(world, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.4), 14, 4.0, 0.1, 0.7)
		"feather":
			Sfx.play("feather")
			Gfx.burst(world, global_position + Vector3(0, 1.0, 0), Color(0.6, 0.3, 0.9), 20, 5.0, 0.12, 0.8)
		_:
			Sfx.play("pickup")
			Gfx.burst(world, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.4), 18, 5.0, 0.12, 0.7)
	collected.emit(self)
	if respawn > 0.0:
		active = false
		visible = false
		_wait = respawn
	else:
		queue_free()
	return true
