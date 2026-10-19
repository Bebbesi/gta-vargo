extends Node
## Stato globale di GTA: Three Legends: protagonisti, progressi, denaro,
## impostazioni e salvataggi locali (nessun servizio online).

signal money_changed(value: int)
signal boosts_changed(value: int)
signal weapon_changed(id: String)
signal settings_changed

const SAVE_PATH := "user://savegame.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_VERSION := 1
const MAX_BOOSTS := 5
const BOOST_HEAL := 35.0
const TOTAL_MISSIONS := 8
const KO_FEE := 100
const BUSTED_FEE := 200
const TOTAL_FEATHERS := 10
const VERSION := "1.1.0"

const WEAPON_ORDER := ["fists", "pistol", "smg", "shotgun", "rifle"]
## Armi del gioco. damage per proiettile, rate = secondi tra un colpo e l'altro,
## spread in gradi, ammo_pack = colpi per caricatore/pacco acquistato o raccolto.
const WEAPONS := {
	"fists": {"name": "PUGNI", "damage": 0.0, "rate": 0.42, "range": 2.2, "spread": 0.0, "pellets": 1,
		"sound": "", "ammo_pack": 0, "price": 0, "ammo_price": 0, "two_hands": false},
	"pistol": {"name": "PISTOLA", "damage": 24.0, "rate": 0.32, "range": 45.0, "spread": 1.5, "pellets": 1,
		"sound": "pistol", "ammo_pack": 24, "price": 300, "ammo_price": 60, "two_hands": false},
	"smg": {"name": "MITRAGLIETTA", "damage": 11.0, "rate": 0.09, "range": 38.0, "spread": 4.0, "pellets": 1,
		"sound": "smg", "ammo_pack": 60, "price": 900, "ammo_price": 90, "two_hands": true},
	"shotgun": {"name": "FUCILE A POMPA", "damage": 10.0, "rate": 0.85, "range": 22.0, "spread": 5.5, "pellets": 7,
		"sound": "shotgun", "ammo_pack": 12, "price": 1200, "ammo_price": 80, "two_hands": true},
	"rifle": {"name": "FUCILE D'ASSALTO", "damage": 19.0, "rate": 0.13, "range": 70.0, "spread": 1.6, "pellets": 1,
		"sound": "rifle", "ammo_pack": 60, "price": 2500, "ammo_price": 150, "two_hands": true},
}

const CHAR_ORDER := ["mike", "tom", "norman"]

const CHARACTERS := {
	"mike": {
		"name": "Mike Vargo",
		"short": "MIKE",
		"initial": "M",
		"color": Color(0.92, 0.3, 0.22),
		"role": "Il pilota",
		"desc": "Coraggioso e imbattibile al volante. Con Mike le auto sono più veloci.",
		"special": "NITRO",
		"special_desc": "In auto: turbo nitro. A piedi: scatto rapido.",
		"max_health": 100.0,
		"run_speed": 8.4,
		"punch": 16.0,
		"drive": 1.18,
		"money_bonus": 1.0,
		"look": {
			"jacket": Color(0.72, 0.15, 0.12), "shirt": Color(0.95, 0.93, 0.88),
			"pants": Color(0.16, 0.2, 0.32), "skin": Color(0.89, 0.7, 0.55),
			"hair": Color(0.28, 0.17, 0.09), "shoes": Color(0.12, 0.1, 0.1),
			"hair_style": "short", "extra": "shades", "scale": 1.0,
		},
	},
	"tom": {
		"name": "Tom Pearl",
		"short": "TOM",
		"initial": "T",
		"color": Color(0.3, 0.6, 0.95),
		"role": "Lo stratega",
		"desc": "Mente brillante: trova indizi, hackera le telecamere e guadagna di più dalle missioni.",
		"special": "ANALISI",
		"special_desc": "Disattiva le telecamere vicine e rivela gli oggetti nascosti sulla mappa.",
		"max_health": 90.0,
		"run_speed": 7.6,
		"punch": 12.0,
		"drive": 1.0,
		"money_bonus": 1.25,
		"look": {
			"jacket": Color(0.15, 0.22, 0.42), "shirt": Color(0.97, 0.97, 0.97),
			"pants": Color(0.15, 0.2, 0.36), "skin": Color(0.95, 0.8, 0.68),
			"hair": Color(0.85, 0.68, 0.35), "shoes": Color(0.25, 0.15, 0.08),
			"hair_style": "slick", "extra": "glasses_tie", "scale": 0.97,
		},
	},
	"norman": {
		"name": "Norman Summerton",
		"short": "NORMAN",
		"initial": "N",
		"color": Color(0.45, 0.8, 0.35),
		"role": "Il lottatore",
		"desc": "Ex pugile: resistente, colpi devastanti e nervi d'acciaio.",
		"special": "FURIA",
		"special_desc": "Onda d'urto, danni raddoppiati e metà dei danni subiti per alcuni secondi.",
		"max_health": 150.0,
		"run_speed": 7.0,
		"punch": 32.0,
		"drive": 0.95,
		"money_bonus": 1.0,
		"look": {
			"jacket": Color(0.33, 0.4, 0.2), "shirt": Color(0.33, 0.4, 0.2),
			"pants": Color(0.4, 0.33, 0.24), "skin": Color(0.55, 0.38, 0.27),
			"hair": Color(0.12, 0.1, 0.08), "shoes": Color(0.2, 0.18, 0.15),
			"hair_style": "bald", "extra": "beard", "scale": 1.14,
		},
	},
}

const SPEAKERS := {
	"mike": ["Mike Vargo", Color(0.95, 0.4, 0.3)],
	"tom": ["Tom Pearl", Color(0.45, 0.7, 1.0)],
	"norman": ["Norman Summerton", Color(0.55, 0.9, 0.45)],
	"pilot": ["Comandante Reyes", Color(0.75, 0.85, 0.95)],
	"lenny": ["Lenny \"Fumo\"", Color(0.75, 0.95, 0.55)],
	"gus": ["Gus", Color(1.0, 0.72, 0.3)],
	"razor": ["Razor", Color(0.85, 0.5, 1.0)],
	"dex": ["Dex Morlan", Color(0.92, 0.92, 0.92)],
	"narrator": ["", Color(0.9, 0.9, 0.8)],
}

const NPC_LOOKS := {
	"gus": {"jacket": Color(0.25, 0.35, 0.55), "shirt": Color(0.25, 0.35, 0.55), "pants": Color(0.25, 0.35, 0.55),
		"skin": Color(0.9, 0.72, 0.6), "hair": Color(0.85, 0.3, 0.1), "shoes": Color(0.1, 0.1, 0.1),
		"hair_style": "cap", "extra": "beard", "scale": 1.05},
	"lenny": {"jacket": Color(0.35, 0.55, 0.25), "shirt": Color(0.2, 0.2, 0.2), "pants": Color(0.3, 0.3, 0.32),
		"skin": Color(0.8, 0.62, 0.48), "hair": Color(0.2, 0.2, 0.22), "shoes": Color(0.9, 0.9, 0.9),
		"hair_style": "beanie", "extra": "", "scale": 0.95},
	"razor": {"jacket": Color(0.45, 0.15, 0.55), "shirt": Color(0.1, 0.1, 0.1), "pants": Color(0.1, 0.1, 0.12),
		"skin": Color(0.88, 0.72, 0.6), "hair": Color(0.85, 0.85, 0.9), "shoes": Color(0.1, 0.1, 0.1),
		"hair_style": "spiky", "extra": "shades", "scale": 1.0},
	"dex": {"jacket": Color(0.93, 0.93, 0.9), "shirt": Color(0.1, 0.1, 0.12), "pants": Color(0.9, 0.9, 0.88),
		"skin": Color(0.9, 0.75, 0.62), "hair": Color(0.08, 0.08, 0.1), "shoes": Color(0.1, 0.1, 0.1),
		"hair_style": "slick", "extra": "crow_pin", "scale": 1.0},
	"viper": {"jacket": Color(0.12, 0.12, 0.14), "shirt": Color(0.5, 0.15, 0.6), "pants": Color(0.18, 0.18, 0.2),
		"skin": Color(0.82, 0.64, 0.5), "hair": Color(0.5, 0.15, 0.6), "shoes": Color(0.08, 0.08, 0.08),
		"hair_style": "short", "extra": "bandana", "scale": 1.0},
	"cop": {"jacket": Color(0.12, 0.18, 0.38), "shirt": Color(0.6, 0.75, 0.95), "pants": Color(0.1, 0.12, 0.22),
		"skin": Color(0.86, 0.68, 0.54), "hair": Color(0.1, 0.14, 0.3), "shoes": Color(0.06, 0.06, 0.06),
		"hair_style": "cap", "extra": "", "scale": 1.02},
	"swat": {"jacket": Color(0.12, 0.12, 0.14), "shirt": Color(0.18, 0.18, 0.2), "pants": Color(0.1, 0.1, 0.12),
		"skin": Color(0.8, 0.62, 0.5), "hair": Color(0.06, 0.06, 0.08), "shoes": Color(0.05, 0.05, 0.05),
		"hair_style": "cap", "extra": "shades", "scale": 1.08},
	"boss": {"jacket": Color(0.35, 0.08, 0.42), "shirt": Color(0.1, 0.1, 0.1), "pants": Color(0.12, 0.12, 0.14),
		"skin": Color(0.6, 0.45, 0.35), "hair": Color(0.1, 0.1, 0.1), "shoes": Color(0.08, 0.08, 0.08),
		"hair_style": "bald", "extra": "bandana", "scale": 1.25},
}

var money: int = 0
var missions_done: int = 0
var boosts: int = 0
var weapons: Dictionary = {"fists": 0}
var current_weapon: String = "fists"
var feathers: Array = []
var current_char: String = "mike"
var char_state: Dictionary = {}
var intro_seen: bool = false
var ending_seen: bool = false
var play_time: float = 0.0
var test_mode: bool = false
var pending_continue: bool = false
## Parametri della partita multiplayer da avviare dopo il ricaricamento della scena.
var pending_mp: Dictionary = {}
## Messaggio da mostrare nel menu principale (es. "connessione persa").
var pending_message: String = ""

var settings: Dictionary = {
	"master": 0.9,
	"music": 0.5,
	"sfx": 0.9,
	"quality": 1,
	"cam_sens": 1.0,
	"show_fps": false,
	"touch_opacity": 0.8,
	"vibration": true,
	"invert_y": false,
	"player_name": "",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	test_mode = args.has("--run-tests")
	_setup_input()
	if OS.has_feature("mobile"):
		Engine.max_fps = 60
	else:
		# Su desktop il mouse simula il tocco, così i comandi touch sono provabili.
		Input.emulate_touch_from_mouse = true
	load_settings()


func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"accelerate": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"attack": [KEY_J, KEY_CTRL],
		"vehicle": [KEY_F, KEY_ENTER],
		"special": [KEY_R],
		"use_boost": [KEY_B],
		"switch_char": [KEY_TAB, KEY_Q],
		"char_1": [KEY_1],
		"char_2": [KEY_2],
		"char_3": [KEY_3],
		"horn": [KEY_H],
		"pause": [KEY_ESCAPE, KEY_P],
		"map": [KEY_M],
		"weapon_next": [KEY_E, KEY_X],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func char_data(id: String) -> Dictionary:
	return CHARACTERS.get(id, CHARACTERS["mike"])


# ---------------------------------------------------------------- partita

func new_game() -> void:
	money = 250
	missions_done = 0
	boosts = 1
	weapons = {"fists": 0}
	current_weapon = "fists"
	feathers = []
	current_char = "mike"
	char_state = {}
	intro_seen = false
	ending_seen = false
	play_time = 0.0
	money_changed.emit(money)
	boosts_changed.emit(boosts)


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)


func add_boost() -> bool:
	if boosts >= MAX_BOOSTS:
		return false
	boosts += 1
	boosts_changed.emit(boosts)
	return true


# ---------------------------------------------------------------- armi

func give_weapon(id: String, ammo: int) -> void:
	if not WEAPONS.has(id):
		return
	var first := not weapons.has(id)
	weapons[id] = int(weapons.get(id, 0)) + ammo
	if first or current_weapon == "fists":
		current_weapon = id
	weapon_changed.emit(current_weapon)


func equip_weapon(id: String) -> void:
	if weapons.has(id):
		current_weapon = id
		weapon_changed.emit(id)


func ammo() -> int:
	return int(weapons.get(current_weapon, 0))


func use_ammo() -> bool:
	if current_weapon == "fists":
		return true
	var a := ammo()
	if a <= 0:
		return false
	weapons[current_weapon] = a - 1
	return true


## Passa all'arma successiva con munizioni (i pugni sono sempre disponibili).
func next_weapon() -> String:
	var start := WEAPON_ORDER.find(current_weapon)
	for k in range(1, WEAPON_ORDER.size() + 1):
		var id: String = WEAPON_ORDER[(start + k) % WEAPON_ORDER.size()]
		if id == "fists" or int(weapons.get(id, 0)) > 0:
			current_weapon = id
			break
	weapon_changed.emit(current_weapon)
	return current_weapon


func confiscate_weapons() -> void:
	weapons = {"fists": 0}
	current_weapon = "fists"
	weapon_changed.emit(current_weapon)


func player_name() -> String:
	var n := str(settings.get("player_name", "")).strip_edges()
	if n == "":
		n = "Giocatore %d" % (randi() % 90 + 10)
		settings["player_name"] = n
	return n.substr(0, 16)


func take_boost() -> bool:
	if boosts <= 0:
		return false
	boosts -= 1
	boosts_changed.emit(boosts)
	return true


# ---------------------------------------------------------------- salvataggi

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(chars: Dictionary) -> bool:
	char_state = chars
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"missions_done": missions_done,
		"boosts": boosts,
		"weapons": weapons,
		"current_weapon": current_weapon,
		"feathers": feathers,
		"current_char": current_char,
		"intro_seen": intro_seen,
		"ending_seen": ending_seen,
		"play_time": play_time,
		"chars": chars,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Impossibile salvare: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Salvataggio danneggiato")
		return false
	var d: Dictionary = parsed
	money = int(d.get("money", 0))
	missions_done = clampi(int(d.get("missions_done", 0)), 0, TOTAL_MISSIONS)
	boosts = clampi(int(d.get("boosts", 0)), 0, MAX_BOOSTS)
	weapons = {"fists": 0}
	var w: Variant = d.get("weapons", {})
	if typeof(w) == TYPE_DICTIONARY:
		for k in w:
			if WEAPONS.has(str(k)):
				weapons[str(k)] = maxi(0, int(w[k]))
	current_weapon = str(d.get("current_weapon", "fists"))
	if not weapons.has(current_weapon):
		current_weapon = "fists"
	weapon_changed.emit(current_weapon)
	feathers = d.get("feathers", [])
	current_char = str(d.get("current_char", "mike"))
	if not CHARACTERS.has(current_char):
		current_char = "mike"
	intro_seen = bool(d.get("intro_seen", true))
	ending_seen = bool(d.get("ending_seen", false))
	play_time = float(d.get("play_time", 0.0))
	char_state = d.get("chars", {})
	money_changed.emit(money)
	boosts_changed.emit(boosts)
	return true


func save_info() -> String:
	if not has_save():
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = parsed
	return "Missioni %d/%d  ·  $%d" % [int(d.get("missions_done", 0)), TOTAL_MISSIONS, int(d.get("money", 0))]


# ---------------------------------------------------------------- impostazioni

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for key in settings.keys():
			settings[key] = cfg.get_value("settings", key, settings[key])
	elif OS.has_feature("mobile"):
		settings["quality"] = 1
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


func apply_settings() -> void:
	_set_bus("Master", float(settings["master"]))
	_set_bus("Music", float(settings["music"]))
	_set_bus("SFX", float(settings["sfx"]))
	settings_changed.emit()


func _set_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)


func vibrate(ms: int) -> void:
	if bool(settings["vibration"]) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
