extends Mission
## Missione 1 — Arrivo in città: dall'aeroporto al rifugio (tutorial).

var boost: Pickup
var hinted := false


func _init() -> void:
	reward = 500


func begin() -> void:
	if world.player.char_id != "mike":
		world.switch_to("mike", true)
	var mike: Protagonist = world.chars["mike"]
	world.chars["tom"].teleport(Vector3(146.5, 0, -139.5), PI)
	world.chars["norman"].teleport(Vector3(153.5, 0, -139.5), PI)
	mike.health = 55.0
	boost = world.spawn_pickup("boost", CityData.TERMINAL_BOOST, 0.0)
	track(boost)
	world.set_checkpoint(CityData.AIRPORT_SPAWN, PI * 0.5)
	objective("Attraversa il terminal e raggiungi l'uscita dell'aeroporto.", CityData.AIRPORT_EXIT, 5.0)
	world.hud.toast("Joystick a sinistra per muoverti, trascina a destra per girare la visuale.", 5.0)


func update(_delta: float) -> void:
	match stage:
		0:
			if not hinted and world.player_pos().distance_to(CityData.TERMINAL_BOOST) < 20.0:
				hinted = true
				world.hud.toast("Sei ferito! Raccogli il Brown Boost marrone per recuperare salute.", 4.0)
			if at_target():
				stage = 1
				objective("Raggiungi il rifugio a nord-est della città.", CityData.SAFEHOUSE_DOOR, 4.0)
				world.hud.toast("Puoi anche prendere un'auto: avvicinati e premi ENTRA.", 4.0)
		1:
			if at_target():
				stage = 2
				_arrive()


func _arrive() -> void:
	world.set_objective_target(null)
	world.hud.set_objective("")
	if in_car():
		world.force_exit(world.player)
	await say(StoryText.M1_END)
	complete()
