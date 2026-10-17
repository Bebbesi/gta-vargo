extends Mission
## Missione 5 — Il piano di Tom: raccogli 4 indizi evitando le telecamere.

# Posizioni delle telecamere relative a ciascun indizio.
const CAM_OFFSETS := [
	[Vector3(-8, 0, 8), Vector3(9, 0, -7)],
	[Vector3(0, 0, 14), Vector3(-14, 0, 0)],
	[Vector3(-8, 0, -6), Vector3(8, 0, 7)],
	[Vector3(0, 0, -4.4), Vector3(12, 0, -4.4)],
]

var clues: Array = []
var cams: Array = []
var found := 0
var alarm := 0.0
var _alarm_sfx := 0.0


func _init() -> void:
	reward = 1500


func intro_lines() -> Array:
	return StoryText.M5_INTRO


func begin() -> void:
	for i in CityData.CLUES.size():
		var cp: Vector3 = CityData.CLUES[i]
		var pk: Pickup = world.spawn_pickup("clue", cp, 0.0)
		track(pk)
		clues.append(pk)
		pk.collected.connect(_on_clue)
		for off in CAM_OFFSETS[i]:
			var cam := SecurityCam.new()
			world.add_child(cam)
			var pos: Vector3 = cp + off
			var dir := cp - pos
			cam.setup(world, pos, atan2(-dir.x, -dir.z))
			cam.add_to_group("security_cams")
			track(cam)
			cams.append(cam)
	_update_objective()
	world.hud.toast("Usa ANALISI (pulsante speciale) per spegnere le telecamere vicine.", 4.0)


func _update_objective() -> void:
	objective("Raccogli gli indizi senza farti vedere dalle telecamere (%d/4)." % found, null)


func _on_clue(_p: Pickup) -> void:
	found += 1
	world.hud.toast("Indizio %d/4 trovato!" % found, 2.0)
	if found >= CityData.CLUES.size():
		stage = 1
		world.hud.set_extra("")
		objective("Torna al rifugio per analizzare gli indizi.", CityData.SAFEHOUSE_DOOR, 4.0)
	else:
		_update_objective()


func on_special(_p: Protagonist) -> void:
	alarm = maxf(0.0, alarm - 20.0)


func update(delta: float) -> void:
	blips = []
	for c in clues:
		if is_instance_valid(c):
			blips.append({"pos": c.global_position, "color": Color(0.35, 0.9, 1.0), "label": "", "kind": "objective"})
	match stage:
		0:
			var seen := false
			var pp: Vector3 = world.player_pos()
			for cam in cams:
				if is_instance_valid(cam) and cam.sees(pp):
					seen = true
					break
			if seen:
				alarm += 60.0 * delta
				_alarm_sfx -= delta
				if _alarm_sfx <= 0.0:
					_alarm_sfx = 0.7
					Sfx.play("alarm", -6.0)
			else:
				alarm = maxf(0.0, alarm - 25.0 * delta)
			world.hud.set_extra("Allarme: %d%%%s" % [int(alarm), "  - TI VEDONO!" if seen else ""])
			if alarm >= 100.0:
				fail("Le telecamere ti hanno scoperto!")
		1:
			if at_target():
				stage = 2
				_finish()


func _finish() -> void:
	world.set_objective_target(null)
	world.hud.set_objective("")
	if in_car():
		world.force_exit(world.player)
	await say(StoryText.M5_END)
	complete()
