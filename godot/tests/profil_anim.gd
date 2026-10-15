extends SceneTree
## Cout par image du pilote d'animation du joueur (anim_ctrl.gd) : avance de l'arbre et ajouts par-dessus.

var frame := 0
var scene: Node
var t_adv := 0
var t_ov := 0
var n := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(delta: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	var ac: Node = scene.get_node("Player").anim
	ac.set_physics_process(false)
	var a := Time.get_ticks_usec()
	ac._tree.advance(delta)
	var b := Time.get_ticks_usec()
	ac._overlay(delta)
	var c := Time.get_ticks_usec()
	t_adv += b - a
	t_ov += c - b
	n += 1
	if n == 200:
		print("avance de l'arbre : %.2f ms   ajouts : %.2f ms" % [t_adv / 200000.0, t_ov / 200000.0])
		return true
	return false
