extends SceneTree
## Journal de partie (Phase 11) : la premiere mission jouee (avec un moment "perdu" loin de l'etal), un achat, un
## delit, une arrestation et un malaise ecrivent bien les evenements (partie_*.jsonl) et le bilan (resume_*.json).
## Lancement : godot --headless --path godot --script res://tests/test_journal.gd

const DOSSIER := "user://test_logs"
var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var partie: Node
var journal: Node
var histoire: Node
var police: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _tap(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await physics_frame
	Input.action_release(action)


func _place(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		partie = root.get_node("Partie")
		journal = partie.journal
		player = scene.get_node("Player")
		histoire = scene.get_node("Histoire")
		police = scene.get_node("Police")
		_check(journal != null and not journal.actif, "journal cree par Partie, inactif sans fenetre (tests)")
		DirAccess.make_dir_recursive_absolute(DOSSIER)
		for f in DirAccess.get_files_at(DOSSIER):
			DirAccess.remove_absolute(DOSSIER.path_join(f))
		journal.actif = true
		journal.dossier = DOSSIER
		journal.delai_perdu = 2.0
		journal.periode_position = 0.5
		journal.periode_resume = 1.0
		partie.save_path = "user://test_sauvegarde.json"
		partie.nouvelle_partie()
		histoire.set("secondes_par_caractere", 0.0)
		histoire.commencer()
		_check(FileAccess.file_exists(journal.fichier_evenements), "nouvelle partie : %s cree" % journal.fichier_evenements.get_file())
	if frame == 30:
		_place(histoire.points["tante"] + Vector3(1.2, 0.2, 0))
	if frame == 50:
		_check(histoire.step == 0, "mission « Bonne arrivée » commencee")
		_tap("parler")
	if frame == 230:
		_check(histoire.step == 1, "etape 2 : acheter le pain")
		# le joueur reste chez la tante sans aller vers l'etal : au bout de 2 s, il est note "perdu"
	if frame == 420:
		var perdu: Array = journal.resume["perdu"]
		_check(perdu.size() >= 1 and perdu[0]["mission"] == "Bonne arrivée" and int(perdu[0]["distance_m"]) > 3,
			"joueur perdu note : %s" % (str(perdu[0]) if perdu.size() > 0 else "rien"))
		scene.get_node("Commerce").buy("etal_pain", 0)
	if frame == 640:
		_place(histoire.points["tante"] + Vector3(1.0, 0.2, 0.4))
	if frame == 660:
		_tap("parler")
	if frame == 860:
		_check(histoire.idx == 1, "mission reussie (mission suivante : %d)" % histoire.idx)
		journal.mission_debut("Test chrono")
		journal.mission_fin(false, "Trop tard !")
		histoire.active = false
		police.crime("vol", player.global_position)
		police._arrest()
	if frame == 1260:
		partie.gagner(5000, "Bourse")
		partie.blesser(200.0)
	if frame == 1560:
		var ev_file: String = journal.fichier_evenements
		var res_file: String = journal.fichier_resume
		journal._fermer()
		# evenements
		var types := {}
		var lignes := FileAccess.get_file_as_string(ev_file).strip_edges().split("\n")
		var bad := 0
		for l in lignes:
			var d = JSON.parse_string(l)
			if typeof(d) != TYPE_DICTIONARY or not d.has("t"):
				bad += 1
				continue
			types[d["e"]] = int(types.get(d["e"], 0)) + 1
		_check(bad == 0, "%d lignes JSON valides" % lignes.size())
		var manquants: Array = []
		for e in ["debut", "mission_debut", "etape", "perdu", "argent", "mission_reussie", "mission_echouee", "delit",
				"recherche", "arrestations", "morts", "pos", "fin"]:
			if not types.has(e):
				manquants.append(e)
		_check(manquants.is_empty(), "tous les evenements presents" if manquants.is_empty() else "manquent : %s" % str(manquants))
		# bilan
		var r = JSON.parse_string(FileAccess.get_file_as_string(res_file))
		_check(typeof(r) == TYPE_DICTIONARY, "bilan lisible : %s" % res_file.get_file())
		if typeof(r) == TYPE_DICTIONARY:
			var m: Dictionary = r["missions"].get("Bonne arrivée", {})
			_check(m.get("reussie", false) and float(m.get("temps_reussite_s", -1)) > 5.0 and (m.get("etapes_s", {}) as Dictionary).size() == 4,
				"« Bonne arrivée » : reussie en %s s, %d etapes chronometrees" % [m.get("temps_reussite_s"), (m.get("etapes_s", {}) as Dictionary).size()])
			var t: Dictionary = r["missions"].get("Test chrono", {})
			_check(t.get("echecs", []) == ["Trop tard !"], "echec note avec sa raison")
			_check(int(r["morts"]) == 1 and int(r["arrestations"]) == 1 and int(r["delits"].get("vol", 0)) == 1 and int(r["recherche_max"]) >= 1,
				"morts %d, arrestations %d, vols %d, recherche max %d" % [r["morts"], r["arrestations"], r["delits"].get("vol", 0), r["recherche_max"]])
			var a: Dictionary = r["argent"]
			_check(int(a["depense"]) > 0 and a["par_raison"].has("Amende") and a["par_raison"].has("Soins"),
				"argent : %s F depenses (%s)" % [a["depense"], ", ".join(a["par_raison"].keys())])
			_check((r["zones"] as Array).size() > 0 and float(r["temps_jeu_s"]) > 20.0,
				"temps de jeu %.0f s, %d zones frequentees" % [r["temps_jeu_s"], (r["zones"] as Array).size()])
		# version dans le menu, version de sauvegarde et conversion v1 -> v2
		var ver_lbl := scene.get_node_or_null("Menus").find_child("Version", true, false) as Label
		_check(ver_lbl != null and ver_lbl.text == "v" + partie.version_jeu(),
			"menu affiche la version : %s" % (ver_lbl.text if ver_lbl else "absente"))
		_check(bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false)),
			"log d'erreurs sur disque active (user://logs/godot.log)")
		_check(partie.sauver(scene), "sauvegarde ecrite")
		var sd = JSON.parse_string(FileAccess.get_file_as_string(partie.save_path))
		_check(typeof(sd) == TYPE_DICTIONARY and int(sd.get("version", 0)) == partie.SAVE_VERSION and sd.get("version_jeu", "") == partie.version_jeu(),
			"sauvegarde version %s (jeu %s)" % [sd.get("version"), sd.get("version_jeu")])
		var v1 := {"version": 1, "argent": 4500, "missions": ["Bonne arrivée", "Le zem de papa"]}
		var f1 := FileAccess.open(partie.save_path, FileAccess.WRITE)
		f1.store_string(JSON.stringify(v1))
		f1.close()
		_check(partie.charger(scene) and partie.argent == 4500 and int(partie.drapeaux.get("mission", -1)) == 2,
			"ancienne sauvegarde v1 convertie et chargee (mission %s)" % str(partie.drapeaux.get("mission")))
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		return true
	return frame > 3000

