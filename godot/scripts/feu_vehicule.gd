class_name FeuVehicule
extends Node3D
## Vehicule qui brule : les flammes grossissent, puis il explose (scripts/explosion.gd) et reste une epave carbonisee
## qu'on ne peut plus conduire. Utilise par les voitures (voiture.gd) et les motos (zem.gd).

@export var delai := 12.0            # s de feu avant l'explosion (moitie si le vehicule est completement detruit)
@export var rayon := 9.0             # m : rayon du souffle

var vehicule: Node3D
var flammes: Node3D
var lumiere: Light3D
var t := 0.0
var explose := false
var _vacillement := 0.0


static func allumer(v: Node3D, flammes_: Node3D = null, lumiere_: Light3D = null, delai_ := 12.0) -> FeuVehicule:
	var ex := v.get_node_or_null("FeuVehicule") as FeuVehicule
	if ex:
		return ex
	var f := FeuVehicule.new()
	f.name = "FeuVehicule"
	f.vehicule = v
	f.flammes = flammes_
	f.lumiere = lumiere_
	f.delai = delai_
	v.add_child(f)
	return f


static func flammes_moto(pos: Vector3) -> Array:
	## Flammes et lueur pour un vehicule sans feu propre (moto) : [particules, lumiere].
	var p := GPUParticles3D.new()
	p.amount = 30
	p.lifetime = 0.7
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.15, 0.05, 0.3)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	g.set_color(1, Color(0.6, 0.1, 0.02, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.55)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = Explosion.tache()
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.omni_range = 5.0
	l.light_energy = 2.0
	l.shadow_enabled = false
	l.position = pos + Vector3(0, 0.4, 0)
	return [p, l]


func _physics_process(delta: float) -> void:
	if vehicule == null or not is_instance_valid(vehicule):
		queue_free()
		return
	t += delta
	_vacillement += delta * 11.0
	if explose:
		# l'epave brule encore un moment, puis les flammes s'eteignent
		if flammes and is_instance_valid(flammes) and t > 70.0:
			(flammes as GPUParticles3D).emitting = false
			if lumiere and is_instance_valid(lumiere):
				lumiere.light_energy = move_toward(lumiere.light_energy, 0.0, delta * 0.5)
		return
	var total := delai * (0.5 if float(vehicule.get("health")) <= 0.0 else 1.0)
	var k := clampf(t / total, 0.0, 1.0)
	if flammes and is_instance_valid(flammes):
		flammes.scale = Vector3.ONE * (1.0 + 1.8 * k)
	if lumiere and is_instance_valid(lumiere):
		lumiere.light_energy = (2.0 + 4.0 * k) * (0.8 + 0.2 * sin(_vacillement) + 0.1 * sin(_vacillement * 2.7))
		lumiere.omni_range = 6.0 + 4.0 * k
	if t >= total:
		_exploser()


func _exploser() -> void:
	explose = true
	t = 0.0
	var v := vehicule
	var monde := v.get_parent()
	var pos := v.global_position + Vector3.UP * 0.8
	# l'occupant est projete et blesse
	if v.get("has_rider"):
		var pl := monde.get_node_or_null("Player")
		if pl and pl.get("vehicle") == v:
			pl.call("exit_vehicle", true)
			get_tree().root.get_node("Partie").call("blesser", 55.0)
			if pl.get("velocity") != null:
				pl.velocity += Vector3(randf_range(-3, 3), 6.0, randf_range(-3, 3))
	v.set("epave", true)
	v.set("health", 0.0)
	if v.get("_vel") != null:
		v.set("_vel", Vector2.ZERO)
	if v.get("speed") != null:
		v.set("speed", 0.0)
	if v.get("moteur") != null:
		v.set("moteur", false)
	Explosion.boum(monde, pos, rayon, v)
	_carboniser(v)
	# la caisse saute sous le souffle puis retombe
	var vis := (v.get("_visual") if v.get("_visual") != null else v.get("visual")) as Node3D
	if vis:
		var y0 := vis.position.y
		var rot0 := vis.rotation
		var tw := create_tween()
		tw.tween_property(vis, "position:y", y0 + 0.7, 0.18).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(vis, "rotation:z", rot0.z + randf_range(-0.12, 0.12), 0.18)
		tw.tween_property(vis, "position:y", y0, 0.35).set_ease(Tween.EASE_IN)
	if flammes and is_instance_valid(flammes):
		flammes.scale = Vector3.ONE * 2.6
		(flammes as GPUParticles3D).emitting = true
	if lumiere and is_instance_valid(lumiere):
		lumiere.light_energy = 5.0


static func _carboniser(v: Node3D) -> void:
	## Epave : tout le vehicule noirci (couche sombre au-dessus des materiaux, sans les modifier : reparer() la retire).
	var suie := StandardMaterial3D.new()
	suie.albedo_color = Color(0.03, 0.025, 0.02, 0.96)
	suie.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	suie.roughness = 1.0
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = suie


static func decarboniser(v: Node3D) -> void:
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = null
