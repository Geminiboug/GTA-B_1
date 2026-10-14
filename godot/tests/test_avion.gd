extends SceneTree
## Test du trafic aerien : un decollage puis un atterrissage forces, positions et vitesses relevees.
## Lancement : godot --headless --path godot --script res://tests/test_avion.gd

var frame := 0
var air: Node


func _initialize() -> void:
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	air = scene.get_node("TraficAerien")


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 10:
		air._begin_takeoff()
	if frame in [600, 1500, 2400]:
		print("TEST decollage t=%ds : vitesse %.0f km/h, distance %.0f m, hauteur %.0f m" % [frame / 60, air._speed * 3.6, air._dist, air._height])
	if frame == 2410:
		air._finish()
		air._begin_landing()
	if frame in [3000, 4800, 6000]:
		print("TEST atterrissage t=%ds : vitesse %.0f km/h, distance au toucher %.0f m, hauteur %.0f m, etat %s" % [(frame - 2410) / 60, air._speed * 3.6, air._dist, air._height, air._state])
	return frame >= 6000
