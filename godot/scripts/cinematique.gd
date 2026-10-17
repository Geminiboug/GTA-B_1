extends CanvasLayer
## Cinematiques (phase 18) : bandes noires, camera scriptee et sous-titres (actifs par defaut, taille reglable dans les
## options : Partie.options["sous_titres"], ["taille_sous_titres"]). Passer : Espace, Entree ou A.
## - cadrer(parle, ecoute) : plan par-dessus l'epaule de celui qui ecoute, sur celui qui parle (dialogues de l'histoire).
## - jouer(plans) : suite de plans {de, vers, regarde, duree, texte, qui} (camera qui glisse de "de" a "vers").
## - sous_titre(qui, texte, duree) ; fin() rend la camera au joueur.

signal finie

@export var duree_fondu := 0.35
var en_cours := false
var _cam: Camera3D
var _cam_prec: Camera3D
var _haut: ColorRect
var _bas: ColorRect
var _st: Label
var _st_t := 0.0
var _plans: Array = []
var _plan_t := 0.0
var _cadre: Array = []           # [parle, ecoute] suivis chaque image
var _bandes := 0.0
var _hud_cache := false


func _ready() -> void:
	layer = 9
	_haut = _bande(true)
	_bas = _bande(false)
	_st = Label.new()
	_st.anchor_left = 0.1
	_st.anchor_right = 0.9
	_st.anchor_top = 1.0
	_st.anchor_bottom = 1.0
	_st.offset_top = -150
	_st.offset_bottom = -40
	_st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_st.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_st.add_theme_color_override("font_color", Color(1, 1, 1))
	_st.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_st.add_theme_constant_override("outline_size", 8)
	_st.visible = false
	add_child(_st)


func _bande(haut: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0)
	r.anchor_right = 1.0
	if haut:
		r.anchor_bottom = 0.0
	else:
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _camera() -> Camera3D:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 50.0
		get_parent().add_child(_cam)
	return _cam


func _debut() -> void:
	if en_cours:
		return
	en_cours = true
	_cam_prec = get_viewport().get_camera_3d()
	_camera().current = true


func fin() -> void:
	if not en_cours:
		return
	en_cours = false
	_plans.clear()
	_cadre.clear()
	if _cam_prec and is_instance_valid(_cam_prec):
		_cam_prec.current = true
	finie.emit()


func cadrer(parle: Node3D, ecoute: Node3D) -> void:
	## Plan de dialogue : par-dessus l'epaule de celui qui ecoute, cadre sur le visage de celui qui parle.
	if parle == null or ecoute == null or not is_instance_valid(parle) or not is_instance_valid(ecoute):
		return
	_debut()
	_cadre = [parle, ecoute]
	_suivre_cadre(1.0)


func _suivre_cadre(k: float) -> void:
	var p: Vector3 = (_cadre[0] as Node3D).global_position + Vector3(0, 1.55, 0)
	var e: Vector3 = (_cadre[1] as Node3D).global_position + Vector3(0, 1.55, 0)
	var axe := (p - e)
	axe.y = 0.0
	if axe.length() < 0.2:
		axe = Vector3(0, 0, -1)
	axe = axe.normalized()
	var cote := axe.cross(Vector3.UP).normalized()
	var pos := e - axe * 0.9 + cote * 0.45 + Vector3(0, 0.12, 0)
	var cam := _camera()
	cam.global_position = cam.global_position.lerp(pos, k)
	cam.look_at(p - Vector3(0, 0.05, 0), Vector3.UP)


func jouer(plans: Array) -> void:
	_debut()
	_cadre.clear()
	_plans = plans.duplicate()
	_plan_t = 0.0


func sous_titre(qui: String, texte: String, duree: float) -> void:
	if not bool(Partie.options.get("sous_titres", true)):
		return
	_st.text = (qui + " : " if qui != "" else "") + texte
	_st.add_theme_font_size_override("font_size", int(Partie.options.get("taille_sous_titres", 26)))
	_st.visible = true
	_st_t = duree


func _process(delta: float) -> void:
	_bandes = move_toward(_bandes, 1.0 if en_cours else 0.0, delta / duree_fondu)
	var h := 0.11 * _bandes
	_haut.anchor_bottom = h
	_bas.anchor_top = 1.0 - h
	_st_t = maxf(0.0, _st_t - delta)
	_st.visible = _st_t > 0.0
	# interface du jeu cachee pendant la cinematique (mini-carte, aide, argent), seulement aux changements
	if en_cours != _hud_cache:
		_hud_cache = en_cours
		for nom in ["../HUD", "../HUDJeu", "../Tactile"]:
			var c := get_node_or_null(nom) as CanvasLayer
			if c and (nom != "../Tactile" or c.get("actif")):
				c.visible = not en_cours
	if not en_cours:
		return
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		fin()
		return
	if not _cadre.is_empty():
		if is_instance_valid(_cadre[0]) and is_instance_valid(_cadre[1]):
			_suivre_cadre(1.0 - exp(-4.0 * delta))
		return
	if _plans.is_empty():
		fin()
		return
	var pl: Dictionary = _plans[0]
	if _plan_t == 0.0 and pl.has("texte"):
		sous_titre(String(pl.get("qui", "")), String(pl["texte"]), float(pl.get("duree", 3.0)))
	_plan_t += delta
	var k := clampf(_plan_t / float(pl.get("duree", 3.0)), 0.0, 1.0)
	var cam := _camera()
	cam.global_position = (pl["de"] as Vector3).lerp(pl.get("vers", pl["de"]), smoothstep(0.0, 1.0, k))
	cam.look_at(pl["regarde"], Vector3.UP)
	if k >= 1.0:
		_plans.pop_front()
		_plan_t = 0.0
