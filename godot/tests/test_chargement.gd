extends SceneTree
## Ecran de chargement : vraie progression du ResourceLoader, construction de la zone en fond, carrousel qui tourne
## pendant le chargement sans le relancer, puis la zone devient current_scene (ecran titre ouvert comme avant).
var frame := 0
var ch: Node
var fails := 0
var progs: Array[float] = []
var diapos := {}
var etapes := {}
var t0 := 0
var mep: Array[float] = []
func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1
func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	ch = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	ch.duree_diapo = 0.3
	ch.duree_fondu = 0.1
	root.add_child(ch)
	current_scene = ch
func _process(_d: float) -> bool:
	frame += 1
	if is_instance_valid(ch) and ch.is_inside_tree():
		if not etapes.has(ch.etape):
			print("etape %s a %d ms" % [ch.etape, Time.get_ticks_msec() - t0])
		etapes[ch.etape] = true
		if ch.etape == "chargement":
			progs.append(ch.progression)
		if ch.etape == "mise_en_place":
			mep.append(ch.progression)
		diapos[ch._diapo] = true
	var z := current_scene
	if z != null and z.name == "ZoneAeroport" or (z != null and z.has_node("Player")):
		if not etapes.has("zone"):
			etapes["zone"] = frame
			_check(true, "la zone est devenue la scene courante (%d ms)" % (Time.get_ticks_msec() - t0))
		if frame == int(etapes["zone"]) + 5:
			_check(progs.size() >= 2 and progs[-1] >= progs[0], "progression reelle croissante (%d mesures, %.0f %% -> %.0f %%)" % [progs.size(), progs[0] * 100.0 if progs.size() else 0.0, progs[-1] * 100.0 if progs.size() else 0.0])
			_check(is_instance_valid(ch) and ch.etape == "mise_en_place", "mise en place etalee en cours, ecran affiche")
			_check(diapos.size() >= 2, "le carrousel a change d'image pendant le chargement (%d images)" % diapos.size())
			var m := z.get_node_or_null("Menus")
			_check(m == null or m.get("_root").visible, "ecran titre ouvert comme au lancement direct")
		if not is_instance_valid(ch) and not etapes.has("fin"):
			etapes["fin"] = frame
			_check(mep.size() >= 5 and mep[-1] > mep[0], "mise en place sur plusieurs images (%d), %.0f %% -> %.0f %%" % [mep.size(), mep[0] * 100.0 if mep.size() else 0.0, mep[-1] * 100.0 if mep.size() else 0.0])
			_check(not root.get_node("Partie").chantier_actif and root.get_node("Partie").chantiers.is_empty(), "toutes les etapes faites")
			var pi := z.get_node("Pietons")
			var libres := pi._walkers.filter(func(w: Dictionary) -> bool: return not w.has("chaise"))      # les vendeurs assis suivent leur tuile
			_check(libres.size() == pi.walker_count, "tous les pietons en place (%d)" % libres.size())
			_check(z.get_node("Concessions").count > 0, "concessions construites (%d)" % z.get_node("Concessions").count)
			print("RESULTAT test_chargement : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
			quit(1 if fails else 0)
			return true
	if frame > 20000 or (is_instance_valid(ch) and ch.etape == "erreur"):
		_check(false, "chargement termine (etape %s)" % (ch.etape if is_instance_valid(ch) else "?"))
		print("RESULTAT test_chargement : %d ECHEC(S)" % fails)
		quit(1)
		return true
	return false
