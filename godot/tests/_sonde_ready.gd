extends SceneTree
var t := 0
var res := []
var fait := false
func _process(_d: float) -> bool:
	if fait:
		return true
	fait = true
	var z: Node = (load("res://scenes/zone_aeroport.tscn") as PackedScene).instantiate()
	for c in z.get_children():
		c.ready.connect(func() -> void:
			var n := Time.get_ticks_usec()
			res.append([(n - t) / 1000.0, c.name])
			t = n)
	t = Time.get_ticks_usec()
	var t0 := t
	root.add_child(z)
	res.sort_custom(func(a, b): return a[0] > b[0])
	for r in res.slice(0, 15):
		print("SONDE %7.0f ms %s" % r)
	print("SONDE total %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
	quit()
	return true
