extends Mission
## Missione 4 — Fuga improvvisa: semina tre auto delle Vipere.

const ESCAPE_DIST := 150.0

var chasers: Array = []
var getaway: Car
var escape_t := 0.0
var elapsed := 0.0


func _init() -> void:
	reward = 1200


func intro_lines() -> Array:
	return StoryText.M4_INTRO


func begin() -> void:
	var pp: Vector3 = world.player_pos()
	if not in_car():
		var sp: Dictionary = world.road_spawn(pp, 8.0, 35.0)
		getaway = world.spawn_car("muscle", sp["pos"], sp["yaw"], Color(0.95, 0.55, 0.1))
		track(getaway)
		objective("Sali sull'auto arancione e scappa!", sp["pos"], 4.0)
	else:
		stage = 1
		_escape_objective()
	for i in 3:
		var s: Dictionary = world.road_spawn(pp, 70.0, 130.0)
		var c: Car = world.spawn_car("viper", s["pos"], s["yaw"])
		c.hostile = true
		c.npc_driver = true
		c.model.set_driver(true, Color(0.8, 0.64, 0.5))
		c.ai_max_speed = 29.0 + i * 1.5
		track(c)
		chasers.append(c)
	world.hud.toast("Le Vipere stanno arrivando!", 3.0)


func _escape_objective() -> void:
	objective("Semina le Vipere! Allontanati di almeno %d metri." % int(ESCAPE_DIST), null)


func update(delta: float) -> void:
	elapsed += delta
	blips = []
	var min_d := INF
	var alive := 0
	for c in chasers:
		if not is_instance_valid(c) or c.wrecked:
			continue
		alive += 1
		if elapsed > 2.5 and c.ai_mode == Car.AI.NONE:
			c.ai_mode = Car.AI.CHASE
			c.ai_target = world.player
		min_d = minf(min_d, c.global_position.distance_to(world.player_pos()))
		blips.append({"pos": c.global_position, "color": Color(0.85, 0.25, 0.95), "label": "", "kind": "enemy_far"})
	match stage:
		0:
			if in_car():
				stage = 1
				_escape_objective()
		1:
			if alive == 0:
				_won("Hai messo fuori uso tutte le auto delle Vipere!")
				return
			world.hud.set_extra("Vipera più vicina: %d m" % int(min_d))
			if min_d > ESCAPE_DIST:
				escape_t += delta
				if escape_t > 3.0:
					_won("Vipere seminate!")
			else:
				escape_t = 0.0


func _won(msg: String) -> void:
	stage = 2
	for c in chasers:
		if is_instance_valid(c):
			c.ai_mode = Car.AI.NONE
	world.hud.set_extra("")
	world.hud.toast(msg, 3.0)
	world.set_objective_target(null)
	world.hud.set_objective("")
	await say(StoryText.M4_END)
	complete()
