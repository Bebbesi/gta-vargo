extends Mission
## Missione 3 — Il pacco misterioso: recupera il pacco al porto e consegnalo a Lenny.

var package: Pickup
var lenny: Node3D


func _init() -> void:
	reward = 1000


func intro_lines() -> Array:
	return StoryText.M3_INTRO


func begin() -> void:
	package = world.spawn_pickup("package", CityData.DOCKS_PACKAGE, 0.0)
	track(package)
	package.collected.connect(_on_package)
	lenny = Props.npc(world, "lenny", CityData.LENNY_POS, PI, "Lenny")
	track(lenny)
	objective("Vai al porto e recupera il pacco misterioso.", CityData.DOCKS_PACKAGE, 2.5)
	blips = [{"pos": CityData.LENNY_POS, "color": Color(0.75, 0.95, 0.55), "label": "L", "kind": "icon"}]


func _on_package(_p: Pickup) -> void:
	stage = 1
	world.hud.set_extra("Pacco recuperato")
	world.hud.toast("Hai il pacco. È più pesante di quanto sembri...", 3.0)
	objective("Consegna il pacco a Lenny in Piazza del Corvo.", CityData.LENNY_POS, 6.0)


func update(_delta: float) -> void:
	if stage == 1 and at_target():
		stage = 2
		_deliver()


func _deliver() -> void:
	world.set_objective_target(null)
	world.hud.set_objective("")
	world.hud.set_extra("")
	await say(StoryText.M3_END)
	complete()
