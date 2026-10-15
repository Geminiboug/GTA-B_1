class_name Bulle
## Bulle de parole au-dessus d'un personnage (ou d'un vehicule) : texte lisible, toujours face a la camera,
## disparait apres quelques secondes. Une seule bulle a la fois par personnage (la nouvelle remplace l'ancienne).


static func say(owner: Node3D, text: String, duration := 2.8, height := 2.15, color := Color(1, 1, 1)) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var old := owner.get_node_or_null("Bulle")
	if old:
		old.queue_free()
	var l := Label3D.new()
	l.name = "Bulle"
	l.text = text
	l.font_size = 44
	l.pixel_size = 0.0045
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, height, 0)
	l.visibility_range_end = 40.0
	l.no_depth_test = true          # toujours lisible, meme derriere le joueur ou un vehicule
	l.render_priority = 2
	owner.add_child(l)
	# sous-titre en bas de l'ecran quand ca se passe pres du joueur (scripts/hud_carte.gd)
	owner.get_tree().call_group("sous_titres", "show_line", text, owner.global_position)
	var tw := l.create_tween()
	tw.tween_interval(duration)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
