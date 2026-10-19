extends Node
## Audio procedurale: tutti gli effetti e la musica sono sintetizzati in codice
## all'avvio, quindi il gioco non contiene file audio protetti da copyright.

const RATE := 22050
const MUSIC_RATE := 16000

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var music_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer
var siren_player: AudioStreamPlayer
var heli_player: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _music_task := -1
var _want_music := false
var _music_volume_db := -6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	engine_player = AudioStreamPlayer.new()
	engine_player.bus = "SFX"
	engine_player.volume_db = -14.0
	add_child(engine_player)
	siren_player = AudioStreamPlayer.new()
	siren_player.bus = "SFX"
	add_child(siren_player)
	heli_player = AudioStreamPlayer.new()
	heli_player.bus = "SFX"
	add_child(heli_player)
	_build_sounds()
	engine_player.stream = _streams["engine"]
	siren_player.stream = _streams["siren"]
	heli_player.stream = _streams["heli"]
	Game.apply_settings()
	if not Game.test_mode:
		_music_task = WorkerThreadPool.add_task(_build_music)


func _process(_delta: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		music_player.stream = _music_stream
		if _want_music:
			_start_music()


func _exit_tree() -> void:
	# Attende la generazione della musica prima di chiudere (evita crash in uscita).
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func _make_buses() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


# ---------------------------------------------------------------- API

func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(sound: String, pos: Vector3, listener: Vector3, max_dist: float = 60.0, volume_db: float = 0.0) -> void:
	var d := pos.distance_to(listener)
	if d > max_dist:
		return
	play(sound, volume_db - d / max_dist * 18.0, randf_range(0.92, 1.08))


func music(on: bool, volume_db: float = -6.0) -> void:
	_want_music = on
	_music_volume_db = volume_db
	if on:
		_start_music()
	else:
		music_player.stop()


func _start_music() -> void:
	music_player.volume_db = _music_volume_db
	if music_player.stream != null and not music_player.playing:
		music_player.play()


func set_engine(on: bool, speed_ratio: float = 0.0) -> void:
	if on:
		if not engine_player.playing:
			engine_player.play()
		engine_player.pitch_scale = 0.7 + clampf(speed_ratio, 0.0, 1.3) * 1.5
		engine_player.volume_db = -16.0 + clampf(speed_ratio, 0.0, 1.0) * 6.0
	elif engine_player.playing:
		engine_player.stop()


## Sirena della polizia: `volume` 0..1 in base alla distanza della pattuglia più vicina.
func set_siren(volume: float) -> void:
	_loop(siren_player, volume, -22.0, -8.0)


func set_heli(volume: float) -> void:
	_loop(heli_player, volume, -24.0, -6.0)


func _loop(p: AudioStreamPlayer, volume: float, min_db: float, max_db: float) -> void:
	if volume <= 0.01:
		if p.playing:
			p.stop()
		return
	p.volume_db = lerpf(min_db, max_db, clampf(volume, 0.0, 1.0))
	if not p.playing:
		p.play()


# ---------------------------------------------------------------- sintesi

func _wav(samples: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


static func _osc(kind: String, phase: float) -> float:
	var f := phase - floorf(phase)
	match kind:
		"square":
			return 1.0 if f < 0.5 else -1.0
		"saw":
			return f * 2.0 - 1.0
		"tri":
			return 4.0 * absf(f - 0.5) - 1.0
		_:
			return sin(phase * TAU)


func _notes(freqs: Array, note_len: float, kind: String = "square", vol: float = 0.35, tail: float = 0.0) -> PackedFloat32Array:
	var n_note := int(note_len * RATE)
	var total := n_note * freqs.size() + int(tail * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase := 0.0
	for i in total:
		var ni := mini(i / n_note, freqs.size() - 1)
		var local := float(i - ni * n_note) / RATE
		var f: float = freqs[ni]
		phase += f / RATE
		var env := exp(-local * 6.0)
		if i >= n_note * freqs.size():
			env = exp(-local * 3.0)
		out[i] = _osc(kind, phase) * vol * env
	return out


func _sweep(f0: float, f1: float, dur: float, kind: String = "sine", vol: float = 0.4, noise: float = 0.0) -> PackedFloat32Array:
	var total := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase := 0.0
	var lp := 0.0
	for i in total:
		var t := float(i) / total
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.3
		var env := (1.0 - t) * minf(1.0, t * 40.0)
		out[i] = (_osc(kind, phase) * (1.0 - noise) + lp * noise) * vol * env
	return out


func _noise(dur: float, vol: float, smooth: float, decay: float, thump: float = 0.0) -> PackedFloat32Array:
	var total := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var lp := 0.0
	var phase := 0.0
	for i in total:
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * smooth
		phase += lerpf(140.0, 45.0, minf(t * 6.0, 1.0)) / RATE
		var env := exp(-t * decay)
		out[i] = (lp * vol + sin(phase * TAU) * thump * exp(-t * 14.0)) * env
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	if b.size() > out.size():
		out.resize(b.size())
	for i in b.size():
		out[i] += b[i]
	return out


func _build_sounds() -> void:
	_streams["pickup"] = _wav(_notes([660.0, 880.0, 1320.0], 0.06, "square", 0.25, 0.12))
	_streams["boost"] = _wav(_mix(_sweep(260.0, 920.0, 0.45, "tri", 0.45), _notes([523.0, 659.0, 784.0, 1047.0], 0.07, "sine", 0.2)))
	_streams["punch"] = _wav(_noise(0.18, 0.7, 0.35, 22.0, 0.9))
	_streams["swing"] = _wav(_sweep(900.0, 300.0, 0.12, "sine", 0.0, 1.0))
	_streams["hurt"] = _wav(_sweep(320.0, 160.0, 0.2, "square", 0.25))
	_streams["crash"] = _wav(_noise(0.6, 0.9, 0.5, 6.0, 1.0))
	_streams["explosion"] = _wav(_noise(1.2, 1.0, 0.18, 3.0, 1.0))
	_streams["horn"] = _wav(_mix(_notes([392.0], 0.42, "square", 0.18), _notes([494.0], 0.42, "square", 0.15)))
	_streams["checkpoint"] = _wav(_notes([1046.0, 1568.0], 0.07, "sine", 0.35, 0.1))
	_streams["click"] = _wav(_notes([1400.0], 0.03, "square", 0.15))
	_streams["door"] = _wav(_noise(0.15, 0.6, 0.12, 25.0, 0.6))
	_streams["switch"] = _wav(_sweep(200.0, 1200.0, 0.5, "sine", 0.3, 0.6))
	_streams["nitro"] = _wav(_sweep(120.0, 700.0, 0.7, "saw", 0.3, 0.5))
	_streams["count"] = _wav(_notes([660.0], 0.18, "square", 0.3))
	_streams["go"] = _wav(_notes([1320.0], 0.45, "square", 0.3))
	_streams["alarm"] = _wav(_notes([880.0, 660.0, 880.0, 660.0], 0.12, "square", 0.25))
	_streams["ko"] = _wav(_sweep(440.0, 70.0, 0.9, "saw", 0.35))
	_streams["mission_pass"] = _wav(_notes([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.11, "square", 0.25, 0.6))
	_streams["mission_fail"] = _wav(_notes([392.0, 330.0, 262.0, 196.0], 0.16, "saw", 0.25, 0.5))
	_streams["cash"] = _wav(_notes([1568.0, 2093.0], 0.05, "square", 0.2, 0.15))
	_streams["feather"] = _wav(_notes([784.0, 988.0, 1175.0, 1568.0], 0.06, "tri", 0.35, 0.3))
	_streams["engine"] = _wav(_engine_loop(), RATE, true)
	_streams["pistol"] = _wav(_mix(_noise(0.22, 0.9, 0.6, 18.0, 0.8), _sweep(900.0, 200.0, 0.06, "square", 0.2)))
	_streams["smg"] = _wav(_mix(_noise(0.11, 0.8, 0.7, 30.0, 0.5), _sweep(1200.0, 300.0, 0.04, "square", 0.15)))
	_streams["shotgun"] = _wav(_noise(0.45, 1.0, 0.3, 8.0, 1.0))
	_streams["rifle"] = _wav(_mix(_noise(0.16, 0.9, 0.55, 22.0, 0.7), _sweep(700.0, 150.0, 0.05, "saw", 0.2)))
	_streams["empty"] = _wav(_notes([2200.0], 0.02, "square", 0.2))
	_streams["reload"] = _wav(_mix(_notes([800.0], 0.03, "square", 0.15), _noise(0.12, 0.4, 0.4, 30.0, 0.0)))
	_streams["busted"] = _wav(_notes([523.0, 392.0, 330.0, 262.0], 0.18, "square", 0.25, 0.4))
	_streams["siren"] = _wav(_siren_loop(), RATE, true)
	_streams["heli"] = _wav(_heli_loop(), RATE, true)


func _siren_loop() -> PackedFloat32Array:
	# Sirena bitonale (700/950 Hz), 1,2 s in loop.
	var total := int(1.2 * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase := 0.0
	for i in total:
		var t := float(i) / RATE
		var f := 700.0 if t < 0.6 else 950.0
		phase += f / RATE
		out[i] = (_osc("tri", phase) * 0.7 + _osc("square", phase) * 0.15) * 0.45
	return out


func _heli_loop() -> PackedFloat32Array:
	# Pale del rotore: colpi di rumore filtrato a 11 Hz.
	var total := RATE
	var out := PackedFloat32Array()
	out.resize(total)
	var lp := 0.0
	for i in total:
		var t := float(i) / RATE
		var beat := fmod(t * 11.0, 1.0)
		lp += (randf_range(-1.0, 1.0) - lp) * 0.12
		out[i] = (lp * 0.9 * exp(-beat * 6.0) + sin(TAU * 60.0 * t) * 0.15) * 0.8
	return out


func _engine_loop() -> PackedFloat32Array:
	# 0,5 s di rombo: armoniche di una sega a 55 Hz con leggero rumore.
	var total := RATE / 2
	var out := PackedFloat32Array()
	out.resize(total)
	var lp := 0.0
	for i in total:
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.08
		var s := _osc("saw", t * 56.0) * 0.45 + sin(t * 112.0 * TAU) * 0.25 + _osc("square", t * 28.0) * 0.15
		out[i] = s * 0.6 + lp * 0.35
	return out


func _build_music() -> void:
	# Loop originale "Port Ardena" (100 BPM, Am - F - C - G), generato in un thread.
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bars := 4
	var total := int(beat * 4.0 * bars * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var roots := [110.0, 87.31, 130.81, 98.0]
	var chords := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
	var lead := [659.25, 523.25, 587.33, 523.25, 440.0, 523.25, 392.0, 440.0,
		523.25, 440.0, 392.0, 329.63, 392.0, 440.0, 493.88, 392.0]
	var lp := 0.0
	for i in total:
		var t := float(i) / MUSIC_RATE
		var beat_pos := t / beat
		var bar := int(beat_pos / 4.0) % bars
		var in_beat := beat_pos - floorf(beat_pos)
		var eighth := beat_pos * 2.0
		var in_eighth := eighth - floorf(eighth)
		var root: float = roots[bar]
		var s := 0.0
		# basso a ottavi
		s += _osc("square", t * root) * 0.16 * exp(-in_eighth * 3.0)
		# accordo pad
		var ch: Array = chords[bar]
		for f in ch:
			s += _osc("saw", t * float(f) * 0.5) * 0.035
		# melodia
		var li := int(eighth / 2.0) % lead.size()
		var lf: float = lead[li]
		s += _osc("tri", t * lf) * 0.11 * exp(-fmod(eighth, 2.0) * 1.2)
		# cassa sui tempi 1 e 3, rullante sul 2 e 4
		var beat_i := int(beat_pos) % 4
		if beat_i == 0 or beat_i == 2:
			s += sin(TAU * t * lerpf(120.0, 40.0, minf(in_beat * 8.0, 1.0))) * 0.5 * exp(-in_beat * 14.0)
		else:
			lp += (randf_range(-1.0, 1.0) - lp) * 0.5
			s += lp * 0.22 * exp(-in_beat * 18.0)
		# charleston in levare
		if in_eighth < 0.12 and int(eighth) % 2 == 1:
			s += randf_range(-1.0, 1.0) * 0.05
		out[i] = s * 0.8
	_music_stream = _wav(out, MUSIC_RATE, true)
