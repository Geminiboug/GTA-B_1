extends SceneTree
## Coup de poing en marchant : pieds plantes pendant le coup (pas de glissade), puis le personnage repart sans que le clip du
## coup continue de jouer pendant qu'il marche.

var frame := 0
var scene: Node
var fails := 0
var pl: Node
var t0 := 0
var glisse := 0
var clip_en_marche := 0
var depl := 0.0
var p_coup := Vector3.ZERO
var etat := 0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	if pl == null:
		pl = scene.get_node("Player")
		pl.set("attente_geste", Vector2(999.0, 999.0))
		(pl.get("cam_pivot") as Node3D).rotation.y = float(pl.get("_facing"))
		Input.action_press("move_forward")
		t0 = frame
	var an: Node = pl.get("anim")
	var v := Vector2(pl.velocity.x, pl.velocity.z).length()
	var t := frame - t0
	if t == 90:
		Input.action_press("attaque")
		p_coup = (pl as Node3D).global_position
	elif t == 92:
		Input.action_release("attaque")
	if t > 92 and t < 92 + 45:
		# pendant ~0,75 s apres le coup : pieds plantes tant que le clip joue
		if an.call("playing_clip") and v > 0.3 and float(pl.get("_coup_lock")) > 0.0:
			glisse += 1
	if t > 92 + 45 and t < 92 + 120:
		if an.call("playing_clip") and v > 1.0:
			clip_en_marche += 1
	if t == 92 + 120:
		depl = ((pl as Node3D).global_position - p_coup).length()
		Input.action_release("move_forward")
		_check(glisse == 0, "aucune image de glissade pendant le coup (%d)" % glisse)
		_check(clip_en_marche == 0, "le clip du coup ne joue plus quand il remarche (%d images)" % clip_en_marche)
		_check(depl > 1.5, "il repart apres le coup (%.1f m en 2 s)" % depl)
		print("RESULTAT test_coup_marche : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
