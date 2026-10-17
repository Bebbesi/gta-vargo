extends Mission
## Missione 7 — La sfida di Norman: sopravvivi a tre ondate di Vipere.

const WAVES := [3, 4, 5]
const SPAWNS := [
	Vector3(-104, 0, 154), Vector3(-76, 0, 154), Vector3(-90, 0, 155),
	Vector3(-106, 0, 141), Vector3(-74, 0, 141), Vector3(-96, 0, 150),
]

var wave := 0
var enemies: Array = []
var break_t := 0.0
var _warned := false


func _init() -> void:
	reward = 2500


func intro_lines() -> Array:
	return StoryText.M7_INTRO


func begin() -> void:
	world.set_checkpoint(CityData.YARD_MARK, 0.0)
	objective("Entra nel cortile del magazzino delle Vipere.", CityData.YARD_CENTER, 8.0)


func update(delta: float) -> void:
	blips = []
	Enemy.assign_attackers(enemies, world.player_pos(), 2)
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			blips.append({"pos": e.global_position, "color": Color(0.95, 0.2, 0.2), "label": "", "kind": "enemy"})
	match stage:
		0:
			if at_target():
				stage = 1
				world.set_objective_target(null)
				_start_wave()
		1, 2:
			var d: float = world.player_pos().distance_to(CityData.YARD_CENTER)
			if d > 75.0:
				fail("Hai abbandonato la sfida.")
				return
			if d > 40.0 and not _warned:
				_warned = true
				world.hud.toast("Torna nel cortile o perderai la sfida!", 3.0)
			elif d < 30.0:
				_warned = false
			if stage == 1:
				var alive := blips.size()
				world.hud.set_extra("Ondata %d/3   ·   Vipere rimaste: %d" % [wave, alive])
				if alive == 0:
					if wave >= WAVES.size():
						stage = 3
						_finish()
					else:
						stage = 2
						break_t = 4.0
						world.hud.show_message("ONDATA %d SUPERATA" % wave, "Recupera le forze con i Brown Boost!", Color(0.5, 1.0, 0.5), 2.5)
						for off: Vector3 in [Vector3(-6, 0, -4), Vector3(6, 0, -4)]:
							track(world.spawn_pickup("boost", CityData.YARD_CENTER + off, 0.0))
			else:
				break_t -= delta
				world.hud.set_extra("Prossima ondata tra %d..." % ceili(break_t))
				if break_t <= 0.0:
					stage = 1
					_start_wave()


func _start_wave() -> void:
	wave += 1
	var n: int = WAVES[wave - 1]
	for i in n:
		var boss := wave == WAVES.size() and i == 0
		var pos: Vector3 = SPAWNS[i % SPAWNS.size()] + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0))
		var e: Enemy = world.spawn_enemy("boss" if boss else "viper", pos, 170.0 if boss else 50.0 + wave * 6.0, "Grosso Sal" if boss else "")
		e.boss = boss
		e.damage = 11.0 if boss else 5.0 + wave
		e.speed = 4.6 if boss else randf_range(4.8, 5.6)
		e.drop_boost = 0.25
		track(e)
		enemies.append(e)
	objective("Sconfiggi tutte le Vipere! Ondata %d di %d." % [wave, WAVES.size()], null)
	world.hud.show_message("ONDATA %d" % wave, "%d Vipere in arrivo" % n, Color(1.0, 0.4, 0.3), 2.0)


func _finish() -> void:
	world.hud.set_extra("")
	world.hud.set_objective("")
	await say(StoryText.M7_END)
	complete()
