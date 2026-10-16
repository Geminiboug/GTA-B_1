extends CanvasLayer
## Deplacement rapide (phase 9) : a pied pres d'une station de zems (motos garees, scripts/props.gd), T ouvre la liste
## des destinations ; 1 a 7 choisit (prix de la course selon la distance, tarifs de zem), fondu, on arrive sur place
## et le temps passe (2 min de jeu par km). Impossible quand la police recherche le joueur.

@export var player_path: NodePath = ^"../Player"
@export var portee := 4.0
@export var prix_base := 200          # FCFA
@export var prix_km := 300            # FCFA par km

# [nom, x, z] (repere du jeu) ; la maison est lue dans scripts/lieux.gd
const DESTINATIONS := [
	["Maison", 0.0, 0.0],
	["Aéroport (aérogare)", 397.0, -300.0],
	["Ararat Hypermarket", 600.0, 150.0],
	["Sweet Dream Beach", 622.0, 292.0],
	["L'Épave Volante", -150.0, 240.0],
	["Haie Verte", -150.0, -840.0],
	["Cadjéhoué", 550.0, -1080.0],
]

var _player: Node3D
var _hud: Node
var _panel: PanelContainer
var _list: VBoxContainer
var _open := false
var _stations: Array = []
var _fade: ColorRect
var _busy := false
var _key_held := {}


func _ready() -> void:
	layer = 6
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null("../HUD")
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.45
	_panel.offset_left = -270
	_panel.offset_right = 270
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_list = VBoxContainer.new()
	_panel.add_child(_list)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_collect.call_deferred()


func _collect() -> void:
	var props := get_node_or_null("../Props")
	if props == null:
		return
	for pk in props.parked:
		if pk.get("model") == "zem":
			var o: Vector3 = (pk["xf"] as Transform3D).origin
			var dup := false
			for s in _stations:
				if (s as Vector3).distance_to(o) < 8.0:
					dup = true
			if not dup:
				_stations.append(o)


func _dest_pos(i: int) -> Vector3:
	if i == 0:
		var lieux := get_node_or_null("../Lieux")
		return lieux.home_position() if lieux else Vector3.ZERO
	return Vector3(DESTINATIONS[i][1], 0.0, DESTINATIONS[i][2])


func prix(i: int) -> int:
	var d := Vector2(_player.global_position.x, _player.global_position.z).distance_to(Vector2(_dest_pos(i).x, _dest_pos(i).z))
	return int(round((prix_base + prix_km * d / 1000.0) / 50.0)) * 50


func near_station() -> bool:
	for s in _stations:
		if (s as Vector3).distance_to(_player.global_position) < portee:
			return true
	return false


func _physics_process(_d: float) -> void:
	if _player == null or _busy:
		return
	if _player.get("vehicle") != null or not near_station():
		_close()
		return
	if not _open:
		if _hud and _hud.has_method("show_hint"):
			_hud.show_hint("T : prendre un zem (déplacement rapide)")
		if Input.is_action_just_pressed("parler"):
			_show()
		return
	if Input.is_action_just_pressed("parler"):
		_close()
		return
	for i in DESTINATIONS.size():
		var down := Input.is_key_pressed(KEY_1 + i)
		if down and not _key_held.get(i, false):
			voyager(i)
		_key_held[i] = down


func voyager(i: int) -> bool:
	if Partie.recherche > 0:
		Partie.notifier("Aucun zem ne veut te prendre : la police te cherche")
		return false
	var p := prix(i)
	if not Partie.payer(p, "Zem vers %s" % DESTINATIONS[i][0]):
		return false
	_close()
	_busy = true
	var to := _dest_pos(i)
	var km := Vector2(_player.global_position.x, _player.global_position.z).distance_to(Vector2(to.x, to.z)) / 1000.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	tw.tween_callback(func() -> void:
		var q := PhysicsRayQueryParameters3D.create(Vector3(to.x, 80, to.z), Vector3(to.x, -10, to.z), 1)
		var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
		_player.global_position = (hit["position"] if not hit.is_empty() else to) + Vector3.UP * 0.2
		_player.reset_physics_interpolation()
		var jn := get_node_or_null("../JourNuit")
		if jn:
			jn.set("hour", fmod(float(jn.get("hour")) + km * 2.0 / 60.0, 24.0))
		if _hud and _hud.has_method("show_place"):
			_hud.show_place(DESTINATIONS[i][0]))
	tw.tween_interval(0.8)
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	tw.tween_callback(func() -> void: _busy = false)
	return true


func _show() -> void:
	_open = true
	_panel.visible = true
	for c in _list.get_children():
		c.free()
	var t := Label.new()
	t.text = "Zem : où on va ?   (%s en poche)" % Partie.fcfa(Partie.argent)
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_list.add_child(t)
	for i in DESTINATIONS.size():
		var l := Label.new()
		l.text = "%d.  %s   %s" % [i + 1, DESTINATIONS[i][0], Partie.fcfa(prix(i))]
		l.add_theme_font_size_override("font_size", 20)
		_list.add_child(l)
	var h := Label.new()
	h.text = "1-%d : partir    T : fermer" % DESTINATIONS.size()
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_list.add_child(h)


func _close() -> void:
	_open = false
	_panel.visible = false
