extends SceneTree
## Mesure du cout CPU par image physique (headless) : scene complete, puis sans circulation, puis sans pietons.
## Lancement : godot --headless --path godot --script res://tests/perf_frames.gd

var frame := 0
var scene: Node
var t0 := 0
var phase := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		t0 = Time.get_ticks_usec()
	elif frame == 90:
		print("PERF scene complete : physique %.2f ms, process %.2f ms" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		scene.get_node("Circulation").process_mode = Node.PROCESS_MODE_DISABLED
		t0 = Time.get_ticks_usec()
	elif frame == 150:
		print("PERF sans circulation : physique %.2f ms, process %.2f ms" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		scene.get_node("Pietons").process_mode = Node.PROCESS_MODE_DISABLED
		t0 = Time.get_ticks_usec()
	elif frame == 210:
		print("PERF sans circulation ni pietons : physique %.2f ms, process %.2f ms" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		return true
	return false
