extends SceneTree
## Repartition du temps d'une image (process, physique, rendu) dans la zone, avec le joueur actuel.

var frame := 0
var acc := Vector4.ZERO


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.add_child(load("res://scenes/zone_aeroport.tscn").instantiate())


func _process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	acc += Vector4(Performance.get_monitor(Performance.TIME_PROCESS), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if frame == 420:
		acc /= 300.0
		print("process %.1f ms  physique %.1f ms  images/s %.0f  appels %.0f" % [acc.x * 1000.0, acc.y * 1000.0, acc.z, acc.w])
		return true
	return false
