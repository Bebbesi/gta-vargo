extends Mission
## Missione 8 — La verità sulla valigetta: il giocatore sceglie il protagonista,
## raggiunge l'aeroporto, ferma l'auto di Dex, sconfigge lui e le guardie e
## recupera la valigetta. Sblocca il finale.

const LOOP := [
	Vector3(300, 0, 150), Vector3(340, 0, 172), Vector3(368, 0, 100), Vector3(368, 0, -150),
	Vector3(330, 0, -170), Vector3(296, 0, -120), Vector3(296, 0, -10), Vector3(298, 0, 60),
]
const GUARD_SPOTS := [Vector3(-10, 0, -8), Vector3(-12, 0, 6), Vector3(-6, 0, 12)]

var dex_car: Car
var dex: Enemy
var guards: Array = []
var briefcase: Pickup
var chase_t := 0.0
var _hint := false


func _init() -> void:
	reward = 5000


func intro_lines() -> Array:
	var lines: Array = StoryText.M8_INTRO.duplicate()
	lines.append_array(StoryText.M8_CHOICE.get(chosen, []))
	return lines


func start() -> void:
	if chosen != "" and world.player.char_id != chosen:
		world.switch_to(chosen, true)
	world.place_trio_at_safehouse()
	world.camera.snap_behind()
	await super.start()


func begin() -> void:
	var sp: Dictionary = world.road_spawn(CityData.SAFEHOUSE_DOOR, 10.0, 28.0)
	var car: Car = world.spawn_car("sport" if chosen == "mike" else "muscle", sp["pos"], sp["yaw"], Color(0.95, 0.3, 0.2))
	track(car)
	timer = 75.0 + (30.0 if chosen == "tom" else 0.0)
	time_fail_reason = "Dex è decollato con la valigetta!"
	objective("Raggiungi l'hangar 2 dell'aeroporto prima che Dex decolli!", CityData.HANGAR, 12.0)
	world.hud.toast("Un'auto ti aspetta in strada davanti al rifugio.", 3.0)


func update(delta: float) -> void:
	blips = []
	match stage:
		0:
			if at_target():
				stage = 10
				timer = -1.0
				world.hud.set_timer(-1.0)
				_start_chase()
		1:
			chase_t += delta
			if is_instance_valid(dex_car):
				blips.append({"pos": dex_car.global_position, "color": Color(1.0, 0.25, 0.2), "label": "", "kind": "enemy_far"})
				world.hud.set_extra("Auto di Dex: %d%%" % int(100.0 * dex_car.health / dex_car.max_health))
			if not in_car() and not _hint:
				_hint = true
				world.hud.toast("Sali su un'auto e sperona Dex finché la sua auto non si ferma!", 3.5)
			if not is_instance_valid(dex_car) or dex_car.wrecked or chase_t > 150.0:
				_dex_on_foot()
		2:
			var alive := 0
			for g in guards:
				if is_instance_valid(g) and not g.dead:
					alive += 1
					blips.append({"pos": g.global_position, "color": Color(0.95, 0.2, 0.2), "label": "", "kind": "enemy"})
			if is_instance_valid(dex) and not dex.dead:
				blips.append({"pos": dex.global_position, "color": Color(1.0, 1.0, 1.0), "label": "D", "kind": "icon"})
			world.hud.set_extra("Guardie rimaste: %d   ·   Dex: %d%%" % [alive, int(100.0 * dex.health / dex.max_health) if is_instance_valid(dex) else 0])
			if alive == 0 and (not is_instance_valid(dex) or dex.dead):
				stage = 3
				var at: Vector3 = dex.global_position if is_instance_valid(dex) else CityData.JET
				briefcase = world.spawn_pickup("briefcase", at + Vector3(1.5, 0, 0), 0.0)
				track(briefcase)
				briefcase.collected.connect(_on_briefcase)
				world.hud.set_extra("")
				objective("Recupera la valigetta!", at + Vector3(1.5, 0, 0), 2.5)


func _start_chase() -> void:
	await say(StoryText.M8_DEX)
	if done:
		return
	dex_car = world.spawn_car("luxury", Vector3(300, 0, 104), PI, Color(0.96, 0.96, 0.96))
	track(dex_car)
	dex_car.hostile = true
	dex_car.npc_driver = true
	dex_car.model.set_driver(true, Color(0.9, 0.75, 0.62))
	dex_car.ai_points = LOOP.duplicate()
	dex_car.ai_loop = true
	dex_car.ai_radius = 12.0
	dex_car.ai_max_speed = 19.0 if chosen == "tom" else 24.0
	dex_car.damage_taken_mult = 2.4
	dex_car.ai_mode = Car.AI.PATH
	if not in_car():
		track(world.spawn_car("sport", Vector3(292, 0, 112), PI * 0.5, Color(0.2, 0.5, 0.95)))
	objective("Ferma l'auto di Dex! Speronala finché non si ferma.", null)
	stage = 1


func _dex_on_foot() -> void:
	stage = 2
	var pos: Vector3 = CityData.JET + Vector3(-14, 0, 0)
	if is_instance_valid(dex_car):
		pos = dex_car.global_position + dex_car.global_transform.basis.x * -3.0
		dex_car.ai_mode = Car.AI.NONE
		dex_car.npc_driver = false
		dex_car.model.set_driver(false)
	dex = world.spawn_enemy("dex", pos, 170.0, "Dex Morlan")
	dex.boss = true
	dex.damage = 11.0
	dex.speed = 5.3
	dex.remove_on_defeat = false
	dex.drop_boost = 0.0
	track(dex)
	for off in GUARD_SPOTS:
		var g: Enemy = world.spawn_enemy("viper", CityData.JET + off, 70.0, "")
		g.damage = 5.0 if chosen == "norman" else 8.0
		g.drop_boost = 0.35
		track(g)
		guards.append(g)
	world.hud.show_message("SCONTRO FINALE", "Dex Morlan e le sue guardie", Color(1.0, 0.4, 0.3), 2.5)
	objective("Sconfiggi Dex e le sue guardie del corpo!", null)


func _on_briefcase(_p: Pickup) -> void:
	stage = 4
	world.set_objective_target(null)
	world.hud.set_objective("")
	if in_car():
		world.force_exit(world.player)
	var base: Vector3 = world.player.global_position
	var i := 0
	for id in world.chars:
		var p: Protagonist = world.chars[id]
		if p != world.player:
			if p.in_vehicle():
				world.force_exit(p)
			i += 1
			p.teleport(base + Vector3(2.0 * i, 0, 2.0), PI)
	await say(StoryText.M8_END)
	complete()
