extends CanvasLayer
## Mini-carte et grande carte, comme dans les GTA.
## - Mini-carte ronde en haut a gauche : centree sur le joueur, tourne avec la camera, s'eloigne quand on roule
##   vite. Nord, fleche du joueur, destination (collee au bord si elle est loin), marqueurs proches,
##   nom de la rue et distance restante dessous.
## - Grande carte : touche M (manette : Select / Back). Le jeu est en pause.
##   Souris : clic gauche = destination (re-clic dessus = l'enlever), clic droit = marqueur perso (ou l'enlever),
##   glisser = deplacer, molette = zoom. Clavier / manette : ZQSD ou stick gauche = deplacer, gachettes = zoom,
##   Entree / A = destination au viseur, P / X = marqueur au viseur, M ou Echap / B = fermer.
## - Destination : itineraire GPS sur les rues (sens uniques respectes, scripts/carte.gd), recalcule en route,
##   colonne de lumiere visible de loin sur place ; arrive a 12 m : effacee avec un petit son.
## Le fond de carte est dessine une seule fois au lancement (SubViewport) a partir des donnees de la zone.

@export var player_path: NodePath = ^"../Player"
@export var minimap_size := 240.0
@export var minimap_margin := 18.0

const S := 2.0                                    # pixels de texture par metre
const SHADER := preload("res://shaders/minicarte.gdshader")
const PINS_FILE := "user://marqueurs.json"
const COL_LAND := Color(0.2, 0.215, 0.195)
const COL_BUILDING := Color(0.33, 0.33, 0.35)
const COL_BUILDING_EDGE := Color(0.24, 0.24, 0.26)
const COL_SEA := Color(0.17, 0.34, 0.5)
const COL_BEACH := Color(0.62, 0.57, 0.43)
const COL_MAJOR := Color(0.93, 0.87, 0.62)
const COL_MINOR := Color(0.78, 0.78, 0.76)
const COL_UNPAVED := Color(0.6, 0.53, 0.43)
const COL_EDGE := Color(0.11, 0.11, 0.12)
const COL_ROUTE := Color(0.74, 0.32, 0.98)
const COL_WAYPOINT := Color(0.98, 0.82, 0.18)
const COL_PIN := Color(0.25, 0.75, 1.0)
const ZONE_COLORS := {"zone_herbe": Color(0.22, 0.32, 0.2), "zone_humide": Color(0.21, 0.3, 0.24),
	"aeroport_tarmac": Color(0.36, 0.37, 0.38), "zone_parking": Color(0.33, 0.33, 0.35),
	"zone_eau": Color(0.18, 0.33, 0.45), "zone_piscine": Color(0.3, 0.6, 0.75), "zone_plage": COL_BEACH}
const PLACES := [
	["Aéroport Int. Cardinal Cotodji", Vector2(397, -318)],
	["Ararat Hypermarket", Vector2(617, 95)],
	["L'Épave Volante", Vector2(-177, 247)],
	["Sweet Dream Beach", Vector2(622, 292)],
	["Haie Verte", Vector2(-150, -840)],
	["Cadjéhoué", Vector2(550, -1080)],
	["Maquis La Plaja", Vector2(-159, 54)],
	["Plage", Vector2(150, 330)],
]

var has_waypoint := false
var waypoint := Vector2.ZERO
var pins: Array = []                       # Vector2
var route := PackedVector2Array()
var route_length := 0.0

var _carte: Carte
var _player: Node3D
var _origin := Vector2.ZERO
var _size_m := Vector2.ONE
var _base_vp: SubViewport
var _over_vp: SubViewport
var _over_node: Node2D
var _holder: Control
var _mini_mat: ShaderMaterial
var _blips: Control
var _info: Label
var _big: Control
var _big_open := false
var _view_center := Vector2.ZERO
var _view_scale := 1.5
var _radius := 90.0
var _route_timer := 0.0
var _street_timer := 0.0
var _street := ""
var _street_labels: Array = []             # [nom, position, angle]
var _beam: MeshInstance3D
var _font: Font
var _press := Vector2.ZERO
var _dragging := false
var _ding: AudioStreamPlayer
var _subtitle: Label
var _subtitle_t := 0.0


var _place_label: Label
var _place_t := 0.0
var _hint: Label
var _hint_t := 0.0
var _home := Vector2.INF


func show_place(text: String) -> void:
	## Nom du lieu (ou evenement) en haut de l'ecran, comme dans les GTA.
	_place_label.text = text
	_place_t = 3.5


func show_hint(text: String) -> void:
	## Indication d'action (a appeler a chaque image tant qu'elle s'applique).
	_hint.text = text
	_hint_t = 0.25


func show_line(text: String, where: Vector3) -> void:
	## Sous-titre d'une replique prononcee pres du joueur (moins de 18 m de la camera).
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(where) > 18.0:
		return
	_subtitle.text = text
	_subtitle_t = 3.2


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carte = Carte.zone()
	_player = get_node_or_null(player_path)
	var b: Array = _carte.data["bounds"]
	_origin = Vector2(float(b[0]), float(b[1]))
	_size_m = Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	_font = ThemeDB.fallback_font
	_base_vp = _make_viewport(false)
	var base := Node2D.new()
	_base_vp.add_child(base)
	base.draw.connect(_paint_base.bind(base))
	_over_vp = _make_viewport(true)
	_over_node = Node2D.new()
	_over_vp.add_child(_over_node)
	_over_node.draw.connect(_paint_overlay)
	_build_minimap()
	_build_big_map()
	_build_beam()
	_street_labels = _find_street_labels()
	_ding = AudioStreamPlayer.new()
	_ding.stream = AudioSynth.ding()
	_ding.volume_db = -6.0
	add_child(_ding)
	_load_pins()
	add_to_group("sous_titres")
	_place_label = _make_label(30, Vector2(-450, 70), Vector2(900, 50), Control.PRESET_CENTER_TOP)
	_place_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_hint = _make_label(20, Vector2(-400, -170), Vector2(800, 36), Control.PRESET_CENTER_BOTTOM)
	var lx: Dictionary = _carte.data.get("lieux", {})
	if lx.has("maison"):
		_home = Vector2(float(lx["maison"]["center"][0]), float(lx["maison"]["center"][1]))
	_subtitle = Label.new()
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.position = Vector2(-500, -110)
	_subtitle.size = Vector2(1000, 60)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_subtitle.add_theme_constant_override("outline_size", 7)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)


# ------------------------------------------------------------------ fond de carte
func _make_viewport(transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(_size_m.x * S), ceili(_size_m.y * S))
	vp.transparent_bg = transparent
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	return vp


func _w2m(p: Vector2) -> Vector2:
	return (p - _origin) * S


func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(_w2m(Vector2(float(p[0]), float(p[1]))))
	return out


func _poly(n: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		n.draw_colored_polygon(pts, col)
		return
	# contour qui se recoupe (rare dans OSM) : triangulation de Delaunay, on garde les triangles interieurs
	var tri := Geometry2D.triangulate_delaunay(pts)
	for i in range(0, tri.size(), 3):
		var t := PackedVector2Array([pts[tri[i]], pts[tri[i + 1]], pts[tri[i + 2]]])
		if Geometry2D.is_point_in_polygon((t[0] + t[1] + t[2]) / 3.0, pts):
			n.draw_colored_polygon(t, col)


func _road_line(n: CanvasItem, pts: PackedVector2Array, width_px: float, col: Color) -> void:
	n.draw_polyline(pts, col, width_px, true)
	for p in pts:
		n.draw_circle(p, width_px / 2.0, col)  # jonctions arrondies


func _paint_base(n: Node2D) -> void:
	var data := _carte.data
	n.draw_rect(Rect2(Vector2.ZERO, _size_m * S), COL_LAND)
	for z in data.get("zones", []):
		var col: Color = ZONE_COLORS.get(z["kind"], Color(0, 0, 0, 0))
		if col.a > 0.0:
			_poly(n, _pts(z["pts"]), col)
	var coast := _pts(data["coast"])
	var inner := _pts(data["beach_inner"])
	if inner.size() > 1 and coast.size() > 1:
		var beach := PackedVector2Array(inner)
		var rc := coast.duplicate()
		rc.reverse()
		beach.append_array(rc)
		_poly(n, beach, COL_BEACH)
	if coast.size() > 1:
		var sea := coast.duplicate()
		var bottom := (_size_m.y + 800.0) * S
		sea.append(Vector2(sea[sea.size() - 1].x, bottom))
		sea.append(Vector2(sea[0].x, bottom))
		_poly(n, sea, COL_SEA)
	var prom := _pts(data.get("promenade", []))
	if prom.size() > 1:
		n.draw_polyline(prom, Color(0.5, 0.49, 0.47), 8.0 * S, true)
	for a in data.get("aeroways", []):
		var c := Color(0.44, 0.44, 0.46) if a["kind"] != "taxiway" else Color(0.4, 0.4, 0.42)
		_road_line(n, _pts(a["pts"]), float(a["width"]) * S, c)
	for bld in data["buildings"]:
		var pts := _pts(bld["pts"])
		_poly(n, pts, COL_BUILDING if bld.get("roof", "") != "abri" else COL_BUILDING.lerp(COL_LAND, 0.5))
		if pts.size() > 2:
			var closed := pts.duplicate()
			closed.append(pts[0])
			n.draw_polyline(closed, COL_BUILDING_EDGE, 1.0)
	# rues : contour sombre puis remplissage, petites rues d'abord
	var order := [["service", "track", "footway", "path", "pedestrian"], ["residential", "unclassified", "living_street"],
		["tertiary", "secondary", "primary", "trunk"]]
	for pass_i in 2:
		for group in order:
			for r in _carte.roads:
				if not (r["kind"] in group):
					continue
				var pts := PackedVector2Array()
				for p in r["pts"]:
					pts.append(_w2m(p))
				var w: float = maxf(float(r["width"]) * S, 4.0)
				if pass_i == 0:
					_road_line(n, pts, w + 2.0 * S, COL_EDGE)
				else:
					var col := COL_MINOR
					if r["major"]:
						col = COL_MAJOR
					elif r["surface"] == "terre":
						col = COL_UNPAVED
					_road_line(n, pts, w, col)


func _paint_overlay() -> void:
	if route.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in route:
		pts.append(_w2m(p))
	_road_line(_over_node, pts, 6.5 * S, Color(0.12, 0.04, 0.16, 0.85))
	_road_line(_over_node, pts, 4.0 * S, COL_ROUTE)


func _find_street_labels() -> Array:
	## Un nom par rue nommee, au milieu de son plus long troncon (grande carte).
	var best := {}
	for r in _carte.roads:
		var name: String = r["name"]
		if name == "" or not r["car"]:
			continue
		var pts: PackedVector2Array = r["pts"]
		var L := 0.0
		for i in pts.size() - 1:
			L += pts[i].distance_to(pts[i + 1])
		if L > best.get(name, [0.0])[0]:
			var acc := 0.0
			for i in pts.size() - 1:
				var seg := pts[i].distance_to(pts[i + 1])
				if acc + seg >= L / 2.0:
					var d := (pts[i + 1] - pts[i]).normalized()
					var ang := atan2(d.y, d.x)
					if absf(ang) > PI / 2.0:
						ang += PI  # texte jamais a l'envers
					best[name] = [L, pts[i].lerp(pts[i + 1], (L / 2.0 - acc) / maxf(seg, 0.01)), ang]
					break
				acc += seg
	var out := []
	for name in best:
		out.append([name, best[name][1], best[name][2]])
	return out


# ------------------------------------------------------------------ mini-carte
func _build_minimap() -> void:
	_holder = Control.new()
	_holder.position = Vector2(minimap_margin, minimap_margin)
	_holder.size = Vector2(minimap_size, minimap_size + 52.0)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	var mini := ColorRect.new()
	mini.size = Vector2(minimap_size, minimap_size)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_mat = ShaderMaterial.new()
	_mini_mat.shader = SHADER
	_mini_mat.set_shader_parameter("base_map", _base_vp.get_texture())
	_mini_mat.set_shader_parameter("overlay", _over_vp.get_texture())
	_mini_mat.set_shader_parameter("map_origin", _origin)
	_mini_mat.set_shader_parameter("map_size_m", _size_m)
	mini.material = _mini_mat
	_holder.add_child(mini)
	_blips = Control.new()
	_blips.size = mini.size
	_blips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blips.draw.connect(_draw_blips)
	_holder.add_child(_blips)
	_info = Label.new()
	_info.position = Vector2(-20, minimap_size + 12.0)   # sous la barre de sante (scripts/hud_jeu.gd)
	_info.size = Vector2(minimap_size + 40.0, 44.0)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 5)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_info)


func _player_pos() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var v = _player.get("vehicle")
	var n: Node3D = v if v else _player
	return Vector2(n.global_position.x, n.global_position.z)


func _player_yaw() -> float:
	var v = _player.get("vehicle") if _player else null
	if v:
		var f: Vector3 = -(v as Node3D).global_basis.z
		return atan2(-f.x, -f.z)
	var body := _player.get_node_or_null("Body") as Node3D if _player else null
	return body.global_rotation.y if body else 0.0


func _player_speed() -> float:
	if _player == null:
		return 0.0
	var v = _player.get("vehicle")
	if v and v.get("speed") != null:
		return absf(float(v.get("speed")))
	return Vector2((_player as CharacterBody3D).velocity.x, (_player as CharacterBody3D).velocity.z).length()


func _cam_heading() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var f := -cam.global_basis.z
	return atan2(-f.x, -f.z)


func _to_mini(w: Vector2, pp: Vector2, h: float, R: float) -> Vector2:
	var fwd := Vector2(-sin(h), -cos(h))
	var right := Vector2(cos(h), -sin(h))
	var rel := w - pp
	return Vector2(rel.dot(right), -rel.dot(fwd)) / _radius * R


func _arrow(ci: CanvasItem, at: Vector2, dir_angle: float, size: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, -size), Vector2(size * 0.7, size * 0.75), Vector2(0, size * 0.35),
		Vector2(-size * 0.7, size * 0.75)])
	var out := PackedVector2Array()
	for p in pts:
		out.append(at + p.rotated(dir_angle))
	ci.draw_colored_polygon(out, col)
	out.append(out[0])
	ci.draw_polyline(out, Color(0, 0, 0, 0.85), 1.5, true)


func _diamond(ci: CanvasItem, at: Vector2, size: float, col: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -size), at + Vector2(size, 0), at + Vector2(0, size), at + Vector2(-size, 0)])
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0, 0, 0, 0.9), 1.5, true)


func _draw_blips() -> void:
	var R := minimap_size / 2.0
	var c := Vector2(R, R)
	var pp := _player_pos()
	var h := _cam_heading()
	# marqueurs proches
	for p in pins:
		var q := _to_mini(p, pp, h, R)
		if q.length() < R * 0.9:
			_blips.draw_circle(c + q, 5.0, Color(0, 0, 0, 0.8))
			_blips.draw_circle(c + q, 3.8, COL_PIN)
	# reperes carres (stationnements de zems, scripts/territoires.gd) : couleur du proprietaire
	for n in get_tree().get_nodes_in_group("carte_repere"):
		var p3 := (n as Node3D).global_position
		var rq := _to_mini(Vector2(p3.x, p3.z), pp, h, R)
		if rq.length() < R * 0.9:
			_blips.draw_rect(Rect2(c + rq - Vector2(5, 5), Vector2(10, 10)), Color(0, 0, 0, 0.85))
			_blips.draw_rect(Rect2(c + rq - Vector2(3.8, 3.8), Vector2(7.6, 7.6)), n.get_meta("couleur", Color.WHITE))
	# maison du joueur (toujours indiquee, collee au bord si loin)
	if _home != Vector2.INF:
		var hq := _to_mini(_home, pp, h, R)
		if hq.length() > R * 0.86:
			hq = hq.normalized() * R * 0.86
		_house_icon(_blips, c + hq, 7.0)
	# destination : collee au bord de la mini-carte si elle est loin
	if has_waypoint:
		var q := _to_mini(waypoint, pp, h, R)
		if q.length() > R * 0.86:
			q = q.normalized() * R * 0.86
		_diamond(_blips, c + q, 7.0, COL_WAYPOINT)
	# patrouilles de police (scripts/police.gd) : point rouge / bleu qui clignote, colle au bord si loin
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	for car in get_tree().get_nodes_in_group("police_car"):
		var p3 := (car as Node3D).global_position
		var pq := _to_mini(Vector2(p3.x, p3.z), pp, h, R)
		if pq.length() > R * 0.86:
			pq = pq.normalized() * R * 0.86
		_blips.draw_circle(c + pq, 6.0, Color(0, 0, 0, 0.85))
		_blips.draw_circle(c + pq, 4.6, Color(0.95, 0.15, 0.15) if blink else Color(0.2, 0.4, 1.0))
	# nord
	var nq := _to_mini(pp + Vector2(0, -1000.0), pp, h, R).normalized() * (R - 13.0)
	_blips.draw_circle(c + nq, 9.0, Color(0.05, 0.05, 0.06, 0.95))
	_blips.draw_string(_font, c + nq + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
	# joueur : fleche dans le sens du corps (ou du vehicule) par rapport a la camera
	_arrow(_blips, c, -( _player_yaw() - h), 9.0, Color(1, 1, 1))


func _process(delta: float) -> void:
	if _player == null:
		return
	_place_t = maxf(0.0, _place_t - delta)
	_place_label.modulate.a = clampf(_place_t / 0.6, 0.0, 1.0)
	_hint_t = maxf(0.0, _hint_t - delta)
	_hint.visible = _hint_t > 0.0
	_subtitle_t = maxf(0.0, _subtitle_t - delta)
	_subtitle.modulate.a = clampf(_subtitle_t / 0.4, 0.0, 1.0)
	var pp := _player_pos()
	var target_r := lerpf(75.0, 170.0, clampf((_player_speed() - 4.0) / 16.0, 0.0, 1.0))
	_radius = lerpf(_radius, target_r, 1.0 - exp(-1.5 * delta))
	_mini_mat.set_shader_parameter("center", pp)
	_mini_mat.set_shader_parameter("heading", _cam_heading())
	_mini_mat.set_shader_parameter("radius_m", _radius)
	_blips.queue_redraw()
	if has_waypoint and not _big_open:
		if pp.distance_to(waypoint) < 12.0:
			clear_waypoint()
			_ding.play()
		else:
			_route_timer -= delta
			if _route_timer <= 0.0:
				_route_timer = 1.5
				_update_route()
	_street_timer -= delta
	if _street_timer <= 0.0:
		_street_timer = 0.5
		_street = _street_name(pp)
	var lines := []
	if _street != "":
		lines.append(_street)
	if has_waypoint:
		lines.append("Destination : %s" % _fmt_dist(route_length + pp.distance_to(route[0]) if route.size() > 0 else pp.distance_to(waypoint)))
	_info.text = "\n".join(lines)
	if _big_open:
		_big_controls(delta)
		_big.queue_redraw()


func _make_label(fs: int, pos: Vector2, size: Vector2, preset: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.position = pos
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _house_icon(ci: CanvasItem, at: Vector2, size: float) -> void:
	## Pictogramme "maison" (comme la planque des GTA) : vert, contour noir.
	var pts := PackedVector2Array([at + Vector2(-size, 0), at + Vector2(0, -size * 0.9), at + Vector2(size, 0),
		at + Vector2(size * 0.75, 0), at + Vector2(size * 0.75, size * 0.8), at + Vector2(-size * 0.75, size * 0.8), at + Vector2(-size * 0.75, 0)])
	ci.draw_colored_polygon(pts, Color(0.15, 0.75, 0.3))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0, 0, 0, 0.9), 1.5, true)


func _fmt_dist(d: float) -> String:
	return "%d m" % int(round(d / 10.0) * 10.0) if d < 1000.0 else "%.1f km" % (d / 1000.0)


func _street_name(p: Vector2) -> String:
	var ri := _carte.road_at(p)
	if ri < 0:
		var near := _carte.nearest_on_network(p)
		if near["edge"] < 0 or near["dist"] > 14.0:
			return ""
		ri = _carte.edges[near["edge"]]["road"]
	return _carte.roads[ri]["name"]


# ------------------------------------------------------------------ destination et itineraire
func set_waypoint(p: Vector2) -> void:
	has_waypoint = true
	waypoint = p
	_beam.global_position = Vector3(p.x, 75.0, p.y)
	_beam.visible = true
	_update_route()


func clear_waypoint() -> void:
	has_waypoint = false
	route = PackedVector2Array()
	route_length = 0.0
	_beam.visible = false
	_over_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_over_node.queue_redraw()


func _update_route() -> void:
	var pp := _player_pos()
	var on_foot: bool = _player.get("vehicle") == null if _player else true
	# dans une cour fermee (maison du joueur) : d'abord le portail, puis la rue (scripts/lieux.gd)
	var lieux := get_node_or_null("../Lieux")
	var pp3: Vector3 = _player.global_position if _player else Vector3(pp.x, 0, pp.y)
	var exit: Array = lieux.sortie(pp3) if lieux and lieux.has_method("sortie") else []
	var head := PackedVector2Array()
	for q: Vector3 in exit:
		head.append(Vector2(q.x, q.z))
	# destination dans une cour fermee : on y entre par le portail
	var tail := PackedVector2Array()
	var entry: Array = lieux.sortie(Vector3(waypoint.x, 0, waypoint.y)) if lieux and lieux.has_method("sortie") and on_foot else []
	if exit.is_empty():
		for i in range(entry.size() - 1, -1, -1):
			tail.append(Vector2(entry[i].x, entry[i].z))
	route = _carte.route(head[-1] if head.size() > 0 else pp, tail[0] if tail.size() > 0 else waypoint, not on_foot)
	if route.size() > 0:
		route.append_array(tail)
		route.append(waypoint)
		head.append_array(route)
		route = head
	route_length = 0.0
	for i in route.size() - 1:
		route_length += route[i].distance_to(route[i + 1])
	_over_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_over_node.queue_redraw()


func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.6
	cm.height = 150.0
	cm.radial_segments = 12
	cm.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(COL_WAYPOINT.r, COL_WAYPOINT.g, COL_WAYPOINT.b, 0.28)
	cm.material = m
	_beam.mesh = cm
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	get_parent().add_child.call_deferred(_beam)


# ------------------------------------------------------------------ marqueurs personnels
func toggle_pin(p: Vector2, tolerance_m: float) -> void:
	for i in pins.size():
		if (pins[i] as Vector2).distance_to(p) < tolerance_m:
			pins.remove_at(i)
			_save_pins()
			return
	pins.append(p)
	_save_pins()


func _save_pins() -> void:
	var arr := []
	for p in pins:
		arr.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	var f := FileAccess.open(PINS_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(arr))


func _load_pins() -> void:
	if not FileAccess.file_exists(PINS_FILE):
		return
	var arr = JSON.parse_string(FileAccess.get_file_as_string(PINS_FILE))
	if arr is Array:
		for p in arr:
			pins.append(Vector2(float(p[0]), float(p[1])))


# ------------------------------------------------------------------ grande carte
func _build_big_map() -> void:
	_big = Control.new()
	_big.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big.visible = false
	_big.mouse_filter = Control.MOUSE_FILTER_STOP
	_big.draw.connect(_draw_big)
	_big.gui_input.connect(_big_gui_input)
	add_child(_big)


func is_map_open() -> bool:
	return _big_open


func open_map(open: bool) -> void:
	if open == _big_open:
		return
	_big_open = open
	_big.visible = open
	_holder.visible = not open
	get_tree().paused = open
	if open:
		_view_center = _player_pos()
		_view_scale = clampf(_big.size.y / 420.0, 0.8, 4.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if has_waypoint:
			_update_route()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		open_map(not _big_open)
		get_viewport().set_input_as_handled()
	elif _big_open and event.is_action_pressed("ui_cancel"):
		open_map(false)
		get_viewport().set_input_as_handled()
	elif _big_open and event.is_action_pressed("ui_accept"):
		_click_waypoint(_view_center)
		get_viewport().set_input_as_handled()
	elif _big_open and event.is_action_pressed("map_pin"):
		toggle_pin(_view_center, 14.0 / _view_scale)
		get_viewport().set_input_as_handled()


func _w2s(w: Vector2) -> Vector2:
	return (w - _view_center) * _view_scale + _big.size / 2.0


func _s2w(s: Vector2) -> Vector2:
	return (s - _big.size / 2.0) / _view_scale + _view_center


func _click_waypoint(w: Vector2) -> void:
	if has_waypoint and waypoint.distance_to(w) < 16.0 / _view_scale:
		clear_waypoint()
	else:
		set_waypoint(w)


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before := _s2w(screen)
	_view_scale = clampf(_view_scale * factor, 0.5, 8.0)
	_view_center += before - _s2w(screen)
	_clamp_view()


func _clamp_view() -> void:
	_view_center = _view_center.clamp(_origin, _origin + _size_m)


func _big_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_dragging = false
			elif not _dragging:
				_click_waypoint(_s2w(mb.position))
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			toggle_pin(_s2w(mb.position), 14.0 / _view_scale)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if _dragging or (event as InputEventMouseMotion).position.distance_to(_press) > 6.0:
			_dragging = true
			_view_center -= (event as InputEventMouseMotion).relative / _view_scale
			_clamp_view()


func _big_controls(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move.length() > 0.05:
		_view_center += move * 420.0 / _view_scale * delta
		_clamp_view()
	var zoom := Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
	if absf(zoom) > 0.05:
		_zoom_at(_big.size / 2.0, pow(2.0, zoom * delta * 1.5))


func _draw_big() -> void:
	var vs := _big.size
	_big.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.06, 0.07, 0.08))
	var rect := Rect2(_w2s(_origin), _size_m * _view_scale)
	_big.draw_texture_rect(_base_vp.get_texture(), rect, false)
	_big.draw_texture_rect(_over_vp.get_texture(), rect, false)
	# noms des rues et des lieux
	var fs := int(clampf(8.0 + _view_scale * 4.0, 11.0, 22.0))
	for sl in _street_labels:
		var at := _w2s(sl[1])
		_big.draw_set_transform(at, sl[2], Vector2.ONE)
		var w := _font.get_string_size(sl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_big.draw_string_outline(_font, Vector2(-w / 2.0, fs * 0.35), sl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
		_big.draw_string(_font, Vector2(-w / 2.0, fs * 0.35), sl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.95, 0.92))
	_big.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for pl in PLACES:
		var at := _w2s(pl[1])
		_big.draw_circle(at, 4.0, Color(0.98, 0.98, 0.95))
		_big.draw_string_outline(_font, at + Vector2(8, 5), pl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		_big.draw_string(_font, at + Vector2(8, 5), pl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.93, 0.7))
	if _home != Vector2.INF:
		var ha := _w2s(_home)
		_house_icon(_big, ha, 10.0)
		_big.draw_string_outline(_font, ha + Vector2(14, 6), "Chez vous", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		_big.draw_string(_font, ha + Vector2(14, 6), "Chez vous", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.6, 1.0, 0.7))
	for car in get_tree().get_nodes_in_group("police_car"):
		var p3 := (car as Node3D).global_position
		var pa := _w2s(Vector2(p3.x, p3.z))
		_big.draw_circle(pa, 7.0, Color(0, 0, 0, 0.85))
		_big.draw_circle(pa, 5.5, Color(0.95, 0.15, 0.15) if int(Time.get_ticks_msec() / 300) % 2 == 0 else Color(0.2, 0.4, 1.0))
	for p in pins:
		var at := _w2s(p)
		_big.draw_line(at, at + Vector2(0, -16), Color(0, 0, 0, 0.9), 3.0)
		_big.draw_circle(at + Vector2(0, -18), 7.0, Color(0, 0, 0, 0.9))
		_big.draw_circle(at + Vector2(0, -18), 5.5, COL_PIN)
	if has_waypoint:
		_diamond(_big, _w2s(waypoint), 10.0, COL_WAYPOINT)
	_arrow(_big, _w2s(_player_pos()), -_player_yaw(), 11.0, Color(1, 1, 1))
	# viseur (clavier / manette)
	var c := vs / 2.0
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_big.draw_line(c + d * 5.0, c + d * 14.0, Color(1, 1, 1, 0.8), 2.0)
	# legende
	var legend := "Clic gauche / Entrée / A : destination     Clic droit / P / X : marqueur     Molette / gâchettes : zoom     Glisser / ZQSD : déplacer     M / Échap : fermer"
	_big.draw_rect(Rect2(0, vs.y - 34, vs.x, 34), Color(0, 0, 0, 0.6))
	_big.draw_string(_font, Vector2(16, vs.y - 12), legend, HORIZONTAL_ALIGNMENT_LEFT, vs.x - 32, 15, Color(0.95, 0.95, 0.95))
	if has_waypoint:
		var t := "Destination : %s" % _fmt_dist(route_length)
		_big.draw_string_outline(_font, Vector2(16, 34), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.9))
		_big.draw_string(_font, Vector2(16, 34), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COL_WAYPOINT)
