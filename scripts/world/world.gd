class_name World
extends Node3D
## Il mondo di gioco: costruisce la città, gestisce protagonisti, veicoli,
## traffico, pedoni, oggetti, armi, polizia, salvataggi, morte/respawn,
## cambio personaggio e (in modalità multiplayer) la sessione di rete.

const PARKED := [
	["sedan", Vector3(75, 0, -160), 0.0], ["muscle", Vector3(87, 0, -160), 0.0], ["taxi", Vector3(99, 0, -160), 0.0],
	["sport", Vector3(81, 0, -140), PI], ["sedan", Vector3(93, 0, -140), PI], ["van", Vector3(105, 0, -140), PI],
	["van", Vector3(-45, 0, 80), 0.0], ["sedan", Vector3(-27, 0, 80), 0.0], ["muscle", Vector3(-21, 0, 100), PI],
	["sedan", Vector3(205, 0, -88), 0.0], ["taxi", Vector3(217, 0, -88), 0.0], ["luxury", Vector3(211, 0, -72), PI],
	["sedan", Vector3(54.0, 0, -30), PI], ["taxi", Vector3(126.0, 0, 30), 0.0], ["van", Vector3(-114.0, 0, -30), 0.0],
	["sedan", Vector3(-6.0, 0, 150), PI], ["muscle", Vector3(30, 0, -54.0), -PI * 0.5], ["sport", Vector3(-66.0, 0, 40), PI],
	["police", Vector3(142, 0, -18), PI], ["police", Vector3(158, 0, -18), PI],
]
const MP_SPAWNS := [
	Vector3(8.6, 0, -40), Vector3(-51.4, 0, 30), Vector3(128.6, 0, -30), Vector3(-90, 0, -128.6),
	Vector3(51.4, 0, 90), Vector3(-128.6, 0, 60), Vector3(90, 0, -51.4), Vector3(-8.6, 0, 150),
]
const TRAFFIC_TYPES := ["sedan", "sedan", "taxi", "van", "muscle", "sport", "sedan", "luxury", "taxi"]

var main: Node
var chars: Dictionary = {}
var player: Protagonist
var camera: GameCamera
var hud: HUD
var missions: MissionManager
var beacon: Node3D
var arrow: Node3D
var sun: DirectionalLight3D
var env: Environment
var airliner: Node3D
var jet: Node3D
var gus: Node3D
var save_marker: Node3D
var state := "menu"
var lock_count := 0
var checkpoint := CityData.SAFEHOUSE_DOOR
var checkpoint_yaw := PI
var cars: Array = []
var traffic: Array = []
var peds: Array = []
var feathers: Array = []
var garage_car: Car
var beacon_target: Variant = null
var rng := RandomNumberGenerator.new()
var intro: IntroCutscene
var _respawning := false
var _traffic_timer := 1.0
var _save_cd := 0.0
var _tom_reveal := 0.0
var _target_traffic := 10
var view_range := 270.0
var police: Police
var mp := false
var net: Node = null
var aim_marker: Node3D
var armory_marker: Node3D
var _aim_target: Node3D = null
var _aim_t := 0.0
var _armory_cd := 0.0
var _spray_cd := 0.0

const FOG_COLOR := Color(0.7, 0.78, 0.88)


func build() -> void:
	rng.seed = 2024
	_environment()
	var cb := CityBuilder.new()
	cb.build(self)
	camera = GameCamera.new()
	camera.world = self
	add_child(camera)
	camera.current = true
	beacon = Props.beacon(self)
	arrow = Props.arrow(self)
	airliner = Props.plane(self, false)
	airliner.global_position = CityData.AIRPORT_PLANE
	jet = Props.plane(self, true)
	jet.global_position = CityData.JET
	gus = Props.npc(self, "gus", CityData.GUS_POS, -PI * 0.5, "Gus")
	mp = not Game.pending_mp.is_empty()
	save_marker = Props.save_marker(self, CityData.SAVE_POINT)
	save_marker.visible = not mp
	armory_marker = Props.shop_marker(self, CityData.ARMORY_POS)
	armory_marker.visible = not mp
	aim_marker = Props.aim_marker(self)
	_spawn_protagonists()
	_target_traffic = 0 if mp else [6, 10, 14][clampi(int(Game.settings["quality"]), 0, 2)]
	for i in PARKED.size():
		var pc: Array = PARKED[i]
		var car := spawn_car(pc[0], pc[1], pc[2])
		car.net_id = i
		if mp:
			car.damage_taken_mult = 0.0
	for i in _target_traffic:
		_add_traffic_car(0.0)
	if not mp:
		_spawn_peds()
	_spawn_pickups()
	police = Police.new()
	police.world = self
	police.name = "Police"
	add_child(police)
	Game.weapon_changed.connect(_on_weapon_changed)
	missions = MissionManager.new()
	missions.world = self
	add_child(missions)
	hud = HUD.new()
	hud.world = self
	add_child(hud)
	Game.settings_changed.connect(apply_quality)
	apply_quality()


func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.24, 0.48, 0.84)
	sm.sky_horizon_color = FOG_COLOR
	sm.ground_bottom_color = FOG_COLOR.darkened(0.1)
	sm.ground_horizon_color = FOG_COLOR
	sky.sky_material = sm
	env.sky = sky
	# Il renderer Compatibility illumina direttamente in spazio sRGB:
	# luci contenute per non "bruciare" i colori.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.9)
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# Nebbia di profondità: gli oggetti svaniscono del tutto al piano lontano
	# della telecamera, così l'orizzonte non mostra tagli.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = FOG_COLOR
	env.fog_density = 1.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.78
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func apply_quality() -> void:
	var q := clampi(int(Game.settings["quality"]), 0, 2)
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = 55.0 if q == 1 else 100.0
	view_range = [190.0, 270.0, 380.0][q]
	set_view_range(view_range)
	get_viewport().msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	_target_traffic = [6, 10, 14][q]


func set_view_range(far: float) -> void:
	camera.far = far
	env.fog_depth_begin = far * 0.35
	env.fog_depth_end = far * 0.97


# ---------------------------------------------------------------- spawn

func _spawn_protagonists() -> void:
	var ids: Array = Game.CHAR_ORDER
	if mp:
		ids = [str(Game.pending_mp.get("char", "mike"))]
	for id in ids:
		var p := Protagonist.new()
		p.setup(id, self)
		add_child(p)
		chars[id] = p
	player = chars[ids[0]]
	player.active = true
	place_trio_at_safehouse()


func place_trio_at_safehouse() -> void:
	var spots := {"mike": Vector3(150, 0, -137), "tom": Vector3(146.5, 0, -139.5), "norman": Vector3(153.5, 0, -139.5)}
	if mp:
		return
	for id in chars:
		var p: Protagonist = chars[id]
		if p.in_vehicle():
			force_exit(p)
		p.teleport(spots[id], PI)


func place_trio_at_airport() -> void:
	var offs := {"mike": Vector3.ZERO, "tom": Vector3(2.5, 0, 2.2), "norman": Vector3(2.5, 0, -2.2)}
	for id in chars:
		var p: Protagonist = chars[id]
		if p.in_vehicle():
			force_exit(p)
		p.teleport(CityData.AIRPORT_SPAWN + offs[id], PI * 0.5)


func spawn_car(type: String, pos: Vector3, yaw: float, color: Variant = null) -> Car:
	var car := Car.new()
	var c: Color = Car.COLORS[rng.randi() % Car.COLORS.size()]
	if color != null:
		c = color
	elif type == "taxi":
		c = Color(0.98, 0.8, 0.12)
	elif type == "viper":
		c = Color(0.1, 0.1, 0.12)
	elif type == "police":
		c = Color(0.95, 0.95, 0.97)
	elif type == "swat":
		c = Color(0.12, 0.13, 0.18)
	car.setup(type, c, self)
	add_child(car)
	car.global_position = pos + Vector3(0, 0.05, 0)
	car.rotation.y = yaw
	cars.append(car)
	car.tree_exiting.connect(_on_car_removed.bind(car))
	return car


func _on_car_removed(car: Car) -> void:
	cars.erase(car)
	traffic.erase(car)


func road_spawn(center: Vector3, min_d: float, max_d: float) -> Dictionary:
	CityData.ensure_graph()
	for i in 60:
		var a := rng.randi() % CityData.nodes.size()
		var nbs: Array = CityData.links[a]
		var b: int = nbs[rng.randi() % nbs.size()]
		var pa: Vector3 = CityData.nodes[a]
		var pb: Vector3 = CityData.nodes[b]
		var d := (pb - pa).normalized()
		var pos := pa.lerp(pb, rng.randf_range(0.25, 0.75)) + d.cross(Vector3.UP) * CityData.LANE
		var dist := Vector2(pos.x - center.x, pos.z - center.z).length()
		if dist >= min_d and dist <= max_d and not _car_near(pos, 7.0):
			return {"pos": pos, "yaw": CityData.yaw_of(d), "a": a, "b": b}
	var near: Dictionary = CityData.nearest_road_point(center)
	var nd: Vector3 = near["dir"]
	return {"pos": near["point"] + nd.cross(Vector3.UP) * CityData.LANE, "yaw": CityData.yaw_of(nd), "a": near["a"], "b": near["b"]}


func _car_near(pos: Vector3, r: float) -> bool:
	for c in cars:
		if is_instance_valid(c) and c.global_position.distance_to(pos) < r:
			return true
	return false


func _add_traffic_car(min_dist: float) -> Car:
	var center := player_pos() if player != null else Vector3.ZERO
	var sp := road_spawn(center, min_dist, 2000.0 if min_dist <= 0.0 else 210.0)
	var car := spawn_car(TRAFFIC_TYPES[rng.randi() % TRAFFIC_TYPES.size()], sp["pos"], sp["yaw"])
	car.set_traffic(sp["a"], sp["b"])
	car.ai_max_speed = rng.randf_range(11.0, 15.0)
	traffic.append(car)
	return car


func _manage_traffic() -> void:
	var pp := player_pos()
	for car in traffic.duplicate():
		if not is_instance_valid(car):
			traffic.erase(car)
			continue
		if car.driver != null or car.ai_mode != Car.AI.TRAFFIC:
			traffic.erase(car)
			car.is_traffic = false
			continue
		var d: float = car.global_position.distance_to(pp)
		if d > 240.0:
			_relocate_traffic(car)
	for car in cars.duplicate():
		if not is_instance_valid(car) or car.driver != null or car.has_meta("mission"):
			continue
		var d2: float = car.global_position.distance_to(pp)
		if car.wrecked and d2 > 110.0:
			if car.is_traffic:
				car.repair()
				_relocate_traffic(car)
			else:
				car.queue_free()
		elif cars.size() > 48 and car.ai_mode == Car.AI.NONE and d2 > 160.0 and car != garage_car:
			car.queue_free()
	while traffic.size() < _target_traffic:
		_add_traffic_car(70.0)


func _relocate_traffic(car: Car) -> void:
	var sp := road_spawn(player_pos(), 70.0, 200.0)
	car.global_position = sp["pos"] + Vector3(0, 0.05, 0)
	car.rotation.y = sp["yaw"]
	car.speed = 0.0
	car.velocity = Vector3.ZERO
	car.set_traffic(sp["a"], sp["b"])


func _manage_garage_car() -> void:
	if Game.missions_done < 2:
		return
	var ok := garage_car != null and is_instance_valid(garage_car) and not garage_car.wrecked \
		and garage_car.global_position.distance_to(CityData.GARAGE_CAR) < 25.0
	if ok or player_pos().distance_to(CityData.GARAGE_CAR) < 45.0:
		return
	garage_car = spawn_car("muscle", CityData.GARAGE_CAR, PI, Color(0.9, 0.45, 0.1))


func _spawn_peds() -> void:
	var n: int = [12, 20, 28][clampi(int(Game.settings["quality"]), 0, 2)]
	for i in n:
		var ped := Pedestrian.new()
		ped.setup(self, rng)
		add_child(ped)
		peds.append(ped)
		_place_ped(ped, Vector3.ZERO, 0.0)


func _place_ped(ped: Pedestrian, avoid: Vector3, min_d: float) -> void:
	for attempt in 20:
		var xi := rng.randi() % 6
		var zi := rng.randi() % 6
		var c := Vector3(CityData.CENTERS[xi], 0, CityData.CENTERS[zi])
		if min_d > 0.0 and c.distance_to(avoid) < min_d:
			continue
		var corner := rng.randi() % 4
		ped.assign_block(c, corner)
		var p0: Vector3 = ped.loop_pts[corner]
		var p1: Vector3 = ped.loop_pts[(corner + 1) % 4]
		ped.loop_dir = 1
		ped.loop_i = (corner + 1) % 4
		ped.revive_at(p0.lerp(p1, rng.randf()) + Vector3(0, 0.05, 0))
		return


func recycle_ped(ped: Pedestrian) -> void:
	_place_ped(ped, player_pos(), 90.0)


func alert_peds(pos: Vector3, r: float) -> void:
	for ped in peds:
		if is_instance_valid(ped) and ped.global_position.distance_to(pos) < r:
			ped.flee(pos, 6.0)


func _spawn_pickups() -> void:
	for p in CityData.BOOST_SPOTS:
		spawn_pickup("boost", p, 45.0)
	for w in CityData.WEAPON_SPOTS:
		spawn_pickup("weapon", w[1], 60.0, w[0])
	if mp:
		return
	for i in CityData.FEATHER_SPOTS.size():
		var f := spawn_pickup("feather", CityData.FEATHER_SPOTS[i], 0.0)
		f.id = str(i)
		f.collected.connect(_on_feather)
		feathers.append(f)


func spawn_pickup(kind: String, pos: Vector3, respawn_time: float = 0.0, sub: String = "") -> Pickup:
	var p := Pickup.new()
	p.setup(self, kind, respawn_time, sub)
	add_child(p)
	p.global_position = pos
	return p


func spawn_enemy(look_id: String, pos: Vector3, hp: float, title: String = "") -> Enemy:
	var e := Enemy.new()
	e.setup(self, look_id, hp, title)
	add_child(e)
	e.global_position = pos + Vector3(0, 0.1, 0)
	return e


func refresh_feathers() -> void:
	for f in feathers.duplicate():
		if is_instance_valid(f) and Game.feathers.has(int(f.id)):
			feathers.erase(f)
			f.queue_free()


func _on_feather(p: Pickup) -> void:
	feathers.erase(p)
	var idx := int(p.id)
	if Game.feathers.has(idx):
		return
	Game.feathers.append(idx)
	Game.add_money(150)
	Sfx.play("cash")
	if Game.feathers.size() >= Game.TOTAL_FEATHERS:
		Game.add_money(2000)
		hud.show_message("TUTTE LE PIUME!", "Bonus collezionista +$2000", Color(0.75, 0.5, 1.0))
	else:
		hud.toast("Piuma del Corvo %d/%d  +$150" % [Game.feathers.size(), Game.TOTAL_FEATHERS], 2.5)


# ---------------------------------------------------------------- stato di gioco

func can_control() -> bool:
	return state == "play" and lock_count == 0 and player != null and not player.dead and not get_tree().paused \
		and not (mp and hud != null and hud.is_menu_open())


func player_pos() -> Vector3:
	if player == null:
		return Vector3.ZERO
	if player.vehicle != null:
		return player.vehicle.global_position
	return player.global_position


func enter_menu_mode() -> void:
	state = "menu"
	camera.mode = "orbit"
	set_view_range(700.0)
	hud.set_hud_visible(false)
	Sfx.music(true, -8.0)


func start_new_game(skip_intro: bool = false) -> void:
	state = "intro"
	place_trio_at_airport()
	switch_to("mike", true)
	for id in chars:
		chars[id].revive()
	hud.set_hud_visible(false)
	Sfx.music(false)
	set_view_range(750.0)
	if skip_intro or Game.test_mode:
		_after_intro()
		return
	intro = IntroCutscene.new()
	intro.world = self
	add_child(intro)
	intro.done.connect(_after_intro)
	intro.play()


func _after_intro() -> void:
	Game.intro_seen = true
	if intro != null:
		intro.queue_free()
		intro = null
	airliner.global_position = CityData.AIRPORT_PLANE
	airliner.rotation = Vector3.ZERO
	state = "play"
	set_view_range(view_range)
	camera.snap_behind()
	hud.set_hud_visible(true)
	missions.start_mission(0)


func continue_game() -> void:
	state = "play"
	set_view_range(view_range)
	apply_loaded_state()
	camera.snap_behind()
	hud.set_hud_visible(true)
	Sfx.music(false)
	if Game.missions_done == 0:
		place_trio_at_airport()
		camera.snap_behind()
		missions.start_mission(0)
	else:
		missions.refresh_marker()
		hud.toast("Partita caricata. Missioni completate: %d/%d" % [Game.missions_done, Game.TOTAL_MISSIONS], 3.0)


func collect_state() -> Dictionary:
	var d := {}
	for id in chars:
		d[id] = chars[id].save_state()
	return d


func apply_loaded_state() -> void:
	for id in chars:
		if Game.char_state.has(id):
			chars[id].load_state(Game.char_state[id])
	switch_to(Game.current_char, true)
	refresh_feathers()


func save_now() -> bool:
	if missions.current != null:
		hud.toast("Non puoi salvare durante una missione.", 2.0)
		return false
	var ok := Game.save_game(collect_state())
	hud.toast("Partita salvata." if ok else "Errore durante il salvataggio!", 2.0)
	return ok


func autosave() -> void:
	Game.save_game(collect_state())


func set_checkpoint(pos: Vector3, y: float = PI) -> void:
	checkpoint = pos
	checkpoint_yaw = y


func set_objective_target(pos: Variant, radius: float = 4.0) -> void:
	beacon_target = pos
	if pos == null:
		beacon.visible = false
		return
	beacon.visible = true
	beacon.global_position = pos
	var colm: MeshInstance3D = beacon.get_node("Column")
	var r := maxf(radius, 1.5)
	colm.scale = Vector3(r, 70.0, r)
	colm.position.y = 35.0


func talk(lines: Array) -> void:
	if lines.is_empty():
		return
	lock_count += 1
	hud.refresh_controls()
	hud.dialogue.play(lines)
	await hud.dialogue.finished
	lock_count = maxi(0, lock_count - 1)
	hud.refresh_controls()


# ---------------------------------------------------------------- ciclo

func _process(delta: float) -> void:
	if state != "play" or player == null:
		return
	Game.play_time += delta
	_update_arrow()
	if _tom_reveal > 0.0:
		_tom_reveal -= delta
		if _tom_reveal <= 0.0:
			for f in feathers:
				if is_instance_valid(f):
					f.revealed = false
	_traffic_timer -= delta
	if _traffic_timer <= 0.0 and not mp:
		_traffic_timer = 2.0
		_manage_traffic()
		_manage_garage_car()
	if not mp:
		_check_save_point(delta)
		_check_armory(delta)
		_check_paint_shop(delta)
	_update_aim_marker(delta)
	if lock_count > 0 or get_tree().paused or player.dead or not can_control():
		return
	if Input.is_action_just_pressed("pause"):
		hud.open_pause()
		return
	if Input.is_action_just_pressed("map"):
		hud.open_map()
		return
	if Input.is_action_just_pressed("vehicle"):
		toggle_vehicle()
	if Input.is_action_just_pressed("attack"):
		player.attack(false)
	elif Input.is_action_pressed("attack") and Game.current_weapon != "fists":
		player.attack(true)
	if Input.is_action_just_pressed("weapon_next") and not player.in_vehicle():
		Game.next_weapon()
		Sfx.play("reload", -6.0)
	if Input.is_action_just_pressed("special"):
		player.use_special()
	if Input.is_action_just_pressed("use_boost"):
		use_boost_item()
	if Input.is_action_just_pressed("horn") and player.in_vehicle():
		Sfx.play("horn", -4.0)
		alert_peds(player_pos(), 12.0)
	if Input.is_action_just_pressed("switch_char"):
		if mp:
			hud.open_scoreboard()
		else:
			hud.open_char_select()
	for i in 3:
		if Input.is_action_just_pressed("char_%d" % (i + 1)):
			request_switch(Game.CHAR_ORDER[i])


func _update_arrow() -> void:
	if beacon_target == null or lock_count > 0:
		arrow.visible = false
		return
	var pp := player_pos()
	var t: Vector3 = beacon_target
	var flat := Vector3(t.x - pp.x, 0, t.z - pp.z)
	if flat.length() < 14.0:
		arrow.visible = false
		return
	arrow.visible = true
	arrow.global_position = pp + Vector3(0, 3.6 if player.in_vehicle() else 2.5, 0)
	arrow.look_at(arrow.global_position + flat.normalized(), Vector3.UP)


func _check_save_point(delta: float) -> void:
	_save_cd = maxf(0.0, _save_cd - delta)
	var near := not player.in_vehicle() and player.global_position.distance_to(CityData.SAVE_POINT) < 1.7
	if near and _save_cd <= 0.0 and missions.current == null and lock_count == 0:
		_save_cd = 1000.0
		player.heal(player.max_health)
		if Game.save_game(collect_state()):
			hud.show_message("PARTITA SALVATA", "Salute ripristinata al rifugio", Color(0.4, 1.0, 0.6))
			Sfx.play("checkpoint")
	elif not near and _save_cd > 900.0:
		_save_cd = 1.5


# ---------------------------------------------------------------- veicoli

func nearest_car(pos: Vector3, r: float) -> Car:
	var best: Car = null
	var best_d := r
	for c in cars:
		if not is_instance_valid(c) or c.wrecked or c.hostile or c.driver != null or c.remote_driver != 0:
			continue
		var d: float = c.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = c
	return best


func toggle_vehicle() -> void:
	if player.in_vehicle():
		var leaving := player.vehicle
		force_exit(player)
		if mp and net != null:
			net.release_car(leaving)
		return
	var car := nearest_car(player.global_position, 4.6)
	if car != null:
		if mp and net != null:
			net.request_car(car)
			return
		enter_vehicle(player, car)
	else:
		hud.toast("Nessuna auto nelle vicinanze.", 1.2)


func enter_vehicle(p: Protagonist, car: Car) -> void:
	if p == player and not mp:
		if car.car_type in ["police", "swat"]:
			report_crime("hijack_police", car.global_position)
		elif car.npc_driver:
			report_crime("hijack", car.global_position)
	if car.npc_driver:
		_eject_npc(car)
	car.ai_mode = Car.AI.NONE
	car.is_traffic = false
	car.frozen = false
	traffic.erase(car)
	car.driver = p
	p.set_in_vehicle(car)
	var look: Dictionary = p.data["look"]
	car.model.set_driver(true, look["skin"])
	Sfx.play("door")
	if p == player:
		camera.last_drag = 10.0
		hud.refresh_controls()
		hud.toast(car.display_name(), 1.2)


func _eject_npc(car: Car) -> void:
	car.npc_driver = false
	var far_ped: Pedestrian = null
	var far_d := -1.0
	for ped in peds:
		var d: float = ped.global_position.distance_to(player_pos())
		if d > far_d:
			far_d = d
			far_ped = ped
	if far_ped != null:
		var side := car.global_transform.basis.x
		far_ped.revive_at(car.global_position + side * 2.4 + Vector3(0, 0.1, 0))
		far_ped.flee(car.global_position, 8.0)


func force_exit(p: Protagonist) -> void:
	var car := p.vehicle
	if car == null:
		return
	var pos := _exit_position(car)
	car.driver = null
	car.model.set_driver(false)
	car.model.set_nitro(false)
	p.set_in_vehicle(null)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set_yaw(car.rotation.y)
	if p == player:
		Sfx.set_engine(false)
		Sfx.play("door")
		hud.refresh_controls()


func put_in_car(p: Protagonist, car: Car) -> void:
	if p.in_vehicle():
		force_exit(p)
	enter_vehicle(p, car)
	if p == player:
		camera.snap_behind()


func _exit_position(car: Car) -> Vector3:
	var space := get_world_3d().direct_space_state
	var c := car.global_position + Vector3(0, 1.0, 0)
	var b := car.global_transform.basis
	var half := car.size * 0.5
	var candidates := [-b.x * (half.x + 0.9), b.x * (half.x + 0.9), b.z * (half.z + 1.0), -b.z * (half.z + 1.0)]
	for off in candidates:
		var target: Vector3 = c + off
		var q := PhysicsRayQueryParameters3D.create(c, target, 1 | 4, [car.get_rid()])
		if space.intersect_ray(q).is_empty():
			return Vector3(target.x, car.global_position.y + 0.1, target.z)
	return car.global_position + Vector3(0, car.size.y + 0.5, 0)


func recover_car(car: Car) -> void:
	var near: Dictionary = CityData.nearest_road_point(car.global_position)
	car.global_position = near["point"] + Vector3(0, 0.5, 0)
	car.velocity = Vector3.ZERO
	car.speed = 0.0


func respawn_fallen(p: Protagonist) -> void:
	var near: Dictionary = CityData.nearest_road_point(p.global_position)
	p.teleport(near["point"] + Vector3(0, 0.5, 0), p.yaw)


# ---------------------------------------------------------------- personaggi

func request_switch(id: String) -> void:
	if player == null or id == player.char_id or _respawning or player.dead:
		return
	if missions.current != null and not missions.current.allow_switch:
		hud.toast("Non puoi cambiare personaggio durante una missione.", 2.0)
		return
	switch_to(id, false)


func switch_to(id: String, instant: bool) -> void:
	var new_p: Protagonist = chars.get(id)
	if new_p == null:
		return
	var old := player
	if old == new_p:
		new_p.active = true
		if instant:
			camera.snap_behind()
		return
	var from_pos := camera.global_position
	if old != null:
		old.active = false
		if old.in_vehicle():
			Sfx.set_engine(false)
	if new_p.dead:
		new_p.revive()
	new_p.active = true
	player = new_p
	Game.current_char = id
	if old != null:
		old.model.set_weapon("fists")
	new_p.model.set_weapon(Game.current_weapon)
	if hud != null:
		hud.on_character_changed()
	if instant or state != "play":
		camera.snap_behind()
	else:
		camera.yaw = new_p.vehicle.rotation.y if new_p.in_vehicle() else new_p.yaw
		camera.start_switch(from_pos)
		Sfx.play("switch")


func use_boost_item() -> void:
	if player.health >= player.max_health - 0.5:
		hud.toast("Salute già al massimo.", 1.2)
		return
	if not Game.take_boost():
		hud.toast("Nessun Brown Boost in scorta. Raccoglili in città!", 1.8)
		return
	var before := player.health
	player.heal(Game.BOOST_HEAL)
	Sfx.play("boost")
	Gfx.burst(self, player_pos() + Vector3(0, 1.2, 0), Color(0.65, 0.4, 0.18), 22, 5.0, 0.14, 0.8)
	Gfx.popup(self, player_pos() + Vector3(0, 2.2, 0), "+%d" % int(round(player.health - before)), Color(1.0, 0.75, 0.4))


func on_tom_analysis(p: Protagonist) -> void:
	_tom_reveal = 10.0
	var count := 0
	for f in feathers:
		if is_instance_valid(f):
			f.revealed = true
			count += 1
	var cams := 0
	for cam in get_tree().get_nodes_in_group("security_cams"):
		if cam.global_position.distance_to(p.global_position) < 40.0:
			cam.disable(8.0)
			cams += 1
	if cams > 0:
		hud.toast("ANALISI: %d telecamere disattivate per 8 secondi." % cams, 2.5)
	else:
		hud.toast("ANALISI: %d piume del Corvo evidenziate sulla mappa." % count, 2.5)
	if missions.current != null:
		missions.current.on_special(p)


# ---------------------------------------------------------------- K.O. e respawn

func on_player_ko(p: Protagonist) -> void:
	if p != player or _respawning:
		return
	_respawning = true
	lock_count += 1
	hud.refresh_controls()
	hud.show_ko(true)
	Sfx.play("ko")
	Game.vibrate(300)
	missions.on_player_ko()
	police.clear()
	if mp and net != null:
		net.on_local_ko()
	await get_tree().create_timer(2.2).timeout
	await hud.fade(true, 0.45)
	_respawn(p)
	hud.show_ko(false)
	await hud.fade(false, 0.45)
	lock_count = maxi(0, lock_count - 1)
	_respawning = false
	hud.refresh_controls()
	missions.after_respawn()


func _respawn(p: Protagonist) -> void:
	if p.in_vehicle():
		var car := p.vehicle
		force_exit(p)
		if mp and net != null:
			net.release_car(car)
	p.revive()
	if mp:
		p.teleport(mp_spawn_point(), PI)
		camera.snap_behind()
		return
	p.teleport(checkpoint, checkpoint_yaw)
	camera.snap_behind()
	var fee := mini(Game.money, Game.KO_FEE)
	if fee > 0:
		Game.add_money(-fee)
		hud.toast("Spese mediche: -$%d" % fee, 2.5)


## Arresto: come il K.O. ma si riparte dalla questura con multa e armi sequestrate.
func on_busted() -> void:
	if _respawning or player.dead:
		return
	_respawning = true
	lock_count += 1
	hud.refresh_controls()
	hud.show_busted(true)
	Sfx.play("busted")
	Game.vibrate(200)
	missions.on_player_down("Sei stato arrestato!")
	police.clear()
	await get_tree().create_timer(2.2).timeout
	await hud.fade(true, 0.45)
	if player.in_vehicle():
		force_exit(player)
	player.revive()
	player.teleport(CityData.POLICE_DOOR, PI)
	camera.snap_behind()
	var fee := mini(Game.money, Game.BUSTED_FEE)
	Game.add_money(-fee)
	Game.confiscate_weapons()
	hud.toast("Arrestato: multa di $%d e armi sequestrate." % fee, 3.5)
	hud.show_busted(false)
	await hud.fade(false, 0.45)
	lock_count = maxi(0, lock_count - 1)
	_respawning = false
	hud.refresh_controls()
	missions.after_respawn()


func play_ending() -> void:
	Game.ending_seen = true
	autosave()
	hud.show_credits()


# ---------------------------------------------------------------- minimappa

func get_blips() -> Array:
	var out := []
	for id in chars:
		var p: Protagonist = chars[id]
		if p != player:
			out.append({"pos": p.global_position, "color": p.data["color"], "label": p.data["initial"], "kind": "char"})
	out.append({"pos": CityData.SAFEHOUSE_DOOR, "color": Color(0.3, 0.95, 0.5), "label": "R", "kind": "icon"})
	if Game.missions_done >= 2:
		out.append({"pos": CityData.GARAGE_INSIDE, "color": Color(1.0, 0.6, 0.2), "label": "G", "kind": "icon"})
	out.append({"pos": Vector3(265, 0, -40), "color": Color(0.7, 0.8, 1.0), "label": "A", "kind": "icon"})
	if missions.marker != null:
		out.append({"pos": missions.marker.global_position, "color": missions.marker_color, "label": missions.marker_letter, "kind": "mission"})
	if missions.current != null:
		out.append_array(missions.current.get_blips())
	if _tom_reveal > 0.0:
		for f in feathers:
			if is_instance_valid(f):
				out.append({"pos": f.global_position, "color": Color(0.7, 0.4, 1.0), "label": "", "kind": "dot"})
	if not mp:
		out.append({"pos": CityData.ARMORY_POS, "color": Color(1.0, 0.5, 0.15), "label": "$", "kind": "icon"})
		out.append({"pos": CityData.POLICE_DOOR, "color": Color(0.35, 0.55, 1.0), "label": "P", "kind": "icon"})
		out.append_array(police.unit_blips())
	elif net != null:
		out.append_array(net.get_blips())
	if beacon_target != null:
		out.append({"pos": beacon_target, "color": Color(1.0, 0.85, 0.2), "label": "", "kind": "objective"})
	return out


# ---------------------------------------------------------------- armi

func _on_weapon_changed(id: String) -> void:
	if player != null:
		player.model.set_weapon(id)
	if hud != null:
		hud.refresh_controls()


func camera_flat_forward() -> Vector3:
	var f := -camera.global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return player.forward()
	return f.normalized()


func aim_point(n: Node3D) -> Vector3:
	if n.has_method("aim_point"):
		return n.aim_point()
	return n.global_position + Vector3(0, 1.2, 0)


## Bersaglio della mira automatica: nemici, polizia, elicotteri, altri
## giocatori e (con priorità minore) pedoni, entro un cono davanti alla
## telecamera o al personaggio e con linea di vista libera.
func find_aim_target(p: Protagonist, max_range: float) -> Node3D:
	var origin := p.global_position + Vector3(0, 1.4, 0)
	var cam_dir := camera_flat_forward()
	var best: Node3D = null
	var best_score := INF
	var space := get_world_3d().direct_space_state
	for group in ["enemies", "aim_targets", "net_avatars", "peds"]:
		for n in get_tree().get_nodes_in_group(group):
			if n == p or not is_instance_valid(n):
				continue
			if n is Actor and (n.dead or (group == "peds" and n.down_time > 0.0)):
				continue
			if group == "peds" and not n.model.visible:
				continue
			var tp := aim_point(n)
			var to := tp - origin
			var d := to.length()
			if d > max_range or d < 0.4:
				continue
			var flat := Vector3(to.x, 0, to.z).normalized()
			var ang := minf(cam_dir.angle_to(flat), p.forward().angle_to(flat))
			if ang > deg_to_rad(38.0):
				continue
			var score := ang * 25.0 + d * 0.4 + (40.0 if group == "peds" else 0.0)
			if score >= best_score:
				continue
			var q := PhysicsRayQueryParameters3D.create(origin, tp, 1)
			if not space.intersect_ray(q).is_empty():
				continue
			best = n
			best_score = score
	return best


## Raggio di un proiettile: restituisce il punto d'impatto e il nodo colpito
## che sa gestire il colpo (metodo take_bullet), se esiste.
func shoot_ray(origin: Vector3, dir: Vector3, reach: float, exclude: Array) -> Dictionary:
	var to := origin + dir * reach
	var q := PhysicsRayQueryParameters3D.create(origin, to, 1 | 2 | 4 | 16, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"pos": to, "node": null}
	var n: Node = hit["collider"]
	while n != null and n != self and not n.has_method("take_bullet"):
		n = n.get_parent()
	if n == self:
		n = null
	return {"pos": hit["position"], "node": n}


## Colpo sparato da un PNG (polizia, elicottero) verso il giocatore.
func npc_shoot(shooter: Node3D, origin: Vector3, accuracy: float, dmg: float, weapon: String) -> void:
	var tp := player_pos() + Vector3(0, 0.9 if player.in_vehicle() else 1.1, 0)
	var dist := origin.distance_to(tp)
	var chance := accuracy * clampf(1.25 - dist / 35.0, 0.2, 1.0)
	if Vector2(player.velocity.x, player.velocity.z).length() > 5.0 or player.in_vehicle():
		chance *= 0.75
	var miss := randf() > chance
	var aim := tp
	if miss:
		aim += Vector3(randf_range(-1.6, 1.6), randf_range(-0.4, 1.2), randf_range(-1.6, 1.6))
	var d := (aim - origin).normalized()
	var excl: Array = []
	if shooter is CollisionObject3D:
		excl.append((shooter as CollisionObject3D).get_rid())
	var res := shoot_ray(origin, d, 70.0, excl)
	var hit_node: Node = res["node"]
	if hit_node != null and (hit_node == player or (player.in_vehicle() and hit_node == player.vehicle)):
		hit_node.take_bullet(dmg, shooter, d)
	Gfx.tracer(self, origin, res["pos"], Color(1.0, 0.65, 0.35))
	Gfx.muzzle_flash(self, origin)
	Sfx.play_at(Game.WEAPONS.get(weapon, Game.WEAPONS["pistol"])["sound"], origin, camera.global_position, 80.0, -4.0)


## Effetto di uno sparo da trasmettere agli altri giocatori (solo multiplayer).
func net_shot(from: Vector3, to: Vector3, weapon: String) -> void:
	if mp and net != null:
		net.send_shot_fx(from, to, weapon)


func _update_aim_marker(delta: float) -> void:
	_aim_t -= delta
	var armed := Game.current_weapon != "fists" and not player.in_vehicle() and lock_count == 0
	if not armed:
		aim_marker.visible = false
		_aim_target = null
		return
	if _aim_t <= 0.0:
		_aim_t = 0.12
		_aim_target = find_aim_target(player, float(Game.WEAPONS[Game.current_weapon]["range"]))
	if _aim_target == null or not is_instance_valid(_aim_target):
		aim_marker.visible = false
		return
	aim_marker.visible = true
	aim_marker.global_position = aim_point(_aim_target) + Vector3(0, 1.1, 0)
	aim_marker.rotation.y += delta * 4.0


# ---------------------------------------------------------------- polizia e crimini

func report_crime(kind: String, pos: Vector3) -> void:
	if police != null and not mp:
		police.report(kind, pos)


## Vero se `source` è il giocatore o l'auto che sta guidando.
func is_player_source(source: Variant) -> bool:
	if source == null or player == null or not is_instance_valid(source):
		return false
	if source == player:
		return true
	return source is Car and (source as Car).driver == player


func _check_armory(delta: float) -> void:
	_armory_cd = maxf(0.0, _armory_cd - delta)
	var near := not player.in_vehicle() and player.global_position.distance_to(CityData.ARMORY_POS) < 1.8
	if near and _armory_cd <= 0.0 and lock_count == 0 and not hud.is_menu_open():
		_armory_cd = 1000.0
		hud.open_armory()
	elif not near and _armory_cd > 900.0:
		_armory_cd = 1.0


## Riverniciatura al garage di Gus: cancella le stelle se la polizia non ti vede.
func _check_paint_shop(delta: float) -> void:
	_spray_cd = maxf(0.0, _spray_cd - delta)
	if police.stars == 0 or not player.in_vehicle() or _spray_cd > 0.0:
		return
	var car: Car = player.vehicle
	if car.global_position.distance_to(CityData.GARAGE_INSIDE) > 7.0:
		return
	_spray_cd = 3.0
	if police.seen:
		hud.toast("Gus non vernicia auto con la polizia alle calcagna: seminala prima!", 2.5)
		return
	var cost := mini(Game.money, 100)
	Game.add_money(-cost)
	police.clear()
	car.repaint(Car.COLORS[rng.randi() % Car.COLORS.size()])
	Sfx.play("cash")
	hud.show_message("RIVERNICIATA!", "Stelle cancellate  -$%d" % cost, Color(1.0, 0.7, 0.3), 2.5)


# ---------------------------------------------------------------- multiplayer

func mp_spawn_point() -> Vector3:
	var best: Vector3 = MP_SPAWNS[0]
	var best_d := -1.0
	for i in 6:
		var p: Vector3 = MP_SPAWNS[rng.randi() % MP_SPAWNS.size()]
		var d := 999.0
		if net != null:
			d = net.nearest_avatar_distance(p)
		if d > best_d:
			best_d = d
			best = p
	return best


func start_multiplayer() -> void:
	state = "play"
	set_view_range(view_range)
	player.teleport(mp_spawn_point(), PI)
	Game.weapons = {"fists": 0}
	Game.give_weapon("pistol", 60)
	camera.snap_behind()
	hud.set_hud_visible(true)
	Sfx.music(false)
	net = NetSession.new()
	net.name = "Net"
	net.world = self
	add_child(net)
	net.start(Game.pending_mp)
