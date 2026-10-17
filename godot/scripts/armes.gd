extends Node3D
## Armes (phase 14, choix valides par Olympe le 17/10/2026 : niveau PEGI 16, armes fictives, jamais de sang, aucune
## violence sur les enfants, option "violence reduite").
## - Armes blanches et improvisees : baton, bouteille (casse apres quelques coups), machette, coupe-coupe ; clic gauche
##   (manette B) frappe avec les clips d'epee (Sword_Regular_A/B/C), degats et portee propres a chaque arme.
## - Armes a feu fictives, rares et cheres : pistolet, fusil a pompe (plombs), fusil de chasse artisanal (un coup) ;
##   clic droit (LB) vise par-dessus l'epaule (haut du corps en pose de tir, les jambes marchent), clic gauche tire,
##   R recharge (clip Pistol_Reload), munitions dans l'inventaire. Recul de la camera, eclair au canon, son
##   synthetise. A la manette, la visee se verrouille sur le passant le plus proche dans l'axe ; stick droit d'un coup
##   sec : cible suivante.
## - Tab (manette : RB a pied) change d'arme (mains nues comprises).
## - Vendeurs : Quincaillerie Le Bon Clou (armes blanches, de jour), et le Gaou, la nuit sur la plage (armes a feu,
##   munitions). Tirer fait fuir les passants et appelle la police (2 etoiles).

const ARMES := {
	"Bâton": {"type": "blanche", "degats": 30.0, "portee": 1.8, "cadence": 0.55, "forme": "baton"},
	"Bouteille": {"type": "blanche", "degats": 26.0, "portee": 1.4, "cadence": 0.45, "forme": "bouteille", "casse": 3},
	"Machette": {"type": "blanche", "degats": 55.0, "portee": 1.9, "cadence": 0.7, "forme": "machette"},
	"Coupe-coupe": {"type": "blanche", "degats": 45.0, "portee": 1.8, "cadence": 0.6, "forme": "coupe"},
	"Pistolet": {"type": "feu", "degats": 40.0, "portee": 60.0, "cadence": 0.28, "chargeur": 12, "munition": "Balles 9 mm",
		"dispersion": 0.012, "forme": "pistolet", "son": 0},
	"Fusil à pompe": {"type": "feu", "degats": 16.0, "plombs": 8, "portee": 28.0, "cadence": 0.95, "chargeur": 6,
		"munition": "Cartouches", "dispersion": 0.06, "forme": "pompe", "son": 1},
	"Fusil de chasse artisanal": {"type": "feu", "degats": 75.0, "portee": 80.0, "cadence": 1.8, "chargeur": 1,
		"munition": "Cartouches", "dispersion": 0.004, "forme": "chasse", "son": 2},
}
const CLIPS_BLANCHE := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]

@export var player_path: NodePath = ^"../Player"
@export var quincaillerie := Vector3(60, 0, -120)     # rue la plus proche : kiosque de la quincaillerie (fictive)
@export var gaou_plage := Vector3(-80, 0, 520)        # le Gaou attend la nuit pres de la plage
@export var verrou_portee := 30.0                     # m : verrouillage de cible a la manette
@export var recul := 0.035                            # rad de recul de la camera par tir (pistolet)

var arme := ""                    # arme en main ("" : mains nues)
var chargeur := {}                # arme -> balles dans le chargeur
var violence_reduite := false
var precision := 1.0              # competence de tir (scripts/stats.gd) : multiplie la dispersion     # option : les passants touches tombent et s'enfuient, rien de plus
var cible: Dictionary = {}        # passant verrouille (manette)
var _player: CharacterBody3D
var _peds: Node
var _cd := 0.0
var _combo := 0
var _modele: Node3D
var _pieces: Node3D               # pieces de l'arme (axe +X = canon / lame), orientees par l'os de la main
var _eclair: OmniLight3D
var _son: AudioStreamPlayer3D
var _coups_bouteille := 0
var _stick_prev := 0.0
var _manette := false
static var _sons := {}


func _ready() -> void:
	_player = get_node_or_null(player_path)
	_peds = get_node_or_null("../Pietons")
	for a in [["arme_suivante", KEY_TAB, JOY_BUTTON_RIGHT_SHOULDER], ["recharger", KEY_R, JOY_BUTTON_LEFT_STICK]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var k := InputEventKey.new()
			k.physical_keycode = a[1]
			InputMap.action_add_event(a[0], k)
			var j := InputEventJoypadButton.new()
			j.button_index = a[2]
			InputMap.action_add_event(a[0], j)
	_son = AudioStreamPlayer3D.new()
	_son.unit_size = 14.0
	_son.max_distance = 260.0
	add_child(_son)
	_vendeurs.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_manette = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_manette = false


# ------------------------------------------------------------------ inventaire
func armes_possedees() -> Array:
	var out: Array = [""]
	for nom in ARMES:
		if Partie.a(nom):
			out.append(nom)
	return out


func equiper(nom: String) -> void:
	arme = nom if nom == "" or Partie.a(nom) else ""
	_player.set("arme", arme)
	_player.set("arme_feu", arme != "" and ARMES[arme]["type"] == "feu")
	if arme != "" and ARMES[arme]["type"] == "feu" and not chargeur.has(arme):
		chargeur[arme] = 0
		_recharger_silencieux()
	_coups_bouteille = 0
	_monter_modele()
	if not _player.is_connected("modele_change", _monter_modele):
		_player.connect("modele_change", _monter_modele)       # silhouette changee : l'arme revient dans la main
	var hud := get_tree().get_first_node_in_group("hud_jeu")
	if hud and hud.has_method("notifier"):
		hud.notifier(tr("Mains nues") if arme == "" else tr(arme) + (" (%d / %d)" % [chargeur.get(arme, 0), Partie.inventaire.get(ARMES[arme]["munition"], 0)] if ARMES[arme]["type"] == "feu" else ""))


func _recharger_silencieux() -> void:
	var a: Dictionary = ARMES[arme]
	var stock: int = int(Partie.inventaire.get(a["munition"], 0))
	var besoin: int = int(a["chargeur"]) - int(chargeur.get(arme, 0))
	var pris := mini(stock, besoin)
	if pris <= 0:
		return
	chargeur[arme] = int(chargeur.get(arme, 0)) + pris
	Partie.inventaire[a["munition"]] = stock - pris
	if int(Partie.inventaire[a["munition"]]) <= 0:
		Partie.inventaire.erase(a["munition"])
	Partie.inventaire_change.emit()


# ------------------------------------------------------------------ boucle
func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	if _eclair:
		_eclair.light_energy = maxf(0.0, _eclair.light_energy - delta * 60.0)
	var pied: bool = _player.get("vehicle") == null and not bool(_player.get("ragdoll") if _player.get("ragdoll") != null else false)
	var libre: bool = pied and (_player.get("menus") as Dictionary).is_empty() and _player.call("_combat_ok")
	if arme != "" and not Partie.a(arme):
		equiper("")
	if libre and Input.is_action_just_pressed("arme_suivante"):
		var liste := armes_possedees()
		equiper(liste[(liste.find(arme) + 1) % liste.size()])
	if _modele:
		_modele.visible = pied
		_orienter()
	var feu: bool = arme != "" and ARMES[arme]["type"] == "feu"
	var vise: bool = feu and libre and Input.is_action_pressed("garde") and _player.is_on_floor()
	_player.set("visee", vise)
	var an: Node = _player.get("anim")
	if an:
		an.set("visee", move_toward(float(an.get("visee")), 1.0 if vise else 0.0, delta * 8.0))
		var cam_pivot: Node3D = _player.get("cam_pivot")
		an.set("visee_pitch", clampf(cam_pivot.rotation.x / 0.6, -1.0, 1.0) if cam_pivot else 0.0)   # camera vers le haut : rotation.x > 0
	if vise and _manette:
		_verrou()
	elif not vise:
		cible = {}
	if not libre:
		return
	if arme != "" and not feu and Input.is_action_just_pressed("attaque") and _cd <= 0.0 and _player.is_on_floor():
		_frapper()
	elif feu and vise and Input.is_action_pressed("attaque") and _cd <= 0.0:
		_tirer()
	elif feu and Input.is_action_just_pressed("recharger") and _cd <= 0.0:
		_recharger()


func _frapper() -> void:
	var a: Dictionary = ARMES[arme]
	_cd = float(a["cadence"])
	var clip: String = CLIPS_BLANCHE[_combo % CLIPS_BLANCHE.size()]
	_combo += 1
	var an: Node = _player.get("anim")
	if an and an.has_method("play_clips"):
		an.play_clips([[clip, 0.0]], true)
	var facing: float = _player.get("_facing")
	var fwd := Vector3(-sin(facing), 0.0, -cos(facing))
	var nom := arme
	get_tree().create_timer(0.28).timeout.connect(func() -> void:
		var touche := false
		var cibles := get_tree().get_nodes_in_group("pnj_interieur")
		if _peds:
			cibles.append(_peds)
		for tg in cibles:
			if is_instance_valid(tg) and tg.player_attack(_player.global_position, fwd, 2, float(a["degats"]) * (0.6 if violence_reduite else 1.0), float(a["portee"]), true):
				touche = true
		_jouer(_son_choc(nom == "Bouteille" and touche))
		if nom == "Bouteille" and touche:
			_coups_bouteille += 1
			if _coups_bouteille >= int(a["casse"]):
				Partie.retirer("Bouteille")      # la bouteille se brise
				Partie.notifier(tr("La bouteille s'est brisée.")))


func _tirer() -> void:
	var a: Dictionary = ARMES[arme]
	if int(chargeur.get(arme, 0)) <= 0:
		_cd = 0.3
		_jouer(_son_clic())
		if int(Partie.inventaire.get(a["munition"], 0)) > 0:
			_recharger()
		return
	_cd = float(a["cadence"])
	chargeur[arme] = int(chargeur[arme]) - 1
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# rayon du centre de l'ecran (la camera est decalee sur l'epaule : h_offset)
	var centre := get_viewport().get_visible_rect().size * 0.5
	var origin := cam.project_ray_origin(centre)
	var dir := cam.project_ray_normal(centre)
	if not cible.is_empty():
		var c: Vector3 = (cible["pos"] as Vector3) + Vector3(0, 1.1, 0)
		dir = (c - origin).normalized()
	var hits := 0
	for k in int(a.get("plombs", 1)):
		var spread: float = float(a["dispersion"]) * precision * (1.6 if Vector2(_player.velocity.x, _player.velocity.z).length() > 0.5 else 1.0)
		var dk := (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread).normalized()
		# on part de devant le joueur (pas de la camera derriere lui), le decor arrete la balle
		var start := _player.global_position + Vector3(0, 1.4, 0)
		var aim_pt := origin + dk * float(a["portee"])
		var q := PhysicsRayQueryParameters3D.create(origin, aim_pt, 1, [_player.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var fin: Vector3 = hit["position"] if not hit.is_empty() else aim_pt
		# touche : le long du rayon de visee, a partir de la hauteur du joueur (rien derriere lui), jusqu'au decor
		var o2 := origin + dk * maxf(0.0, (start - origin).dot(dk))
		var portee := o2.distance_to(fin)
		if _peds and _peds.has_method("tir"):
			var p: Vector3 = _peds.tir(o2, dk, float(a["degats"]) * (0.6 if violence_reduite else 1.0), portee)
			if p != Vector3.INF:
				hits += 1
				var st := get_node_or_null("../Stats")
				if st:
					st.balle_au_but()
		if not hit.is_empty():
			_impact(fin)
	# effets : eclair au canon, recul de la camera, son ; police et passants alertes
	_flash()
	var cp: Node3D = _player.get("cam_pivot")
	if cp:
		cp.rotation.x = clampf(cp.rotation.x + recul * (2.5 if arme != "Pistolet" else 1.0), -1.2, 0.5)
		cp.rotation.y += randf_range(-0.3, 0.3) * recul
	if _player.has_method("shake"):
		_player.shake(0.12 if arme == "Pistolet" else 0.3)
	_jouer(_son_tir(int(a["son"])))
	get_tree().call_group("police", "crime", "tir", _player.global_position)


func _recharger() -> void:
	var a: Dictionary = ARMES[arme]
	if int(Partie.inventaire.get(a["munition"], 0)) <= 0 or int(chargeur.get(arme, 0)) >= int(a["chargeur"]):
		return
	_cd = 1.4
	var an: Node = _player.get("anim")
	if an and an.has_method("play_clips"):
		an.play_clips([["Pistol_Reload", 0.0]], true)
	_recharger_silencieux()


func _verrou() -> void:
	## Manette : la visee se pose sur le passant le plus proche dans l'axe de la camera ; un coup sec du stick droit
	## passe a la cible suivante de ce cote.
	if _peds == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fwd := -cam.global_transform.basis.z
	var stick := Input.get_axis("look_left", "look_right")
	var flick := absf(stick) > 0.8 and absf(_stick_prev) < 0.3
	_stick_prev = stick
	if not cible.is_empty() and not flick and cible.get("state", "") != "down":
		return
	var best: Dictionary = {}
	var bs := -INF
	for w in _peds.get("_walkers"):
		if w == cible or w.get("state", "") == "down":
			continue
		var rel: Vector3 = (w["pos"] as Vector3) + Vector3(0, 1.1, 0) - cam.global_position
		var dist := rel.length()
		if dist > verrou_portee:
			continue
		var al := rel.normalized().dot(fwd)
		if al < 0.85:
			continue
		if flick:
			var side := rel.normalized().dot(cam.global_transform.basis.x)
			if signf(side) != signf(stick):
				continue
		var score := al * 2.0 - dist / verrou_portee
		if score > bs:
			bs = score
			best = w
	cible = best


# ------------------------------------------------------------------ modeles et effets
func _monter_modele() -> void:
	if _modele and is_instance_valid(_modele):
		_modele.queue_free()
	_modele = null
	_eclair = null
	if arme == "":
		return
	var skel := Squelette.find(_player.get_node_or_null("Body"))
	if skel == null:
		return
	var att := BoneAttachment3D.new()
	att.name = "MainArme"
	att.bone_name = Squelette.bone_name(skel, "piv_main_D")
	skel.add_child(att)
	_modele = att
	_pieces = Node3D.new()
	att.add_child(_pieces)
	var ba: Node3D = _pieces
	var forme: String = ARMES[arme]["forme"]
	var metal := _mat(Color(0.12, 0.12, 0.13), 0.7, 0.35)
	var bois := _mat(Color(0.36, 0.22, 0.12), 0.0, 0.7)
	var lame := _mat(Color(0.72, 0.72, 0.7), 0.85, 0.3)
	# repere de l'os de la main (mesure, bras le long du corps) : +X vers l'avant (sortie du poing), +Y vers les doigts
	# (le bas), Z en travers de la paume ; R : rotation qui couche un cylindre (axe Y) le long de +X
	var R := Vector3(0, 0, -PI / 2)
	match forme:
		"baton":
			_piece(ba, _cyl(0.02, 0.025, 0.95), bois, Vector3(0.3, 0.05, 0), R)
		"bouteille":
			var verre := _mat(Color(0.15, 0.35, 0.15, 0.7), 0.0, 0.1)
			verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_piece(ba, _cyl(0.035, 0.035, 0.18), verre, Vector3(0.14, 0.05, 0), R)
			_piece(ba, _cyl(0.012, 0.03, 0.09), verre, Vector3(0.0, 0.05, 0), R)
		"machette", "coupe":
			var long := 0.5 if forme == "machette" else 0.38
			_piece(ba, _cyl(0.016, 0.016, 0.13), bois, Vector3(0.02, 0.05, 0), R)
			_piece(ba, _boite(Vector3(long, 0.05 if forme == "machette" else 0.07, 0.004)), lame, Vector3(0.08 + long / 2, 0.06, 0), Vector3.ZERO)
		"pistolet":
			_piece(ba, _boite(Vector3(0.19, 0.035, 0.03)), metal, Vector3(0.09, 0.0, 0), Vector3.ZERO)
			_piece(ba, _boite(Vector3(0.045, 0.11, 0.028)), metal, Vector3(0.02, 0.06, 0), Vector3(0, 0, 0.25))
		"pompe", "chasse":
			var lg := 0.75 if forme == "pompe" else 1.0
			_piece(ba, _cyl(0.014, 0.014, lg), metal, Vector3(lg / 2 - 0.05, 0.0, 0), R)
			_piece(ba, _boite(Vector3(0.38, 0.07, 0.04)), bois, Vector3(-0.22, 0.04, 0), Vector3(0, 0, 0.15))
			if forme == "pompe":
				_piece(ba, _cyl(0.022, 0.022, 0.16), bois, Vector3(0.35, 0.03, 0), R)
	if ARMES[arme]["type"] == "feu":
		_eclair = OmniLight3D.new()
		_eclair.light_color = Color(1.0, 0.8, 0.45)
		_eclair.omni_range = 5.0
		_eclair.light_energy = 0.0
		_eclair.shadow_enabled = false
		_eclair.position = Vector3(0.6, 0.0, 0)
		_pieces.add_child(_eclair)


func _orienter() -> void:
	## Arme a feu : le canon suit la visee (camera) ou pointe vers l'avant et le bas au repos, quelle que soit la
	## rotation de la main dans le clip (la prise de la main differe entre la marche et la pose de tir).
	if _pieces == null or arme == "" or ARMES[arme]["type"] != "feu":
		return
	var dir: Vector3
	if bool(_player.get("visee")):
		var cam := get_viewport().get_camera_3d()
		var centre := get_viewport().get_visible_rect().size * 0.5
		var cible_pt := cam.project_ray_origin(centre) + cam.project_ray_normal(centre) * 30.0 if cam else _pieces.global_position
		dir = (cible_pt - _pieces.global_position).normalized()
	else:
		var f: float = _player.get("_facing")
		dir = (Vector3(-sin(f), 0, -cos(f)) + Vector3(0, -0.9, 0)).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
	var z := dir.cross(up).normalized()
	var y := z.cross(dir).normalized()
	var sc := _pieces.global_basis.get_scale().abs()   # l os de la main droite peut etre en miroir
	_pieces.global_basis = Basis(dir, -y, -z).scaled(sc)   # base directe, +Y des pieces vers le bas (crosse sous le canon)


func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _cyl(r1: float, r2: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r2
	c.height = h
	c.radial_segments = 10
	return c


func _boite(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


func _piece(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _flash() -> void:
	if _eclair:
		_eclair.light_energy = 4.0


func _impact(p: Vector3) -> void:
	## Petit nuage de poussiere la ou la balle frappe le decor.
	var g := GPUParticles3D.new()
	g.one_shot = true
	g.amount = 10
	g.lifetime = 0.6
	g.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, -4, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.12
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.5, 0.42)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	g.draw_pass_1 = q
	get_tree().current_scene.add_child(g) if get_tree().current_scene else get_parent().add_child(g)
	g.global_position = p
	g.emitting = true
	get_tree().create_timer(1.0).timeout.connect(g.queue_free)


func _jouer(s: AudioStream) -> void:
	_son.global_position = _player.global_position + Vector3(0, 1.4, 0)
	_son.stream = s
	_son.play()


func _son_tir(kind: int) -> AudioStream:
	if not _sons.has("tir%d" % kind):
		_sons["tir%d" % kind] = AudioSynth.coup_de_feu(kind)
	return _sons["tir%d" % kind]


func _son_clic() -> AudioStream:
	if not _sons.has("clic"):
		_sons["clic"] = AudioSynth.passage_rapport()
	return _sons["clic"]


func _son_choc(verre: bool) -> AudioStream:
	if not _sons.has("choc%s" % verre):
		_sons["choc%s" % verre] = AudioSynth.coup_arme(verre)
	return _sons["choc%s" % verre]


# ------------------------------------------------------------------ vendeurs
func _vendeurs() -> void:
	## Quincaillerie (kiosque au bord de la rue) et le Gaou (la nuit, pres de la plage) : points d'achat du commerce.
	var com := get_node_or_null("../Commerce")
	var carte := Carte.zone()
	for v in [["quincaillerie", quincaillerie, "QUINCAILLERIE LE BON CLOU"], ["gaou", gaou_plage, ""]]:
		var p: Vector3 = v[1]
		var near: Dictionary = carte.nearest_on_network(Vector2(p.x, p.z)) if carte else {}
		if not near.is_empty():
			var q: Vector2 = near["point"]
			p = Vector3(q.x + 3.5, 0.0, q.y)
		var kiosque := Node3D.new()
		kiosque.name = "Vendeur_" + v[0]
		add_child(kiosque)
		kiosque.global_position = p
		if v[0] == "quincaillerie":
			var comptoir := MeshInstance3D.new()
			comptoir.mesh = _boite(Vector3(1.8, 1.0, 0.7))
			comptoir.material_override = _mat(Color(0.45, 0.3, 0.18), 0.0, 0.8)
			comptoir.position = Vector3(0, 0.5, 0)
			kiosque.add_child(comptoir)
			var toit := MeshInstance3D.new()
			toit.mesh = _boite(Vector3(2.2, 0.05, 1.3))
			toit.material_override = _mat(Color(0.6, 0.62, 0.65), 0.6, 0.5)
			toit.position = Vector3(0, 2.3, 0)
			kiosque.add_child(toit)
			var enseigne := Label3D.new()
			enseigne.text = v[2]
			enseigne.font_size = 48
			enseigne.pixel_size = 0.006
			enseigne.outline_size = 10
			enseigne.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			enseigne.position = Vector3(0, 2.6, 0)
			kiosque.add_child(enseigne)
		if com:
			com.spots.append({"pos": p, "kind": v[0], "nuit": v[0] == "gaou"})
