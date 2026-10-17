class_name IntroCutscene
extends Node
## Scena iniziale: volo AR-77 sopra Port Ardena, guasto al motore,
## atterraggio d'emergenza e scoperta del furto della valigetta.

signal done

var world: Node
var plane: Node3D
var phase := 0
var ang := 2.2
var center := Vector3(80, 150, 10)
var radius := 330.0
var smoke: CPUParticles3D
var fire: CPUParticles3D
var _finished := false
var _skipped := false
var _tween: Tween
var _shake := 0.0


func play() -> void:
	plane = world.airliner
	world.state = "intro"
	world.hud.set_hud_visible(false)
	world.hud.show_skip(true, skip)
	smoke = Gfx.emitter(plane, Color(0.25, 0.25, 0.27), 30, 1.2, 1.0, 2.5)
	smoke.position = Vector3(-6.5, 1.0, 1.0)
	smoke.local_coords = false
	fire = Gfx.emitter(plane, Color(1.0, 0.5, 0.1), 20, 0.7, 2.0, 0.5)
	fire.position = Vector3(-6.5, 1.1, 0.0)
	phase = 1
	_place_on_circle(0.0)
	world.camera.mode = "cinematic_hard"
	_update_camera(0.0)
	Sfx.music(true, -10.0)
	world.hud.fade_instant(true)
	await world.hud.fade(false, 1.2)
	if _skipped:
		return
	await _say(StoryText.INTRO_FLIGHT)
	if _skipped:
		return
	phase = 2
	smoke.emitting = true
	fire.emitting = true
	Sfx.play("explosion")
	_shake = 1.0
	await _say(StoryText.INTRO_INCIDENT)
	if _skipped:
		return
	await world.hud.fade(true, 0.6)
	if _skipped:
		return
	phase = 3
	fire.emitting = false
	plane.global_position = Vector3(361, 42, 380)
	plane.rotation = Vector3(deg_to_rad(-6), 0, 0)
	world.camera.mode = "cinematic_hard"
	world.camera.cine_pos = Vector3(338, 7, 95)
	world.camera.cine_look = plane.global_position
	await world.hud.fade(false, 0.6)
	_tween = create_tween()
	_tween.tween_property(plane, "global_position", Vector3(361, 0.2, 150), 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(plane, "rotation:x", 0.0, 4.0)
	_tween.tween_property(plane, "global_position", Vector3(361, 0.0, -30), 4.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _tween.finished
	if _skipped:
		return
	await world.hud.fade(true, 0.5)
	if _skipped:
		return
	phase = 4
	smoke.emitting = false
	plane.global_position = CityData.AIRPORT_PLANE
	plane.rotation = Vector3.ZERO
	world.place_trio_at_airport()
	world.camera.mode = "cinematic_hard"
	world.camera.cine_pos = CityData.AIRPORT_SPAWN + Vector3(-9, 3.2, 6)
	world.camera.cine_look = CityData.AIRPORT_SPAWN + Vector3(2, 1.4, 0)
	await world.hud.fade(false, 0.6)
	await _say(StoryText.INTRO_LANDING)
	if _skipped:
		return
	_finish()


func _say(lines: Array) -> void:
	world.hud.dialogue.play(lines)
	await world.hud.dialogue.finished


func skip() -> void:
	if _finished:
		return
	_skipped = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	world.hud.dialogue.abort()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	world.hud.show_skip(false, Callable())
	if smoke:
		smoke.queue_free()
	if fire:
		fire.queue_free()
	plane.global_position = CityData.AIRPORT_PLANE
	plane.rotation = Vector3.ZERO
	world.place_trio_at_airport()
	world.hud.fade_instant(false)
	Sfx.music(false)
	done.emit()


func _place_on_circle(bank: float) -> void:
	var pos := center + Vector3(cos(ang) * radius, 0, sin(ang) * radius)
	var dir := Vector3(-sin(ang), 0, cos(ang))
	plane.global_position = pos
	plane.look_at(pos + dir, Vector3.UP)
	plane.rotate_object_local(Vector3(0, 0, 1), bank)


func _process(delta: float) -> void:
	if _finished:
		return
	_shake = maxf(0.0, _shake - delta * 0.4)
	if phase == 1 or phase == 2:
		ang += delta * (0.2 if phase == 1 else 0.24)
		var wobble := sin(Time.get_ticks_msec() * 0.02) * 0.12 * _shake
		_place_on_circle(-0.32 + wobble)
		if phase == 2:
			plane.global_position.y -= 0.0
		_update_camera(delta)
	elif phase == 3:
		world.camera.cine_look = plane.global_position + Vector3(0, 3, 0)


func _update_camera(_delta: float) -> void:
	var fwd := -plane.global_transform.basis.z
	var right := plane.global_transform.basis.x
	var line: int = world.hud.dialogue.index
	var pos := Vector3.ZERO
	var look := plane.global_position
	if phase == 2:
		pos = plane.global_position - right * 34.0 + Vector3(0, 9, 0) + fwd * 10.0
		look = plane.global_position - right * 5.0
	else:
		match line % 3:
			0:
				pos = plane.global_position - fwd * 48.0 + Vector3(0, 14, 0) - right * 14.0
			1:
				pos = plane.global_position + right * 36.0 + Vector3(0, 4, 0) + fwd * 4.0
			_:
				pos = plane.global_position + fwd * 40.0 + Vector3(0, -6, 0) + right * 18.0
	if _shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.8
	world.camera.cine_pos = pos
	world.camera.cine_look = look
