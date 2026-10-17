class_name Limiteur
## Limiteur de vitesse des vehicules conduits par le joueur (demande d'Olympe du 17/10/2026) : K (manette : croix bas)
## l'active ou le coupe ; tant qu'il est actif, l'accelerateur ne depasse pas vitesse_kmh, sous la limite au-dela
## de laquelle la police donne une contravention (scripts/police.gd, limite_vitesse : 70 km/h). Etat partage entre la
## voiture et le zem (on le garde en changeant de vehicule), affiche sous le compteur (scripts/hud_jeu.gd).

static var actif := false
static var vitesse_kmh := 50.0


static func entrees() -> void:
	## A appeler une fois par image depuis le vehicule conduit : bascule sur K / croix bas.
	if not InputMap.has_action("limiteur"):
		InputMap.add_action("limiteur")
		var k := InputEventKey.new()
		k.physical_keycode = KEY_K
		InputMap.action_add_event("limiteur", k)
		var j := InputEventJoypadButton.new()
		j.button_index = JOY_BUTTON_DPAD_DOWN
		InputMap.action_add_event("limiteur", j)
	if Input.is_action_just_pressed("limiteur"):
		actif = not actif


static func gaz(acc_in: float, speed: float) -> float:
	## Accelerateur limite : on relache en approchant de la consigne, rien au-dessus (le frein moteur fait le reste).
	if not actif:
		return acc_in
	var marge := vitesse_kmh / 3.6 - speed
	return minf(acc_in, clampf(marge / 1.5, 0.0, 1.0))


static func retenue(speed: float) -> float:
	## Frein doux si l'on depasse la consigne (descente, limiteur active en roulant vite).
	if not actif:
		return 0.0
	return clampf((speed - vitesse_kmh / 3.6 - 1.0) / 4.0, 0.0, 0.5)
