extends SceneTree
func _init() -> void:
	var c := Carte.zone()
	var n3 := 0
	var n4 := 0
	var maj2 := 0
	var maj3 := 0
	for n in c.nodes.size():
		var d := c.node_degree(n)
		if d == 3: n3 += 1
		if d >= 4: n4 += 1
		var m := 0
		for e in c.node_edges[n]:
			if c.edges[e]["major"]:
				m += 1
		if d >= 3 and m >= 2: maj2 += 1
		if d >= 3 and m >= 3: maj3 += 1
	print("noeuds ", c.nodes.size(), " deg3 ", n3, " deg4+ ", n4, " >=2 majeures ", maj2, " >=3 majeures ", maj3)
	quit()
