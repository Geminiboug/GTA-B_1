extends SceneTree
## Mesure : temps de _ready de chaque systeme de la zone (dans l'ordre), pour trouver ce qui ralentit le demarrage
## quand la carte grandit.
## Lancement : godot --headless --path godot --script res://tests/mesure_ready.gd
var paquet: PackedScene
var frame := 0


func _initialize() -> void:
	var t := Time.get_ticks_usec()
	paquet = load("res://scenes/zone_aeroport.tscn") as PackedScene
	print("scene chargee : %d ms" % ((Time.get_ticks_usec() - t) / 1000))


func _process(_d: float) -> bool:
	frame += 1
	if frame != 2:
		return frame > 4
	var scene := paquet.instantiate()
	var dernier := [Time.get_ticks_usec()]
	var temps: Array = []
	for n in scene.get_children():
		n.ready.connect(func() -> void:
			var now := Time.get_ticks_usec()
			temps.append([(now - dernier[0]) / 1000, String(n.name)])
			dernier[0] = now)
	var t := Time.get_ticks_usec()
	root.add_child(scene)
	print("ajoutee (tous les _ready) : %d ms" % ((Time.get_ticks_usec() - t) / 1000))
	temps.sort_custom(func(a, b): return a[0] > b[0])
	for e in temps.slice(0, 15):
		print("  %6d ms  %s" % [e[0], e[1]])
	return false
