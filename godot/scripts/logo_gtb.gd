class_name LogoGtb
extends Control
## Logo GTB (planche de marque d'Olympe) avec l'animation 2 validee le 22/10/2026 : un halo de lumiere s'ouvre,
## le logo apparait avec une legere mise a l'echelle et un eclat qui retombe, en 2,5 s.
## Texte alternatif : si l'image manque, le mot GTB est affiche.

const IMAGE := "res://assets/ui/logo_gtb.png"

@export var duree := 2.5
@export var rejouer_au_affichage := true

var _logo: TextureRect
var _halo: TextureRect
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.78, 0.16, 0.5), Color(0.9, 0.49, 0.13, 0.12), Color(0.9, 0.49, 0.13, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_halo = TextureRect.new()
	_halo.texture = gt
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_halo.modulate.a = 0.0
	add_child(_halo)
	_logo = TextureRect.new()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(IMAGE):
		_logo.texture = load(IMAGE)
	else:
		var l := Label.new()
		l.text = "GTB"
		l.add_theme_font_size_override("font_size", 96)
		l.add_theme_color_override("font_color", Color(1.0, 0.78, 0.16))
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_logo.add_child(l)
	add_child(_logo)
	resized.connect(_centrer)
	_centrer()
	if rejouer_au_affichage:
		jouer()


func _centrer() -> void:
	if _logo:
		_logo.pivot_offset = size * 0.5
		_halo.pivot_offset = size * 0.5


func jouer() -> void:
	if _tween:
		_tween.kill()
	if DisplayServer.get_name() == "headless":
		_logo.modulate = Color(1, 1, 1, 1)
		_logo.scale = Vector2.ONE
		_halo.modulate.a = 0.35
		return
	_logo.modulate = Color(3, 3, 3, 0)
	_logo.scale = Vector2(0.9, 0.9)
	_halo.modulate.a = 0.0
	_halo.scale = Vector2(0.15, 0.15)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_halo, "modulate:a", 1.0, duree * 0.35).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_halo, "scale", Vector2(0.7, 0.7), duree * 0.35).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_halo, "scale", Vector2(1.1, 1.1), duree * 0.65).set_delay(duree * 0.35)
	_tween.tween_property(_halo, "modulate:a", 0.35, duree * 0.65).set_delay(duree * 0.35)
	_tween.tween_property(_logo, "modulate", Color(1, 1, 1, 1), duree * 0.7).set_delay(duree * 0.18).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_logo, "scale", Vector2.ONE, duree * 0.8).set_delay(duree * 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
