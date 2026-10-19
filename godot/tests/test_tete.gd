extends SceneTree
## Les PNJ regardent devant eux (pas la tete baissee) : a l'arret et en marche, le regard (axe avant de la tete) ne
## plonge pas de plus de `max_plongee` degres sous l'horizontale, pour plusieurs morphologies et clips d'attente.
var frame := 0
var fails := 0
var persos: Array = []
var mesures := {}
@export var max_plongee := 12.0


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	var i := 0
	for v in ["femme", "homme", "femme_ronde", "homme_fort", "homme_age", "fille"]:
		var ch := PnjUtil.make(v)
		ch.set_script(preload("res://scripts/anim_ctrl.gd"))
		root.add_child(ch)
		ch.position = Vector3(i * 2.0, 0, 0)
		persos.append(ch)
		i += 1


func _plongee(ch: Node3D) -> float:
	## Angle (degres) du regard sous l'horizontale : axe avant de l'os de la tete (le modele regarde +Z du squelette).
	var sk: Skeleton3D = ch.find_children("*", "Skeleton3D", true, false)[0]
	var h := sk.find_bone("Head")
	var b := (sk.global_transform * sk.get_bone_global_pose(h)).basis.orthonormalized()
	var avant := b * Vector3(0, 0, 1)
	return rad_to_deg(-asin(clampf(avant.normalized().y, -1.0, 1.0)))


func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		for ch in persos:
			mesures[ch] = [_plongee(ch)]
			ch.set("speed", 1.3)
			ch.set("on_floor", true)
	if frame == 160:
		for ch in persos:
			mesures[ch].append(_plongee(ch))
			print("  %s : arret %.0f deg, marche %.0f deg (clips %s)" % [ch.get_meta("variante"), mesures[ch][0], mesures[ch][1], ch.get("loco_clips")])
			_check(mesures[ch][0] < max_plongee and mesures[ch][1] < max_plongee, "%s regarde devant lui" % ch.get_meta("variante"))
		print("RESULTAT test_tete : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
