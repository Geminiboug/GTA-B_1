extends SceneTree
## Icone provisoire du jeu (en attendant le logo d'Olympe) : "GTB" jaune zem sur fond nuit, bande verte, palette du
## jeu (scripts/chargement.gd). Lancement (avec fenetre) : godot --path godot --script res://tools/faire_icone.gd
var vp: SubViewport
var f := 0
func _initialize() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fond := ColorRect.new()
	fond.color = Color("#17140F")
	fond.size = Vector2(1024, 1024)
	vp.add_child(fond)
	var bande := ColorRect.new()
	bande.color = Color("#008751")
	bande.position = Vector2(0, 760)
	bande.size = Vector2(1024, 90)
	vp.add_child(bande)
	var laterite := ColorRect.new()
	laterite.color = Color("#B0472B")
	laterite.position = Vector2(0, 850)
	laterite.size = Vector2(1024, 40)
	vp.add_child(laterite)
	var l := Label.new()
	l.text = "GTB"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(1024, 760)
	l.add_theme_font_size_override("font_size", 420)
	l.add_theme_color_override("font_color", Color("#F2BB2C"))
	l.add_theme_color_override("font_outline_color", Color("#B0472B"))
	l.add_theme_constant_override("outline_size", 36)
	var fnt := SystemFont.new()
	fnt.font_names = PackedStringArray(["Arial Black", "Impact", "Arial"])
	fnt.font_weight = 900
	l.add_theme_font_override("font", fnt)
	vp.add_child(l)
func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		vp.get_texture().get_image().save_png("res://icone.png")
		print("icone ecrite")
		return true
	return false
