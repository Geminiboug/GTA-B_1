extends SceneTree
## Mesure (avec fenetre) : ce que la zone garde en memoire apres la mise en place : tuiles posees, objets et sommets
## dessines, memoire video (textures, tampons) et memoire vive, par systeme (nombre de MeshInstance3D / MultiMesh).
## Lancement : godot --path godot --script res://tests/mesure_memoire.gd
var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	if frame % 100 == 0:
		print("image ", frame, " ", Time.get_ticks_msec())
	if frame < 600:
		return false
	var monde: Node = null
	for n in scene.get_children():
		if n.has_method("chargee"):
			monde = n
	var posees := 0
	if monde:
		for c in monde.get("tuiles"):
			posees += 1 if monde.get("tuiles")[c]["noeud"] != null else 0
	print("tuiles posees : %d / %d" % [posees, (monde.get("tuiles") as Dictionary).size() if monde else 0])
	print("memoire video : %.0f Mo (textures %.0f Mo, tampons %.0f Mo), memoire vive %.0f Mo" % [
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1e6, Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6])
	print("objets dessines %d, primitives %d, appels %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	for n in scene.get_children():
		var mi := n.find_children("*", "MeshInstance3D", true, false).size()
		var mm := n.find_children("*", "MultiMeshInstance3D", true, false)
		var inst := 0
		for m in mm:
			if (m as MultiMeshInstance3D).multimesh:
				inst += (m as MultiMeshInstance3D).multimesh.instance_count
		if mi + mm.size() > 20:
			print("  %s : %d MeshInstance3D, %d MultiMesh (%d instances)" % [n.name, mi, mm.size(), inst])
	quit()
	return true
