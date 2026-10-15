extends CanvasLayer
## Mode debug (validation des phases 3 a 5). F1 : desactive -> infos -> infos + chemins.
## Infos : images/s, appels de rendu, joueur (position, vitesse, allure, au sol, vehicule), etat d'animation
## (character_anim.gd : animation procedurale, pas d'AnimationTree pour l'instant), heure, meteo, PNJ et vehicules.
## Chemins : piétons -> leur cible (cyan), vehicules -> troncon de route en cours (orange), position des PNJ.
## Teleportation (en mode debug, a pied) : touches 1 a 8 (liste TELEPORTS, reglable dans l'editeur).

@export var toggle_key := KEY_F1
@export var refresh := 0.2                  # s entre deux mises a jour des chemins
@export var teleports: Array[Dictionary] = [
	{"nom": "Carrefour principal (rond-point)", "pos": Vector3(528, 1, -301)},
	{"nom": "Route des peches (front de mer)", "pos": Vector3(43.7, 1, 10.2)},
	{"nom": "Plage", "pos": Vector3(0, 1, 330)},
	{"nom": "Terminal (parvis)", "pos": Vector3(385, 1, -280)},
	{"nom": "Terminal (hall)", "pos": Vector3(399, 1, -344)},
	{"nom": "Ararat Hypermarket (interieur)", "pos": Vector3(621, 1, 73)},
	{"nom": "Maison du joueur (cour)", "pos": Vector3(311, 1, 112)},
	{"nom": "Piste (bord, cote aerogare)", "pos": Vector3(-343, 1, -221)},
]

var mode := 0          # 0 desactive, 1 infos, 2 infos + chemins
var _label: Label
var _panel: PanelContainer
var _lines: MeshInstance3D
var _imesh: ImmediateMesh
var _t := 0.0
var _scene: Node


func _ready() -> void:
	layer = 50
	_scene = get_parent()
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_content_margin_all(8)
	sb.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.85))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_panel.add_child(_label)
	_imesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _imesh
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_lines.material_override = m
	_scene.add_child.call_deferred(_lines)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = (event as InputEventKey).keycode
	if k == toggle_key:
		mode = (mode + 1) % 3
		_apply()
	elif mode > 0 and k >= KEY_1 and k <= KEY_9 and k - KEY_1 < teleports.size():
		teleport(k - KEY_1)


func _apply() -> void:
	_panel.visible = mode > 0
	_lines.visible = mode == 2
	if mode != 2:
		_imesh.clear_surfaces()


func teleport(i: int) -> bool:
	## Teleporte le joueur (a pied) vers le point i. Renvoie false si impossible (dans un vehicule).
	var p := _scene.get_node_or_null("Player") as CharacterBody3D
	if p == null or p.get("vehicle") != null:
		return false
	var at: Vector3 = teleports[i]["pos"]
	# pose sur le sol (rayon vertical) : sol, chaussee, plage ou plancher d'un interieur
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 3.0, at.z), Vector3(at.x, at.y - 20.0, at.z))
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		at.y = (hit["position"] as Vector3).y
	p.global_position = at + Vector3(0, 0.02, 0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	var hud := _scene.get_node_or_null("HUD")
	if hud and hud.has_method("show_hint"):
		hud.show_hint("Teleportation : " + String(teleports[i]["nom"]))
	return true


func info_text() -> String:
	var lines := PackedStringArray()
	lines.append("DEBUG (F1)   %d images/s   %d appels de rendu   %d objets" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	var p := _scene.get_node_or_null("Player") as CharacterBody3D
	if p:
		var hv := Vector2(p.velocity.x, p.velocity.z).length()
		var allure := "arret"
		if hv > 0.2:
			allure = "marche" if hv <= float(p.get("walk_speed")) + 0.3 else ("trot" if hv <= float(p.get("jog_speed")) + 0.3 else "sprint")
		var veh: Node = p.get("vehicle")
		lines.append("Joueur  (%.1f, %.1f, %.1f)   %.1f m/s (%.0f km/h)  %s   au sol : %s   vehicule : %s" % [p.global_position.x,
			p.global_position.y, p.global_position.z, hv, hv * 3.6, allure, "oui" if p.is_on_floor() else "non",
			veh.name if veh else "aucun"])
		var anim: Node = p.get("anim")
		if anim:
			lines.append("Animation  procedurale (character_anim.gd)   vitesse %.1f   assis %s   en l'air %s" % [float(anim.get("speed")),
				anim.get("seated"), not bool(anim.get("on_floor"))])
	var day := _scene.get_node_or_null("JourNuit")
	var meteo := _scene.get_node_or_null("Meteo")
	lines.append("Heure %s   pluie %.2f" % [("%05.2f" % float(day.get("hour"))) if day else "?", float(meteo.get("rain")) if meteo else 0.0])
	var ped := _scene.get_node_or_null("Pietons")
	var trf := _scene.get_node_or_null("Circulation")
	lines.append("PNJ a pied %d   vehicules %d" % [(ped.get("_walkers") as Array).size() if ped else 0,
		(trf.get("_agents") as Array).size() if trf else 0])
	lines.append("Teleportation (touches) :")
	for i in range(0, teleports.size(), 2):
		var row := "  %d  %s" % [i + 1, teleports[i]["nom"]]
		if i + 1 < teleports.size():
			row = row.rpad(44) + "%d  %s" % [i + 2, teleports[i + 1]["nom"]]
		lines.append(row)
	return "\n".join(lines)


func _process(delta: float) -> void:
	if mode == 0:
		return
	_label.text = info_text()
	if mode != 2:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = refresh
	_draw_paths()


func _draw_paths() -> void:
	_imesh.clear_surfaces()
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var ped := _scene.get_node_or_null("Pietons")
	if ped:
		for w: Dictionary in ped.get("_walkers"):
			var pos: Vector3 = w.get("pos", Vector3.ZERO)
			_seg(pos + Vector3(0, 0.05, 0), pos + Vector3(0, 2.2, 0), Color(1, 1, 1))
			if w.has("target"):
				var t: Vector2 = w["target"]
				_seg(pos + Vector3(0, 0.15, 0), Vector3(t.x, 0.15, t.y), Color(0.2, 1, 1))
	var trf := _scene.get_node_or_null("Circulation")
	if trf:
		for a: Dictionary in trf.get("_agents"):
			var pts: Variant = a.get("pts")
			if pts is PackedVector2Array or pts is Array:
				var arr: Array = Array(pts)
				for j in range(maxi(0, int(a.get("i", 0))), arr.size() - 1):
					var q0: Vector2 = arr[j]
					var q1: Vector2 = arr[j + 1]
					_seg(Vector3(q0.x, 0.3, q0.y), Vector3(q1.x, 0.3, q1.y), Color(1, 0.55, 0.1))
	_imesh.surface_set_color(Color(0, 0, 0, 0))
	_imesh.surface_add_vertex(Vector3.ZERO)
	_imesh.surface_add_vertex(Vector3.ZERO)   # jamais de surface vide
	_imesh.surface_end()


func _seg(a: Vector3, b: Vector3, c: Color) -> void:
	_imesh.surface_set_color(c)
	_imesh.surface_add_vertex(a)
	_imesh.surface_set_color(c)
	_imesh.surface_add_vertex(b)
