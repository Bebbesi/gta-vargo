class_name MissionManager
extends Node
## Gestisce la sequenza delle 8 missioni della storia: indicatori di inizio,
## avvio, ricompense, fallimenti, nuovi tentativi e salvataggio automatico.

const SCRIPTS := [
	preload("res://scripts/missions/m1_arrival.gd"),
	preload("res://scripts/missions/m2_first_car.gd"),
	preload("res://scripts/missions/m3_package.gd"),
	preload("res://scripts/missions/m4_escape.gd"),
	preload("res://scripts/missions/m5_tom_plan.gd"),
	preload("res://scripts/missions/m6_mike_race.gd"),
	preload("res://scripts/missions/m7_norman_fight.gd"),
	preload("res://scripts/missions/m8_finale.gd"),
]

const INFO := [
	{"title": "Arrivo in città", "char": "", "pos": CityData.AIRPORT_SPAWN, "auto": true},
	{"title": "Prima automobile", "char": "", "pos": CityData.SAFEHOUSE_MARK},
	{"title": "Il pacco misterioso", "char": "", "pos": CityData.GARAGE_MARK},
	{"title": "Fuga improvvisa", "char": "", "pos": Vector3(-30, 0, -8.6)},
	{"title": "Il piano di Tom", "char": "tom", "pos": CityData.SAFEHOUSE_MARK},
	{"title": "La corsa di Mike", "char": "mike", "pos": CityData.GARAGE_MARK},
	{"title": "La sfida di Norman", "char": "norman", "pos": CityData.YARD_MARK},
	{"title": "La verità sulla valigetta", "char": "", "pos": CityData.SAFEHOUSE_MARK, "choose": true},
]

var world: Node
var current: Mission = null
var current_index := -1
var marker: Node3D = null
var marker_color := Color.WHITE
var marker_letter := "S"
var _cooldown := 0.0
var _retry_m1 := false


func next_index() -> int:
	return Game.missions_done if Game.missions_done < Game.TOTAL_MISSIONS else -1


func refresh_marker() -> void:
	if marker != null:
		marker.queue_free()
		marker = null
	if current != null:
		return
	var i := next_index()
	if i < 0:
		return
	var req: String = INFO[i]["char"]
	marker_letter = "S"
	marker_color = Color(1.0, 0.85, 0.3)
	if req != "":
		marker_letter = Game.CHARACTERS[req]["initial"]
		marker_color = Game.CHARACTERS[req]["color"]
	elif INFO[i].get("choose", false):
		marker_letter = "?"
	marker = Props.mission_marker(world, INFO[i]["pos"], marker_color, marker_letter)
	_cooldown = 1.0


func _physics_process(delta: float) -> void:
	if current != null:
		if world.state == "play":
			current.tick(delta)
		return
	_cooldown -= delta
	if marker == null or _cooldown > 0.0 or not world.can_control():
		return
	var pp: Vector3 = world.player_pos()
	var mp := marker.global_position
	var d := Vector2(pp.x - mp.x, pp.z - mp.z).length()
	var ok := d < 2.0
	if world.player.in_vehicle():
		ok = d < 3.5 and absf(world.player.vehicle.speed) < 4.0
	if ok:
		try_start(next_index())


func try_start(i: int) -> void:
	if i < 0 or current != null:
		return
	var req: String = INFO[i]["char"]
	if req != "" and world.player.char_id != req:
		var nm: String = Game.CHARACTERS[req]["name"]
		world.hud.toast("Questa missione è di %s. Premi CAMBIA per giocare con lui." % nm, 3.0)
		_cooldown = 4.0
		return
	if INFO[i].get("choose", false):
		_cooldown = 3.0
		world.hud.open_final_choice(_on_final_choice.bind(i))
		return
	start_mission(i)


func _on_final_choice(id: String, i: int) -> void:
	if id != "":
		start_mission(i, id)


func start_mission(i: int, chosen: String = "") -> void:
	if current != null:
		return
	if marker != null:
		marker.queue_free()
		marker = null
	current_index = i
	current = SCRIPTS[i].new()
	current.world = world
	current.index = i
	current.title = INFO[i]["title"]
	current.chosen = chosen
	current.name = "Mission%d" % (i + 1)
	add_child(current)
	current.finished.connect(_on_finished)
	world.hud.show_message("MISSIONE %d" % (i + 1), INFO[i]["title"], Color(1.0, 0.85, 0.3), 2.5)
	Sfx.play("checkpoint")
	current.start()


func _on_finished(success: bool, reason: String) -> void:
	var m := current
	var i := current_index
	current = null
	m.cleanup()
	m.queue_free()
	if success:
		Game.missions_done = maxi(Game.missions_done, i + 1)
		var mult: float = world.player.data["money_bonus"]
		var reward := int(round(m.reward * mult)) + m.bonus
		Game.add_money(reward)
		var extra := "  (bonus Tom +25%)" if mult > 1.0 else ""
		world.hud.show_message("MISSIONE COMPIUTA!", "+$%d%s" % [reward, extra], Color(1.0, 0.82, 0.25), 3.5)
		Sfx.play("mission_pass")
		Game.vibrate(120)
		world.set_checkpoint(m.checkpoint_after, PI)
		world.autosave()
		if Game.test_mode:
			print("[MISSIONE %d] COMPLETATA (+$%d)" % [i + 1, reward])
		if i == 2:
			get_tree().create_timer(3.0).timeout.connect(start_mission.bind(3, ""))
		elif i == Game.TOTAL_MISSIONS - 1:
			world.play_ending()
			refresh_marker()
		else:
			refresh_marker()
	else:
		world.hud.show_message("MISSIONE FALLITA", reason, Color(1.0, 0.3, 0.25), 3.5)
		Sfx.play("mission_fail")
		if Game.test_mode:
			print("[MISSIONE %d] FALLITA: %s" % [i + 1, reason])
		if i == 0:
			_retry_m1 = true
		else:
			refresh_marker()


func on_player_ko() -> void:
	on_player_down("Sei finito K.O.")


func on_player_down(reason: String) -> void:
	if current != null:
		current.fail(reason)


func after_respawn() -> void:
	if _retry_m1 and current == null:
		_retry_m1 = false
		world.place_trio_at_airport()
		world.camera.snap_behind()
		start_mission(0)
