extends Mission
## Missione 6 — La corsa di Mike: gara a checkpoint contro Razor entro il tempo limite.

const ROUTE := [
	Vector3(-60, 0, -40), Vector3(-60, 0, 60), Vector3(-60, 0, 120), Vector3(60, 0, 120),
	Vector3(120, 0, 120), Vector3(120, 0, 0), Vector3(120, 0, -60), Vector3(0, 0, -60),
	Vector3(0, 0, -120), Vector3(-60, 0, -120),
]
const TIME_LIMIT := 80.0

var car: Car
var rival: Car
var cp := 0
var countdown := 3.6
var race_started := false
var rival_done := false
var _count_shown := 4


func _init() -> void:
	reward = 2000
	time_fail_reason = "Tempo scaduto! Razor se la ride."


func intro_lines() -> Array:
	return StoryText.M6_INTRO


func begin() -> void:
	var start := CityData.RACE_START
	car = world.spawn_car("sport", start, PI, Color(0.98, 0.82, 0.1))
	track(car)
	rival = world.spawn_car("sport", start + Vector3(-7, 0, 0), PI, Color(0.6, 0.2, 0.85))
	track(rival)
	rival.hostile = true
	rival.npc_driver = true
	rival.model.set_driver(true, Color(0.88, 0.72, 0.6))
	rival.ai_points = ROUTE.duplicate()
	rival.ai_radius = 11.0
	rival.ai_max_speed = 31.0
	rival.ai_mode = Car.AI.PATH
	world.put_in_car(world.player, car)
	car.frozen = true
	rival.frozen = true
	objective("Preparati... la gara sta per iniziare!", null)


func update(delta: float) -> void:
	blips = []
	if is_instance_valid(rival):
		blips.append({"pos": rival.global_position, "color": Color(0.7, 0.3, 1.0), "label": "", "kind": "enemy_far"})
	if not race_started:
		countdown -= delta
		var n := ceili(countdown)
		if n != _count_shown and n > 0 and n <= 3:
			_count_shown = n
			world.hud.show_message(str(n), "", Color.WHITE, 0.6)
			Sfx.play("count")
		if countdown <= 0.0:
			race_started = true
			if is_instance_valid(car):
				car.frozen = false
			rival.frozen = false
			timer = TIME_LIMIT
			world.hud.show_message("VIA!", "", Color(0.4, 1.0, 0.4), 0.8)
			Sfx.play("go")
			_cp_objective()
		return
	if is_instance_valid(rival) and rival.path_done and not rival_done:
		rival_done = true
		world.hud.toast("Razor ha tagliato il traguardo! Finisci comunque entro il tempo.", 3.0)
	if at_target():
		cp += 1
		Sfx.play("checkpoint")
		if cp >= ROUTE.size():
			_finish()
			return
		_cp_objective()
	world.hud.set_extra("Checkpoint %d/%d   ·   Posizione: %s" % [cp, ROUTE.size(), "1°" if _ahead() else "2°"])


func _cp_objective() -> void:
	var last := cp == ROUTE.size() - 1
	var text := "TRAGUARDO! Taglialo prima di Razor." if last else "Checkpoint %d/%d: segui il faro giallo." % [cp + 1, ROUTE.size()]
	objective(text, ROUTE[cp], 11.0)


func _ahead() -> bool:
	if rival_done or not is_instance_valid(rival):
		return false
	if cp != rival.ai_index:
		return cp > rival.ai_index
	var goal: Vector3 = ROUTE[cp]
	return world.player_pos().distance_to(goal) < rival.global_position.distance_to(goal)


func _finish() -> void:
	timer = -1.0
	world.hud.set_timer(-1.0)
	var won := not rival_done
	if won:
		bonus = 500
	world.set_objective_target(null)
	world.hud.set_objective("")
	world.hud.set_extra("")
	if is_instance_valid(rival):
		rival.ai_mode = Car.AI.NONE
	world.hud.show_message("1° POSTO!" if won else "2° POSTO", "Tempo rispettato", Color(1.0, 0.85, 0.3), 2.0)
	await say(StoryText.M6_WIN if won else StoryText.M6_LOSE)
	complete()
