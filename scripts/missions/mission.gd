class_name Mission
extends Node
## Base delle missioni: obiettivi, indicatori (faro + freccia + minimappa),
## timer, oggetti generati, condizioni di successo/fallimento, ricompense.

signal finished(success: bool, reason: String)

var world: Node
var index := 0
var title := ""
var chosen := ""
var reward := 500
var bonus := 0
var stage := 0
var started := false
var done := false
var allow_switch := false
var timer := -1.0
var time_fail_reason := "Tempo scaduto!"
var target: Variant = null
var target_radius := 4.0
var blips: Array = []
var spawned: Array = []
var checkpoint_after := CityData.SAFEHOUSE_DOOR


func intro_lines() -> Array:
	return []


func begin() -> void:
	pass


func update(_delta: float) -> void:
	pass


func on_special(_p: Protagonist) -> void:
	pass


func start() -> void:
	var lines := intro_lines()
	if not lines.is_empty():
		await world.talk(lines)
	if done or not is_inside_tree():
		return
	started = true
	begin()


func tick(delta: float) -> void:
	if not started or done:
		return
	if timer >= 0.0 and world.lock_count == 0:
		timer -= delta
		world.hud.set_timer(maxf(timer, 0.0))
		if timer <= 0.0:
			timer = -1.0
			world.hud.set_timer(-1.0)
			fail(time_fail_reason)
			return
	update(delta)


func objective(text: String, pos: Variant = null, radius: float = 4.0) -> void:
	world.hud.set_objective(text)
	target = pos
	target_radius = radius
	world.set_objective_target(pos, radius)
	if Game.test_mode:
		print("[MISSIONE %d] %s" % [index + 1, text])


func at_target() -> bool:
	if target == null:
		return false
	var t: Vector3 = target
	var pp: Vector3 = world.player_pos()
	return Vector2(pp.x - t.x, pp.z - t.z).length() < target_radius


func player() -> Protagonist:
	return world.player


func in_car() -> bool:
	return world.player.in_vehicle()


func complete() -> void:
	if done:
		return
	done = true
	finished.emit(true, "")


func fail(reason: String) -> void:
	if done:
		return
	done = true
	finished.emit(false, reason)


func track(n: Node) -> Node:
	spawned.append(n)
	if n is Car:
		n.set_meta("mission", true)
	return n


func cleanup() -> void:
	for n in spawned:
		if not is_instance_valid(n):
			continue
		if n is Car:
			var c := n as Car
			c.hostile = false
			c.frozen = false
			if c.driver != null:
				c.remove_meta("mission")
				continue
			if c.ai_mode != Car.AI.NONE:
				c.ai_mode = Car.AI.NONE
			c.queue_free()
		else:
			n.queue_free()
	spawned.clear()
	world.hud.set_extra("")
	world.hud.set_timer(-1.0)
	world.hud.set_objective("")
	world.set_objective_target(null)
	timer = -1.0


func get_blips() -> Array:
	return blips


func say(lines: Array) -> void:
	await world.talk(lines)
