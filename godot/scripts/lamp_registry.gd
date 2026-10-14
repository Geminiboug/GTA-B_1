extends Node
## Autoload "LampRegistry" : positions des tetes de lampadaires (remplies par props.gd).
## Sert a l'eclairage de nuit : seules les lampes proches du joueur recoivent une vraie lumiere.

var positions := PackedVector3Array()


func add(p: Vector3) -> void:
	positions.append(p)


func clear() -> void:
	positions.clear()
