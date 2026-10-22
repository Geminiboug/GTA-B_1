extends Node3D
## Lieux dans lesquels on entre (blender/tools/build_interieurs.py) : maison du joueur, Ararat Hypermarket (nom
## fictif), terminal de l'aeroport. Ce script :
## - charge les modeles (deja places dans le monde) et remplace quelques materiaux (carrelage, terrazzo) ;
## - anime les portes : battantes (portail, porte d'entree) et coulissantes automatiques (magasin, terminal),
##   qui s'ouvrent quand le joueur (a pied ou en vehicule) ou un PNJ approche ;
## - allume les plafonniers, regle l'eclairage d'interieur (sonde de reflets "interieur" sur chaque volume) ;
## - pose les textes (enseignes, rayons, caisses, comptoirs, tableau des departs a l'heure du jeu) ;
## - fait vivre les lieux : clients, caissieres, vigiles, voyageurs, agents (scripts/pnj_interieur.gd) ;
## - lit de la maison : E pour dormir jusqu'au matin ; nom du lieu affiche en entrant ;
## - en jeu normal, le joueur commence chez lui (cour de la maison) avec son zem gare dans la cour.

@export var player_path: NodePath = ^"../Player"
@export var zem_path: NodePath = ^"../Zem"
@export var spawn_at_home := true

const MODELS := {"maison": "res://assets/models/lieu_maison.glb", "ararat": "res://assets/models/lieu_ararat.glb",
	"terminal": "res://assets/models/lieu_terminal.glb"}
const NAMES := {"maison": "Chez vous", "ararat": "Ararat Hypermarket", "terminal": "Aéroport International Cardinal Cotodji"}
const SOL := preload("res://shaders/sol.gdshader")
const PRODUIT := preload("res://shaders/produit.gdshader")
const PNJ := preload("res://scripts/pnj_interieur.gd")
const RAYONS := {"epicerie": "Épicerie", "boissons": "Boissons", "hygiene": "Hygiène et beauté", "entretien": "Entretien",
	"laitiers": "Produits laitiers", "conserves": "Conserves", "bebe": "Bébé", "riz": "Riz et céréales", "huile": "Huiles",
	"sucre": "Sucre et café", "the": "Thé et infusions", "biscuits": "Biscuits", "boulangerie": "Boulangerie",
	"fruits": "Fruits et légumes", "vrac": "Gros conditionnement"}
const COMPAGNIES := ["AIR GBÉ", "ATLANTIQUE EXPRESS", "SAHEL AIRWAYS", "GOLFE AVIATION", "TRANS-OUEST", "AIR LAGUNE"]
const VOLS := [["Air Gbé 214", "Paris"], ["Atlantique Express 33", "Abidjan"], ["Sahel Airways 508", "Ouagadougou"],
	["Golfe Aviation 72", "Lagos"], ["Air Gbé 118", "Bruxelles"], ["Trans-Ouest 401", "Dakar"], ["Air Lagune 9", "Lomé"],
	["Atlantique Express 61", "Accra"], ["Air Gbé 300", "Casablanca"], ["Sahel Airways 17", "Douala"]]

var doors: Array = []          # {body, kind, axis_angle / slide, open (0..1), pos}
var zones: Array = []          # {name, aabb (monde)}
var bed: Node3D
var _player: Node3D
var _day: Node
var _hud: Node
var _board: Array[Label3D] = []   # colonnes du tableau des departs : vol, destination, heure, porte, etat
var _board_t := 0.0
var _current_zone := ""
var _house_lights: Array[OmniLight3D] = []
var _fade: ColorRect
var _sleeping := false
@export var interior_shadow := 60.0   # m : portee des ombres du soleil quand on est dans un lieu
var sorties: Array = []         # cours fermees : {aabb, porte, dehors} (sortie())
var shop_spots: Array = []      # caisses de l'Ararat, cafe de l'aerogare (scripts/commerce.gd) : {pos, kind}


func _ready() -> void:
	_player = get_node_or_null(player_path)
	_day = get_node_or_null("../JourNuit")
	_hud = get_node_or_null("../HUD")
	for key in MODELS:
		if not ResourceLoader.exists(MODELS[key]):
			continue
		var inst := (load(MODELS[key]) as PackedScene).instantiate() as Node3D
		inst.name = "Lieu_" + key
		add_child(inst)
		_setup(inst, key)
	if spawn_at_home and get_tree().current_scene == get_parent():
		_spawn_home.call_deferred()
	_epave_porte()


func _epave_porte() -> void:
	## Epave de la plage (zone_aeroport_reperes, blender/tools/build_epave.py) : la carlingue collisionne des deux cotes
	## (en ratant la porte, on traversait la peau par l'arriere et on restait coince dans l'encadrement), et deux
	## poteaux ronds bordent l'ouverture (1,15 m) : on glisse vers la porte au lieu de s'accrocher a l'arete.
	var rep := get_node_or_null("../zone_aeroport_reperes")
	if rep == null:
		return
	for n in rep.find_children("avion_*", "", true, false):
		for cs in n.find_children("*", "CollisionShape3D", true, false):
			var sh := (cs as CollisionShape3D).shape as ConcavePolygonShape3D
			if sh:
				sh.backface_collision = true
	var seuil := rep.find_child("escalier_palier_seuil", true, false) as MeshInstance3D
	if seuil == null:
		return
	var c: Vector3 = seuil.global_transform * seuil.mesh.get_aabb().get_center()
	var corps := StaticBody3D.new()
	corps.name = "EpavePorte"
	add_child(corps)
	for dz in [-1.0, 1.0]:
		var jamb := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.12
		cy.height = 3.0
		jamb.shape = cy
		corps.add_child(jamb)
		# le long de la carlingue (axe local Z du seuil, = axe du fuselage), juste hors de l'ouverture
		var b := seuil.global_transform.basis.orthonormalized()
		jamb.global_position = c + b.x * 0.05 + Vector3.UP * 1.5 + b.z * dz * (0.576 + 0.12)


# ------------------------------------------------------------------ mise en place
# occultation : les murs pleins du lieu (portes et vitrines deja en trous) cachent la ville quand on est dedans
func _occluder(mi: MeshInstance3D) -> void:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var base := verts.size()
		verts.append_array(arr[Mesh.ARRAY_VERTEX])
		var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for i in ind:
			idx.append(base + i)
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(verts, idx)
	var oi := OccluderInstance3D.new()
	oi.name = "Occultation"
	oi.occluder = occ
	mi.add_child(oi)


func _setup(root: Node3D, key: String) -> void:
	# direction des gondoles (perpendiculaire a la facade d'entree) pour le shader des produits
	var axis := Vector3.ZERO
	var dg := root.find_child("porte_coulissante_%s_g" % key, true, false) as Node3D
	var dd := root.find_child("porte_coulissante_%s_d" % key, true, false) as Node3D
	if key == "ararat" and dg and dd:
		var du := dd.global_position - dg.global_position
		axis = Vector3(-du.z, 0, du.x).normalized()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		_materials(mi as MeshInstance3D, axis)
		var n := String(mi.name)
		if key != "maison" and (n.contains("produits") or n.contains("deco") or n.contains("mobilier")):
			(mi as MeshInstance3D).visibility_range_end = 85.0    # details d'interieur : seulement de pres
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # sous le toit
		if n.begins_with(key + "_structure"):
			_occluder(mi as MeshInstance3D)
	for e in root.find_children("*", "Node3D", true, false):
		var n := String(e.name)
		if e is MeshInstance3D:
			if n.begins_with("zone_interieur"):
				_zone(e as MeshInstance3D, key)
			continue
		if n.begins_with("porte_battante_") or n.begins_with("porte_coulissante_"):
			if not n.ends_with("_vantail"):
				_door(e as Node3D, n.begins_with("porte_coulissante_"))
		elif n.begins_with("lumiere_"):
			_light(e as Node3D, n, key)
		elif n.begins_with("texte_"):
			_text(e as Node3D, n)
		elif n == "action_lit":
			bed = e as Node3D
	# sortie par le portail (GPS a pied depuis la cour : scripts/hud_carte.gd)
	var pg := root.find_child("porte_battante_portail_g", true, false) as Node3D
	var pd := root.find_child("porte_battante_portail_d", true, false) as Node3D
	if pg and pd:
		var box := AABB()
		var first := true
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var bb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		# milieu de l'ouverture : centre des deux battants (les gonds sont aux extremites)
		var gate := Vector3.ZERO
		for e in [pg, pd]:
			var leaf := (e as Node3D).find_child("*vantail*", true, false) as MeshInstance3D
			gate += leaf.global_transform * leaf.mesh.get_aabb().get_center() if leaf else (e as Node3D).global_position
		gate *= 0.5
		gate.y = 0.0
		var out := gate - box.get_center()
		out.y = 0.0
		out = out.normalized()
		sorties.append({"aabb": box, "porte": gate - out * 1.5, "dehors": gate + out * 3.0})
	var pnj := Node3D.new()
	pnj.set_script(PNJ)
	pnj.name = "PNJ_" + key
	add_child(pnj)
	pnj.call("setup", root, key, _player)


func _materials(mi: MeshInstance3D, axis: Vector3) -> void:
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		if m == null:
			continue
		var sm: ShaderMaterial = null
		match m.resource_name:
			"mat_carrelage":
				sm = _sol(10, Color(0.88, 0.86, 0.82))
			"mat_terrazzo":
				sm = _sol(12, Color(0.8, 0.78, 0.74))
			"mat_sable_cour":
				sm = _sol(5, Color(1, 1, 1))
		if axis != Vector3.ZERO and m.resource_name.begins_with("mat_produit_") and m is BaseMaterial3D:
			var i := int(m.resource_name.trim_prefix("mat_produit_"))
			sm = ShaderMaterial.new()
			sm.shader = PRODUIT
			var c := (m as BaseMaterial3D).albedo_color
			sm.set_shader_parameter("base_color", Vector3(c.r, c.g, c.b))
			var lc: Color = [Color(0.95, 0.95, 0.93), Color(0.96, 0.9, 0.75), Color(0.12, 0.12, 0.14)][i % 3]
			if i == 3:
				lc = Color(0.75, 0.1, 0.1)   # produit blanc : etiquette rouge
			sm.set_shader_parameter("label_color", Vector3(lc.r, lc.g, lc.b))
			sm.set_shader_parameter("item_w", 0.085 + 0.018 * (i % 5))
			sm.set_shader_parameter("axis", axis)
		if sm:
			mi.set_surface_override_material(s, sm)
		elif m is BaseMaterial3D and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			d.cull_mode = BaseMaterial3D.CULL_DISABLED      # vitres visibles des deux cotes
			mi.set_surface_override_material(s, d)


var _sol_cache := {}


func _sol(mode: int, tint: Color) -> ShaderMaterial:
	var k := "%d|%s" % [mode, tint.to_html()]
	if not _sol_cache.has(k):
		var m := ShaderMaterial.new()
		m.shader = SOL
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		m.set_shader_parameter("depth_pull", 0.0)
		_sol_cache[k] = m
	return _sol_cache[k]


func _zone(mi: MeshInstance3D, key: String) -> void:
	## Volume interieur : sonde de reflets "interieur" (l'eclairage du ciel ne passe plus a travers les murs),
	## lumiere ambiante d'interieur, et nom du lieu quand le joueur y entre.
	mi.visible = false
	var aabb := mi.global_transform * mi.mesh.get_aabb()
	zones.append({"name": key, "aabb": aabb.grow(0.3)})
	if key in ["ararat", "terminal"]:
		# grand volume ferme : les sons qui y naissent resonnent (bus Interieur, scripts/partie.gd)
		var zone := Area3D.new()
		zone.name = "Reverb_" + key
		zone.reverb_bus_enabled = true
		zone.reverb_bus_name = &"Interieur"
		zone.reverb_bus_amount = 0.45
		zone.reverb_bus_uniformity = 0.3
		zone.monitoring = false
		zone.monitorable = false
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = aabb.size
		cs.shape = bx
		zone.add_child(cs)
		add_child(zone)
		zone.global_position = aabb.get_center()
	var probe := ReflectionProbe.new()
	probe.interior = true
	probe.size = aabb.size
	probe.box_projection = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(1.0, 0.95, 0.85) if key == "maison" else Color(0.95, 0.97, 1.0)
	probe.ambient_color_energy = 0.55 if key == "maison" else 0.95
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	probe.global_position = aabb.get_center()


func _door(e: Node3D, sliding: bool) -> void:
	## Porte : le vantail (mesh enfant) devient un corps anime avec une collision.
	var leaf: MeshInstance3D = null
	for c in e.find_children("*", "MeshInstance3D", true, false):
		leaf = c
		break
	if leaf == null:
		return
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var aabb := leaf.mesh.get_aabb()
	box.size = aabb.size.max(Vector3(0.04, 0.04, 0.04))
	cs.shape = box
	cs.position = aabb.get_center()
	e.add_child(body)
	leaf.reparent(body, false)
	body.add_child(cs)
	var d := {"body": body, "sliding": sliding, "open": 0.0, "closed": body.transform, "pos": e.global_position}
	if sliding:
		d["slide"] = Vector3(-aabb.size.x * 0.95 if String(e.name).ends_with("_g") else aabb.size.x * 0.95, 0, 0)
	else:
		# s'ouvre vers l'interieur (le vantail tourne autour du gond, du cote ou il s'etend)
		d["angle"] = deg_to_rad(95.0) * signf(aabb.get_center().x)
	# portes coulissantes : detecteur a ~4 m devant la porte (mesure depuis le centre de chaque vantail)
	d["range"] = 5.5 if String(e.name).contains("portail") else (4.5 if sliding else 3.2)
	doors.append(d)


func _light(e: Node3D, n: String, key: String) -> void:
	var l := OmniLight3D.new()
	l.shadow_enabled = false
	if n.contains("ampoule"):
		l.light_color = Color(1.0, 0.82, 0.6)
		l.omni_range = 6.5
		l.light_energy = 1.4
	else:
		l.light_color = Color(0.92, 0.96, 1.0)
		l.omni_range = 7.0 if key == "maison" else 20.0
		l.light_energy = 1.2 if key == "maison" else 1.8
	e.add_child(l)
	if key == "maison":
		_house_lights.append(l)


func _text(e: Node3D, n: String) -> void:
	var l := Label3D.new()
	var txt := ""
	var size := 0.25
	var col := Color(1, 1, 1)
	var parts := n.split("_")
	if n.begins_with("texte_ararat_enseigne"):
		txt = "ARARAT HYPERMARKET"
		size = 1.5
	elif n.begins_with("texte_ararat_slogan"):
		txt = "Tout sous un même toit"
		size = 0.6
		col = Color(1, 0.92, 0.3)
	elif n.begins_with("texte_ararat_caisse"):
		shop_spots.append({"pos": e.global_position, "kind": "caisse"})
		txt = "Caisse %d" % (int(parts[parts.size() - 1]) + 1)
		size = 0.18
	elif n.begins_with("texte_ararat_rayon"):
		# chaque rayon vend ses articles : il faut aller au rayon pour acheter (retour d'Olympe du 21/10/2026)
		shop_spots.append({"pos": e.global_position, "kind": "rayon_" + String(parts[3])})
		txt = RAYONS.get(parts[3], parts[3].capitalize())
		size = 0.22
	elif n.begins_with("texte_terminal_enseigne"):
		txt = "AÉROPORT INTERNATIONAL CARDINAL COTODJI"
		size = 1.6
	elif n.begins_with("texte_terminal_comptoir"):
		var k := int(parts[parts.size() - 1])
		txt = "%s · Comptoir %d" % [COMPAGNIES[k / 2 % COMPAGNIES.size()], k + 1]
		size = 0.16
	elif n.begins_with("texte_terminal_departs"):
		l.free()
		_departure_board(e)
		return
	elif n.begins_with("texte_terminal_embarquement"):
		txt = "EMBARQUEMENT\nPassagers munis d'une carte d'embarquement uniquement"
		size = 0.2
	elif n.begins_with("texte_terminal_cafe"):
		shop_spots.append({"pos": e.global_position, "kind": "cafe"})
		txt = "CAFÉ DU LITTORAL"
		size = 0.3
	elif n.begins_with("texte_terminal_librairie"):
		txt = "LIBRAIRIE · PRESSE"
		size = 0.3
	l.text = txt
	l.modulate = col
	l.outline_size = 0
	l.pixel_size = size / 64.0
	l.font_size = 64
	l.double_sided = false
	l.shaded = false
	l.visibility_range_end = 220.0 if size > 1.0 else 60.0
	e.add_child(l)
	# le texte se lit face a l'axe -Y du repere Blender (= +Z Godot) : retourne pour etre lisible de face
	l.rotation = Vector3(0, PI, 0)
	l.position = Vector3(0, 0, 0)
	if n.begins_with("texte_ararat_caisse") or n.begins_with("texte_ararat_rayon"):
		# panneau suspendu : meme texte sur l'autre face (8 cm derriere, epaisseur du panneau)
		var back := l.duplicate() as Label3D
		e.add_child(back)
		back.rotation = Vector3.ZERO
		back.position = Vector3(0, 0, 0.08)


func _departure_board(e: Node3D) -> void:
	## Tableau des departs : une colonne par champ (police proportionnelle -> colonnes alignees), ecran de 5,8 x 2,4 m.
	## Le repere est en haut de l'ecran ; le texte se lit face a +Z Godot (retourne comme les autres textes).
	var holder := Node3D.new()
	e.add_child(holder)
	holder.rotation = Vector3(0, PI, 0)
	for x in [-2.75, -1.0, 0.55, 1.35, 1.95]:
		var l := Label3D.new()
		l.font_size = 64
		l.pixel_size = 0.13 / 64.0
		l.outline_size = 0
		l.shaded = false
		l.double_sided = false
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.line_spacing = 2.0
		l.modulate = Color(1.0, 0.85, 0.3)
		l.visibility_range_end = 60.0
		l.position = Vector3(x, 0.1, 0)
		holder.add_child(l)
		_board.append(l)


func _board_columns() -> Array:
	var h: float = _day.get("hour") if _day else 12.0
	var cols := [["DÉPARTS"], ["Destination"], ["Heure"], ["Porte"], ["État"]]
	for i in VOLS.size():
		var t := fmod(h + 0.4 + i * 0.55, 24.0)
		var etat := "À l'heure"
		var dt := t - h
		if dt < 0.0:
			dt += 24.0
		if dt < 0.7:
			etat = "Embarquement"
		elif i % 4 == 2:
			etat = "Retardé"
		cols[0].append(VOLS[i][0])
		cols[1].append(VOLS[i][1])
		cols[2].append("%02d:%02d" % [int(t), int(fmod(t, 1.0) * 60.0) / 5 * 5])
		cols[3].append(str(1 + i % 6))
		cols[4].append(etat)
	var out := []
	for c in cols:
		out.append("\n".join(c))
	return out


# ------------------------------------------------------------------ boucle
func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var pv = _player.get("vehicle")
	var ppos: Vector3 = (pv as Node3D).global_position if pv else _player.global_position
	var movers: Array = [ppos]
	for c in get_children():
		if c.has_method("positions"):
			movers.append_array(c.call("positions"))
	for d in doors:
		var body: AnimatableBody3D = d["body"]
		var center: Vector3 = d["pos"]   # porte fermee : le vantail s'eloigne en s'ouvrant
		var want := false
		for p in movers:
			if (p as Vector3).distance_to(center) < d["range"]:
				want = true
				break
		d["open"] = move_toward(d["open"], 1.0 if want else 0.0, delta * (1.6 if d["sliding"] else 1.1))
		var k := smoothstep(0.0, 1.0, d["open"])
		var closed: Transform3D = d["closed"]
		if d["sliding"]:
			body.transform = closed.translated_local(d["slide"] * k)
		else:
			body.transform = closed * Transform3D(Basis(Vector3.UP, d["angle"] * k), Vector3.ZERO)
	# lumieres de la maison : le soir, ou quand on est dedans
	var night: float = _day.get("night") if _day else 0.0
	var inside := _zone_at(ppos)
	for l in _house_lights:
		l.visible = night > 0.35 or inside == "maison"
	# nom du lieu en entrant
	if inside != _current_zone:
		_current_zone = inside
		# a l'interieur, les ombres du soleil ne servent qu'a ce qu'on voit par les vitres : portee reduite (budget 60 img/s)
		var sun := get_node_or_null("../Sun") as DirectionalLight3D
		if sun:
			var q := int(Partie.options.get("qualite", 2))
			sun.directional_shadow_max_distance = interior_shadow if inside != "" else float(Qualite.PRESETS[clampi(q, 0, 2)][0])
		if inside != "" and _hud and _hud.has_method("show_place"):
			_hud.show_place(NAMES[inside])
	# tableau des departs : mis a jour chaque minute de jeu
	_board_t -= delta
	if not _board.is_empty() and _board_t <= 0.0:
		_board_t = 2.0
		var cols := _board_columns()
		for i in _board.size():
			_board[i].text = cols[i]
	# lit : E pour dormir
	if bed and pv == null and not _sleeping:
		var dist := _player.global_position.distance_to(bed.global_position)
		if dist < 1.6:
			if _hud and _hud.has_method("show_hint"):
				_hud.show_hint("E : dormir jusqu'au matin et sauvegarder")
			if Input.is_action_just_pressed("interact"):
				_sleep()


func _zone_at(p: Vector3) -> String:
	for z in zones:
		if (z["aabb"] as AABB).has_point(p + Vector3(0, 0.5, 0)):
			return z["name"]
	return ""


func _sleep() -> void:
	## Fondu au noir, nuit qui passe, reveil a 7 h.
	_sleeping = true
	var an: Node = _player.get("anim") if _player else null
	if an and an.has_method("play_clips"):
		an.play_clips([["Sitting_Enter", 2.0]], true)      # on s'assoit sur le lit avant le fondu
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.2)
	tw.tween_callback(func() -> void:
		if _day:
			_day.set("hour", 7.0)
		if _hud and _hud.has_method("show_place"):
			_hud.show_place("Une nouvelle journée commence")
		Partie.soigner(100.0)
		Partie.sauver(get_parent()))
	tw.tween_interval(1.5)
	tw.tween_property(_fade, "color:a", 0.0, 1.5)
	tw.tween_callback(func() -> void: _sleeping = false)


func _spawn_home() -> void:
	var root := get_node_or_null("Lieu_maison")
	if root == null or _player == null:
		return
	var sp := root.find_child("spawn_joueur", true, false) as Node3D
	var zp := root.find_child("place_zem", true, false) as Node3D
	if sp:
		_player.global_position = sp.global_position + Vector3(0, 0.2, 0)
		_player.reset_physics_interpolation()
		var yaw := sp.global_rotation.y + PI   # dos a la maison, face au portail
		_player.set("_facing", yaw)
		var cp := _player.get_node_or_null("CamPivot") as Node3D
		if cp:
			cp.rotation.y = yaw
	var zem := get_node_or_null(zem_path) as Node3D
	if zem and zp:
		zem.global_transform = Transform3D(Basis(Vector3.UP, zp.global_rotation.y), zp.global_position + Vector3(0, 0.15, 0))
		zem.set("_yaw", zp.global_rotation.y)
		zem.reset_physics_interpolation()


func sortie(p: Vector3) -> Array:
	## Points a suivre pour sortir d'une cour fermee (devant le portail puis dans la rue), ou [] si p est dehors.
	for s in sorties:
		var b: AABB = s["aabb"]
		if p.x > b.position.x and p.x < b.end.x and p.z > b.position.z and p.z < b.end.z:
			return [s["porte"], s["dehors"]]
	return []


func home_position() -> Vector3:
	var root := get_node_or_null("Lieu_maison")
	var sp := root.find_child("spawn_joueur", true, false) as Node3D if root else null
	return sp.global_position if sp else Vector3.ZERO
