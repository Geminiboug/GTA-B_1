extends Node3D
## Balisage lumineux de l'aerodrome (piste 06/24, 2 400 m) :
## - feux de bord de piste blancs tous les 60 m, feux de seuil verts et d'extremite rouges ;
## - rampes d'approche (420 m, barres de 5 feux tous les 30 m, barre transversale a 300 m) aux deux bouts ;
## - feux de bord de taxiway bleus tous les 30 m ;
## - PAPI (4 optiques a gauche de la piste, a 300 m de chaque seuil) : rouge / blanc selon l'angle de vue, de jour
##   comme de nuit (godot/shaders/papi.gdshader).
## Les feux s'allument au crepuscule (et par forte pluie). Axe de piste : donnees OSM de la zone, prolonge a 2 400 m.

const FEU := preload("res://shaders/feu.gdshader")
const PAPI := preload("res://shaders/papi.gdshader")
const RUNWAY_LENGTH := 2400.0
const HALF_WIDTH := 22.5

var _mats: Array[ShaderMaterial] = []
var _day: Node
var _weather: Node
var _t := 0.0
var thresholds: Array = []       # [[seuil (Vector2), direction d'atterrissage (Vector2), nom]] : utilise par air_traffic.gd


func _ready() -> void:
	_day = get_node_or_null("../JourNuit")
	_weather = get_node_or_null("../Meteo")
	var data: Dictionary = Carte.zone().data
	var best: Array = []
	for r in data.get("runways", []):
		if r.size() > best.size():
			best = r
	if best.size() < 2:
		return
	var p0 := Vector2(float(best[0][0]), float(best[0][1]))
	var p1 := Vector2(float(best[-1][0]), float(best[-1][1]))
	if p1.x < p0.x:
		var tmp := p0
		p0 = p1
		p1 = tmp
	var u := (p1 - p0).normalized()
	var a := p0
	var b := p0 + u * RUNWAY_LENGTH
	var n := Vector2(-u.y, u.x)
	thresholds = [[a, u, "06"], [b, -u, "24"]]
	var white: Array = []
	var green: Array = []
	var red: Array = []
	var blue: Array = []
	# bords de piste
	var t := 0.0
	while t <= RUNWAY_LENGTH + 0.1:
		for s: float in [-1.0, 1.0]:
			white.append(_v(a + u * t + n * s * (HALF_WIDTH + 1.0), 0.35))
		t += 60.0
	for th in thresholds:
		var e: Vector2 = th[0]
		var d: Vector2 = th[1]
		# seuil (vert, vers l'avion qui arrive) et fin de piste pour l'autre sens (rouge)
		for k in 8:
			var off := -HALF_WIDTH + 2.5 + k * (2.0 * HALF_WIDTH - 5.0) / 7.0
			green.append(_v(e - d * 3.0 + n * off, 0.3))
			red.append(_v(e - d * 1.5 + n * off, 0.3))
		# rampe d'approche
		var ta := 30.0
		while ta <= 420.0:
			var c := e - d * ta
			var h := 0.5 + ta * 0.012
			var bar := 15 if absf(ta - 300.0) < 1.0 else 5
			for k in bar:
				white.append(_v(c + n * (k - (bar - 1) * 0.5) * (2.0 if bar > 5 else 1.0), h))
			ta += 30.0
		_papi(e, d)
	# taxiways
	for aw in data.get("aeroways", []):
		if aw["kind"] != "taxiway":
			continue
		var pts: Array = aw["pts"]
		var hw := float(aw.get("width", 23.0)) * 0.5 + 1.0
		var carry := 0.0
		for k in pts.size() - 1:
			var q0 := Vector2(float(pts[k][0]), float(pts[k][1]))
			var q1 := Vector2(float(pts[k + 1][0]), float(pts[k + 1][1]))
			var seg := q0.distance_to(q1)
			if seg < 0.1:
				continue
			var dir := (q1 - q0) / seg
			var nn := Vector2(-dir.y, dir.x)
			var s2 := carry
			while s2 < seg:
				for sd: float in [-1.0, 1.0]:
					blue.append(_v(q0 + dir * s2 + nn * sd * hw, 0.3))
				s2 += 30.0
			carry = s2 - seg
	_lights(white, Color(1.0, 0.95, 0.82), 3.0, "FeuxPisteBlancs")
	_lights(green, Color(0.2, 1.0, 0.35), 3.5, "FeuxSeuil")
	_lights(red, Color(1.0, 0.12, 0.08), 3.0, "FeuxFinPiste")
	_lights(blue, Color(0.25, 0.4, 1.0), 2.5, "FeuxTaxiway")
	_update(true)


func _v(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, p.y)


func _lights(points: Array, col: Color, energy: float, name_: String) -> void:
	if points.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = FEU
	m.set_shader_parameter("color", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("energy", energy)
	quad.material = m
	_mats.append(m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = points.size()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in points.size():
		var p: Vector3 = points[i]
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		lo = lo.min(p)
		hi = hi.max(p)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# les feux grossissent avec la distance dans le shader : boite englobante elargie
	mmi.custom_aabb = AABB(lo - Vector3(20, 20, 20), hi - lo + Vector3(40, 40, 40))
	add_child(mmi)


func _papi(e: Vector2, d: Vector2) -> void:
	## 4 optiques a gauche de la piste (vue de l'avion qui arrive), a 300 m du seuil.
	var left := Vector2(d.y, -d.x)
	var base := e + d * 300.0 + left * (HALF_WIDTH + 15.0)
	var angles := [3.5, 3.17, 2.83, 2.5]      # de la plus proche de la piste a la plus eloignee
	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color(0.18, 0.18, 0.2)
	for k in 4:
		var p := base + left * (k * 9.0)
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 0.7, 0.9)
		box.material = housing
		body.mesh = box
		add_child(body)
		body.global_position = Vector3(p.x, 0.55, p.y)
		body.global_rotation.y = atan2(-d.x, -d.y)
		for leg: float in [-0.5, 0.5]:
			var lg := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.04
			cyl.bottom_radius = 0.04
			cyl.height = 0.4
			cyl.material = housing
			lg.mesh = cyl
			body.add_child(lg)
			lg.position = Vector3(leg, -0.4, 0)
		# optique (face tournee vers l'approche)
		var lens := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.1, 0.42)
		var m := ShaderMaterial.new()
		m.shader = PAPI
		m.set_shader_parameter("angle_deg", angles[k])
		m.set_shader_parameter("approach_dir", Vector3(-d.x, 0, -d.y))
		q.material = m
		lens.mesh = q
		body.add_child(lens)
		lens.position = Vector3(0, 0.02, 0.46)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_update(false)


func _update(_force: bool) -> void:
	var night: float = _day.get("night") if _day else 0.0
	var rain: float = _weather.get("rain") if _weather and _weather.get("rain") != null else 0.0
	var on := clampf(maxf(smoothstep(0.15, 0.45, night), smoothstep(0.5, 0.9, rain)), 0.0, 1.0)
	for m in _mats:
		m.set_shader_parameter("on", on)
