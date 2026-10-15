extends SceneTree
## Liste des clips des bibliotheques Quaternius (noms et durees).
const AC := preload("res://scripts/anim_ctrl.gd")


func _initialize() -> void:
	AC._load_libs()
	for key in AC._libs:
		var lib: AnimationLibrary = AC._libs[key]
		var out := []
		for n in lib.get_animation_list():
			out.append("%s(%.1f)" % [n, lib.get_animation(n).length])
		print(key, " : ", ", ".join(out))
	quit()
