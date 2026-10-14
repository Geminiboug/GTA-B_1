extends StaticBody3D
## Limites du monde : murs invisibles autour de la zone + fond marin praticable.
## Coordonnees Godot : X = est, Z = sud (Z = -Y Blender). Zone OSM : x [-677, 677], z [-386, 386],
## la mer est prolongee de 400 m au sud (osm_import.py SEA_EXTRA) : z jusqu'a 786.

@export var x_min := -677.0
@export var x_max := 677.0
@export var z_min := -386.0
@export var z_max := 786.0
@export var wall_height := 60.0
@export var seabed_depth := -1.2  # sous la surface de l'eau (-0.3) : on a de l'eau jusqu'aux genoux / mi-cuisse


func _ready() -> void:
	var cx := (x_min + x_max) / 2.0
	var cz := (z_min + z_max) / 2.0
	var w := x_max - x_min
	var d := z_max - z_min
	# murs : nord, sud, ouest, est
	_box(Vector3(cx, wall_height / 2.0 - 5.0, z_min - 1.0), Vector3(w + 4.0, wall_height, 2.0))
	_box(Vector3(cx, wall_height / 2.0 - 5.0, z_max + 1.0), Vector3(w + 4.0, wall_height, 2.0))
	_box(Vector3(x_min - 1.0, wall_height / 2.0 - 5.0, cz), Vector3(2.0, wall_height, d + 4.0))
	_box(Vector3(x_max + 1.0, wall_height / 2.0 - 5.0, cz), Vector3(2.0, wall_height, d + 4.0))
	# fond marin sous toute la zone (sous le sol a terre, donc sans effet hors de l'eau)
	_box(Vector3(cx, seabed_depth - 0.5, cz), Vector3(w, 1.0, d))


func _box(pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)
