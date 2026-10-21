class_name Explosion
## Explosion d'un vehicule en feu (retour d'Olympe du 21/10/2026 : degats, feu, puis explosion realiste) : boule de feu, fumee
## noire, debris, flash de lumiere, detonation, souffle qui blesse et renverse le joueur et les passants proches, et qui
## abime les vehicules voisins (reaction en chaine).

static var _tache_tex: Texture2D


static func tache() -> Texture2D:
	if _tache_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tache_tex = t
	return _tache_tex


static func _particules(amount: int, vie: float, additif: bool, taille: Vector2, rampe: Gradient, vitesse: Vector2, gravite: Vector3, rayon: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = vie
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = rayon
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = vitesse.x
	pm.initial_velocity_max = vitesse.y
	pm.gravity = gravite
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = taille.x
	pm.scale_max = taille.y
	var gt := GradientTexture1D.new()
	gt.gradient = rampe
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additif else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = tache()
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	q.material = m
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 40, 60))
	return p


static func boum(monde: Node, pos: Vector3, rayon := 9.0, source: Node = null) -> void:
	var racine := Node3D.new()
	racine.name = "Explosion"
	monde.add_child(racine)
	racine.global_position = pos
	# boule de feu : orange vif additif (les couleurs saturees restent orange sur le sable), coeur blanc-jaune bref
	var feu := Gradient.new()
	feu.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	feu.colors = PackedColorArray([Color(1.0, 0.6, 0.12, 1), Color(0.95, 0.3, 0.04, 0.95), Color(0.5, 0.1, 0.02, 0.6), Color(0.1, 0.03, 0.01, 0)])
	var boule := _particules(60, 1.6, false, Vector2(4.0, 8.0), feu, Vector2(2.0, 6.5), Vector3(0, 3.0, 0), 1.0)
	racine.add_child(boule)
	boule.emitting = true
	var coeur_g := Gradient.new()
	coeur_g.offsets = PackedFloat32Array([0.0, 1.0])
	coeur_g.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1), Color(1.0, 0.5, 0.1, 0)])
	var coeur := _particules(10, 0.4, true, Vector2(6.0, 10.0), coeur_g, Vector2(0.5, 2.0), Vector3.ZERO, 0.4)
	racine.add_child(coeur)
	coeur.emitting = true
	# fumee noire qui monte longtemps
	var fum := Gradient.new()
	fum.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	fum.colors = PackedColorArray([Color(0.12, 0.1, 0.1, 0.0), Color(0.1, 0.09, 0.09, 0.65), Color(0.2, 0.19, 0.19, 0.0)])
	var fumee := _particules(30, 6.0, false, Vector2(5.0, 9.0), fum, Vector2(1.0, 3.5), Vector3(0, 1.6, 0), 1.2)
	racine.add_child(fumee)
	fumee.emitting = true
	# eclats (tole, vitres)
	var ecl := Gradient.new()
	ecl.offsets = PackedFloat32Array([0.0, 1.0])
	ecl.colors = PackedColorArray([Color(1, 0.7, 0.3, 1), Color(0.2, 0.15, 0.1, 0)])
	var eclats := _particules(26, 1.6, true, Vector2(0.12, 0.3), ecl, Vector2(8.0, 16.0), Vector3(0, -9.0, 0), 0.4)
	racine.add_child(eclats)
	eclats.emitting = true
	# flash
	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.65, 0.3)
	lum.omni_range = rayon * 2.5
	lum.light_energy = 16.0
	lum.shadow_enabled = false
	lum.position = Vector3(0, 1.2, 0)
	racine.add_child(lum)
	var tw := racine.create_tween()
	tw.tween_property(lum, "light_energy", 0.0, 0.9).set_ease(Tween.EASE_OUT)
	# detonation
	var son := AudioStreamPlayer3D.new()
	son.stream = AudioSynth.explosion()
	son.unit_size = 45.0
	son.max_distance = 600.0
	son.volume_db = 4.0
	racine.add_child(son)
	son.play()
	racine.get_tree().create_timer(9.0).timeout.connect(racine.queue_free)
	_souffle(monde, pos, rayon, source)


static func _souffle(monde: Node, pos: Vector3, rayon: float, source: Node) -> void:
	var arbre := monde.get_tree()
	# joueur
	var pl := monde.get_node_or_null("Player") as Node3D
	if pl:
		var d := pl.global_position.distance_to(pos)
		if d < rayon * 4.0 and pl.has_method("shake"):
			pl.call("shake", clampf(1.4 - d / (rayon * 4.0), 0.1, 1.2))
		if d < rayon and pl.get("vehicle") == null:
			var k := 1.0 - d / rayon
			arbre.root.get_node("Partie").call("blesser", lerpf(15.0, 75.0, k))
			var away := (pl.global_position - pos) * Vector3(1, 0, 1)
			if pl.get("velocity") != null and away.length() > 0.01:
				pl.velocity += away.normalized() * 9.0 * k + Vector3.UP * 5.0 * k
	# passants
	var peds := monde.get_node_or_null("Pietons")
	if peds and peds.has_method("souffle"):
		peds.call("souffle", pos, rayon)
	# vehicules voisins : tole enfoncee, feu possible (reaction en chaine)
	for v in arbre.get_nodes_in_group("vehicules"):
		if v == source or not (v is Node3D) or not v.has_method("damage"):
			continue
		var dv: float = (v as Node3D).global_position.distance_to(pos)
		if dv < rayon * 1.2:
			v.call("damage", lerpf(70.0, 12.0, dv / (rayon * 1.2)))
