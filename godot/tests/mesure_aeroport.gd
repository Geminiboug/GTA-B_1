extends SceneTree
func _init() -> void:
	var c := Carte.zone()
	var kinds := {}
	for ed in c.edges:
		kinds[ed["kind"]] = int(kinds.get(ed["kind"], 0)) + 1
	print("kinds aretes : ", kinds)
	var zk := {}
	for z in c.data.get("zones", []):
		zk[z["kind"]] = int(zk.get(z["kind"], 0)) + 1
	print("zones : ", zk)
	print("cles data : ", c.data.keys())
	print("pistes : ", c.data.get("runways", []).size(), " taxiways : ", c.data.get("taxiways", []).size())
	quit()
