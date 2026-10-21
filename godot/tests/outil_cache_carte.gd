extends SceneTree
## Outil : precalcule le cache de la carte (rues raccordees, masques chaussees et batiments au metre) apres chaque
## import de la zone (osm_import.py), et chronometre chaque etape de Carte._load.
## Lancement : godot --headless --path godot --script res://tests/outil_cache_carte.gd


func _initialize() -> void:
	var t := Time.get_ticks_msec()
	var c := Carte.zone()
	print("carte calculee en %d ms" % (Time.get_ticks_msec() - t))
	c.ecrire_cache(ProjectSettings.globalize_path(Carte.CACHE_PATH))
	var f := FileAccess.open(Carte.CACHE_PATH, FileAccess.READ)
	print("cache ecrit : %s (%.1f Mo)" % [Carte.CACHE_PATH, f.get_length() / 1e6 if f else -1.0])
	# etapes chronometrees (meme ordre que Carte._load, avec le cache)
	var e := Carte.new()
	t = Time.get_ticks_msec()
	var texte := FileAccess.get_file_as_string(Carte.DATA_PATH)
	print("  lecture du fichier : %d ms (%.1f Mo)" % [Time.get_ticks_msec() - t, texte.length() / 1e6])
	t = Time.get_ticks_msec()
	e.data = JSON.parse_string(texte)
	print("  analyse JSON : %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	print("  md5 : %s %d ms" % [e._empreinte(), Time.get_ticks_msec() - t])
	Carte._zone = null
	t = Time.get_ticks_msec()
	Carte.zone()
	print("relecture complete avec le cache : %d ms" % (Time.get_ticks_msec() - t))
	quit()
