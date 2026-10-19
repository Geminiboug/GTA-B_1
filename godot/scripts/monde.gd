class_name Monde
extends Node3D
## Chargement par morceaux (docs/chargement_par_morceaux.md) : la zone est faite de tuiles de 500 m, un .glb par tuile
## (osm_import.py, 9e argument), plus un fichier commun toujours charge (mer, plage d'un seul tenant...).
## Etape 2 : toutes les tuiles sont posees avant le _ready des systemes voisins (realisme, vegetation, props), le jeu
## est identique a l'ancien fichier unique. Avec `dynamique`, seules les tuiles a moins de rayon_charge du joueur sont
## gardees : les autres arrivent en arriere-plan (fil de chargement) et partent au-dela de rayon_libere.

signal tuile_chargee(cle: Vector2i, noeud: Node3D)
signal tuile_dechargee(cle: Vector2i)

@export var dossier := DOSSIER
@export var dynamique := false
@export var rayon_charge := 650.0     # m du joueur au bord de la tuile
@export var rayon_libere := 900.0     # plus grand que rayon_charge : pas d'aller-retour en bord de tuile
@export var joueur_path: NodePath = ^"../Player"

const DOSSIER := "res://assets/models/tuiles/"

var tuiles := {}     # Vector2i -> {"rect": Rect2 (x, z), "fichier": String, "noeud": Node3D, "attente": bool}
var commun: Node3D


func _enter_tree() -> void:
	if not tuiles.is_empty():
		return
	var idx: Variant = JSON.parse_string(FileAccess.get_file_as_string(dossier + "tuiles.json"))
	if typeof(idx) != TYPE_DICTIONARY:
		push_error("Monde : index des tuiles illisible (%stuiles.json)" % dossier)
		return
	commun = (load(dossier + String(idx["commun"])) as PackedScene).instantiate()
	commun.name = "Commun"
	add_child(commun)
	for t in idx["tuiles"]:
		var r: Array = t["rect"]
		var cle := Vector2i(int(t["x"]), int(t["y"]))
		tuiles[cle] = {"rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), "fichier": dossier + String(t["fichier"]),
			"noeud": null, "attente": false}
	# au lancement : tout (etape 2), ou ce qui entoure le point de depart (le joueur est pose par la scene)
	var depart := _position_joueur()
	for cle in tuiles:
		if not dynamique or _distance(cle, depart) < rayon_charge:
			_poser(cle, (load(tuiles[cle]["fichier"]) as PackedScene).instantiate())


static func fichiers(dos := DOSSIER) -> PackedStringArray:
	## Fichiers poses au lancement (fichier commun + tuiles), pour un chargement en arriere-plan avant la scene.
	var idx: Variant = JSON.parse_string(FileAccess.get_file_as_string(dos + "tuiles.json"))
	var res := PackedStringArray()
	if typeof(idx) != TYPE_DICTIONARY:
		return res
	res.append(dos + String(idx["commun"]))
	for t in idx["tuiles"]:
		res.append(dos + String(t["fichier"]))
	return res


func _physics_process(_d: float) -> void:
	if not dynamique:
		return
	var p := _position_joueur()
	for cle in tuiles:
		var t: Dictionary = tuiles[cle]
		var d := _distance(cle, p)
		if d < rayon_charge and t["noeud"] == null and not t["attente"]:
			ResourceLoader.load_threaded_request(t["fichier"])
			t["attente"] = true
		elif t["attente"]:
			var st := ResourceLoader.load_threaded_get_status(t["fichier"])
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				t["attente"] = false
				if d < rayon_libere:
					_poser(cle, (ResourceLoader.load_threaded_get(t["fichier"]) as PackedScene).instantiate())
			elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				t["attente"] = false
		elif d > rayon_libere and t["noeud"] != null and not _epinglee(cle):
			(t["noeud"] as Node3D).queue_free()
			t["noeud"] = null
			tuile_dechargee.emit(cle)


func _poser(cle: Vector2i, n: Node3D) -> void:
	n.name = "Tuile_%d_%d" % [cle.x, cle.y]
	add_child(n)
	tuiles[cle]["noeud"] = n
	tuile_chargee.emit(cle, n)


func chargee(p: Vector3) -> bool:
	## Vrai si la tuile sous ce point est en place (ou hors des tuiles : rien a attendre).
	for cle in tuiles:
		if (tuiles[cle]["rect"] as Rect2).has_point(Vector2(p.x, p.z)):
			return tuiles[cle]["noeud"] != null
	return true


var epingles: Array[Vector3] = []     # points gardes charges (missions en cours)


func _epinglee(cle: Vector2i) -> bool:
	for p in epingles:
		if _distance(cle, p) < rayon_charge:
			return true
	return false


func _distance(cle: Vector2i, p: Vector3) -> float:
	## Distance du point au rectangle de la tuile (0 dedans).
	var r: Rect2 = tuiles[cle]["rect"]
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.z, r.position.y, r.end.y))
	return q.distance_to(Vector2(p.x, p.z))


func _position_joueur() -> Vector3:
	var j := get_node_or_null(joueur_path) as Node3D
	return j.global_position if j and j.is_inside_tree() else (j.position if j else Vector3.ZERO)
