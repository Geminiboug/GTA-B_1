extends SceneTree
var frame := 0
var scene: Node
func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 90:
		return false
	var pl := scene.get_node("Player")
	var an: Node = pl.get("anim")
	for c in pl.COUPS:
		print("coup ", c, " : ", an.call("clip_length", c), " s")
	quit()
	return true
