extends Mission
## Missione 2 — Prima automobile: trova un'auto e portala nel garage di Gus.

var hint_given := false


func _init() -> void:
	reward = 750


func intro_lines() -> Array:
	return StoryText.M2_INTRO


func begin() -> void:
	world.set_checkpoint(CityData.SAFEHOUSE_DOOR, PI)
	if in_car():
		stage = 1
		_drive_objective()
	else:
		objective("Raggiungi il parcheggio a ovest e sali su un'auto.", CityData.PARKING_LOT, 14.0)


func _drive_objective() -> void:
	objective("Guida fino al garage di Gus.", CityData.GARAGE_DOOR, 9.0)


func update(_delta: float) -> void:
	match stage:
		0:
			if in_car():
				stage = 1
				_drive_objective()
			elif at_target() and not hint_given:
				hint_given = true
				world.hud.toast("Avvicinati a un'auto e premi ENTRA per salire.", 3.0)
		1:
			if not in_car():
				stage = 0
				objective("Sali su un'auto per continuare.", null)
			elif at_target():
				stage = 2
				objective("Entra nel garage e fermati sulle strisce arancioni.", CityData.GARAGE_INSIDE, 6.0)
		2:
			if not in_car():
				stage = 0
				objective("Sali su un'auto per continuare.", null)
			elif at_target() and absf(world.player.vehicle.speed) < 1.5:
				stage = 3
				_finish()


func _finish() -> void:
	world.set_objective_target(null)
	world.hud.set_objective("")
	await say(StoryText.M2_END)
	complete()
